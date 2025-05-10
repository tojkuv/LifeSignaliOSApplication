import Foundation
import FirebaseAuth
import ComposableArchitecture

/// Protocol defining authentication operations
protocol AuthenticationClientProtocol {
    /// Check if a user is authenticated
    var isAuthenticated: Bool { get }
    
    /// Get the current user ID if authenticated
    func getCurrentUserId() -> String?
    
    /// Sign in with phone number
    func signInWithPhoneNumber(_ phoneNumber: String) async throws -> String
    
    /// Verify the code sent to the user's phone
    func verifyCode(verificationID: String, verificationCode: String) async throws
    
    /// Sign out the current user
    func signOut() async throws
    
    /// Get authentication status as a string
    func getAuthenticationStatus() -> String
}

/// Live implementation of AuthenticationClient
struct AuthenticationLiveClient: AuthenticationClientProtocol {
    private let currentUser: @Sendable () -> FirebaseAuth.User?
    
    init() {
        self.currentUser = { Auth.auth().currentUser }
    }
    
    var isAuthenticated: Bool {
        return currentUser() != nil
    }
    
    func getCurrentUserId() -> String? {
        return currentUser()?.uid
    }
    
    func signInWithPhoneNumber(_ phoneNumber: String) async throws -> String {
        // For testing purposes, disable app verification
        // This should be removed in production
        Auth.auth().settings?.isAppVerificationDisabledForTesting = true
        
        do {
            let verificationID = try await withCheckedThrowingContinuation { continuation in
                PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { verificationID, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let verificationID = verificationID else {
                        continuation.resume(throwing: AuthenticationError.verificationFailed)
                        return
                    }
                    
                    // Save verification ID to UserDefaults
                    UserDefaults.standard.set(verificationID, forKey: "authVerificationID")
                    continuation.resume(returning: verificationID)
                }
            }
            
            return verificationID
        } catch {
            throw AuthenticationError.phoneVerificationFailed(error.localizedDescription)
        }
    }
    
    func verifyCode(verificationID: String, verificationCode: String) async throws {
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: verificationCode
        )
        
        do {
            _ = try await Auth.auth().signIn(with: credential)
        } catch {
            throw AuthenticationError.codeVerificationFailed(error.localizedDescription)
        }
    }
    
    func signOut() async throws {
        do {
            try Auth.auth().signOut()
        } catch {
            throw AuthenticationError.signOutFailed(error.localizedDescription)
        }
    }
    
    func getAuthenticationStatus() -> String {
        if let user = currentUser() {
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

/// Mock implementation for testing
struct AuthenticationMockClient: AuthenticationClientProtocol {
    var isAuthenticated: Bool = false
    private var mockUserId: String? = nil
    
    func getCurrentUserId() -> String? {
        return mockUserId
    }
    
    func signInWithPhoneNumber(_ phoneNumber: String) async throws -> String {
        return "mock-verification-id"
    }
    
    func verifyCode(verificationID: String, verificationCode: String) async throws {
        self.mockUserId = "mock-user-id"
    }
    
    func signOut() async throws {
        self.mockUserId = nil
    }
    
    func getAuthenticationStatus() -> String {
        return isAuthenticated ? "Authenticated (MOCK)" : "Not authenticated (MOCK)"
    }
}

/// Authentication-related errors
enum AuthenticationError: Error, LocalizedError {
    case verificationFailed
    case phoneVerificationFailed(String)
    case codeVerificationFailed(String)
    case signOutFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Failed to verify phone number"
        case .phoneVerificationFailed(let message):
            return "Phone verification failed: \(message)"
        case .codeVerificationFailed(let message):
            return "Code verification failed: \(message)"
        case .signOutFailed(let message):
            return "Sign out failed: \(message)"
        }
    }
}

// TCA dependency registration
extension DependencyValues {
    var authClient: AuthenticationClientProtocol {
        get { self[AuthenticationClientKey.self] }
        set { self[AuthenticationClientKey.self] = newValue }
    }
    
    private enum AuthenticationClientKey: DependencyKey {
        static let liveValue: AuthenticationClientProtocol = AuthenticationLiveClient()
        static let testValue: AuthenticationClientProtocol = AuthenticationMockClient()
    }
}
