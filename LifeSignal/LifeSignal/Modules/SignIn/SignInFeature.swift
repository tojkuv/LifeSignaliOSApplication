import Foundation
import ComposableArchitecture
import FirebaseAuth

/// Feature for handling user sign-in
@Reducer
struct SignInFeature {
    /// Cancellation IDs for long-running effects
    enum CancelID: Hashable, Sendable {
        case signIn
    }

    /// The state of the sign-in feature
    @ObservableState
    struct State: Equatable, Sendable {
        /// Phone number for authentication
        var phoneNumber: String = ""

        /// Phone region for authentication (e.g., "US", "CA", "GB")
        var phoneRegion: String = "US"

        /// Verification code entered by the user
        var verificationCode: String = ""

        /// Verification ID received from Firebase
        var verificationID: String = ""

        /// Flag indicating if verification code has been sent
        var isCodeSent: Bool = false

        /// Flag indicating if user is authenticated - using shared state
        @Shared(.inMemory("authState")) var isAuthenticated = false

        /// Loading state
        var isLoading: Bool = false

        /// Error state
        var error: Error?

        /// Custom Equatable implementation to handle Error? property
        static func == (lhs: State, rhs: State) -> Bool {
            lhs.phoneNumber == rhs.phoneNumber &&
            lhs.phoneRegion == rhs.phoneRegion &&
            lhs.verificationCode == rhs.verificationCode &&
            lhs.verificationID == rhs.verificationID &&
            lhs.isCodeSent == rhs.isCodeSent &&
            lhs.isLoading == rhs.isLoading &&
            (lhs.error != nil) == (rhs.error != nil)
            // Note: isAuthenticated is shared and doesn't need to be compared
        }

        /// Format the phone number for display
        func formattedPhoneNumber() -> String {
            @Dependency(\.phoneFormatter) var phoneFormatter
            return phoneFormatter.formatPhoneNumber(phoneNumber, region: phoneRegion)
        }
    }

    /// Actions that can be performed on the sign-in feature
    enum Action: BindableAction, Equatable, Sendable {
        /// Binding action for two-way binding with the view
        case binding(BindingAction<State>)

        /// Send verification code to the user's phone
        case sendVerificationCode
        case sendVerificationCodeResponse(TaskResult<String>)

        /// Verify the code entered by the user
        case verifyCode
        case verifyCodeResponse(TaskResult<Bool>)

        /// Clear any error state
        case clearError

        /// Delegate actions to communicate with parent features
        case delegate(Delegate)

        /// Delegate actions enum
        enum Delegate: Equatable, Sendable {
            case signInSuccessful
        }
    }

    /// Dependencies
    @Dependency(\.firebaseAuth) var firebaseAuth
    @Dependency(\.firebaseSessionClient) var firebaseSessionClient
    @Dependency(\.phoneFormatter) var phoneFormatter

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .sendVerificationCode:
                state.isLoading = true
                return .run { [phoneNumber = state.phoneNumber, phoneRegion = state.phoneRegion, phoneFormatter, firebaseAuth] send in
                    let result = await TaskResult {
                        let formattedPhoneNumber = phoneFormatter.formatPhoneNumber(phoneNumber, region: phoneRegion)
                        return try await firebaseAuth.verifyPhoneNumber(formattedPhoneNumber)
                    }
                    await send(.sendVerificationCodeResponse(result))
                }
                .cancellable(id: CancelID.signIn)

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
                        // Create credential using the auth client
                        let credential = firebaseAuth.phoneAuthCredential(
                            verificationID: verificationID,
                            verificationCode: verificationCode
                        )

                        // Sign in with the credential
                        let authResult = try await firebaseAuth.signIn(credential)

                        // After successful authentication, update the session
                        if let userId = authResult.user.uid {
                            // Create a new session using the session client
                            _ = try await firebaseSessionClient.createSession(userId)
                        }

                        return true
                    }
                    await send(.verifyCodeResponse(result))
                }
                .cancellable(id: CancelID.signIn)

            case let .verifyCodeResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Update the shared authentication state
                    state.$isAuthenticated.withLock { $0 = true }
                    return .send(.delegate(.signInSuccessful))
                case let .failure(error):
                    state.error = error
                    return .none
                }

            case .clearError:
                state.error = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }
}