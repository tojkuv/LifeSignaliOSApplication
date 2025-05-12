import Foundation
import FirebaseAuth
import FirebaseFirestore
import DependenciesMacros
import Dependencies
import XCTestDynamicOverlay
import OSLog

/// A client for managing Firebase session operations
@DependencyClient
struct FirebaseSessionClient: Sendable {
    /// Get the current session ID
    var getCurrentSessionId: @Sendable () -> String?

    /// Set the current session ID
    var setCurrentSessionId: @Sendable (_ sessionId: String) -> Void

    /// Clear the current session ID
    var clearSessionId: @Sendable () -> Void

    /// Create a new session for a user
    var createSession: @Sendable (_ userId: String) async throws -> String

    /// Validate a session for a user
    var validateSession: @Sendable (_ userId: String, _ sessionId: String) async throws -> Bool

    /// Stream session changes for a user
    var streamSessionChanges: @Sendable (_ userId: String) -> AsyncStream<String?>
}

// MARK: - Live Implementation

extension FirebaseSessionClient: DependencyKey {
    static let liveValue = Self(
        getCurrentSessionId: {
            FirebaseLogger.session.debug("Getting current session ID")
            let sessionId = UserDefaults.standard.string(forKey: "user_session_id")
            if let sessionId = sessionId {
                FirebaseLogger.session.debug("Current session ID: \(sessionId)")
            } else {
                FirebaseLogger.session.debug("No current session ID found")
            }
            return sessionId
        },

        setCurrentSessionId: { sessionId in
            FirebaseLogger.session.debug("Setting current session ID: \(sessionId)")
            UserDefaults.standard.set(sessionId, forKey: "user_session_id")
            FirebaseLogger.session.info("Session ID set successfully")
        },

        clearSessionId: {
            FirebaseLogger.session.debug("Clearing session ID")
            UserDefaults.standard.removeObject(forKey: "user_session_id")
            FirebaseLogger.session.info("Session ID cleared successfully")
        },

        createSession: { userId in
            FirebaseLogger.session.debug("Creating new session for user: \(userId)")
            // Generate a new session ID
            let sessionId = UUID().uuidString
            FirebaseLogger.session.debug("Generated session ID: \(sessionId)")

            // Create session data
            let sessionData: [String: Any] = [
                FirestoreConstants.UserFields.sessionId: sessionId,
                FirestoreConstants.UserFields.lastActive: FieldValue.serverTimestamp()
            ]

            do {
                // Update the user document with the new session
                let db = Firestore.firestore()
                try await db.collection(FirestoreConstants.Collections.users).document(userId).updateData(sessionData)
                FirebaseLogger.session.info("Session created in Firestore for user: \(userId)")

                // Store the session ID locally
                UserDefaults.standard.set(sessionId, forKey: "user_session_id")
                FirebaseLogger.session.debug("Session ID stored locally")

                return sessionId
            } catch {
                FirebaseLogger.session.error("Failed to create session: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        validateSession: { userId, sessionId in
            FirebaseLogger.session.debug("Validating session for user: \(userId)")
            do {
                let db = Firestore.firestore()
                let documentSnapshot = try await db.collection(FirestoreConstants.Collections.users).document(userId).getDocument()

                guard documentSnapshot.exists, let data = documentSnapshot.data() else {
                    FirebaseLogger.session.error("User document not found")
                    throw FirebaseError.documentNotFound
                }

                // Get the remote session ID
                guard let remoteSessionId = data[FirestoreConstants.UserFields.sessionId] as? String else {
                    FirebaseLogger.session.warning("No session ID found in user document")
                    return false
                }

                // Compare with the local session ID
                let isValid = remoteSessionId == sessionId
                FirebaseLogger.session.info("Session validation result: \(isValid)")
                return isValid
            } catch {
                FirebaseLogger.session.error("Session validation failed: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        streamSessionChanges: { userId in
            FirebaseLogger.session.debug("Starting session changes stream for user: \(userId)")
            return AsyncStream { continuation in
                let db = Firestore.firestore()
                let userRef = db.collection(FirestoreConstants.Collections.users).document(userId)

                // Set up listener
                let listener = userRef.addSnapshotListener { documentSnapshot, error in
                    if let error = error {
                        FirebaseLogger.session.error("Error listening for session changes: \(error.localizedDescription)")
                        return
                    }

                    guard let document = documentSnapshot, document.exists else {
                        FirebaseLogger.session.warning("Document does not exist")
                        continuation.yield(nil)
                        return
                    }

                    if let data = document.data(), let sessionId = data[FirestoreConstants.UserFields.sessionId] as? String {
                        FirebaseLogger.session.debug("Session change detected: \(sessionId)")
                        continuation.yield(sessionId)
                    } else {
                        FirebaseLogger.session.debug("No session ID in document")
                        continuation.yield(nil)
                    }
                }

                // Set up cancellation
                continuation.onTermination = { _ in
                    FirebaseLogger.session.debug("Terminating session changes listener for user \(userId)")
                    listener.remove()
                }
            }
        }
    )
}

// MARK: - Mock Implementation

extension FirebaseSessionClient {
    /// A mock implementation that returns predefined values for testing
    static func mock(
        getCurrentSessionId: @escaping () -> String? = { nil },
        setCurrentSessionId: @escaping (_ sessionId: String) -> Void = { _ in },
        clearSessionId: @escaping () -> Void = { },
        createSession: @escaping (_ userId: String) async throws -> String = { _ in UUID().uuidString },
        validateSession: @escaping (_ userId: String, _ sessionId: String) async throws -> Bool = { _, _ in true },
        streamSessionChanges: @escaping (_ userId: String) -> AsyncStream<String?> = { _ in AsyncStream { _ in } }
    ) -> Self {
        Self(
            getCurrentSessionId: getCurrentSessionId,
            setCurrentSessionId: setCurrentSessionId,
            clearSessionId: clearSessionId,
            createSession: createSession,
            validateSession: validateSession,
            streamSessionChanges: streamSessionChanges
        )
    }

    /// A test implementation that fails with an unimplemented error
    static let testValue = Self(
        getCurrentSessionId: XCTUnimplemented("\(Self.self).getCurrentSessionId", placeholder: nil),
        setCurrentSessionId: XCTUnimplemented("\(Self.self).setCurrentSessionId"),
        clearSessionId: XCTUnimplemented("\(Self.self).clearSessionId"),
        createSession: XCTUnimplemented("\(Self.self).createSession", placeholder: { _ in "" }),
        validateSession: XCTUnimplemented("\(Self.self).validateSession", placeholder: { _, _ in false }),
        streamSessionChanges: XCTUnimplemented("\(Self.self).streamSessionChanges", placeholder: { _ in AsyncStream { _ in } })
    )
}

extension DependencyValues {
    var firebaseSessionClient: FirebaseSessionClient {
        get { self[FirebaseSessionClient.self] }
        set { self[FirebaseSessionClient.self] = newValue }
    }
}
