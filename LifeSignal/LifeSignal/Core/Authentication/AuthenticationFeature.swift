import Foundation
import ComposableArchitecture
import FirebaseAuth

/// Feature for managing user authentication
@Reducer
struct AuthenticationFeature {
    /// The state of the authentication feature
    struct State: Equatable {
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

        /// Loading state
        var isLoading: Bool = false

        /// Error state
        var error: Error? = nil
    }

    /// Actions that can be performed on the authentication feature
    enum Action: Equatable {
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

        /// Clear any error state
        case clearError
    }

    /// Dependencies for the authentication feature
    @Dependency(\.tcaAuthClient) var authClient

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .sendVerificationCode:
                state.isLoading = true
                return .run { [phoneNumber = state.phoneNumber, phoneRegion = state.phoneRegion] send in
                    let result = await TaskResult {
                        try await authClient.sendVerificationCode(
                            phoneNumber: phoneNumber,
                            phoneRegion: phoneRegion
                        )
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
                        try await authClient.verifyCode(
                            verificationID: verificationID,
                            verificationCode: verificationCode
                        )
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
                        try await authClient.signOut()
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
                        try await authClient.isAuthenticated()
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

            case .clearError:
                state.error = nil
                return .none
            }
        }
    }
}
