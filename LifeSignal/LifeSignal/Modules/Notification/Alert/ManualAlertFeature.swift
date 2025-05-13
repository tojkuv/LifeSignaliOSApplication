import Foundation
import ComposableArchitecture
import FirebaseAuth
import Dependencies

/// Feature for managing manual alerts
@Reducer
struct AlertFeature {
    /// The state of the alert feature
    @ObservableState
    struct State: Equatable, Sendable {
        /// Whether a manual alert is active
        var isAlertActive: Bool = false

        /// When the alert was triggered
        var alertTimestamp: Date? = nil

        /// Loading state
        var isLoading: Bool = false

        /// UI state
        var showAlertConfirmation: Bool = false
        var showClearAlertConfirmation: Bool = false

        /// Error state
        var error: UserFacingError?
    }

    /// Actions that can be performed on the alert feature
    @CasePathable
    enum Action: Equatable, Sendable {
        /// Update alert state from user data
        case updateAlertState(isActive: Bool, timestamp: Date?)

        /// Set whether to show the alert confirmation dialog
        case setShowAlertConfirmation(Bool)

        /// Set whether to show the clear alert confirmation dialog
        case setShowClearAlertConfirmation(Bool)

        /// Trigger manual alert
        case triggerManualAlert
        case triggerManualAlertSucceeded
        case triggerManualAlertError(UserFacingError)

        /// Clear manual alert
        case clearManualAlert
        case clearManualAlertSucceeded
        case clearManualAlertError(UserFacingError)

        /// Clear any error state
        case clearError
    }

    /// Dependencies
    @Dependency(\.firebaseUserClient) var firebaseUserClient
    @Dependency(\.firebaseAuth) var firebaseAuth
    @Dependency(\.firebaseNotification) var firebaseNotification

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .updateAlertState(isActive, timestamp):
                state.isAlertActive = isActive
                state.alertTimestamp = timestamp
                return .none

            case let .setShowAlertConfirmation(show):
                state.showAlertConfirmation = show
                return .none

            case let .setShowClearAlertConfirmation(show):
                state.showClearAlertConfirmation = show
                return .none

            case .triggerManualAlert:
                state.isLoading = true
                // Update local state immediately for better UX
                state.isAlertActive = true
                state.alertTimestamp = Date()

                return .run { send in
                    do {
                        // Get the authenticated user ID or throw if not available
                        let userId = try await firebaseAuth.currentUserId()

                        // Get user name for notification
                        let userData = try await firebaseUserClient.getUserDocument(userId)

                        // Trigger manual alert using the client
                        let success = try await firebaseUserClient.triggerManualAlert(userId)

                        if success {
                            // Send a notification to confirm the alert was activated
                            let notificationSent = try await firebaseNotification.sendManualAlertNotification(userData.name)
                            if !notificationSent {
                                // Log that notification wasn't sent, but don't throw an error
                                FirebaseLogger.user.warning("Manual alert notification could not be sent for user \(userData.name)")
                            }

                            // Send success response
                            await send(.triggerManualAlertSucceeded)
                        } else {
                            // Handle the case where the operation returned false but didn't throw
                            let userFacingError = UserFacingError.operationFailed("Failed to trigger manual alert")
                            await send(.triggerManualAlertError(userFacingError))
                        }
                    } catch {
                        // Map the error to a user-facing error
                        let userFacingError = UserFacingError.from(error)

                        // Handle error directly in the effect
                        await send(.triggerManualAlertError(userFacingError))
                    }
                }

            case .triggerManualAlertSucceeded:
                state.isLoading = false
                // Alert was already updated in state when action was dispatched
                return .none

            case let .triggerManualAlertError(error):
                state.isLoading = false
                // Revert the local state change if there was an error
                state.isAlertActive = false
                state.alertTimestamp = nil
                state.error = error

                // Log the error
                FirebaseLogger.user.error("Manual alert trigger failed: \(error)")
                return .none

            case .clearManualAlert:
                state.isLoading = true
                // Update local state immediately for better UX
                state.isAlertActive = false
                state.alertTimestamp = nil

                return .run { send in
                    do {
                        // Get the authenticated user ID or throw if not available
                        let userId = try await firebaseAuth.currentUserId()

                        // Get user name for notification
                        let userData = try await firebaseUserClient.getUserDocument(userId)

                        // Clear manual alert using the client
                        let success = try await firebaseUserClient.clearManualAlert(userId)

                        if success {
                            // Send a notification to confirm the alert was cleared
                            let notificationSent = try await firebaseNotification.clearManualAlertNotification(userData.name)
                            if !notificationSent {
                                // Log that notification wasn't sent, but don't throw an error
                                FirebaseLogger.user.warning("Manual alert clear notification could not be sent for user \(userData.name)")
                            }

                            // Send success response
                            await send(.clearManualAlertSucceeded)
                        } else {
                            // Handle the case where the operation returned false but didn't throw
                            let userFacingError = UserFacingError.operationFailed("Failed to clear manual alert")
                            await send(.clearManualAlertError(userFacingError))
                        }
                    } catch {
                        // Map the error to a user-facing error
                        let userFacingError = UserFacingError.from(error)

                        // Handle error directly in the effect
                        await send(.clearManualAlertError(userFacingError))
                    }
                }

            case .clearManualAlertSucceeded:
                state.isLoading = false
                // Alert was already updated in state when action was dispatched
                return .none

            case let .clearManualAlertError(error):
                state.isLoading = false
                // Revert the local state change if there was an error
                state.isAlertActive = true
                state.alertTimestamp = Date()
                state.error = error

                // Log the error
                FirebaseLogger.user.error("Manual alert clear failed: \(error)")
                return .none

            case .clearError:
                state.error = nil
                return .none
            }
        }
    }
}
