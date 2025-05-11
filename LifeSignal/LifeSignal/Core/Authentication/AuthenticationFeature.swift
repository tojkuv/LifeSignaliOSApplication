import Foundation
import ComposableArchitecture
import FirebaseAuth
@preconcurrency import FirebaseFirestore

/// Feature for managing user authentication and sessions
@Reducer
struct AuthenticationFeature {
    /// Cancellation IDs for long-running effects
    enum CancelID: Hashable {
        case sessionStream
    }
    /// The state of the authentication feature
    struct State: Equatable, Sendable {
        // MARK: - Authentication Properties

        /// Phone number for authentication
        var phoneNumber: String = ""

        /// Phone region for authentication
        var phoneRegion: String = "US"

        /// Verification code entered by the user
        var verificationCode: String = ""

        /// Verification ID received from Firebase
        var verificationID: String = ""

        /// Flag indicating if verification code has been sent
        var isCodeSent: Bool = false

        /// Flag indicating if user is authenticated
        var isAuthenticated: Bool = false

        // MARK: - Session Properties

        /// The current session ID
        var sessionId: String?

        /// Flag indicating if the session is valid
        var isSessionValid: Bool = false

        // MARK: - UI State

        /// Loading state
        var isLoading: Bool = false

        /// Error state
        var error: Error? = nil

        /// Custom Equatable implementation to handle Error? property
        static func == (lhs: State, rhs: State) -> Bool {
            lhs.phoneNumber == rhs.phoneNumber &&
            lhs.phoneRegion == rhs.phoneRegion &&
            lhs.verificationCode == rhs.verificationCode &&
            lhs.verificationID == rhs.verificationID &&
            lhs.isCodeSent == rhs.isCodeSent &&
            lhs.isAuthenticated == rhs.isAuthenticated &&
            lhs.sessionId == rhs.sessionId &&
            lhs.isSessionValid == rhs.isSessionValid &&
            lhs.isLoading == rhs.isLoading &&
            (lhs.error != nil) == (rhs.error != nil)
        }
    }

    /// Actions that can be performed on the authentication feature
    enum Action: Equatable, Sendable {
        // MARK: - Authentication Actions

        /// Send verification code to the user's phone
        case sendVerificationCode
        case sendVerificationCodeResponse(TaskResult<String>)

        /// Verify the code entered by the user
        case verifyCode
        case verifyCodeResponse(TaskResult<Bool>)

        /// Update the phone number
        case updatePhoneNumber(String)

        /// Update the phone region
        case updatePhoneRegion(String)

        /// Update the verification code
        case updateVerificationCode(String)

        /// Sign out the user
        case signOut
        case signOutResponse(TaskResult<Bool>)

        /// Check if the user is authenticated
        case checkAuthenticationState
        case checkAuthenticationStateResponse(TaskResult<Bool>)

        // MARK: - Session Actions

        /// Get the current session ID
        case getCurrentSessionId
        case getCurrentSessionIdResponse(String?)

        /// Update the session ID in Firestore and UserDefaults
        case updateSession(userId: String)
        case updateSessionResponse(TaskResult<Void>)

        /// Validate the current session against Firestore
        case validateSession(userId: String)
        case validateSessionResponse(TaskResult<Bool>)

        /// Start watching for session changes
        case startSessionStream(userId: String)
        case sessionInvalidated
        case stopSessionStream

        /// Clear the session ID
        case clearSessionId
        case clearSessionIdResponse

        // MARK: - UI Actions

        /// Clear any error state
        case clearError
    }

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .sendVerificationCode:
                state.isLoading = true
                return .run { [phoneNumber = state.phoneNumber, phoneRegion = state.phoneRegion] send in
                    let result = await TaskResult {
                        let formattedPhoneNumber = PhoneFormatter.formatPhoneNumber(phoneNumber, region: phoneRegion)

                        return try await withCheckedThrowingContinuation { continuation in
                            PhoneAuthProvider.provider().verifyPhoneNumber(formattedPhoneNumber, uiDelegate: nil) { verificationID, error in
                                if let error = error {
                                    continuation.resume(throwing: error)
                                    return
                                }

                                guard let verificationID = verificationID else {
                                    let error = NSError(domain: "AuthenticationFeature", code: 500, userInfo: [NSLocalizedDescriptionKey: "Verification ID not received"])
                                    continuation.resume(throwing: error)
                                    return
                                }

                                continuation.resume(returning: verificationID)
                            }
                        }
                    }
                    await send(.sendVerificationCodeResponse(result))
                }

            case let .sendVerificationCodeResponse(result):
                state.isLoading = false
                switch result {
                case let .success(verificationID):
                    state.verificationID = verificationID
                    state.isCodeSent = true
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }

            case .verifyCode:
                state.isLoading = true
                return .run { [verificationID = state.verificationID, verificationCode = state.verificationCode] send in
                    let result = await TaskResult {
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
                                    let error = NSError(domain: "AuthenticationFeature", code: 500, userInfo: [NSLocalizedDescriptionKey: "Authentication failed"])
                                    continuation.resume(throwing: error)
                                    return
                                }

                                // After successful authentication, update the session
                                Task {
                                    if let userId = Auth.auth().currentUser?.uid {
                                        // Update the session directly
                                        try await updateSessionInternal(userId: userId)
                                    }
                                }

                                continuation.resume(returning: true)
                            }
                        }
                    }
                    await send(.verifyCodeResponse(result))
                }

            case let .verifyCodeResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    state.isAuthenticated = true
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }

            case let .updatePhoneNumber(phoneNumber):
                state.phoneNumber = phoneNumber
                return .none

            case let .updatePhoneRegion(phoneRegion):
                state.phoneRegion = phoneRegion
                return .none

            case let .updateVerificationCode(verificationCode):
                state.verificationCode = verificationCode
                return .none

            case .signOut:
                state.isLoading = true
                return .run { send in
                    let result = await TaskResult {
                        do {
                            // Clear session ID from UserDefaults
                            UserDefaults.standard.removeObject(forKey: "user_session_id")

                            try Auth.auth().signOut()
                            return true
                        } catch {
                            throw error
                        }
                    }
                    await send(.signOutResponse(result))
                }

            case let .signOutResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    state.isAuthenticated = false
                    state.phoneNumber = ""
                    state.verificationCode = ""
                    state.verificationID = ""
                    state.isCodeSent = false
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }

            case .checkAuthenticationState:
                state.isLoading = true
                return .run { send in
                    let result = await TaskResult {
                        return Auth.auth().currentUser != nil
                    }
                    await send(.checkAuthenticationStateResponse(result))
                }

            case let .checkAuthenticationStateResponse(result):
                state.isLoading = false
                switch result {
                case let .success(isAuthenticated):
                    state.isAuthenticated = isAuthenticated
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }

            // MARK: - Session Actions

            case .getCurrentSessionId:
                return .run { send in
                    let sessionId = UserDefaults.standard.string(forKey: "user_session_id")
                    await send(.getCurrentSessionIdResponse(sessionId))
                }

            case let .getCurrentSessionIdResponse(sessionId):
                state.sessionId = sessionId
                return .none

            case let .updateSession(userId):
                state.isLoading = true
                return .run { send in
                    let result = await TaskResult {
                        try await updateSessionInternal(userId: userId)
                    }
                    await send(.updateSessionResponse(result))
                }

            case let .updateSessionResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }

            case let .validateSession(userId):
                state.isLoading = true
                return .run { send in
                    let result = await TaskResult {
                        // Get the local session ID
                        guard let localSessionId = UserDefaults.standard.string(forKey: "user_session_id") else {
                            throw SessionError.noLocalSessionId
                        }

                        // Get the user document
                        let db = Firestore.firestore()
                        let documentSnapshot = try await db.collection(FirestoreConstants.Collections.users).document(userId).getDocument()

                        guard documentSnapshot.exists, let data = documentSnapshot.data() else {
                            throw SessionError.userDocumentNotFound
                        }

                        // Check if the remote session ID matches the local one
                        if let remoteSessionId = data[FirestoreConstants.UserFields.sessionId] as? String {
                            return remoteSessionId == localSessionId
                        } else {
                            throw SessionError.noRemoteSessionId
                        }
                    }
                    await send(.validateSessionResponse(result))
                }

            case let .validateSessionResponse(result):
                state.isLoading = false
                switch result {
                case let .success(isValid):
                    state.isSessionValid = isValid
                    return .none
                case let .failure(error):
                    state.error = error
                    state.isSessionValid = false
                    return .none
                }

            case let .startSessionStream(userId):
                return .run { send in
                    for await _ in await watchSession(userId: userId) {
                        await send(.sessionInvalidated)
                    }
                }
                .cancellable(id: CancelID.sessionStream)

            case .sessionInvalidated:
                state.isSessionValid = false
                return .none

            case .stopSessionStream:
                return .cancel(id: CancelID.sessionStream)

            case .clearSessionId:
                return .run { send in
                    UserDefaults.standard.removeObject(forKey: "user_session_id")
                    await send(.clearSessionIdResponse)
                }

            case .clearSessionIdResponse:
                state.sessionId = nil
                state.isSessionValid = false
                return .none

            // MARK: - UI Actions

            case .clearError:
                state.error = nil
                return .none
            }
        }
    }

    /// Get the current user ID if authenticated
    static func getCurrentUserId() -> String? {
        return Auth.auth().currentUser?.uid
    }

    /// Get authentication status as a string
    static func getAuthenticationStatus() -> String {
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

    /// Check if the user is authenticated
    static func isAuthenticated() -> Bool {
        return Auth.auth().currentUser != nil
    }

    /// Helper method to update the session
    private func updateSessionInternal(userId: String) async throws {
        // Generate a new session ID
        let sessionId = UUID().uuidString

        // Save locally first
        UserDefaults.standard.set(sessionId, forKey: "user_session_id")

        // Session data to update or create
        let sessionData: [String: Any] = [
            FirestoreConstants.UserFields.sessionId: sessionId,
            FirestoreConstants.UserFields.lastSignInTime: FieldValue.serverTimestamp()
        ]

        // Try to get the user document
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreConstants.Collections.users).document(userId)
        let document = try await userRef.getDocument()

        // Document exists, update it
        if document.exists {
            // For test users, use setData with merge to ensure all fields are preserved
            if let phoneNumber = Auth.auth().currentUser?.phoneNumber,
               phoneNumber == "+11234567890" || phoneNumber == "+16505553434" {
                try await userRef.setData(sessionData, merge: true)
            } else {
                // Regular user, use updateData
                try await userRef.updateData(sessionData)
            }
        } else {
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

            // Create the document
            try await userRef.setData(userData)
        }
    }

    /// Watch for session changes
    private func watchSession(userId: String) async -> AsyncStream<Void> {
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
    }
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
extension AuthenticationFeature: DependencyKey {
    static let liveValue = AuthenticationFeature()
}

extension DependencyValues {
    var authenticationFeature: AuthenticationFeature {
        get { self[AuthenticationFeature.self] }
        set { self[AuthenticationFeature.self] = newValue }
    }
}
