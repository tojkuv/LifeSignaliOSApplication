import UIKit
import UserNotifications
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import FirebaseFunctions
import ComposableArchitecture

class AppDelegate: NSObject, UIApplicationDelegate {
    // Store for the app feature
    let store: StoreOf<AppFeature>

    // Observer for FCM token updates
    private var fcmTokenObserver: NSObjectProtocol?

    override init() {
        // Initialize the store
        self.store = Store(initialState: AppFeature.State()) {
            AppFeature()
        }
        super.init()

        // Set up observer for FCM token updates
        fcmTokenObserver = NotificationCenter.default.addObserver(
            forName: MessagingDelegateAdapter.fcmTokenUpdatedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let token = notification.userInfo?["token"] as? String else {
                return
            }

            // Forward to app feature
            Task {
                await ViewStore(self?.store ?? Store(initialState: AppFeature.State()) { AppFeature() },
                               observe: { $0 }).send(.updateFCMToken(token))
            }
        }
    }

    deinit {
        // Remove observer
        if let observer = fcmTokenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // We don't need to initialize Firebase here anymore
        // The LifeSignalApp will trigger the appLaunched action
        // which will handle initialization through the AppFeature
        return true
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }

    // Handle URL scheme for Firebase Auth
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if Auth.auth().canHandle(url) {
            return true
        }

        // Forward to app feature
        ViewStore(store, observe: { $0 }).send(.handleURL(url))
        return true
    }

    // Handle push notifications for Firebase Auth and FCM
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Forward to app feature
        ViewStore(store, observe: { $0 }).send(.registerDeviceToken(deviceToken))
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification notification: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if Auth.auth().canHandleNotification(notification) {
            completionHandler(.noData)
            return
        }

        // Forward to app feature
        Task {
            await ViewStore(store, observe: { $0 }).send(.handleRemoteNotification(notification))
            completionHandler(.newData)
        }
    }

    // MARK: - Error Handling

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
}
