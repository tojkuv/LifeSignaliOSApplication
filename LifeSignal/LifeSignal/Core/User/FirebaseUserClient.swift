import Foundation
import ComposableArchitecture
import FirebaseFirestore
import FirebaseAuth
import DependenciesMacros
import XCTestDynamicOverlay
import OSLog

/// A client for interacting with Firebase user data
@DependencyClient
struct FirebaseUserClient: Sendable {
    /// Get user data once
    var getUserData: @Sendable (_ userId: String) async throws -> UserData

    /// Get user document once
    var getUserDocument: @Sendable (_ userId: String) async throws -> UserData

    /// Stream user data updates
    var streamUserData: @Sendable (_ userId: String) -> AsyncStream<TaskResult<UserData>>

    /// Stream user document updates
    var streamUserDocument: @Sendable (_ userId: String) -> AsyncStream<TaskResult<UserData>>

    /// Update user document with arbitrary fields
    var updateUserDocument: @Sendable (_ userId: String, _ fields: [String: Any]) async throws -> Void

    /// Update user profile
    var updateProfile: @Sendable (_ userId: String, _ update: ProfileUpdate) async throws -> Void

    /// Update notification preferences
    var updateNotificationPreferences: @Sendable (_ userId: String, _ preferences: NotificationPreferences) async throws -> Void

    /// Update check-in interval
    var updateCheckInInterval: @Sendable (_ userId: String, _ interval: TimeInterval) async throws -> Void

    /// Perform check-in
    var checkIn: @Sendable (_ userId: String) async throws -> Void

    /// Trigger manual alert
    var triggerManualAlert: @Sendable (_ userId: String) async throws -> Void

    /// Clear manual alert
    var clearManualAlert: @Sendable (_ userId: String) async throws -> Void
}

// MARK: - Live Implementation

extension FirebaseUserClient: DependencyKey {
    static let liveValue = Self(
        getUserData: { userId in
            FirebaseLogger.user.debug("Getting user data for user: \(userId)")
            do {
                let db = Firestore.firestore()
                let documentSnapshot = try await db.collection(FirestoreConstants.Collections.users).document(userId).getDocument()

                guard documentSnapshot.exists, let data = documentSnapshot.data() else {
                    FirebaseLogger.user.error("User document not found: \(userId)")
                    throw FirebaseError.documentNotFound
                }

                let userData = UserData.fromFirestore(data, userId: userId)
                FirebaseLogger.user.debug("Retrieved user data for user: \(userId)")
                return userData
            } catch {
                FirebaseLogger.user.error("Failed to get user data: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        getUserDocument: { userId in
            FirebaseLogger.user.debug("Getting user document for user: \(userId)")
            do {
                let db = Firestore.firestore()
                let documentSnapshot = try await db.collection(FirestoreConstants.Collections.users).document(userId).getDocument()

                guard documentSnapshot.exists, let data = documentSnapshot.data() else {
                    FirebaseLogger.user.error("User document not found: \(userId)")
                    throw FirebaseError.documentNotFound
                }

                let userData = UserData.fromFirestore(data, userId: userId)
                FirebaseLogger.user.debug("Retrieved user document for user: \(userId)")
                return userData
            } catch {
                FirebaseLogger.user.error("Failed to get user document: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        streamUserData: { userId in
            FirebaseLogger.user.debug("Starting user data stream for user: \(userId)")
            return FirestoreStreamHelper.documentStream(
                path: "\(FirestoreConstants.Collections.users)/\(userId)",
                logger: FirebaseLogger.user
            ) { snapshot in
                guard let data = snapshot.data() else {
                    FirebaseLogger.user.warning("Document exists but has no data")
                    throw FirebaseError.emptyDocument
                }

                let userData = UserData.fromFirestore(data, userId: userId)
                FirebaseLogger.user.debug("Received user data update for user: \(userId)")
                return userData
            }
        },

        streamUserDocument: { userId in
            FirebaseLogger.user.debug("Starting user document stream for user: \(userId)")
            return FirestoreStreamHelper.documentStream(
                path: "\(FirestoreConstants.Collections.users)/\(userId)",
                logger: FirebaseLogger.user
            ) { snapshot in
                guard let data = snapshot.data() else {
                    FirebaseLogger.user.warning("Document exists but has no data")
                    throw FirebaseError.emptyDocument
                }

                let userData = UserData.fromFirestore(data, userId: userId)
                FirebaseLogger.user.debug("Received user document update for user: \(userId)")
                return userData
            }
        },

        updateUserDocument: { userId, fields in
            FirebaseLogger.user.debug("Updating user document for user: \(userId)")
            do {
                // Add last updated timestamp if not already present
                var fieldsToUpdate = fields
                if fieldsToUpdate[FirestoreConstants.UserFields.lastUpdated] == nil {
                    @Dependency(\.firebaseTimestampManager) var timestampManager
                    fieldsToUpdate[FirestoreConstants.UserFields.lastUpdated] = timestampManager.serverTimestamp()
                }

                let db = Firestore.firestore()
                try await db.collection(FirestoreConstants.Collections.users).document(userId).updateData(fieldsToUpdate)
                FirebaseLogger.user.info("Updated user document for user: \(userId)")
            } catch {
                FirebaseLogger.user.error("Failed to update user document: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        updateProfile: { userId, update in
            FirebaseLogger.user.debug("Updating profile for user: \(userId)")
            do {
                @Dependency(\.firebaseTimestampManager) var timestampManager
                let fields: [String: Any] = [
                    FirestoreConstants.UserFields.name: update.name,
                    FirestoreConstants.UserFields.emergencyNote: update.emergencyNote,
                    FirestoreConstants.UserFields.profileComplete: true,
                    FirestoreConstants.UserFields.lastUpdated: timestampManager.serverTimestamp()
                ]

                let db = Firestore.firestore()
                try await db.collection(FirestoreConstants.Collections.users).document(userId).updateData(fields)
                FirebaseLogger.user.info("Updated profile for user: \(userId)")
            } catch {
                FirebaseLogger.user.error("Failed to update profile: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        updateNotificationPreferences: { userId, preferences in
            FirebaseLogger.user.debug("Updating notification preferences for user: \(userId)")
            do {
                @Dependency(\.firebaseTimestampManager) var timestampManager
                let fields: [String: Any] = [
                    FirestoreConstants.UserFields.notificationEnabled: preferences.enabled,
                    FirestoreConstants.UserFields.notify30MinBefore: preferences.notify30MinBefore,
                    FirestoreConstants.UserFields.notify2HoursBefore: preferences.notify2HoursBefore,
                    FirestoreConstants.UserFields.lastUpdated: timestampManager.serverTimestamp()
                ]

                let db = Firestore.firestore()
                try await db.collection(FirestoreConstants.Collections.users).document(userId).updateData(fields)
                FirebaseLogger.user.info("Updated notification preferences for user: \(userId)")
            } catch {
                FirebaseLogger.user.error("Failed to update notification preferences: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        updateCheckInInterval: { userId, interval in
            FirebaseLogger.user.debug("Updating check-in interval for user: \(userId) to \(interval) seconds")
            do {
                @Dependency(\.firebaseTimestampManager) var timestampManager
                let fields: [String: Any] = [
                    FirestoreConstants.UserFields.checkInInterval: interval,
                    FirestoreConstants.UserFields.lastUpdated: timestampManager.serverTimestamp()
                ]

                let db = Firestore.firestore()
                try await db.collection(FirestoreConstants.Collections.users).document(userId).updateData(fields)
                FirebaseLogger.user.info("Updated check-in interval for user: \(userId)")
            } catch {
                FirebaseLogger.user.error("Failed to update check-in interval: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        checkIn: { userId in
            FirebaseLogger.user.debug("Performing check-in for user: \(userId)")
            do {
                @Dependency(\.firebaseTimestampManager) var timestampManager
                let fields: [String: Any] = [
                    FirestoreConstants.UserFields.lastCheckedIn: timestampManager.serverTimestamp(),
                    FirestoreConstants.UserFields.lastUpdated: timestampManager.serverTimestamp()
                ]

                let db = Firestore.firestore()
                try await db.collection(FirestoreConstants.Collections.users).document(userId).updateData(fields)
                FirebaseLogger.user.info("Check-in completed for user: \(userId)")
            } catch {
                FirebaseLogger.user.error("Failed to perform check-in: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        triggerManualAlert: { userId in
            FirebaseLogger.user.debug("Triggering manual alert for user: \(userId)")
            do {
                @Dependency(\.firebaseTimestampManager) var timestampManager
                let fields: [String: Any] = [
                    FirestoreConstants.UserFields.manualAlertActive: true,
                    FirestoreConstants.UserFields.manualAlertTimestamp: timestampManager.serverTimestamp(),
                    FirestoreConstants.UserFields.lastUpdated: timestampManager.serverTimestamp()
                ]

                let db = Firestore.firestore()
                try await db.collection(FirestoreConstants.Collections.users).document(userId).updateData(fields)
                FirebaseLogger.user.info("Manual alert triggered for user: \(userId)")
            } catch {
                FirebaseLogger.user.error("Failed to trigger manual alert: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        clearManualAlert: { userId in
            FirebaseLogger.user.debug("Clearing manual alert for user: \(userId)")
            do {
                @Dependency(\.firebaseTimestampManager) var timestampManager
                let fields: [String: Any] = [
                    FirestoreConstants.UserFields.manualAlertActive: false,
                    FirestoreConstants.UserFields.lastUpdated: timestampManager.serverTimestamp()
                ]

                let db = Firestore.firestore()
                try await db.collection(FirestoreConstants.Collections.users).document(userId).updateData(fields)
                FirebaseLogger.user.info("Manual alert cleared for user: \(userId)")
            } catch {
                FirebaseLogger.user.error("Failed to clear manual alert: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        }
    )
}

// MARK: - Test Implementation

extension FirebaseUserClient {
    /// A test implementation that returns predefined values for testing
    static let testValue = Self(
        getUserData: XCTUnimplemented("\(Self.self).getUserData", placeholder: .empty),
        getUserDocument: XCTUnimplemented("\(Self.self).getUserDocument", placeholder: .empty),
        streamUserData: XCTUnimplemented("\(Self.self).streamUserData", placeholder: { _ in AsyncStream { _ in } }),
        streamUserDocument: XCTUnimplemented("\(Self.self).streamUserDocument", placeholder: { _ in AsyncStream { _ in } }),
        updateUserDocument: XCTUnimplemented("\(Self.self).updateUserDocument"),
        updateProfile: XCTUnimplemented("\(Self.self).updateProfile"),
        updateNotificationPreferences: XCTUnimplemented("\(Self.self).updateNotificationPreferences"),
        updateCheckInInterval: XCTUnimplemented("\(Self.self).updateCheckInInterval"),
        checkIn: XCTUnimplemented("\(Self.self).checkIn"),
        triggerManualAlert: XCTUnimplemented("\(Self.self).triggerManualAlert"),
        clearManualAlert: XCTUnimplemented("\(Self.self).clearManualAlert")
    )

    /// A mock implementation that returns predefined values for testing
    static func mock(
        getUserData: @escaping (_ userId: String) async throws -> UserData = { _ in .empty },
        getUserDocument: @escaping (_ userId: String) async throws -> UserData = { _ in .empty },
        streamUserData: @escaping (_ userId: String) -> AsyncStream<TaskResult<UserData>> = { _ in
            AsyncStream { continuation in
                continuation.yield(.success(.empty))
                continuation.finish()
            }
        },
        streamUserDocument: @escaping (_ userId: String) -> AsyncStream<TaskResult<UserData>> = { _ in
            AsyncStream { continuation in
                continuation.yield(.success(.empty))
                continuation.finish()
            }
        },
        updateUserDocument: @escaping (_ userId: String, _ fields: [String: Any]) async throws -> Void = { _, _ in },
        updateProfile: @escaping (_ userId: String, _ update: ProfileUpdate) async throws -> Void = { _, _ in },
        updateNotificationPreferences: @escaping (_ userId: String, _ preferences: NotificationPreferences) async throws -> Void = { _, _ in },
        updateCheckInInterval: @escaping (_ userId: String, _ interval: TimeInterval) async throws -> Void = { _, _ in },
        checkIn: @escaping (_ userId: String) async throws -> Void = { _ in },
        triggerManualAlert: @escaping (_ userId: String) async throws -> Void = { _ in },
        clearManualAlert: @escaping (_ userId: String) async throws -> Void = { _ in }
    ) -> Self {
        Self(
            getUserData: getUserData,
            getUserDocument: getUserDocument,
            streamUserData: streamUserData,
            streamUserDocument: streamUserDocument,
            updateUserDocument: updateUserDocument,
            updateProfile: updateProfile,
            updateNotificationPreferences: updateNotificationPreferences,
            updateCheckInInterval: updateCheckInInterval,
            checkIn: checkIn,
            triggerManualAlert: triggerManualAlert,
            clearManualAlert: clearManualAlert
        )
    }
}

extension DependencyValues {
    var firebaseUserClient: FirebaseUserClient {
        get { self[FirebaseUserClient.self] }
        set { self[FirebaseUserClient.self] = newValue }
    }
}
