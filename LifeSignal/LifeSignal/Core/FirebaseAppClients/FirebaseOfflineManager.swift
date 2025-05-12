import Foundation
import FirebaseFirestore
import FirebaseAuth
import DependenciesMacros
import Dependencies
import XCTestDynamicOverlay
import OSLog

/// A client for managing Firebase offline capabilities
@DependencyClient
struct FirebaseOfflineManager: Sendable {
    /// Enable offline persistence
    var enableOfflinePersistence: @Sendable () async -> Void

    /// Disable network
    var disableNetwork: @Sendable () async throws -> Void

    /// Enable network
    var enableNetwork: @Sendable () async throws -> Void

    /// Check if network is enabled
    var isNetworkEnabled: @Sendable () async -> Bool

    /// Wait for pending writes to be acknowledged
    var waitForPendingWrites: @Sendable () async throws -> Void

    /// Clear persistence
    var clearPersistence: @Sendable () async throws -> Void

    /// Set cache size
    var setCacheSize: @Sendable (_ sizeInBytes: Int64) async -> Void
}

// MARK: - Live Implementation

extension FirebaseOfflineManager: DependencyKey {
    static let liveValue = Self(
        enableOfflinePersistence: {
            FirebaseLogger.app.debug("Enabling offline persistence")
            let settings = Firestore.firestore().settings
            settings.isPersistenceEnabled = true

            // Use a reasonable cache size instead of unlimited to prevent excessive storage usage
            // 100MB is a good default for most applications
            settings.cacheSizeBytes = 100 * 1024 * 1024

            // Enable offline transaction persistence
            settings.persistenceEnabled = true

            // Set the settings on the Firestore instance
            Firestore.firestore().settings = settings

            // Add snapshots in sync listener to know when all listeners are in sync
            let _ = Firestore.firestore().addSnapshotsInSyncListener {
                FirebaseLogger.app.debug("All Firestore listeners are in sync")
            }

            FirebaseLogger.app.info("Offline persistence enabled with optimized settings")
        },

        disableNetwork: {
            FirebaseLogger.app.debug("Disabling network")
            do {
                try await Firestore.firestore().disableNetwork()
                FirebaseLogger.app.info("Network disabled")
            } catch {
                FirebaseLogger.app.error("Failed to disable network: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        enableNetwork: {
            FirebaseLogger.app.debug("Enabling network")
            do {
                try await Firestore.firestore().enableNetwork()
                FirebaseLogger.app.info("Network enabled")
            } catch {
                FirebaseLogger.app.error("Failed to enable network: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        isNetworkEnabled: {
            // There's no direct API to check network status, so we'll use a workaround
            // This is a placeholder - in a real implementation, you might want to track this state
            FirebaseLogger.app.debug("Checking if network is enabled")
            return true
        },

        waitForPendingWrites: {
            FirebaseLogger.app.debug("Waiting for pending writes")
            do {
                try await Firestore.firestore().waitForPendingWrites()
                FirebaseLogger.app.info("All pending writes acknowledged")
            } catch {
                FirebaseLogger.app.error("Failed to wait for pending writes: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        clearPersistence: {
            FirebaseLogger.app.debug("Clearing persistence")
            do {
                try await Firestore.firestore().clearPersistence()
                FirebaseLogger.app.info("Persistence cleared")
            } catch {
                FirebaseLogger.app.error("Failed to clear persistence: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        setCacheSize: { sizeInBytes in
            FirebaseLogger.app.debug("Setting cache size to \(sizeInBytes) bytes")
            let settings = Firestore.firestore().settings
            settings.cacheSizeBytes = sizeInBytes
            Firestore.firestore().settings = settings
            FirebaseLogger.app.info("Cache size set to \(sizeInBytes) bytes")
        }
    )
}

// MARK: - Mock Implementation

extension FirebaseOfflineManager {
    /// A mock implementation that returns predefined values for testing
    static func mock(
        enableOfflinePersistence: @escaping () async -> Void = { },
        disableNetwork: @escaping () async throws -> Void = { },
        enableNetwork: @escaping () async throws -> Void = { },
        isNetworkEnabled: @escaping () async -> Bool = { true },
        waitForPendingWrites: @escaping () async throws -> Void = { },
        clearPersistence: @escaping () async throws -> Void = { },
        setCacheSize: @escaping (_ sizeInBytes: Int64) async -> Void = { _ in }
    ) -> Self {
        Self(
            enableOfflinePersistence: enableOfflinePersistence,
            disableNetwork: disableNetwork,
            enableNetwork: enableNetwork,
            isNetworkEnabled: isNetworkEnabled,
            waitForPendingWrites: waitForPendingWrites,
            clearPersistence: clearPersistence,
            setCacheSize: setCacheSize
        )
    }

    /// A test implementation that fails with an unimplemented error
    static let testValue = Self(
        enableOfflinePersistence: XCTUnimplemented("\(Self.self).enableOfflinePersistence"),
        disableNetwork: XCTUnimplemented("\(Self.self).disableNetwork"),
        enableNetwork: XCTUnimplemented("\(Self.self).enableNetwork"),
        isNetworkEnabled: XCTUnimplemented("\(Self.self).isNetworkEnabled", placeholder: true),
        waitForPendingWrites: XCTUnimplemented("\(Self.self).waitForPendingWrites"),
        clearPersistence: XCTUnimplemented("\(Self.self).clearPersistence"),
        setCacheSize: XCTUnimplemented("\(Self.self).setCacheSize")
    )
}

// MARK: - Dependency Registration

extension DependencyValues {
    var firebaseOfflineManager: FirebaseOfflineManager {
        get { self[FirebaseOfflineManager.self] }
        set { self[FirebaseOfflineManager.self] = newValue }
    }
}
