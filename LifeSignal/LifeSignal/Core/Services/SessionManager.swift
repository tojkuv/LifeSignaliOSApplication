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

        // Reference to the user document
        let userDocRef = db.collection("users").document(userId)

        // First check if the document exists
        userDocRef.getDocument { [weak self] document, error in
            guard let self = self else { return }

            if let error = error {
                print("Error checking user document: \(error.localizedDescription)")
                completion(false, error)
                return
            }

            // Session data to update or create
            let sessionData: [String: Any] = [
                "sessionId": sessionId,
                "lastSignInTime": FieldValue.serverTimestamp()
            ]

            if let document = document, document.exists {
                // Document exists, update it
                print("User document exists, updating session data")

                // For test users, use setData with merge to ensure all fields are preserved
                if let phoneNumber = Auth.auth().currentUser?.phoneNumber,
                   phoneNumber == "+11234567890" || phoneNumber == "+16505553434" {
                    print("This is a test user, using setData with merge")
                    userDocRef.setData(sessionData, merge: true) { error in
                        if let error = error {
                            print("Error updating session in Firestore: \(error.localizedDescription)")

                            // Check if it's a permission error
                            if let nsError = error as NSError?, nsError.domain == "FIRFirestoreErrorDomain" {
                                print("Firestore error code: \(nsError.code)")
                                print("Firestore error details: \(nsError.userInfo)")
                            }

                            completion(false, error)
                            return
                        }

                        print("Session updated successfully for existing test user: \(userId)")
                        completion(true, nil)
                    }
                } else {
                    // Regular user, use updateData
                    userDocRef.updateData(sessionData) { error in
                        if let error = error {
                            print("Error updating session in Firestore: \(error.localizedDescription)")

                            // Check if it's a permission error
                            if let nsError = error as NSError?, nsError.domain == "FIRFirestoreErrorDomain" {
                                print("Firestore error code: \(nsError.code)")
                                print("Firestore error details: \(nsError.userInfo)")
                            }

                            completion(false, error)
                            return
                        }

                        print("Session updated successfully for existing user: \(userId)")
                        completion(true, nil)
                    }
                }
            } else {
                // Document doesn't exist, create it with basic user data
                var userData = sessionData

                // Add additional required fields for a new user
                userData["uid"] = userId
                userData["createdAt"] = FieldValue.serverTimestamp()
                userData["profileComplete"] = false

                // Generate a QR code ID for the new user - CRITICAL FIELD
                let qrCodeId = UUID().uuidString
                userData["qrCodeId"] = qrCodeId
                print("Generated QR code ID for new user: \(qrCodeId)")

                // Add phone number if available
                if let phoneNumber = Auth.auth().currentUser?.phoneNumber {
                    userData["phoneNumber"] = phoneNumber
                } else {
                    userData["phoneNumber"] = "" // Required field
                }

                // Add required fields according to Firestore rules
                userData["name"] = "New User" // Required field
                userData["note"] = "" // Required field
                userData["checkInInterval"] = 24 * 60 * 60 // 24 hours in seconds
                userData["lastCheckedIn"] = FieldValue.serverTimestamp()

                // Initialize other fields with default values
                userData["notificationEnabled"] = true
                userData["notify30MinBefore"] = false
                userData["notify2HoursBefore"] = false
                userData["manualAlertActive"] = false
                userData["contacts"] = []

                // Log the data we're about to save
                print("Creating new user document with fields: \(userData.keys.joined(separator: ", "))")

                // Create the document
                userDocRef.setData(userData) { error in
                    if let error = error {
                        print("Error creating user document: \(error.localizedDescription)")

                        // Check if it's a permission error
                        if let nsError = error as NSError?, nsError.domain == "FIRFirestoreErrorDomain" {
                            print("Firestore error code: \(nsError.code)")
                            print("Firestore error details: \(nsError.userInfo)")
                        }

                        completion(false, error)
                        return
                    }

                    print("Created new user document with session for user: \(userId)")
                    completion(true, nil)
                }
            }
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

    /// Sign out and reset app state
    /// - Parameter completion: Optional callback with success flag
    func signOutAndResetAppState(completion: ((Bool) -> Void)? = nil) {
        signOut { success in
            if success {
                completion?(true)
            } else {
                completion?(false)
            }
        }
    }
}
