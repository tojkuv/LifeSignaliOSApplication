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
    var currentUser: @Sendable () async -> User?

    /// Sign out the current user
    var signOut: @Sendable () async throws -> Void

    /// Sign in with a credential
    var signIn: @Sendable (_ credential: AuthCredential) async throws -> AuthDataResult

    /// Create a phone auth credential
    var phoneAuthCredential: @Sendable (_ verificationID: String, _ verificationCode: String) -> AuthCredential

    /// Get the current user's ID
    var currentUserId: @Sendable () async -> String?

    /// Send verification code to phone number
    var verifyPhoneNumber: @Sendable (_ phoneNumber: String) async throws -> String

    /// Update the phone number of the current user
    var updatePhoneNumber: @Sendable (_ credential: AuthCredential) async throws -> Void

    /// Check if user is authenticated
    var isAuthenticated: @Sendable () async -> Bool
}

// MARK: - Live Implementation

extension FirebaseAuthClient: DependencyKey {
    static let liveValue = Self(
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
            if let uid = Auth.auth().currentUser?.uid {
                FirebaseLogger.auth.debug("Current user ID: \(uid)")
                return uid
            } else {
                FirebaseLogger.auth.debug("No current user ID")
                return nil
            }
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
        currentUser: @escaping () async -> User? = { nil },
        signOut: @escaping () async throws -> Void = { },
        signIn: @escaping (_ credential: AuthCredential) async throws -> AuthDataResult = { _ in
            fatalError("Mock not implemented")
        },
        phoneAuthCredential: @escaping (_ verificationID: String, _ verificationCode: String) -> AuthCredential = { _, _ in
            fatalError("Mock not implemented")
        },
        currentUserId: @escaping () async -> String? = { nil },
        verifyPhoneNumber: @escaping (_ phoneNumber: String) async throws -> String = { _ in
            fatalError("Mock not implemented")
        },
        updatePhoneNumber: @escaping (_ credential: AuthCredential) async throws -> Void = { _ in
            fatalError("Mock not implemented")
        },
        isAuthenticated: @escaping () async -> Bool = { false }
    ) -> Self {
        Self(
            currentUser: currentUser,
            signOut: signOut,
            signIn: signIn,
            phoneAuthCredential: phoneAuthCredential,
            currentUserId: currentUserId,
            verifyPhoneNumber: verifyPhoneNumber,
            updatePhoneNumber: updatePhoneNumber,
            isAuthenticated: isAuthenticated
        )
    }

    /// A test implementation that fails with an unimplemented error
    static let testValue = Self(
        currentUser: XCTUnimplemented("\(Self.self).currentUser", placeholder: nil),
        signOut: XCTUnimplemented("\(Self.self).signOut"),
        signIn: XCTUnimplemented("\(Self.self).signIn", placeholder: { _ in
            fatalError("Unimplemented: \(Self.self).signIn")
        }),
        phoneAuthCredential: XCTUnimplemented("\(Self.self).phoneAuthCredential", placeholder: { _, _ in
            fatalError("Unimplemented: \(Self.self).phoneAuthCredential")
        }),
        currentUserId: XCTUnimplemented("\(Self.self).currentUserId", placeholder: nil),
        verifyPhoneNumber: XCTUnimplemented("\(Self.self).verifyPhoneNumber", placeholder: { _ in
            fatalError("Unimplemented: \(Self.self).verifyPhoneNumber")
        }),
        updatePhoneNumber: XCTUnimplemented("\(Self.self).updatePhoneNumber", placeholder: { _ in
            fatalError("Unimplemented: \(Self.self).updatePhoneNumber")
        }),
        isAuthenticated: XCTUnimplemented("\(Self.self).isAuthenticated", placeholder: false)
    )
}

extension DependencyValues {
    var firebaseAuth: FirebaseAuthClient {
        get { self[FirebaseAuthClient.self] }
        set { self[FirebaseAuthClient.self] = newValue }
    }
}
