import Foundation
import FirebaseAuth
import DependenciesMacros
import Dependencies
import XCTestDynamicOverlay
import OSLog

/// A client for interacting with Firebase Authentication
@DependencyClient
struct FirebaseAuthClient: Sendable {
    /// Get the current authenticated user
    var currentUser: @Sendable () async -> User? = { nil }

    /// Sign out the current user
    var signOut: @Sendable () async throws -> Void = { }

    /// Sign in with a credential
    var signIn: @Sendable (AuthCredential) async throws -> AuthDataResult = { _ in
        throw FirebaseError.notAuthenticated
    }

    /// Create a phone auth credential
    var phoneAuthCredential: @Sendable (String, String) -> PhoneAuthCredential = { verificationID, verificationCode in
        PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: verificationCode)
    }

    /// Get the current user's ID or throw an authentication error if not available
    var currentUserId: @Sendable () async throws -> String = {
        throw FirebaseError.notAuthenticated
    }

    /// Send verification code to phone number
    var verifyPhoneNumber: @Sendable (String) async throws -> String = { _ in
        throw FirebaseError.notAuthenticated
    }

    /// Update the phone number of the current user
    var updatePhoneNumber: @Sendable (PhoneAuthCredential) async throws -> Void = { _ in }

    /// Check if user is authenticated
    var isAuthenticated: @Sendable () async -> Bool = { false }
}

// MARK: - Live Implementation

extension FirebaseAuthClient: DependencyKey {
    static let liveValue: FirebaseAuthClient = FirebaseAuthClient(
        currentUser: {
            FirebaseLogger.auth.debug("Getting current user")
            return Auth.auth().currentUser
        },
        signOut: {
            FirebaseLogger.auth.debug("Signing out user")
            do {
                try Auth.auth().signOut()
                FirebaseLogger.auth.info("User signed out successfully")
            } catch {
                FirebaseLogger.auth.error("Error signing out: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },
        signIn: { credential in
            FirebaseLogger.auth.debug("Signing in with credential")
            do {
                let authResult = try await Auth.auth().signIn(with: credential)
                FirebaseLogger.auth.info("User signed in successfully: \(authResult.user.uid)")
                return authResult
            } catch {
                FirebaseLogger.auth.error("Sign in failed with error: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },
        phoneAuthCredential: { verificationID, verificationCode in
            FirebaseLogger.auth.debug("Creating phone auth credential")
            return PhoneAuthProvider.provider().credential(
                withVerificationID: verificationID,
                verificationCode: verificationCode
            )
        },
        currentUserId: {
            FirebaseLogger.auth.debug("Requiring authenticated user ID")
            guard let uid = Auth.auth().currentUser?.uid else {
                FirebaseLogger.auth.error("Authentication required but no user is signed in")
                throw FirebaseError.notAuthenticated
            }
            FirebaseLogger.auth.debug("Authenticated user ID: \(uid)")
            return uid
        },
        verifyPhoneNumber: { phoneNumber in
            FirebaseLogger.auth.debug("Verifying phone number")
            do {
                let verificationID = try await PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil)
                FirebaseLogger.auth.info("Phone verification code sent successfully")
                return verificationID
            } catch {
                FirebaseLogger.auth.error("Phone verification failed with error: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },
        updatePhoneNumber: { credential in
            FirebaseLogger.auth.debug("Updating phone number")
            guard let currentUser = Auth.auth().currentUser else {
                FirebaseLogger.auth.error("No current user to update phone number")
                throw FirebaseError.notAuthenticated
            }

            do {
                try await currentUser.updatePhoneNumber(credential)
                FirebaseLogger.auth.info("Phone number updated successfully")
            } catch {
                FirebaseLogger.auth.error("Phone number update failed with error: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },
        isAuthenticated: {
            let isAuthenticated = Auth.auth().currentUser != nil
            FirebaseLogger.auth.debug("User authentication status: \(isAuthenticated)")
            return isAuthenticated
        }
    )
}

// MARK: - Mock Implementation

extension FirebaseAuthClient {
    /// A mock implementation that returns predefined values for testing
    static func mock(
        currentUser: @Sendable @escaping () async -> User? = { nil },
        signOut: @Sendable @escaping () async throws -> Void = { },
        signIn: @Sendable @escaping (AuthCredential) async throws -> AuthDataResult = { _ in
            throw FirebaseError.notAuthenticated
        },
        phoneAuthCredential: @Sendable @escaping (String, String) -> PhoneAuthCredential = { verificationID, verificationCode in
            PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: verificationCode)
        },
        currentUserId: @Sendable @escaping () async throws -> String = {
            throw FirebaseError.notAuthenticated
        },
        verifyPhoneNumber: @Sendable @escaping (String) async throws -> String = { _ in
            throw FirebaseError.notAuthenticated
        },
        updatePhoneNumber: @Sendable @escaping (PhoneAuthCredential) async throws -> Void = { _ in },
        isAuthenticated: @Sendable @escaping () async -> Bool = { false }
    ) -> Self {
        Self(
            currentUser: currentUser,
            signOut: signOut,
            signIn: signIn,
            phoneAuthCredential: phoneAuthCredential,
            currentUserIdOptional: currentUserIdOptional,
            currentUserId: currentUserId,
            verifyPhoneNumber: verifyPhoneNumber,
            updatePhoneNumber: updatePhoneNumber,
            isAuthenticated: isAuthenticated
        )
    }
}

extension FirebaseAuthClient: TestDependencyKey {
    /// A test implementation that fails with an unimplemented error
    static var testValue: FirebaseAuthClient {
        let currentUserPlaceholder: @Sendable () async -> User? = { nil }
        let signOutPlaceholder: @Sendable () async throws -> Void = { }
        let signInPlaceholder: @Sendable (AuthCredential) async throws -> AuthDataResult = { _ in
            throw FirebaseError.notAuthenticated
        }
        let phoneAuthCredentialPlaceholder: @Sendable (String, String) -> PhoneAuthCredential = { verificationID, verificationCode in
            PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: verificationCode)
        }
        let currentUserIdPlaceholder: @Sendable () async throws -> String = { throw FirebaseError.notAuthenticated }
        let verifyPhoneNumberPlaceholder: @Sendable (String) async throws -> String = { _ in
            throw FirebaseError.notAuthenticated
        }
        let updatePhoneNumberPlaceholder: @Sendable (PhoneAuthCredential) async throws -> Void = { _ in }
        let isAuthenticatedPlaceholder: @Sendable () async -> Bool = { false }

        return FirebaseAuthClient(
            currentUser: unimplemented("\(Self.self).currentUser", placeholder: currentUserPlaceholder),
            signOut: unimplemented("\(Self.self).signOut", placeholder: signOutPlaceholder),
            signIn: unimplemented("\(Self.self).signIn", placeholder: signInPlaceholder),
            phoneAuthCredential: unimplemented("\(Self.self).phoneAuthCredential", placeholder: phoneAuthCredentialPlaceholder),
            currentUserId: unimplemented("\(Self.self).currentUserId", placeholder: currentUserIdPlaceholder),
            verifyPhoneNumber: unimplemented("\(Self.self).verifyPhoneNumber", placeholder: verifyPhoneNumberPlaceholder),
            updatePhoneNumber: unimplemented("\(Self.self).updatePhoneNumber", placeholder: updatePhoneNumberPlaceholder),
            isAuthenticated: unimplemented("\(Self.self).isAuthenticated", placeholder: isAuthenticatedPlaceholder)
        )
    }
}

extension DependencyValues {
    var firebaseAuth: FirebaseAuthClient {
        get { self[FirebaseAuthClient.self] }
        set { self[FirebaseAuthClient.self] = newValue }
    }
}
