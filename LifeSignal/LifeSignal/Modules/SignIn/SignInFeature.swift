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
        var error: UserFacingError?

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
        case sendVerificationCodeSucceeded(verificationID: String)
        case sendVerificationCodeFailed(UserFacingError)

        /// Verify the code entered by the user
        case verifyCode
        case verifyCodeSucceeded
        case verifyCodeFailed(UserFacingError)

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
                    do {
                        let formattedPhoneNumber = phoneFormatter.formatPhoneNumber(phoneNumber, region: phoneRegion)
                        let verificationID = try await firebaseAuth.verifyPhoneNumber(formattedPhoneNumber)
                        await send(.sendVerificationCodeSucceeded(verificationID: verificationID))
                    } catch {
                        let userFacingError = UserFacingError.from(error)
                        await send(.sendVerificationCodeFailed(userFacingError))
                    }
                }
                .cancellable(id: CancelID.signIn)

            case let .sendVerificationCodeSucceeded(verificationID):
                state.isLoading = false
                state.verificationID = verificationID
                state.isCodeSent = true
                return .none

            case let .sendVerificationCodeFailed(error):
                state.isLoading = false
                state.error = error
                return .none

            case .verifyCode:
                state.isLoading = true
                return .run { [verificationID = state.verificationID, verificationCode = state.verificationCode] send in
                    do {
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
                            try await firebaseSessionClient.createSession(userId)
                        }

                        await send(.verifyCodeSucceeded)
                    } catch {
                        let userFacingError = UserFacingError.from(error)
                        await send(.verifyCodeFailed(userFacingError))
                    }
                }
                .cancellable(id: CancelID.signIn)

            case .verifyCodeSucceeded:
                state.isLoading = false
                // Update the shared authentication state
                state.$isAuthenticated.withLock { $0 = true }
                return .send(.delegate(.signInSuccessful))

            case let .verifyCodeFailed(error):
                state.isLoading = false
                state.error = error
                return .none

            case .clearError:
                state.error = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }
}