import UIKit
import UserNotifications
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate {
    // Session listener for Firebase
    var sessionListener: ListenerRegistration?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Initialize Firebase
        FirebaseService.shared.configure()
        return true
    }

    /// Remove the session listener
    func removeSessionListener() {
        sessionListener?.remove()
        sessionListener = nil
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

                    // Handle the alert
                    NotificationService.shared.handleDependentAlert(
                        dependentId: dependentId,
                        dependentName: dependentName,
                        timestamp: timestamp
                    )

                    // Post notification to navigate to the dependent's details
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToDependentDetails"),
                        object: nil,
                        userInfo: ["dependentId": dependentId]
                    )
                }
            case "manualAlertCanceled":
                if let dependentId = notification["dependentId"] as? String,
                   let dependentName = notification["dependentName"] as? String {
                    print("Manual alert canceled for dependent: \(dependentId) - \(dependentName)")

                    // Handle the alert cancellation
                    NotificationService.shared.handleDependentAlertCancellation(
                        dependentId: dependentId,
                        dependentName: dependentName
                    )

                    // Post notification to navigate to the dependent's details
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToDependentDetails"),
                        object: nil,
                        userInfo: ["dependentId": dependentId]
                    )
                }
            case "checkInExpired":
                if let dependentId = notification["dependentId"] as? String {
                    print("Check-in expired for dependent: \(dependentId)")
                    // Post notification to navigate to the dependent's details
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToDependentDetails"),
                        object: nil,
                        userInfo: ["dependentId": dependentId]
                    )
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
