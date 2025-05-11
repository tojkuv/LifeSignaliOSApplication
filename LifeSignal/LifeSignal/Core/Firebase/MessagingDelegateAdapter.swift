import Foundation
import FirebaseMessaging

/// Adapter for Firebase Messaging delegate
class MessagingDelegateAdapter: NSObject, MessagingDelegate {
    /// Shared instance
    static let shared = MessagingDelegateAdapter()
    
    /// Notification name for FCM token updates
    static let fcmTokenUpdatedNotification = NSNotification.Name("FCMTokenUpdated")
    
    /// Handle FCM token refresh
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(fcmToken ?? "nil")")
        
        // Notify observers of token update
        if let token = fcmToken {
            NotificationCenter.default.post(
                name: MessagingDelegateAdapter.fcmTokenUpdatedNotification,
                object: nil,
                userInfo: ["token": token]
            )
        }
    }
}
