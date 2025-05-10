import Foundation
import ComposableArchitecture
import FirebaseAuth

/// Client for interacting with authentication functionality
struct AuthClient {
    /// Send verification code to the user's phone
    var sendVerificationCode: (phoneNumber: String, phoneRegion: String) async throws -> String
    
    /// Verify the code entered by the user
    var verifyCode: (verificationID: String, verificationCode: String) async throws -> Bool
    
    /// Sign out the user
    var signOut: () async throws -> Bool
    
    /// Check if the user is authenticated
    var isAuthenticated: () async throws -> Bool
}

extension AuthClient: DependencyKey {
    /// Live implementation of the authentication client
    static var liveValue: Self {
        return Self(
            sendVerificationCode: { phoneNumber, phoneRegion in
                let formattedPhoneNumber = PhoneFormatter.formatPhoneNumber(phoneNumber, region: phoneRegion)
                
                return try await withCheckedThrowingContinuation { continuation in
                    PhoneAuthProvider.provider().verifyPhoneNumber(formattedPhoneNumber, uiDelegate: nil) { verificationID, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                            return
                        }
                        
                        guard let verificationID = verificationID else {
                            let error = NSError(domain: "AuthClient", code: 500, userInfo: [NSLocalizedDescriptionKey: "Verification ID not received"])
                            continuation.resume(throwing: error)
                            return
                        }
                        
                        continuation.resume(returning: verificationID)
                    }
                }
            },
            
            verifyCode: { verificationID, verificationCode in
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
                            let error = NSError(domain: "AuthClient", code: 500, userInfo: [NSLocalizedDescriptionKey: "Authentication failed"])
                            continuation.resume(throwing: error)
                            return
                        }
                        
                        continuation.resume(returning: true)
                    }
                }
            },
            
            signOut: {
                do {
                    try Auth.auth().signOut()
                    return true
                } catch {
                    throw error
                }
            },
            
            isAuthenticated: {
                return Auth.auth().currentUser != nil
            }
        )
    }
    
    /// Test implementation of the authentication client
    static var testValue: Self {
        return Self(
            sendVerificationCode: { _, _ in
                return "test-verification-id"
            },
            
            verifyCode: { _, _ in
                return true
            },
            
            signOut: {
                return true
            },
            
            isAuthenticated: {
                return false
            }
        )
    }
}

extension DependencyValues {
    var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}
