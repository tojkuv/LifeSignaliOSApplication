import Foundation
import ComposableArchitecture
import FirebaseMessaging
import FirebaseAuth
import UserNotifications
import XCTestDynamicOverlay
import Dependencies
import OSLog
import UIKit

/// A client for handling Firebase notifications
@DependencyClient
struct FirebaseNotificationClient: Sendable {
    /// Register for remote notifications
    var registerForRemoteNotifications: @Sendable () async -> Void = { }

    /// Handle device token registration
    var handleDeviceToken: @Sendable (Data) async -> Void = { _ in }

    /// Handle remote notification
    var handleRemoteNotification: @Sendable ([AnyHashable: Any]) async -> UIBackgroundFetchResult = { _ in .noData }

    /// Request notification authorization
    var requestAuthorization: @Sendable () async throws -> Bool = {
        throw FirebaseError.operationFailed
    }

    /// Get current authorization status
    var getAuthorizationStatus: @Sendable () async -> UNAuthorizationStatus = { .notDetermined }

    /// Set notification delegate
    var setNotificationDelegate: @Sendable (UNUserNotificationCenterDelegate) -> Void = { _ in }

    /// Show a local notification
    var showLocalNotification: @Sendable (String, String, [String: Any]) async throws -> Bool = { _, _, _ in
        throw FirebaseError.operationFailed
    }

    /// Schedule a check-in reminder notification
    var scheduleCheckInReminder: @Sendable (Date, Int) async throws -> String = { _, _ in
        throw FirebaseError.operationFailed
    }

    /// Cancel scheduled notifications
    var cancelScheduledNotifications: @Sendable ([String]) async -> Void = { _ in }

    /// Send a manual alert notification
    var sendManualAlertNotification: @Sendable (String) async throws -> Bool = { _ in
        throw FirebaseError.operationFailed
    }

    /// Clear a manual alert notification
    var clearManualAlertNotification: @Sendable (String) async throws -> Bool = { _ in
        throw FirebaseError.operationFailed
    }
}

extension FirebaseNotificationClient: DependencyKey {
    /// Helper method to create notification content
    private static func createNotificationContent(
        title: String,
        body: String,
        userInfo: [String: Any]
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // Add user info
        for (key, value) in userInfo {
            if let value = value as? String {
                content.userInfo[key] = value
            }
        }

        return content
    }
    static let liveValue = Self(
        registerForRemoteNotifications: {
            FirebaseLogger.notification.debug("Registering for remote notifications")
            do {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                FirebaseLogger.notification.info("Registered for remote notifications")
            } catch {
                FirebaseLogger.notification.error("Failed to register for remote notifications: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },
        handleDeviceToken: { deviceToken in
            FirebaseLogger.notification.debug("Handling device token")
            do {
                // Pass device token to auth
                Auth.auth().setAPNSToken(deviceToken, type: .unknown)
                FirebaseLogger.notification.debug("Set APNS token in Auth")

                // Pass device token to FCM
                Messaging.messaging().apnsToken = deviceToken
                FirebaseLogger.notification.debug("Set APNS token in FCM")

                // Get the FCM token and post a notification
                @Dependency(\.firebaseMessaging) var firebaseMessaging
                if let token = firebaseMessaging.getFCMToken() {
                    FirebaseLogger.notification.info("Got FCM token: \(token)")
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("FCMTokenUpdated"),
                            object: nil,
                            userInfo: ["token": token]
                        )
                    }
                    FirebaseLogger.notification.debug("Posted FCM token notification")
                } else {
                    FirebaseLogger.notification.warning("FCM token not available")
                }
            } catch {
                FirebaseLogger.notification.error("Error handling device token: \(error.localizedDescription)")
                // We don't throw here because this is a fire-and-forget operation
            }
        },
        handleRemoteNotification: { notification in
            FirebaseLogger.notification.debug("Handling remote notification")
            if Auth.auth().canHandleNotification(notification) {
                FirebaseLogger.notification.debug("Auth can handle notification")
                return .noData
            }

            // Post a notification that the ContentView can listen for
            do {
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RemoteNotificationReceived"),
                        object: nil,
                        userInfo: notification
                    )
                }
                FirebaseLogger.notification.info("Posted remote notification received event")
                return .newData
            } catch {
                FirebaseLogger.notification.error("Error handling remote notification: \(error.localizedDescription)")
                return .failed
            }
        },
        requestAuthorization: {
            FirebaseLogger.notification.debug("Requesting notification authorization")
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
                FirebaseLogger.notification.info("Notification authorization \(granted ? "granted" : "denied")")
                return granted
            } catch {
                FirebaseLogger.notification.error("Failed to request notification authorization: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },
        getAuthorizationStatus: {
            FirebaseLogger.notification.debug("Getting notification authorization status")
            do {
                return await withCheckedContinuation { continuation in
                    UNUserNotificationCenter.current().getNotificationSettings { settings in
                        FirebaseLogger.notification.debug("Authorization status: \(settings.authorizationStatus.rawValue)")
                        continuation.resume(returning: settings.authorizationStatus)
                    }
                }
            } catch {
                FirebaseLogger.notification.error("Error getting authorization status: \(error.localizedDescription)")
                return .notDetermined
            }
        },
        setNotificationDelegate: { delegate in
            FirebaseLogger.notification.debug("Setting notification delegate")
            UNUserNotificationCenter.current().delegate = delegate
            FirebaseLogger.notification.info("Notification delegate set")
        },
        showLocalNotification: { title, body, userInfo in
            FirebaseLogger.notification.debug("Showing local notification: \(title)")
            do {
                // Create notification content
                let content = createNotificationContent(title: title, body: body, userInfo: userInfo)

                // Create a trigger (immediate)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

                // Create the request
                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: trigger
                )

                // Add the request to the notification center
                try await UNUserNotificationCenter.current().add(request)
                FirebaseLogger.notification.info("Local notification added successfully")
                return true
            } catch {
                FirebaseLogger.notification.error("Failed to show local notification: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },
        scheduleCheckInReminder: { expirationDate, minutesBefore in
            FirebaseLogger.notification.debug("Scheduling check-in reminder for \(minutesBefore) minutes before \(expirationDate)")
            do {
                // Create notification content
                let content = createNotificationContent(
                    title: "Check-in Reminder",
                    body: "Your check-in will expire in \(minutesBefore) minutes.",
                    userInfo: ["type": "checkInReminder"]
                )

                // Calculate the notification time
                let reminderDate = expirationDate.addingTimeInterval(-TimeInterval(minutesBefore * 60))
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminderDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

                // Create a unique identifier for this reminder
                let identifier = "checkInReminder-\(expirationDate.timeIntervalSince1970)-\(minutesBefore)"

                // Create the request
                let request = UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: trigger
                )

                // Add the request to the notification center
                try await UNUserNotificationCenter.current().add(request)
                FirebaseLogger.notification.info("Check-in reminder scheduled for \(reminderDate)")
                return identifier
            } catch {
                FirebaseLogger.notification.error("Failed to schedule check-in reminder: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },
        cancelScheduledNotifications: { identifiers in
            FirebaseLogger.notification.debug("Cancelling scheduled notifications: \(identifiers)")
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
            FirebaseLogger.notification.info("Cancelled \(identifiers.count) scheduled notifications")
        },
        sendManualAlertNotification: { userName in
            FirebaseLogger.notification.debug("Sending manual alert notification for user: \(userName)")
            do {
                // Create notification content
                let content = createNotificationContent(
                    title: "Manual Alert Activated",
                    body: "You have activated a manual alert. Your responders will be notified.",
                    userInfo: ["type": "manualAlert", "userName": userName]
                )

                // Create a trigger (immediate)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

                // Create the request
                let request = UNNotificationRequest(
                    identifier: "manualAlert-\(UUID().uuidString)",
                    content: content,
                    trigger: trigger
                )

                // Add the request to the notification center
                try await UNUserNotificationCenter.current().add(request)
                FirebaseLogger.notification.info("Manual alert notification sent for user: \(userName)")
                return true
            } catch {
                FirebaseLogger.notification.error("Failed to send manual alert notification: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },
        clearManualAlertNotification: { userName in
            FirebaseLogger.notification.debug("Clearing manual alert notification for user: \(userName)")
            do {
                // Create notification content
                let content = createNotificationContent(
                    title: "Manual Alert Cleared",
                    body: "Your manual alert has been cleared.",
                    userInfo: ["type": "manualAlertCleared", "userName": userName]
                )

                // Create a trigger (immediate)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

                // Create the request
                let request = UNNotificationRequest(
                    identifier: "manualAlertCleared-\(UUID().uuidString)",
                    content: content,
                    trigger: trigger
                )

                // Add the request to the notification center
                try await UNUserNotificationCenter.current().add(request)
                FirebaseLogger.notification.info("Manual alert cleared notification sent for user: \(userName)")
                return true
            } catch {
                FirebaseLogger.notification.error("Failed to clear manual alert notification: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        }
    )

    /// A mock implementation that returns predefined values for testing
    static func mock(
        registerForRemoteNotifications: @escaping () async -> Void = { },
        handleDeviceToken: @escaping (Data) async -> Void = { _ in },
        handleRemoteNotification: @escaping ([AnyHashable: Any]) async -> UIBackgroundFetchResult = { _ in .noData },
        requestAuthorization: @escaping () async throws -> Bool = { true },
        getAuthorizationStatus: @escaping () async -> UNAuthorizationStatus = { .authorized },
        setNotificationDelegate: @escaping (UNUserNotificationCenterDelegate) -> Void = { _ in },
        showLocalNotification: @escaping (String, String, [String: Any]) async throws -> Bool = { _, _, _ in true },
        scheduleCheckInReminder: @escaping (Date, Int) async throws -> String = { _, _ in UUID().uuidString },
        cancelScheduledNotifications: @escaping ([String]) async -> Void = { _ in },
        sendManualAlertNotification: @escaping (String) async throws -> Bool = { _ in true },
        clearManualAlertNotification: @escaping (String) async throws -> Bool = { _ in true }
    ) -> Self {
        Self(
            registerForRemoteNotifications: registerForRemoteNotifications,
            handleDeviceToken: handleDeviceToken,
            handleRemoteNotification: handleRemoteNotification,
            requestAuthorization: requestAuthorization,
            getAuthorizationStatus: getAuthorizationStatus,
            setNotificationDelegate: setNotificationDelegate,
            showLocalNotification: showLocalNotification,
            scheduleCheckInReminder: scheduleCheckInReminder,
            cancelScheduledNotifications: cancelScheduledNotifications,
            sendManualAlertNotification: sendManualAlertNotification,
            clearManualAlertNotification: clearManualAlertNotification
        )
    }
}

extension FirebaseNotificationClient: TestDependencyKey {
    /// A test implementation that fails with an unimplemented error
    static let testValue = Self(
        registerForRemoteNotifications: unimplemented("\(Self.self).registerForRemoteNotifications"),
        handleDeviceToken: unimplemented("\(Self.self).handleDeviceToken"),
        handleRemoteNotification: unimplemented("\(Self.self).handleRemoteNotification", placeholder: .noData),
        requestAuthorization: unimplemented("\(Self.self).requestAuthorization", placeholder: false),
        getAuthorizationStatus: unimplemented("\(Self.self).getAuthorizationStatus", placeholder: .notDetermined),
        setNotificationDelegate: unimplemented("\(Self.self).setNotificationDelegate"),
        showLocalNotification: unimplemented("\(Self.self).showLocalNotification", placeholder: true),
        scheduleCheckInReminder: unimplemented("\(Self.self).scheduleCheckInReminder", placeholder: "test-id"),
        cancelScheduledNotifications: unimplemented("\(Self.self).cancelScheduledNotifications"),
        sendManualAlertNotification: unimplemented("\(Self.self).sendManualAlertNotification", placeholder: true),
        clearManualAlertNotification: unimplemented("\(Self.self).clearManualAlertNotification", placeholder: true)
    )
}

extension DependencyValues {
    var firebaseNotification: FirebaseNotificationClient {
        get { self[FirebaseNotificationClient.self] }
        set { self[FirebaseNotificationClient.self] = newValue }
    }
}
