import Foundation
import ComposableArchitecture
import FirebaseAuth

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
        
        /// Loading state
        var isLoading: Bool = false
        
        /// Error state
        var error: Error?
        
        /// Custom Equatable implementation to handle Error? property
        static func == (lhs: State, rhs: State) -> Bool {
            lhs.notificationEnabled == rhs.notificationEnabled &&
            lhs.notify30MinBefore == rhs.notify30MinBefore &&
            lhs.notify2HoursBefore == rhs.notify2HoursBefore &&
            lhs.isLoading == rhs.isLoading &&
            (lhs.error != nil) == (rhs.error != nil)
        }
    }
    
    /// Actions that can be performed on the notification feature
    enum Action: Equatable, Sendable {
        /// Update notification state from user data
        case updateNotificationState(enabled: Bool, notify30Min: Bool, notify2Hours: Bool)
        
        /// Update notification settings (enabled/disabled)
        case updateNotificationSettings(enabled: Bool)
        case updateNotificationSettingsResponse(TaskResult<Void>)
        
        /// Update notification preferences (timing)
        case updateNotificationPreferences(notify30Min: Bool, notify2Hours: Bool)
        case updateNotificationPreferencesResponse(TaskResult<Void>)
        
        /// Update FCM token
        case updateFCMToken(String)
        case updateFCMTokenResponse(TaskResult<Void>)
        
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
            case let .updateNotificationState(enabled, notify30Min, notify2Hours):
                state.notificationEnabled = enabled
                state.notify30MinBefore = notify30Min
                state.notify2HoursBefore = notify2Hours
                return .none
                
            case let .updateNotificationSettings(enabled):
                state.isLoading = true
                // Update local state immediately for better UX
                state.notificationEnabled = enabled
                
                return .run { [firebaseUserClient, firebaseNotification, notify30Min = state.notify30MinBefore, notify2Hours = state.notify2HoursBefore] send in
                    let result = await TaskResult {
                        guard let userId = firebaseAuth.currentUserId() else {
                            throw NSError(domain: "NotificationFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }
                        
                        // Get user data for check-in expiration
                        let userData = try await firebaseUserClient.getUserDocument(userId)
                        
                        // Create notification preferences with updated enabled state
                        let preferences = NotificationPreferences(
                            enabled: enabled,
                            notify30MinBefore: notify30Min,
                            notify2HoursBefore: notify2Hours
                        )
                        
                        // Update notification preferences using the client
                        try await firebaseUserClient.updateNotificationPreferences(userId, preferences)
                        
                        // If notifications are disabled, cancel any scheduled reminders
                        if !enabled {
                            let identifiers = [
                                "checkInReminder-\(userData.checkInExpiration.timeIntervalSince1970)-30",
                                "checkInReminder-\(userData.checkInExpiration.timeIntervalSince1970)-120"
                            ]
                            await firebaseNotification.cancelScheduledNotifications(identifiers: identifiers)
                        } else {
                            // If notifications are enabled, schedule reminders based on preferences
                            let expirationDate = userData.checkInExpiration
                            var reminderIds: [String] = []
                            
                            // Schedule 30-minute reminder if enabled
                            if notify30Min {
                                let reminderId = try await firebaseNotification.scheduleCheckInReminder(
                                    expirationDate: expirationDate,
                                    minutesBefore: 30
                                )
                                reminderIds.append(reminderId)
                            }
                            
                            // Schedule 2-hour reminder if enabled
                            if notify2Hours {
                                let reminderId = try await firebaseNotification.scheduleCheckInReminder(
                                    expirationDate: expirationDate,
                                    minutesBefore: 120
                                )
                                reminderIds.append(reminderId)
                            }
                        }
                        
                        // Show a notification about the updated settings
                        if enabled {
                            try await firebaseNotification.showLocalNotification(
                                title: "Notifications Enabled",
                                body: "You will now receive check-in reminders and alerts.",
                                userInfo: ["type": "notificationSettingsUpdate"]
                            )
                        }
                    }
                    await send(.updateNotificationSettingsResponse(result))
                }
                
            case let .updateNotificationSettingsResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Notification settings were already updated in state when action was dispatched
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }
                
            case let .updateNotificationPreferences(notify30Min, notify2Hours):
                state.isLoading = true
                // Update local state immediately for better UX
                state.notify30MinBefore = notify30Min
                state.notify2HoursBefore = notify2Hours
                
                return .run { [firebaseUserClient, firebaseNotification, enabled = state.notificationEnabled] send in
                    let result = await TaskResult {
                        guard let userId = firebaseAuth.currentUserId() else {
                            throw NSError(domain: "NotificationFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }
                        
                        // Get user data for check-in expiration
                        let userData = try await firebaseUserClient.getUserDocument(userId)
                        
                        // Create notification preferences
                        let preferences = NotificationPreferences(
                            enabled: enabled,
                            notify30MinBefore: notify30Min,
                            notify2HoursBefore: notify2Hours
                        )
                        
                        // Update notification preferences using the client
                        try await firebaseUserClient.updateNotificationPreferences(userId, preferences)
                        
                        // Cancel any existing scheduled notifications
                        let identifiers = [
                            "checkInReminder-\(userData.checkInExpiration.timeIntervalSince1970)-30",
                            "checkInReminder-\(userData.checkInExpiration.timeIntervalSince1970)-120"
                        ]
                        await firebaseNotification.cancelScheduledNotifications(identifiers: identifiers)
                        
                        // Only schedule notifications if they're enabled
                        if enabled {
                            // Schedule new reminders based on the updated preferences
                            let expirationDate = userData.checkInExpiration
                            var reminderIds: [String] = []
                            
                            // Schedule 30-minute reminder if enabled
                            if notify30Min {
                                let reminderId = try await firebaseNotification.scheduleCheckInReminder(
                                    expirationDate: expirationDate,
                                    minutesBefore: 30
                                )
                                reminderIds.append(reminderId)
                            }
                            
                            // Schedule 2-hour reminder if enabled
                            if notify2Hours {
                                let reminderId = try await firebaseNotification.scheduleCheckInReminder(
                                    expirationDate: expirationDate,
                                    minutesBefore: 120
                                )
                                reminderIds.append(reminderId)
                            }
                            
                            // Show a notification about the updated preferences
                            try await firebaseNotification.showLocalNotification(
                                title: "Notification Settings Updated",
                                body: "Your check-in notification preferences have been updated.",
                                userInfo: ["type": "notificationPreferencesUpdate"]
                            )
                        }
                    }
                    await send(.updateNotificationPreferencesResponse(result))
                }
                
            case let .updateNotificationPreferencesResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Preferences were already updated in state when action was dispatched
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }
                
            case let .updateFCMToken(token):
                return .run { [firebaseUserClient] send in
                    let result = await TaskResult {
                        guard let userId = firebaseAuth.currentUserId() else {
                            throw NSError(domain: "NotificationFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }
                        
                        // Update FCM token in Firestore
                        let fields: [String: Any] = [
                            FirestoreConstants.UserFields.fcmToken: token,
                            FirestoreConstants.UserFields.lastUpdated: FieldValue.serverTimestamp()
                        ]
                        
                        // Use the Firebase user client to update the user document
                        try await firebaseUserClient.updateUserDocument(userId, fields)
                    }
                    await send(.updateFCMTokenResponse(result))
                }
                
            case let .updateFCMTokenResponse(result):
                switch result {
                case .success:
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }
                
            case .clearError:
                state.error = nil
                return .none
            }
        }
    }
}
