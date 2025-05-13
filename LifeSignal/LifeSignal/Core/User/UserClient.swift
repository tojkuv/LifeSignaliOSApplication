import Foundation
import ComposableArchitecture
import FirebaseFirestore
import FirebaseAuth
import DependenciesMacros
import XCTestDynamicOverlay
import OSLog
import Dependencies

/// A client for interacting with Firebase user data
@DependencyClient
struct FirebaseUserClient: Sendable {
    /// Get user document once
    var getUserDocument: @Sendable (String) async throws -> UserData = { _ in
        throw FirebaseError.operationFailed
    }

    /// Stream user document updates
    var streamUser: @Sendable (String) -> AsyncStream<UserData> = { _ in
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    /// Update user document with arbitrary fields
    var updateUserDocument: @Sendable (String, [String: Any]) async throws -> Bool = { _, _ in
        throw FirebaseError.operationFailed
    }

    /// Update user profile
    var updateProfile: @Sendable (String, ProfileUpdate) async throws -> Bool = { _, _ in
        throw FirebaseError.operationFailed
    }

    /// Update notification preferences
    var updateNotificationPreferences: @Sendable (String, NotificationPreferences) async throws -> Bool = { _, _ in
        throw FirebaseError.operationFailed
    }

    /// Update check-in interval
    var updateCheckInInterval: @Sendable (String, TimeInterval) async throws -> Bool = { _, _ in
        throw FirebaseError.operationFailed
    }

    /// Perform check-in
    var checkIn: @Sendable (String) async throws -> Bool = { _ in
        throw FirebaseError.operationFailed
    }

    /// Trigger manual alert
    var triggerManualAlert: @Sendable (String) async throws -> Bool = { _ in
        throw FirebaseError.operationFailed
    }

    /// Clear manual alert
    var clearManualAlert: @Sendable (String) async throws -> Bool = { _ in
        throw FirebaseError.operationFailed
    }
}

// MARK: - Live Implementation

extension FirebaseUserClient: DependencyKey {
    static let liveValue = Self(
        getUserDocument: { userId in
            FirebaseLogger.user.debug("Getting user data for user: \(userId)")
            let path = "\(FirestoreConstants.Collections.users)/\(userId)"

            @Dependency(\.firestoreStorage) var firestoreStorage
            do {
                let userData = try await firestoreStorage.getDocument(
                    path: path,
                    transform: { snapshot in
                        guard let data = snapshot.data() else {
                            throw FirebaseError.emptyDocument
                        }

                        let userData = UserData.fromFirestore(data, userId: userId)
                        FirebaseLogger.user.debug("Retrieved user data for user: \(userId)")
                        return userData
                    }
                )
                return userData
            } catch {
                FirebaseLogger.user.error("Failed to get user document: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        streamUser: { userId in
            FirebaseLogger.user.debug("Starting user data stream for user: \(userId)")
            let path = "\(FirestoreConstants.Collections.users)/\(userId)"

            @Dependency(\.firestoreStorage) var firestoreStorage
            return firestoreStorage.documentStream(
                path: path,
                transform: { snapshot in
                    guard let data = snapshot.data() else {
                        FirebaseLogger.user.warning("Document exists but has no data")
                        throw FirebaseError.emptyDocument
                    }

                    let userData = UserData.fromFirestore(data, userId: userId)
                    FirebaseLogger.user.debug("Received user data update for user: \(userId)")
                    return userData
                }
            )
        },

        updateUserDocument: { userId, fields in
            FirebaseLogger.user.debug("Updating user document for user: \(userId)")

            // Add last updated timestamp if not already present
            var fieldsToUpdate = fields
            if fieldsToUpdate[FirestoreConstants.UserFields.lastUpdated] == nil {
                @Dependency(\.firebaseTimestampManager) var timestampManager
                fieldsToUpdate[FirestoreConstants.UserFields.lastUpdated] = timestampManager.serverTimestamp()
            }

            let path = "\(FirestoreConstants.Collections.users)/\(userId)"
            @Dependency(\.firestoreStorage) var firestoreStorage

            do {
                let success = try await firestoreStorage.updateDocument(
                    path: path,
                    data: fieldsToUpdate
                )

                if success {
                    FirebaseLogger.user.info("Updated user document for user: \(userId)")
                }

                return success
            } catch {
                FirebaseLogger.user.error("Failed to update user document: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        updateProfile: { userId, update in
            FirebaseLogger.user.debug("Updating profile for user: \(userId)")

            @Dependency(\.firebaseTimestampManager) var timestampManager
            let fields: [String: Any] = [
                FirestoreConstants.UserFields.name: update.name,
                FirestoreConstants.UserFields.emergencyNote: update.emergencyNote,
                FirestoreConstants.UserFields.profileComplete: true,
                FirestoreConstants.UserFields.lastUpdated: timestampManager.serverTimestamp()
            ]

            let path = "\(FirestoreConstants.Collections.users)/\(userId)"
            @Dependency(\.firestoreStorage) var firestoreStorage

            do {
                let success = try await firestoreStorage.updateDocument(
                    path: path,
                    data: fields
                )

                if success {
                    FirebaseLogger.user.info("Updated profile for user: \(userId)")
                }

                return success
            } catch {
                FirebaseLogger.user.error("Failed to update profile: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        updateNotificationPreferences: { userId, preferences in
            FirebaseLogger.user.debug("Updating notification preferences for user: \(userId)")

            @Dependency(\.firebaseTimestampManager) var timestampManager
            let fields: [String: Any] = [
                FirestoreConstants.UserFields.notificationEnabled: preferences.enabled,
                FirestoreConstants.UserFields.notify30MinBefore: preferences.notify30MinBefore,
                FirestoreConstants.UserFields.notify2HoursBefore: preferences.notify2HoursBefore,
                FirestoreConstants.UserFields.lastUpdated: timestampManager.serverTimestamp()
            ]

            let path = "\(FirestoreConstants.Collections.users)/\(userId)"
            @Dependency(\.firestoreStorage) var firestoreStorage

            do {
                let success = try await firestoreStorage.updateDocument(
                    path: path,
                    data: fields
                )

                if success {
                    FirebaseLogger.user.info("Updated notification preferences for user: \(userId)")
                }

                return success
            } catch {
                FirebaseLogger.user.error("Failed to update notification preferences: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        updateCheckInInterval: { userId, interval in
            FirebaseLogger.user.debug("Updating check-in interval for user: \(userId) to \(interval) seconds")

            @Dependency(\.firebaseTimestampManager) var timestampManager
            let fields: [String: Any] = [
                FirestoreConstants.UserFields.checkInInterval: interval,
                FirestoreConstants.UserFields.lastUpdated: timestampManager.serverTimestamp()
            ]

            let path = "\(FirestoreConstants.Collections.users)/\(userId)"
            @Dependency(\.firestoreStorage) var firestoreStorage

            do {
                let success = try await firestoreStorage.updateDocument(
                    path: path,
                    data: fields
                )

                if success {
                    FirebaseLogger.user.info("Updated check-in interval for user: \(userId)")
                }

                return success
            } catch {
                FirebaseLogger.user.error("Failed to update check-in interval: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        checkIn: { userId in
            FirebaseLogger.user.debug("Performing check-in for user: \(userId)")

            @Dependency(\.firebaseTimestampManager) var timestampManager
            let fields: [String: Any] = [
                FirestoreConstants.UserFields.lastCheckedIn: timestampManager.serverTimestamp(),
                FirestoreConstants.UserFields.lastUpdated: timestampManager.serverTimestamp()
            ]

            let path = "\(FirestoreConstants.Collections.users)/\(userId)"
            @Dependency(\.firestoreStorage) var firestoreStorage

            do {
                let success = try await firestoreStorage.updateDocument(
                    path: path,
                    data: fields
                )

                if success {
                    FirebaseLogger.user.info("Check-in completed for user: \(userId)")
                }

                return success
            } catch {
                FirebaseLogger.user.error("Failed to check in: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        triggerManualAlert: { userId in
            FirebaseLogger.user.debug("Triggering manual alert for user: \(userId)")

            @Dependency(\.firebaseTimestampManager) var timestampManager
            let fields: [String: Any] = [
                FirestoreConstants.UserFields.manualAlertActive: true,
                FirestoreConstants.UserFields.manualAlertTimestamp: timestampManager.serverTimestamp(),
                FirestoreConstants.UserFields.lastUpdated: timestampManager.serverTimestamp()
            ]

            let path = "\(FirestoreConstants.Collections.users)/\(userId)"
            @Dependency(\.firestoreStorage) var firestoreStorage

            do {
                let success = try await firestoreStorage.updateDocument(
                    path: path,
                    data: fields
                )

                if success {
                    FirebaseLogger.user.info("Manual alert triggered for user: \(userId)")
                }

                return success
            } catch {
                FirebaseLogger.user.error("Failed to trigger manual alert: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        clearManualAlert: { userId in
            FirebaseLogger.user.debug("Clearing manual alert for user: \(userId)")

            @Dependency(\.firebaseTimestampManager) var timestampManager
            let fields: [String: Any] = [
                FirestoreConstants.UserFields.manualAlertActive: false,
                FirestoreConstants.UserFields.lastUpdated: timestampManager.serverTimestamp()
            ]

            let path = "\(FirestoreConstants.Collections.users)/\(userId)"
            @Dependency(\.firestoreStorage) var firestoreStorage

            do {
                let success = try await firestoreStorage.updateDocument(
                    path: path,
                    data: fields
                )

                if success {
                    FirebaseLogger.user.info("Manual alert cleared for user: \(userId)")
                }

                return success
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
        getUserDocument: unimplemented("\(Self.self).getUserDocument", placeholder: { _ in throw FirebaseError.operationFailed }),
        streamUser: unimplemented("\(Self.self).streamUser", placeholder: { _ in
            AsyncStream { continuation in
                continuation.yield(.empty)
                continuation.finish()
            }
        }),
        updateUserDocument: unimplemented("\(Self.self).updateUserDocument", placeholder: { _, _ in throw FirebaseError.operationFailed }),
        updateProfile: unimplemented("\(Self.self).updateProfile", placeholder: { _, _ in throw FirebaseError.operationFailed }),
        updateNotificationPreferences: unimplemented("\(Self.self).updateNotificationPreferences", placeholder: { _, _ in throw FirebaseError.operationFailed }),
        updateCheckInInterval: unimplemented("\(Self.self).updateCheckInInterval", placeholder: { _, _ in throw FirebaseError.operationFailed }),
        checkIn: unimplemented("\(Self.self).checkIn", placeholder: { _ in throw FirebaseError.operationFailed }),
        triggerManualAlert: unimplemented("\(Self.self).triggerManualAlert", placeholder: { _ in throw FirebaseError.operationFailed }),
        clearManualAlert: unimplemented("\(Self.self).clearManualAlert", placeholder: { _ in throw FirebaseError.operationFailed })
    )

    /// A mock implementation that returns predefined values for testing
    static func mock(
        getUserDocument: @escaping @Sendable (String) async throws -> UserData = { _ in .empty },
        streamUser: @escaping @Sendable (String) -> AsyncStream<UserData> = { _ in
            AsyncStream<UserData> { continuation in
                continuation.yield(.empty)
                continuation.finish()
            }
        },
        updateUserDocument: @escaping @Sendable (String, [String: Any]) async throws -> Bool = { _, _ in true },
        updateProfile: @escaping @Sendable (String, ProfileUpdate) async throws -> Bool = { _, _ in true },
        updateNotificationPreferences: @escaping @Sendable (String, NotificationPreferences) async throws -> Bool = { _, _ in true },
        updateCheckInInterval: @escaping @Sendable (String, TimeInterval) async throws -> Bool = { _, _ in true },
        checkIn: @escaping @Sendable (String) async throws -> Bool = { _ in true },
        triggerManualAlert: @escaping @Sendable (String) async throws -> Bool = { _ in true },
        clearManualAlert: @escaping @Sendable (String) async throws -> Bool = { _ in true }
    ) -> Self {
        Self(
            getUserDocument: getUserDocument,
            streamUser: streamUser,
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
