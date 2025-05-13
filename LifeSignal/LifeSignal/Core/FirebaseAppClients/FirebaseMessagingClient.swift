import Foundation
import FirebaseMessaging
import Dependencies
import ComposableArchitecture
import XCTestDynamicOverlay
import OSLog

/// Client for handling Firebase Cloud Messaging
@DependencyClient
struct FirebaseMessagingClient: Sendable {
    /// Set up the messaging delegate
    var setDelegate: @Sendable () -> Void = { }

    /// Get the current FCM token
    var getFCMToken: @Sendable () -> String? = { nil }

    /// Register for token updates
    var registerForTokenUpdates: @Sendable (@Sendable @escaping (String) -> Void) -> Void = { _ in }

    /// Unregister from token updates
    var unregisterFromTokenUpdates: @Sendable () -> Void = { }
}

// MARK: - Live Implementation
extension FirebaseMessagingClient: DependencyKey {
    static let liveValue = Self(
        setDelegate: {
            FirebaseLogger.messaging.debug("Setting Firebase Messaging delegate")
            Messaging.messaging().delegate = MessagingDelegateHandler.shared
            FirebaseLogger.messaging.info("Firebase Messaging delegate set")
        },
        getFCMToken: {
            FirebaseLogger.messaging.debug("Getting FCM token")
            if let token = Messaging.messaging().fcmToken {
                FirebaseLogger.messaging.debug("FCM token available: \(token)")
                return token
            } else {
                FirebaseLogger.messaging.warning("FCM token not available")
                return nil
            }
        },
        registerForTokenUpdates: { callback in
            FirebaseLogger.messaging.debug("Registering for FCM token updates")
            MessagingDelegateHandler.shared.registerCallback(callback)
            FirebaseLogger.messaging.info("Registered for FCM token updates")
        },
        unregisterFromTokenUpdates: {
            FirebaseLogger.messaging.debug("Unregistering from FCM token updates")
            MessagingDelegateHandler.shared.unregisterCallbacks()
            FirebaseLogger.messaging.info("Unregistered from FCM token updates")
        }
    )

}

// MARK: - Mock Implementation

extension FirebaseMessagingClient {
    /// A mock implementation that returns predefined values for testing
    static func mock(
        setDelegate: @Sendable @escaping () -> Void = { },
        getFCMToken: @Sendable @escaping () -> String? = { "mock-fcm-token" },
        registerForTokenUpdates: @Sendable @escaping (@Sendable @escaping (String) -> Void) -> Void = { _ in },
        unregisterFromTokenUpdates: @Sendable @escaping () -> Void = { }
    ) -> Self {
        Self(
            setDelegate: setDelegate,
            getFCMToken: getFCMToken,
            registerForTokenUpdates: registerForTokenUpdates,
            unregisterFromTokenUpdates: unregisterFromTokenUpdates
        )
    }
}

extension FirebaseMessagingClient: TestDependencyKey {
    /// Test implementation that fails with unimplemented error
    static let testValue = Self(
        setDelegate: unimplemented("\(Self.self).setDelegate"),
        getFCMToken: unimplemented("\(Self.self).getFCMToken", placeholder: "test-fcm-token"),
        registerForTokenUpdates: unimplemented("\(Self.self).registerForTokenUpdates"),
        unregisterFromTokenUpdates: unimplemented("\(Self.self).unregisterFromTokenUpdates")
    )
}

// Private handler class to implement the delegate protocol
private final class MessagingDelegateHandler: NSObject, MessagingDelegate, @unchecked Sendable {
    static let shared = MessagingDelegateHandler()

    private var callbacks: [@Sendable (String) -> Void] = []
    private let lock = NSLock()

    func registerCallback(_ callback: @escaping @Sendable (String) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        callbacks.append(callback)
        FirebaseLogger.messaging.debug("Added FCM token callback, total callbacks: \(self.callbacks.count)")
    }

    func unregisterCallbacks() {
        lock.lock()
        defer { lock.unlock() }
        let count = callbacks.count
        callbacks.removeAll()
        FirebaseLogger.messaging.debug("Removed all \(count) FCM token callbacks")
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let token = fcmToken {
            FirebaseLogger.messaging.info("Received new FCM token: \(token)")

            // Create a copy of callbacks to avoid holding the lock during callback execution
            lock.lock()
            let callbacksCopy = callbacks
            lock.unlock()

            FirebaseLogger.messaging.debug("Notifying \(callbacksCopy.count) callbacks about new FCM token")
            for callback in callbacksCopy {
                callback(token)
            }
        } else {
            FirebaseLogger.messaging.warning("Received nil FCM token")
        }
    }
}

// MARK: - Dependency Registration
extension DependencyValues {
    var firebaseMessaging: FirebaseMessagingClient {
        get { self[FirebaseMessagingClient.self] }
        set { self[FirebaseMessagingClient.self] = newValue }
    }
}
