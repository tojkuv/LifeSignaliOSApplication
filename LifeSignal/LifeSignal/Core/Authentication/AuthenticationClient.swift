import Foundation
import ComposableArchitecture
import FirebaseAuth
import FirebaseFirestore

/// Client for interacting with authentication functionality
struct AuthenticationClient: Sendable {
    /// Send verification code to the user's phone
    var sendVerificationCode: @Sendable (phoneNumber: String, phoneRegion: String) async throws -> String

    /// Verify the code entered by the user
    var verifyCode: @Sendable (verificationID: String, verificationCode: String) async throws -> Bool

    /// Sign out the user
    var signOut: @Sendable () async throws -> Bool

    /// Check if the user is authenticated
    var isAuthenticated: @Sendable () async throws -> Bool

    /// Get the current user ID if authenticated
    var getCurrentUserId: @Sendable () async -> String?

    /// Get authentication status as a string
    var getAuthenticationStatus: @Sendable () async -> String
}

extension AuthenticationClient: DependencyKey {
    /// Live implementation of the authentication client
    static var liveValue: Self {
        @Dependency(\.firebaseClient) var firebaseClient

        return Self(
            sendVerificationCode: { (phoneNumber, phoneRegion) in
                let formattedPhoneNumber = PhoneFormatter.formatPhoneNumber(phoneNumber, region: phoneRegion)

                return try await withCheckedThrowingContinuation { continuation in
                    PhoneAuthProvider.provider().verifyPhoneNumber(formattedPhoneNumber, uiDelegate: nil) { verificationID, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                            return
                        }

                        guard let verificationID = verificationID else {
                            let error = NSError(domain: "AuthenticationClient", code: 500, userInfo: [NSLocalizedDescriptionKey: "Verification ID not received"])
                            continuation.resume(throwing: error)
                            return
                        }

                        continuation.resume(returning: verificationID)
                    }
                }
            },

            verifyCode: { (verificationID, verificationCode) in
                let credential = PhoneAuthProvider.provider().credential(
                    withVerificationID: verificationID,
                    verificationCode: verificationCode
                )

                return try await withCheckedThrowingContinuation { continuation in
                    Auth.auth().signIn(with: credential) { authResult, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                            return
                        }

                        guard authResult != nil else {
                            let error = NSError(domain: "AuthenticationClient", code: 500, userInfo: [NSLocalizedDescriptionKey: "Authentication failed"])
                            continuation.resume(throwing: error)
                            return
                        }

                        // After successful authentication, update the session
                        Task {
                            if let userId = Auth.auth().currentUser?.uid {
                                do {
                                    // Generate a new session ID
                                    let sessionId = UUID().uuidString

                                    // Save session ID to UserDefaults
                                    UserDefaults.standard.set(sessionId, forKey: "user_session_id")

                                    // Update session in Firestore
                                    let sessionData: [String: Any] = [
                                        "sessionId": sessionId,
                                        "lastSignInTime": FieldValue.serverTimestamp()
                                    ]

                                    try await firebaseClient.updateUserData(userId: userId, data: sessionData)
                                } catch {
                                    print("Error updating session: \(error.localizedDescription)")
                                }
                            }
                        }

                        continuation.resume(returning: true)
                    }
                }
            },

            signOut: {
                do {
                    // Clear session ID from UserDefaults
                    UserDefaults.standard.removeObject(forKey: "user_session_id")

                    try Auth.auth().signOut()
                    return true
                } catch {
                    throw error
                }
            },

            isAuthenticated: {
                return Auth.auth().currentUser != nil
            },

            getCurrentUserId: {
                return Auth.auth().currentUser?.uid
            },

            getAuthenticationStatus: {
                if let user = Auth.auth().currentUser {
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
        )
    }

    /// Test implementation of the authentication client
    static var testValue: Self {
        return Self(
            sendVerificationCode: { (_, _) in
                return "test-verification-id"
            },

            verifyCode: { (_, _) in
                return true
            },

            signOut: {
                return true
            },

            isAuthenticated: {
                return false
            },

            getCurrentUserId: {
                return nil
            },

            getAuthenticationStatus: {
                return "Not authenticated (TEST)"
            }
        )
    }
}

// MARK: - Dependency Values Extension
extension DependencyValues {
    /// Access the authentication client
    var authClient: AuthenticationClient {
        get { self[AuthenticationClient.self] }
        set { self[AuthenticationClient.self] = newValue }
    }
}
