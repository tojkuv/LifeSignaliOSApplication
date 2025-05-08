import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

/// Service class for managing user sessions including creation, validation, and termination
class SessionManager {
    // Singleton instance
    static let shared = SessionManager()

    // UserDefaults key for session ID
    private let sessionIdKey = "user_session_id"

    // Firestore reference
    private let db = Firestore.firestore()

    // Private initializer for singleton
    private init() {}

    // MARK: - Session ID Management

    /// Generate a new session ID
    /// - Returns: A new UUID string
    private func generateSessionId() -> String {
        return UUID().uuidString
    }

    /// Get the current session ID from UserDefaults
    /// - Returns: The current session ID or nil if not set
    func getCurrentSessionId() -> String? {
        return UserDefaults.standard.string(forKey: sessionIdKey)
    }

    /// Save a session ID to UserDefaults
    /// - Parameter sessionId: The session ID to save
    private func saveSessionId(_ sessionId: String) {
        UserDefaults.standard.set(sessionId, forKey: sessionIdKey)
    }

    /// Clear the session ID from UserDefaults
    func clearSessionId() {
        UserDefaults.standard.removeObject(forKey: sessionIdKey)
    }

    /// Update the session ID in Firestore and UserDefaults
    /// - Parameters:
    ///   - userId: The user ID to update
    ///   - completion: Callback with success flag and error
    func updateSession(userId: String, completion: @escaping (Bool, Error?) -> Void) {
        let sessionId = generateSessionId()

        // Save locally first
        saveSessionId(sessionId)

        // Update in Firestore
        db.collection("users").document(userId).updateData([
            "sessionId": sessionId,
            "lastSignInTime": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Error updating session in Firestore: \(error.localizedDescription)")
                completion(false, error)
                return
            }

            print("Session updated successfully for user: \(userId)")
            completion(true, nil)
        }
    }

    // MARK: - Session Validation

    /// Validate the current session against Firestore
    /// - Parameters:
    ///   - userId: The user ID to validate
    ///   - completion: Callback with valid flag and error
    func validateSession(userId: String, completion: @escaping (Bool, Error?) -> Void) {
        guard let localSessionId = getCurrentSessionId() else {
            completion(false, NSError(domain: "SessionManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No local session ID"]))
            return
        }

        db.collection("users").document(userId).getDocument { document, error in
            if let error = error {
                print("Error validating session: \(error.localizedDescription)")
                completion(false, error)
                return
            }

            guard let document = document, document.exists else {
                completion(false, NSError(domain: "SessionManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "User document not found"]))
                return
            }

            if let remoteSessionId = document.data()?["sessionId"] as? String {
                let isValid = remoteSessionId == localSessionId
                completion(isValid, nil)
            } else {
                completion(false, NSError(domain: "SessionManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "No remote session ID"]))
            }
        }
    }

    // MARK: - Session Monitoring

    /// Set up a listener for session changes
    /// - Parameters:
    ///   - userId: The user ID to listen for
    ///   - onInvalidSession: Callback when session becomes invalid
    /// - Returns: ListenerRegistration that should be stored and removed when no longer needed
    func watchSession(userId: String, onInvalidSession: @escaping () -> Void) -> ListenerRegistration {
        return db.collection("users").document(userId).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let snapshot = snapshot, snapshot.exists else {
                return
            }

            if let remoteSessionId = snapshot.data()?["sessionId"] as? String,
               let localSessionId = self.getCurrentSessionId(),
               remoteSessionId != localSessionId {
                // Session is invalid, sign out
                print("Session invalid - remote: \(remoteSessionId), local: \(localSessionId)")
                onInvalidSession()
            }
        }
    }

    // MARK: - Session Termination

    /// Sign out the current user and update app state
    /// - Parameter completion: Optional callback with success flag
    func signOut(completion: ((Bool) -> Void)? = nil) {
        // Remove session listener if any
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.removeSessionListener()
        }

        // Sign out from Firebase
        let success = AuthenticationService.shared.signOut()

        // Clear session ID
        clearSessionId()

        // Notify completion
        completion?(success)
    }

    /// Sign out and reset app state using environment objects
    /// - Parameters:
    ///   - isAuthenticated: Binding to authentication state
    ///   - needsOnboarding: Binding to onboarding state
    func signOutAndResetAppState(isAuthenticated: Binding<Bool>, needsOnboarding: Binding<Bool>) {
        signOut { success in
            if success {
                // Update app state on main thread
                DispatchQueue.main.async {
                    isAuthenticated.wrappedValue = false
                    needsOnboarding.wrappedValue = false
                }
            }
        }
    }
}
