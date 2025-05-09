import Foundation
import FirebaseCore
import FirebaseAuth

/// Service class for Firebase Authentication functionality
class AuthenticationService {
    // Singleton instance
    static let shared = AuthenticationService()

    // Private initializer for singleton
    private init() {
        // Check if we already have a user
        updateCurrentUser()
    }

    /// Current authenticated user
    private(set) var currentUser: FirebaseAuth.User?

    /// Flag indicating if a user is authenticated
    var isAuthenticated: Bool {
        return currentUser != nil
    }

    /// Update the current user reference
    private func updateCurrentUser() {
        currentUser = Auth.auth().currentUser
    }

    /// Get the current user ID if authenticated
    /// - Returns: User ID string or nil if not authenticated
    func getCurrentUserID() -> String? {
        return currentUser?.uid
    }

    /// Sign in with phone number
    /// - Parameters:
    ///   - phoneNumber: The phone number to authenticate with
    ///   - completion: Callback with verification ID and error
    func signInWithPhoneNumber(_ phoneNumber: String, completion: @escaping (String?, Error?) -> Void) {
        // For testing purposes, disable app verification
        // This should be removed in production
        Auth.auth().settings?.isAppVerificationDisabledForTesting = true

        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { verificationID, error in
            if let error = error {
                print("Error sending verification code: \(error.localizedDescription)")
                completion(nil, error)
                return
            }

            // Save verification ID to UserDefaults
            UserDefaults.standard.set(verificationID, forKey: "authVerificationID")

            completion(verificationID, nil)
        }
    }

    /// Verify the code sent to the user's phone
    /// - Parameters:
    ///   - verificationID: The verification ID received from signInWithPhoneNumber
    ///   - verificationCode: The code entered by the user
    ///   - completion: Callback with AuthDataResult and error
    func verifyCode(verificationID: String, verificationCode: String, completion: @escaping (AuthDataResult?, Error?) -> Void) {
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: verificationCode
        )

        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            if let error = error {
                print("Error verifying code: \(error.localizedDescription)")
                completion(nil, error)
                return
            }

            // Update current user
            self?.updateCurrentUser()

            completion(authResult, nil)
        }
    }

    /// Sign out the current user
    /// - Returns: True if sign out was successful, false otherwise
    func signOut() -> Bool {
        do {
            try Auth.auth().signOut()
            updateCurrentUser()
            return true
        } catch {
            print("Error signing out: \(error.localizedDescription)")
            return false
        }
    }

    /// Get authentication status as a string
    /// - Returns: A string describing the current authentication status
    func getAuthenticationStatus() -> String {
        if let user = currentUser {
            return """
            Authenticated!
            User ID: \(user.uid)
            Phone: \(user.phoneNumber ?? "Not available")
            Provider ID: \(user.providerID)
            """
        } else {
            return "Not authenticated"
        }
    }
}
