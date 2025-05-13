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
    var getUserData: @Sendable (String) async throws -> UserData

    /// Get user document once
    var getUserDocument: @Sendable (String) async throws -> UserData

    /// Stream user data updates
    var streamUserData: @Sendable (String) -> AsyncStream<UserData>

    /// Stream user document updates
    var streamUserDocument: @Sendable (String) -> AsyncStream<UserData>

    /// Update user document with arbitrary fields
    var updateUserDocument: @Sendable (String, [String: Any]) async throws -> Void

    /// Update user profile
    var updateProfile: @Sendable (String, ProfileUpdate) async throws -> Void

    /// Update notification preferences
    var updateNotificationPreferences: @Sendable (String, NotificationPreferences) async throws -> Void

    /// Update check-in interval
    var updateCheckInInterval: @Sendable (String, TimeInterval) async throws -> Void

    /// Perform check-in
    var checkIn: @Sendable (String) async throws -> Void

    /// Trigger manual alert
    var triggerManualAlert: @Sendable (String) async throws -> Void

    /// Clear manual alert
    var clearManualAlert: @Sendable (String) async throws -> Void
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

            // Create a new AsyncStream that transforms the TaskResult stream into a UserData stream
            return AsyncStream<UserData> { continuation in
                // Create a task to handle the stream
                let task = Task {
                    do {
                        // Get the original stream with TaskResult
                        let taskResultStream = FirestoreStreamHelper.documentStream(
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

                        // Process the TaskResult stream
                        for await result in taskResultStream {
                            switch result {
                            case .success(let userData):
                                continuation.yield(userData)
                            case .failure(let error):
                                FirebaseLogger.user.error("Error in user data stream: \(error.localizedDescription)")
                                // Map the error to a UserFacingError for better handling
                                let userFacingError = UserFacingError.from(error)
                                FirebaseLogger.user.debug("Mapped to user facing error: \(userFacingError)")
                                // We don't propagate errors in the stream, just log them
                                // This makes the stream more resilient and easier to use
                                continue
                            }
                        }

                        // If we get here, the stream has ended
                        continuation.finish()
                    } catch {
                        FirebaseLogger.user.error("Fatal error in user data stream: \(error.localizedDescription)")
                        continuation.finish()
                    }
                }

                // Set up cancellation
                continuation.onTermination = { _ in
                    task.cancel()
                }
            }
        },

        streamUserDocument: { userId in
            FirebaseLogger.user.debug("Starting user document stream for user: \(userId)")

            // Create a new AsyncStream that transforms the TaskResult stream into a UserData stream
            return AsyncStream<UserData> { continuation in
                // Create a task to handle the stream
                let task = Task {
                    do {
                        // Get the original stream with TaskResult
                        let taskResultStream = FirestoreStreamHelper.documentStream(
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

                        // Process the TaskResult stream
                        for await result in taskResultStream {
                            switch result {
                            case .success(let userData):
                                continuation.yield(userData)
                            case .failure(let error):
                                FirebaseLogger.user.error("Error in user document stream: \(error.localizedDescription)")
                                // Map the error to a UserFacingError for better handling
                                let userFacingError = UserFacingError.from(error)
                                FirebaseLogger.user.debug("Mapped to user facing error: \(userFacingError)")
                                // We don't propagate errors in the stream, just log them
                                // This makes the stream more resilient and easier to use
                                continue
                            }
                        }

                        // If we get here, the stream has ended
                        continuation.finish()
                    } catch {
                        FirebaseLogger.user.error("Fatal error in user document stream: \(error.localizedDescription)")
                        continuation.finish()
                    }
                }

                // Set up cancellation
                continuation.onTermination = { _ in
                    task.cancel()
                }
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

extension FirebaseUserClient: TestDependencyKey {
    /// A test implementation that returns predefined values for testing
    static let testValue = Self(
        getUserData: unimplemented("\(Self.self).getUserData", placeholder: .empty),
        getUserDocument: unimplemented("\(Self.self).getUserDocument", placeholder: .empty),
        streamUserData: unimplemented("\(Self.self).streamUserData", placeholder: { _ in
            AsyncStream { continuation in
                continuation.yield(.empty)
                continuation.finish()
            }
        }),
        streamUserDocument: unimplemented("\(Self.self).streamUserDocument", placeholder: { _ in
            AsyncStream { continuation in
                continuation.yield(.empty)
                continuation.finish()
            }
        }),
        updateUserDocument: unimplemented("\(Self.self).updateUserDocument"),
        updateProfile: unimplemented("\(Self.self).updateProfile"),
        updateNotificationPreferences: unimplemented("\(Self.self).updateNotificationPreferences"),
        updateCheckInInterval: unimplemented("\(Self.self).updateCheckInInterval"),
        checkIn: unimplemented("\(Self.self).checkIn"),
        triggerManualAlert: unimplemented("\(Self.self).triggerManualAlert"),
        clearManualAlert: unimplemented("\(Self.self).clearManualAlert")
    )

    /// A mock implementation that returns predefined values for testing
    static func mock(
        getUserData: @escaping @Sendable (String) async throws -> UserData = { _ in .empty },
        getUserDocument: @escaping @Sendable (String) async throws -> UserData = { _ in .empty },
        streamUserData: @escaping @Sendable (String) -> AsyncStream<UserData> = { _ in
            AsyncStream<UserData> { continuation in
                continuation.yield(.empty)
                continuation.finish()
            }
        },
        streamUserDocument: @escaping @Sendable (String) -> AsyncStream<UserData> = { _ in
            AsyncStream<UserData> { continuation in
                continuation.yield(.empty)
                continuation.finish()
            }
        },
        updateUserDocument: @escaping @Sendable (String, [String: Any]) async throws -> Void = { _, _ in },
        updateProfile: @escaping @Sendable (String, ProfileUpdate) async throws -> Void = { _, _ in },
        updateNotificationPreferences: @escaping @Sendable (String, NotificationPreferences) async throws -> Void = { _, _ in },
        updateCheckInInterval: @escaping @Sendable (String, TimeInterval) async throws -> Void = { _, _ in },
        checkIn: @escaping @Sendable (String) async throws -> Void = { _ in },
        triggerManualAlert: @escaping @Sendable (String) async throws -> Void = { _ in },
        clearManualAlert: @escaping @Sendable (String) async throws -> Void = { _ in }
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
