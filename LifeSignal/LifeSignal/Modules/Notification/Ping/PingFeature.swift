import Foundation
import ComposableArchitecture
import FirebaseAuth
import FirebaseFunctions
import Dependencies
import UserNotifications

/// Feature for managing ping operations between users
@Reducer
struct PingFeature {
    /// The state of the ping feature
    @ObservableState
    struct State: Equatable, Sendable {
        /// Loading state
        var isLoading: Bool = false

        /// UI state
        var showPingConfirmation: Bool = false
        var showClearPingConfirmation: Bool = false

        /// Notification authorization status
        var authorizationStatus: UNAuthorizationStatus = .notDetermined

        /// Error state
        var error: UserFacingError?
    }

    /// Actions that can be performed on the ping feature
    @CasePathable
    enum Action: Equatable, Sendable {
        /// Set whether to show the ping confirmation dialog
        case setShowPingConfirmation(Bool)

        /// Set whether to show the clear ping confirmation dialog
        case setShowClearPingConfirmation(Bool)

        /// Check notification authorization status
        case checkAuthorizationStatus
        case authorizationStatusUpdated(UNAuthorizationStatus)

        /// Request notification authorization
        case requestAuthorization
        case authorizationRequestSucceeded(Bool)
        case authorizationRequestFailed(UserFacingError)

        /// Ping a dependent
        case pingDependent(id: String)
        case dependentPinged(id: String)
        case dependentPingError(id: String, UserFacingError)

        /// Clear a ping
        case clearPing(id: String)
        case pingCleared(id: String)
        case pingClearError(id: String, UserFacingError)

        /// Respond to a ping
        case respondToPing(id: String)
        case pingResponseSent(id: String)
        case pingResponseError(id: String, UserFacingError)

        /// Respond to all pings
        case respondToAllPings
        case allPingsResponseSent
        case allPingsResponseError(UserFacingError)

        /// Delegate actions
        case delegate(DelegateAction)

        /// Clear any error state
        case clearError

        /// Actions that will be delegated to parent features
        enum DelegateAction: Equatable, Sendable {
            case pingUpdated(id: String, hasOutgoingPing: Bool, outgoingPingTimestamp: Date?)
            case pingResponseUpdated(id: String, hasIncomingPing: Bool, incomingPingTimestamp: Date?)
            case allPingsResponseUpdated
            case pingOperationFailed(UserFacingError)
        }
    }

    /// Dependencies
    @Dependency(\.firebaseAuth) var firebaseAuth
    @Dependency(\.timeFormatter) var timeFormatter
    @Dependency(\.firebaseNotification) var firebaseNotification

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .setShowPingConfirmation(show):
                state.showPingConfirmation = show
                return .none

            case let .setShowClearPingConfirmation(show):
                state.showClearPingConfirmation = show
                return .none

            case let .pingDependent(id):
                state.isLoading = true

                return .run { send in
                    do {
                        // Get the authenticated user ID or throw if not available
                        let userId = try await firebaseAuth.currentUserId()

                        // Call the Firebase function to ping the dependent
                        let data: [String: Any] = [
                            "dependentId": id
                        ]

                        let functions = Functions.functions()
                        let result = try await functions.httpsCallable("pingDependent").call(data)

                        guard let _ = result.data as? [String: Any] else {
                            throw FirebaseError.invalidData
                        }

                        // Update the timestamp to the current time
                        let now = Date()

                        // Try to send a notification about the ping
                        do {
                            _ = try await firebaseNotification.showLocalNotification(
                                "Ping Sent",
                                "You have sent a ping to your contact.",
                                ["type": "pingNotification", "contactId": id]
                            )
                        } catch {
                            // Log but don't fail the operation if notification fails
                            FirebaseLogger.notification.warning("Failed to show ping notification: \(error.localizedDescription)")
                        }

                        // Notify parent feature about the successful ping
                        await send(.delegate(.pingUpdated(id: id, hasOutgoingPing: true, outgoingPingTimestamp: now)))

                        // Send success action
                        await send(.dependentPinged(id: id))
                    } catch {
                        // Map the error to a user-facing error
                        let userFacingError = UserFacingError.from(error)

                        // Handle error directly in the effect
                        await send(.dependentPingError(id: id, userFacingError))

                        // Notify parent feature about the failure
                        await send(.delegate(.pingOperationFailed(userFacingError)))
                    }
                }

            case .dependentPinged:
                state.isLoading = false
                return .none

            case let .dependentPingError(_, error):
                state.isLoading = false
                state.error = error

                // Log the error
                FirebaseLogger.contacts.error("Dependent ping failed: \(error)")
                return .none

            case let .clearPing(id):
                state.isLoading = true

                return .run { send in
                    do {
                        // Get the authenticated user ID or throw if not available
                        let userId = try await firebaseAuth.currentUserId()

                        // Call the Firebase function to clear the ping
                        let data: [String: Any] = [
                            "userId": userId,
                            "contactId": id
                        ]

                        let functions = Functions.functions()
                        let result = try await functions.httpsCallable("clearPing").call(data)

                        guard let _ = result.data as? [String: Any] else {
                            throw FirebaseError.invalidData
                        }

                        // Try to send a notification about clearing the ping
                        do {
                            _ = try await firebaseNotification.showLocalNotification(
                                "Ping Cleared",
                                "You have cleared your ping.",
                                ["type": "pingClearedNotification", "contactId": id]
                            )
                        } catch {
                            // Log but don't fail the operation if notification fails
                            FirebaseLogger.notification.warning("Failed to show ping cleared notification: \(error.localizedDescription)")
                        }

                        // Notify parent feature about the successful ping clear
                        await send(.delegate(.pingUpdated(id: id, hasOutgoingPing: false, outgoingPingTimestamp: nil)))

                        // Send success action
                        await send(.pingCleared(id: id))
                    } catch {
                        // Map the error to a user-facing error
                        let userFacingError = UserFacingError.from(error)

                        // Handle error directly in the effect
                        await send(.pingClearError(id: id, userFacingError))

                        // Notify parent feature about the failure
                        await send(.delegate(.pingOperationFailed(userFacingError)))
                    }
                }

            case .pingCleared:
                state.isLoading = false
                return .none

            case let .pingClearError(_, error):
                state.isLoading = false
                state.error = error

                // Log the error
                FirebaseLogger.contacts.error("Ping clear failed: \(error)")
                return .none

            case let .respondToPing(id):
                state.isLoading = true

                return .run { send in
                    do {
                        // Get the authenticated user ID or throw if not available
                        let userId = try await firebaseAuth.currentUserId()

                        // Call the Firebase function to respond to the ping
                        let data: [String: Any] = [
                            "responderId": id
                        ]

                        let functions = Functions.functions()
                        let result = try await functions.httpsCallable("respondToPing").call(data)

                        guard let _ = result.data as? [String: Any] else {
                            throw FirebaseError.invalidData
                        }

                        // Try to send a notification about responding to the ping
                        do {
                            _ = try await firebaseNotification.showLocalNotification(
                                "Ping Response Sent",
                                "You have responded to a ping.",
                                ["type": "pingResponseNotification", "contactId": id]
                            )
                        } catch {
                            // Log but don't fail the operation if notification fails
                            FirebaseLogger.notification.warning("Failed to show ping response notification: \(error.localizedDescription)")
                        }

                        // Notify parent feature about the successful ping response
                        await send(.delegate(.pingResponseUpdated(id: id, hasIncomingPing: false, incomingPingTimestamp: nil)))

                        // Send success action
                        await send(.pingResponseSent(id: id))
                    } catch {
                        // Map the error to a user-facing error
                        let userFacingError = UserFacingError.from(error)

                        // Handle error directly in the effect
                        await send(.pingResponseError(id: id, userFacingError))

                        // Notify parent feature about the failure
                        await send(.delegate(.pingOperationFailed(userFacingError)))
                    }
                }

            case .pingResponseSent:
                state.isLoading = false
                return .none

            case let .pingResponseError(_, error):
                state.isLoading = false
                state.error = error

                // Log the error
                FirebaseLogger.contacts.error("Ping response failed: \(error)")
                return .none

            case .respondToAllPings:
                state.isLoading = true

                return .run { send in
                    do {
                        // Get the authenticated user ID or throw if not available
                        let userId = try await firebaseAuth.currentUserId()

                        // Call the Firebase function to respond to all pings
                        let functions = Functions.functions()
                        let result = try await functions.httpsCallable("respondToAllPings").call(nil)

                        guard let _ = result.data as? [String: Any] else {
                            throw FirebaseError.invalidData
                        }

                        // Try to send a notification about responding to all pings
                        do {
                            _ = try await firebaseNotification.showLocalNotification(
                                "All Pings Responded",
                                "You have responded to all pending pings.",
                                ["type": "allPingsResponseNotification"]
                            )
                        } catch {
                            // Log but don't fail the operation if notification fails
                            FirebaseLogger.notification.warning("Failed to show all pings response notification: \(error.localizedDescription)")
                        }

                        // Notify parent feature about the successful response to all pings
                        await send(.delegate(.allPingsResponseUpdated))

                        // Send success action
                        await send(.allPingsResponseSent)
                    } catch {
                        // Map the error to a user-facing error
                        let userFacingError = UserFacingError.from(error)

                        // Handle error directly in the effect
                        await send(.allPingsResponseError(userFacingError))

                        // Notify parent feature about the failure
                        await send(.delegate(.pingOperationFailed(userFacingError)))
                    }
                }

            case .allPingsResponseSent:
                state.isLoading = false
                return .none

            case let .allPingsResponseError(error):
                state.isLoading = false
                state.error = error

                // Log the error
                FirebaseLogger.contacts.error("All pings response failed: \(error)")
                return .none

            case .delegate:
                // These actions are handled by the parent feature
                return .none

            case .clearError:
                state.error = nil
                return .none
            }
        }
    }
}
