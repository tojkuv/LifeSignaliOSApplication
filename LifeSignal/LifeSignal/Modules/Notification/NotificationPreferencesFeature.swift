import Foundation
import ComposableArchitecture
import Dependencies
import FirebaseFirestore
import UserNotifications

/// Feature for managing notification preferences
@Reducer
struct NotificationFeature {
    /// The state of the notification feature
    @ObservableState
    struct State: Equatable, Sendable {
        /// Whether notifications are enabled
        var notificationEnabled: Bool = true

        /// Whether to notify 30 minutes before check-in expiration
        var notify30MinBefore: Bool = true

        /// Whether to notify 2 hours before check-in expiration
        var notify2HoursBefore: Bool = false

        /// Current notification authorization status
        var authorizationStatus: UNAuthorizationStatus = .notDetermined

        /// Loading state
        var isLoading: Bool = false

        /// Error state
        var error: UserFacingError?
    }

    /// Actions that can be performed on the notification feature
    @CasePathable
    enum Action: Equatable, Sendable {
        /// Update notification state from user data
        case updateNotificationState(enabled: Bool, notify30Min: Bool, notify2Hours: Bool)

        /// Check notification authorization status
        case checkAuthorizationStatus
        case authorizationStatusUpdated(UNAuthorizationStatus)

        /// Request notification authorization
        case requestAuthorization
        case authorizationRequestSucceeded(Bool)
        case authorizationRequestFailed(UserFacingError)

        /// Update notification settings (enabled/disabled)
        case updateNotificationSettings(enabled: Bool)
        case updateNotificationSettingsSucceeded
        case updateNotificationSettingsError(UserFacingError)

        /// Update notification preferences (timing)
        case updateNotificationPreferences(notify30Min: Bool, notify2Hours: Bool)
        case updateNotificationPreferencesSucceeded
        case updateNotificationPreferencesError(UserFacingError)

        /// Update FCM token
        case updateFCMToken(String)
        case updateFCMTokenSucceeded
        case updateFCMTokenError(UserFacingError)

        /// Clear any error state
        case clearError
    }

    /// Dependencies
    @Dependency(\.firebaseUserClient) var firebaseUserClient
    @Dependency(\.firebaseAuth) var firebaseAuth
    @Dependency(\.firebaseNotification) var firebaseNotification
    @Dependency(\.firebaseTimestampManager) var timestampManager

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .updateNotificationState(enabled, notify30Min, notify2Hours):
                state.notificationEnabled = enabled
                state.notify30MinBefore = notify30Min
                state.notify2HoursBefore = notify2Hours
                return .none

            case .checkAuthorizationStatus:
                return .run { send in
                    let status = await firebaseNotification.getAuthorizationStatus()
                    await send(.authorizationStatusUpdated(status))
                }

            case let .authorizationStatusUpdated(status):
                state.authorizationStatus = status
                return .none

            case .requestAuthorization:
                state.isLoading = true
                return .run { send in
                    do {
                        let authorized = try await firebaseNotification.requestAuthorization()
                        await send(.authorizationRequestSucceeded(authorized))
                    } catch {
                        let userFacingError = UserFacingError.from(error)
                        await send(.authorizationRequestFailed(userFacingError))
                    }
                }

            case let .authorizationRequestSucceeded(authorized):
                state.isLoading = false
                if authorized {
                    state.authorizationStatus = .authorized
                } else {
                    state.authorizationStatus = .denied
                }
                return .none

            case let .authorizationRequestFailed(error):
                state.isLoading = false
                state.error = error
                return .none

            case let .updateNotificationSettings(enabled):
                state.isLoading = true
                // Update local state immediately for better UX
                state.notificationEnabled = enabled

                return .run { [notify30Min = state.notify30MinBefore, notify2Hours = state.notify2HoursBefore] send in
                    do {
                        // First check if we have notification permission if enabling notifications
                        if enabled {
                            let status = await firebaseNotification.getAuthorizationStatus()
                            if status != .authorized {
                                // Request authorization if not already authorized
                                let authorized = try await firebaseNotification.requestAuthorization()
                                if !authorized {
                                    throw UserFacingError.permissionDenied("Notification permission is required to enable notifications")
                                }
                            }
                        }

                        let userId = try await firebaseAuth.currentUserId()

                        // Get user data for check-in expiration
                        let userData = try await firebaseUserClient.getUserDocument(userId)

                        // Create notification preferences with updated enabled state
                        let preferences = NotificationPreferences(
                            enabled: enabled,
                            notify30MinBefore: notify30Min,
                            notify2HoursBefore: notify2Hours
                        )

                        // Update notification preferences using the client
                        let success = try await firebaseUserClient.updateNotificationPreferences(userId, preferences)

                        if !success {
                            throw UserFacingError.operationFailed("Failed to update notification preferences")
                        }

                        // If notifications are disabled, cancel any scheduled reminders
                        if !enabled {
                            let identifiers = [
                                "checkInReminder-\(userData.checkInExpiration.timeIntervalSince1970)-30",
                                "checkInReminder-\(userData.checkInExpiration.timeIntervalSince1970)-120"
                            ]
                            await firebaseNotification.cancelScheduledNotifications(identifiers)
                        } else {
                            // If notifications are enabled, schedule reminders based on preferences
                            let expirationDate = userData.checkInExpiration
                            var reminderIds: [String] = []

                            // Schedule 30-minute reminder if enabled
                            if notify30Min {
                                let reminderId = try await firebaseNotification.scheduleCheckInReminder(
                                    expirationDate,
                                    30
                                )
                                reminderIds.append(reminderId)
                            }

                            // Schedule 2-hour reminder if enabled
                            if notify2Hours {
                                let reminderId = try await firebaseNotification.scheduleCheckInReminder(
                                    expirationDate,
                                    120
                                )
                                reminderIds.append(reminderId)
                            }
                        }

                        // Show a notification about the updated settings
                        if enabled {
                            _ = try await firebaseNotification.showLocalNotification(
                                "Notifications Enabled",
                                "You will now receive check-in reminders and alerts.",
                                ["type": "notificationSettingsUpdate"]
                            )
                        }

                        await send(.updateNotificationSettingsSucceeded)
                    } catch {
                        let userFacingError = UserFacingError.from(error)
                        await send(.updateNotificationSettingsError(userFacingError))
                    }
                }

            case .updateNotificationSettingsSucceeded:
                state.isLoading = false
                return .none

            case let .updateNotificationSettingsError(error):
                state.isLoading = false
                state.error = error
                return .none

            case let .updateNotificationPreferences(notify30Min, notify2Hours):
                state.isLoading = true
                // Update local state immediately for better UX
                state.notify30MinBefore = notify30Min
                state.notify2HoursBefore = notify2Hours

                return .run { [enabled = state.notificationEnabled] send in
                    do {
                        // Only proceed if notifications are enabled
                        if enabled {
                            let status = await firebaseNotification.getAuthorizationStatus()
                            if status != .authorized {
                                // Request authorization if not already authorized
                                let authorized = try await firebaseNotification.requestAuthorization()
                                if !authorized {
                                    throw UserFacingError.permissionDenied("Notification permission is required to update notification preferences")
                                }
                            }
                        }

                        let userId = try await firebaseAuth.currentUserId()

                        // Get user data for check-in expiration
                        let userData = try await firebaseUserClient.getUserDocument(userId)

                        // Create notification preferences
                        let preferences = NotificationPreferences(
                            enabled: enabled,
                            notify30MinBefore: notify30Min,
                            notify2HoursBefore: notify2Hours
                        )

                        // Update notification preferences using the client
                        let success = try await firebaseUserClient.updateNotificationPreferences(userId, preferences)

                        if !success {
                            throw UserFacingError.operationFailed("Failed to update notification preferences")
                        }

                        // Cancel any existing scheduled notifications
                        let identifiers = [
                            "checkInReminder-\(userData.checkInExpiration.timeIntervalSince1970)-30",
                            "checkInReminder-\(userData.checkInExpiration.timeIntervalSince1970)-120"
                        ]
                        await firebaseNotification.cancelScheduledNotifications(identifiers)

                        // Only schedule notifications if they're enabled
                        if enabled {
                            // Schedule new reminders based on the updated preferences
                            let expirationDate = userData.checkInExpiration
                            var reminderIds: [String] = []

                            // Schedule 30-minute reminder if enabled
                            if notify30Min {
                                let reminderId = try await firebaseNotification.scheduleCheckInReminder(
                                    expirationDate,
                                    30
                                )
                                reminderIds.append(reminderId)
                            }

                            // Schedule 2-hour reminder if enabled
                            if notify2Hours {
                                let reminderId = try await firebaseNotification.scheduleCheckInReminder(
                                    expirationDate,
                                    120
                                )
                                reminderIds.append(reminderId)
                            }

                            // Show a notification about the updated preferences
                            _ = try await firebaseNotification.showLocalNotification(
                                "Notification Settings Updated",
                                "Your check-in notification preferences have been updated.",
                                ["type": "notificationPreferencesUpdate"]
                            )
                        }

                        await send(.updateNotificationPreferencesSucceeded)
                    } catch {
                        let userFacingError = UserFacingError.from(error)
                        await send(.updateNotificationPreferencesError(userFacingError))
                    }
                }

            case .updateNotificationPreferencesSucceeded:
                state.isLoading = false
                return .none

            case let .updateNotificationPreferencesError(error):
                state.isLoading = false
                state.error = error
                return .none

            case let .updateFCMToken(token):
                return .run { send in
                    do {
                        let userId = try await firebaseAuth.currentUserId()

                        // Update FCM token in Firestore
                        let fields: [String: Any] = [
                            FirestoreConstants.UserFields.fcmToken: token,
                            FirestoreConstants.UserFields.lastUpdated: timestampManager.serverTimestamp()
                        ]

                        // Use the Firebase user client to update the user document
                        let success = try await firebaseUserClient.updateUserDocument(userId, fields)

                        if !success {
                            throw UserFacingError.operationFailed("Failed to update FCM token")
                        }

                        await send(.updateFCMTokenSucceeded)
                    } catch {
                        let userFacingError = UserFacingError.from(error)
                        await send(.updateFCMTokenError(userFacingError))
                    }
                }

            case .updateFCMTokenSucceeded:
                return .none

            case let .updateFCMTokenError(error):
                state.error = error
                return .none

            case .clearError:
                state.error = nil
                return .none
            }
        }
    }
}
