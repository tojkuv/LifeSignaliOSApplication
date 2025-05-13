import Foundation
import ComposableArchitecture
import FirebaseCore
import FirebaseAuth
import FirebaseFunctions
import FirebaseMessaging
import UserNotifications
import XCTestDynamicOverlay
import Dependencies
import OSLog
import UIKit

/// A client for handling Firebase app lifecycle
@DependencyClient
struct FirebaseAppClient: Sendable {
    /// Configure Firebase
    var configure: @Sendable () -> Void = { }

    /// Set up Firebase Messaging for push notifications
    var setupMessaging: @Sendable () async -> Void = { }

    /// Handle open URL
    var handleOpenURL: @Sendable (URL) -> Bool = { _ in false }

    /// Add auth state listener
    var addAuthStateListener: @Sendable (@Sendable @escaping (Auth, User?) -> Void) -> NSObjectProtocol = { _ in
        NSObject()
    }

    /// Remove auth state listener
    var removeAuthStateListener: @Sendable (NSObjectProtocol) -> Void = { _ in }

    /// Get Firebase initialization status as a string
    var getInitializationStatus: @Sendable () -> String = { "Firebase not initialized" }
}

extension FirebaseAppClient: DependencyKey {
    static let liveValue = Self(
        configure: {
            FirebaseLogger.app.debug("Configuring Firebase")
            // Remove the unnecessary do-catch block since no throwing operations are performed
            if FirebaseApp.app() == nil {
                FirebaseApp.configure()
                FirebaseLogger.app.info("Firebase configured successfully")
            } else {
                FirebaseLogger.app.debug("Firebase already configured")
            }

            // Set up Firebase Functions
            let _ = Functions.functions(region: "us-central1")
            FirebaseLogger.app.debug("Firebase Functions initialized")

            // Set up Firebase Messaging delegate
            @Dependency(\.firebaseMessaging) var firebaseMessaging
            firebaseMessaging.setDelegate()
            FirebaseLogger.app.debug("Firebase Messaging delegate set")

            // Enable offline persistence
            @Dependency(\.firebaseOfflineManager) var firebaseOfflineManager
            Task {
                await firebaseOfflineManager.enableOfflinePersistence()
            }
        },
        setupMessaging: {
            FirebaseLogger.app.debug("Setting up Firebase Messaging")
            // Request notification permissions
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: authOptions)
                if granted {
                    FirebaseLogger.app.info("Notification authorization granted")
                    await MainActor.run {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                    FirebaseLogger.app.debug("Registered for remote notifications")
                } else {
                    FirebaseLogger.app.warning("Notification authorization denied by user")
                }
            } catch {
                FirebaseLogger.app.error("Error requesting notification authorization: \(error.localizedDescription)")
                // We don't throw here because this is a fire-and-forget operation
            }
        },
        handleOpenURL: { url in
            FirebaseLogger.app.debug("Handling open URL: \(url)")
            let canHandle = Auth.auth().canHandle(url)
            FirebaseLogger.app.debug("Firebase Auth can\(canHandle ? "" : "not") handle URL")
            return canHandle
        },
        addAuthStateListener: { listener in
            FirebaseLogger.app.debug("Adding auth state listener")
            let handle = Auth.auth().addStateDidChangeListener(listener)
            FirebaseLogger.app.debug("Auth state listener added")
            return handle
        },
        removeAuthStateListener: { observer in
            FirebaseLogger.app.debug("Removing auth state listener")
            guard let nsObject = observer as? NSObject else {
                FirebaseLogger.app.error("Failed to cast observer to NSObject")
                return
            }
            Auth.auth().removeStateDidChangeListener(nsObject)
            FirebaseLogger.app.debug("Auth state listener removed")
        },
        getInitializationStatus: {
            FirebaseLogger.app.debug("Getting Firebase initialization status")
            if let app = FirebaseApp.app() {
                let options = app.options
                let status = """
                Firebase is initialized!
                App name: \(app.name)
                Google App ID: \(options.googleAppID)
                GCM Sender ID: \(options.gcmSenderID)
                Project ID: \(options.projectID ?? "Not available")
                """
                FirebaseLogger.app.debug("Firebase is initialized")
                return status
            } else {
                FirebaseLogger.app.warning("Firebase is NOT initialized")
                return "Firebase is NOT initialized!"
            }
        }
    )

    /// A mock implementation that returns predefined values for testing
    static func mock(
        configure: @Sendable @escaping () -> Void = { },
        setupMessaging: @Sendable @escaping () async -> Void = { },
        handleOpenURL: @Sendable @escaping (URL) -> Bool = { _ in false },
        addAuthStateListener: @Sendable @escaping (@Sendable @escaping (Auth, User?) -> Void) -> NSObjectProtocol = { _ in NSObject() },
        removeAuthStateListener: @Sendable @escaping (NSObjectProtocol) -> Void = { _ in },
        getInitializationStatus: @Sendable @escaping () -> String = { "Firebase mock initialized" }
    ) -> Self {
        Self(
            configure: configure,
            setupMessaging: setupMessaging,
            handleOpenURL: handleOpenURL,
            addAuthStateListener: addAuthStateListener,
            removeAuthStateListener: removeAuthStateListener,
            getInitializationStatus: getInitializationStatus
        )
    }
}

extension FirebaseAppClient: TestDependencyKey {
    /// A test implementation that fails with an unimplemented error
    static let testValue = Self(
        configure: unimplemented("\(Self.self).configure"),
        setupMessaging: unimplemented("\(Self.self).setupMessaging"),
        handleOpenURL: unimplemented("\(Self.self).handleOpenURL", placeholder: false),
        addAuthStateListener: unimplemented("\(Self.self).addAuthStateListener", placeholder: NSObject()),
        removeAuthStateListener: unimplemented("\(Self.self).removeAuthStateListener"),
        getInitializationStatus: unimplemented("\(Self.self).getInitializationStatus", placeholder: "Firebase test initialized")
    )
}

extension DependencyValues {
    var firebaseApp: FirebaseAppClient {
        get { self[FirebaseAppClient.self] }
        set { self[FirebaseAppClient.self] = newValue }
    }
}
