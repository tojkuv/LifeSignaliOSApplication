import UIKit
import UserNotifications
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import ComposableArchitecture

class AppDelegate: NSObject, UIApplicationDelegate {
    // Session listener for Firebase
    var sessionListenerTask: Task<Void, Never>?

    // TCA dependency container
    private let dependencies = DependencyValues()

    // TCA clients
    private var firebaseClient: FirebaseClient {
        dependencies.firebaseClient
    }

    private var sessionClient: SessionClient {
        dependencies.sessionClient
    }

    private var authClient: AuthenticationClient {
        dependencies.authClient
    }

    private var notificationClient: NotificationClientProtocol {
        dependencies.notificationClient
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Initialize Firebase using the client
        Task {
            await firebaseClient.configure()

            // Set up session listener if user is authenticated
            if let userId = await authClient.getCurrentUserId() {
                setupSessionListener(userId: userId)
            }
        }
        return true
    }

    /// Remove the session listener
    func removeSessionListener() {
        sessionListenerTask?.cancel()
        sessionListenerTask = nil
    }

    /// Set up a listener for session changes
    /// - Parameter userId: The user ID to monitor
    func setupSessionListener(userId: String) {
        // Cancel any existing listener
        removeSessionListener()

        // Create a new listener task
        sessionListenerTask = Task {
            // Get the session stream
            let sessionStream = await sessionClient.watchSession(userId: userId)

            // Process session events
            for await _ in sessionStream {
                // Session was invalidated, sign out the user
                print("Session was invalidated, signing out")

                // Sign out on the main thread
                await MainActor.run {
                    // Sign out using Auth
                    try? Auth.auth().signOut()

                    // Clear session ID
                    Task {
                        await sessionClient.clearSessionId()
                    }

                    // Post notification to reset app state
                    NotificationCenter.default.post(name: NSNotification.Name("ResetAppState"), object: nil)
                }

                // Break the loop
                break
            }
        }
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }

    // Handle URL scheme for Firebase Auth
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if Auth.auth().canHandle(url) {
            return true
        }

        // Handle other URL schemes if needed
        return false
    }

    // Handle push notifications for Firebase Auth and FCM
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Pass device token to auth
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)

        // Pass device token to FCM
        Messaging.messaging().apnsToken = deviceToken

        // Set up observer for FCM token updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFCMTokenUpdate),
            name: MessagingDelegateAdapter.fcmTokenUpdatedNotification,
            object: nil
        )
    }

    @objc private func handleFCMTokenUpdate(notification: Notification) {
        guard let token = notification.userInfo?["token"] as? String else {
            return
        }

        // Get the current user ID using the auth client
        Task {
            if let userId = await authClient.getCurrentUserId() {
                // Update FCM token in Firestore using the firebase client
                do {
                    try await firebaseClient.updateFCMToken(token: token, userId: userId)
                    print("FCM token updated in Firestore")
                } catch {
                    print("Error updating FCM token: \(error.localizedDescription)")
                }
            }
        }
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification notification: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if Auth.auth().canHandleNotification(notification) {
            completionHandler(.noData)
            return
        }

        // Handle FCM notifications
        print("Received remote notification: \(notification)")

        // Check if this is an alert notification
        if let alertType = notification["alertType"] as? String {
            print("Received alert notification of type: \(alertType)")

            // Handle different alert types
            switch alertType {
            case "manualAlert":
                if let dependentId = notification["dependentId"] as? String,
                   let dependentName = notification["dependentName"] as? String {
                    print("Manual alert from dependent: \(dependentId) - \(dependentName)")

                    // Get the timestamp
                    var timestamp = Date()
                    if let timestampStr = notification["timestamp"] as? String,
                       let timestampDouble = Double(timestampStr) {
                        timestamp = Date(timeIntervalSince1970: timestampDouble)
                    }

                    // Handle the alert using the notification client
                    Task {
                        await notificationClient.handleDependentAlert(
                            dependentId: dependentId,
                            dependentName: dependentName,
                            timestamp: timestamp
                        )
                    }
                }
            case "manualAlertCanceled":
                if let dependentId = notification["dependentId"] as? String,
                   let dependentName = notification["dependentName"] as? String {
                    print("Manual alert canceled for dependent: \(dependentId) - \(dependentName)")

                    // Handle the alert cancellation using the notification client
                    Task {
                        await notificationClient.handleDependentAlertCancellation(
                            dependentId: dependentId,
                            dependentName: dependentName
                        )
                    }
                }
            case "checkInExpired":
                if let dependentId = notification["dependentId"] as? String {
                    print("Check-in expired for dependent: \(dependentId)")
                    // Handle check-in expiration using the notification client
                    Task {
                        if let dependentName = notification["dependentName"] as? String {
                            await notificationClient.showLocalNotification(
                                title: "Check-in Expired",
                                body: "\(dependentName)'s check-in has expired.",
                                userInfo: ["dependentId": dependentId]
                            )
                        }
                    }
                }
            default:
                break
            }
        }

        completionHandler(.newData)
    }

    // MARK: - Messaging Delegate

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
}
