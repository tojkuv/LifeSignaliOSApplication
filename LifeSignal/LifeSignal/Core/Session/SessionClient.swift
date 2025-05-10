import Foundation
@preconcurrency import FirebaseFirestore
import FirebaseAuth
import ComposableArchitecture

/// Client for managing user sessions
struct SessionClient: Sendable {
    /// Get the current session ID
    var getCurrentSessionId: @Sendable () async -> String?

    /// Update the session ID in Firestore and UserDefaults
    var updateSession: @Sendable (userId: String) async throws -> Void

    /// Validate the current session against Firestore
    var validateSession: @Sendable (userId: String) async throws -> Bool

    /// Set up a listener for session changes
    var watchSession: @Sendable (userId: String) async -> AsyncStream<Void>

    /// Clear the session ID
    var clearSessionId: @Sendable () async -> Void
}

extension SessionClient {
    /// Live implementation of SessionClient
    static let live = Self(
        getCurrentSessionId: {
            return UserDefaults.standard.string(forKey: "user_session_id")
        },

        updateSession: { userId in
            // Generate a new session ID
            let sessionId = UUID().uuidString

            // Save locally first
            UserDefaults.standard.set(sessionId, forKey: "user_session_id")

            // Session data to update or create
            let sessionData: [String: Any] = [
                FirestoreConstants.UserFields.sessionId: sessionId,
                FirestoreConstants.UserFields.lastSignInTime: FieldValue.serverTimestamp()
            ]

            // Get the dependency values
            @Dependency(\.firebaseClient) var firebaseClient

            do {
                // Try to get the user document
                let userData = try await firebaseClient.getDocument(collection: FirestoreConstants.Collections.users, documentId: userId)

                // Document exists, update it
                // For test users, use setData with merge to ensure all fields are preserved
                if let phoneNumber = Auth.auth().currentUser?.phoneNumber,
                   phoneNumber == "+11234567890" || phoneNumber == "+16505553434" {
                    try await firebaseClient.setDocument(
                        collection: FirestoreConstants.Collections.users,
                        documentId: userId,
                        data: sessionData,
                        merge: true
                    )
                } else {
                    // Regular user, use updateData
                    try await firebaseClient.updateDocument(
                        collection: FirestoreConstants.Collections.users,
                        documentId: userId,
                        data: sessionData
                    )
                }
            } catch FirebaseError.documentNotFound {
                // Document doesn't exist, create it with basic user data
                var userData = sessionData

                // Add additional required fields for a new user
                userData[FirestoreConstants.UserFields.uid] = userId
                userData[FirestoreConstants.UserFields.createdAt] = FieldValue.serverTimestamp()
                userData[FirestoreConstants.UserFields.profileComplete] = false

                // Generate a QR code ID for the new user - CRITICAL FIELD
                let qrCodeId = UUID().uuidString
                userData[FirestoreConstants.UserFields.qrCodeId] = qrCodeId

                // Add phone number if available
                if let phoneNumber = Auth.auth().currentUser?.phoneNumber {
                    userData[FirestoreConstants.UserFields.phoneNumber] = phoneNumber
                } else {
                    userData[FirestoreConstants.UserFields.phoneNumber] = "" // Required field
                }

                // Add required fields according to Firestore rules
                userData[FirestoreConstants.UserFields.name] = "New User" // Required field
                userData[FirestoreConstants.UserFields.note] = "" // Required field
                userData[FirestoreConstants.UserFields.checkInInterval] = 24 * 60 * 60 // 24 hours in seconds
                userData[FirestoreConstants.UserFields.lastCheckedIn] = FieldValue.serverTimestamp()

                // Initialize other fields with default values
                userData[FirestoreConstants.UserFields.notificationEnabled] = true
                userData[FirestoreConstants.UserFields.notify30MinBefore] = false
                userData[FirestoreConstants.UserFields.notify2HoursBefore] = false
                userData[FirestoreConstants.UserFields.manualAlertActive] = false
                userData[FirestoreConstants.UserFields.contacts] = []

                // Create the document
                try await firebaseClient.setDocument(
                    collection: FirestoreConstants.Collections.users,
                    documentId: userId,
                    data: userData,
                    merge: false
                )
            }
        },

        validateSession: { userId in
            // Get the local session ID
            guard let localSessionId = UserDefaults.standard.string(forKey: "user_session_id") else {
                throw SessionError.noLocalSessionId
            }

            // Get the dependency values
            @Dependency(\.firebaseClient) var firebaseClient

            // Get the user document
            let userData = try await firebaseClient.getDocument(
                collection: FirestoreConstants.Collections.users,
                documentId: userId
            )

            // Check if the remote session ID matches the local one
            if let remoteSessionId = userData[FirestoreConstants.UserFields.sessionId] as? String {
                return remoteSessionId == localSessionId
            } else {
                throw SessionError.noRemoteSessionId
            }
        },

        watchSession: { userId in
            // Get the dependency values
            let db = Firestore.firestore()

            return AsyncStream { continuation in
                let listener = db.collection(FirestoreConstants.Collections.users).document(userId).addSnapshotListener { snapshot, error in
                    guard let snapshot = snapshot, snapshot.exists else {
                        return
                    }

                    Task {
                        if let remoteSessionId = snapshot.data()?[FirestoreConstants.UserFields.sessionId] as? String,
                           let localSessionId = UserDefaults.standard.string(forKey: "user_session_id"),
                           remoteSessionId != localSessionId {
                            // Session is invalid
                            continuation.yield()
                        }
                    }
                }

                continuation.onTermination = { _ in
                    listener.remove()
                }
            }
        },

        clearSessionId: {
            UserDefaults.standard.removeObject(forKey: "user_session_id")
        }
    )

    /// Test implementation for testing
    static let test = Self(
        getCurrentSessionId: {
            return "mock-session-id"
        },

        updateSession: { _ in
            // No-op for testing
        },

        validateSession: { _ in
            return true
        },

        watchSession: { _ in
            return AsyncStream { _ in
                // No-op for testing
            }
        },

        clearSessionId: {
            // No-op for testing
        }
    )
}

/// Session-related errors
enum SessionError: Error, LocalizedError {
    case noLocalSessionId
    case userDocumentNotFound
    case noRemoteSessionId

    var errorDescription: String? {
        switch self {
        case .noLocalSessionId:
            return "No local session ID"
        case .userDocumentNotFound:
            return "User document not found"
        case .noRemoteSessionId:
            return "No remote session ID"
        }
    }
}

// TCA dependency registration
extension DependencyValues {
    var sessionClient: SessionClient {
        get { self[SessionClientKey.self] }
        set { self[SessionClientKey.self] = newValue }
    }

    private enum SessionClientKey: DependencyKey {
        static let liveValue = SessionClient.live
        static let testValue = SessionClient.test
    }
}
