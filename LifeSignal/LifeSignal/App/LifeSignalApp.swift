import SwiftUI
import ComposableArchitecture
import FirebaseAuth
import FirebaseCore
import FirebaseMessaging
import UserNotifications

/// AppDelegate that handles app lifecycle events using AppFeature
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// The app's store
    let store: StoreOf<AppFeature>

    /// Dependencies
    @Dependency(\.firebaseApp) private var firebaseApp
    @Dependency(\.firebaseNotification) private var firebaseNotification
    @Dependency(\.firebaseMessaging) private var firebaseMessaging

    /// Callback for FCM token updates
    private var tokenUpdateCallback: ((String) -> Void)?

    /// Observer for auth state changes
    private var authStateObserver: NSObjectProtocol?

    /// Initialize with a store
    init(store: StoreOf<AppFeature>) {
        self.store = store
        super.init()

        // Set up callback for FCM token updates
        tokenUpdateCallback = { [weak self] token in
            // Post a notification that the ContentView can listen for
            NotificationCenter.default.post(
                name: NSNotification.Name("FCMTokenUpdated"),
                object: nil,
                userInfo: ["token": token]
            )
        }

        // Register for token updates
        firebaseMessaging.registerForTokenUpdates(tokenUpdateCallback!)

        // Set up notification center delegate
        firebaseNotification.setNotificationDelegate(self)
    }

    deinit {
        // Unregister from token updates
        firebaseMessaging.unregisterFromTokenUpdates()

        // Remove auth state observer
        if let observer = authStateObserver {
            firebaseApp.removeAuthStateListener(observer)
        }
    }

    // MARK: - UIApplicationDelegate Methods

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure Firebase
        firebaseApp.configure()

        // Set up Firebase Messaging
        Task {
            await firebaseApp.setupMessaging()
        }

        // Initialize app
        Task { @MainActor in
            store.send(.appAppeared)
        }

        // Set up auth state listener
        authStateObserver = firebaseApp.addAuthStateListener { [weak self] (auth, user) in
            // Post a notification that the ContentView can listen for
            NotificationCenter.default.post(
                name: NSNotification.Name("AuthStateChanged"),
                object: nil,
                userInfo: ["user": user as Any]
            )
        }

        return true
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }

    // MARK: - URL Handling

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if firebaseApp.handleOpenURL(url) {
            return true
        }

        // Forward to app feature
        Task { @MainActor in
            store.send(.handleURL(url))
        }

        return true
    }

    // MARK: - Push Notification Handling

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task {
            await firebaseNotification.handleDeviceToken(deviceToken)
        }
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification notification: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Task {
            let result = await firebaseNotification.handleRemoteNotification(notification)
            completionHandler(result)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Handle failure silently in production
    }

    // MARK: - UNUserNotificationCenterDelegate Methods

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Post a notification that the ContentView can listen for
        NotificationCenter.default.post(
            name: NSNotification.Name("NotificationResponseReceived"),
            object: nil,
            userInfo: ["response": response]
        )

        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Always show notifications when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
}

/// The main app entry point
@main
struct LifeSignalApp: App {
    /// The app delegate adaptor
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// Initialize the app
    init() {
        // Initialize app delegate with store
        #if DEBUG
        let store = Store(initialState: AppFeature.State()) {
            AppFeature()
                ._printChanges()
        } withDependencies: {
            // Configure dependencies for development
            // This is where you can override dependencies for testing or development
            $0.firebaseOfflineManager = .liveValue
            $0.firebaseTimestampManager = .liveValue
        }
        #else
        let store = Store(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            // Configure dependencies for production
            // This is where you can set up production dependencies
            $0.firebaseOfflineManager = .liveValue
            $0.firebaseTimestampManager = .liveValue
        }
        #endif

        _appDelegate = UIApplicationDelegateAdaptor(AppDelegate.self, store: store)
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: appDelegate.store)
        }
    }
}

/// Root view that provides the app store to the environment
struct RootView: View {
    /// The store for the app feature
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        ContentView(store: store)
    }
}
