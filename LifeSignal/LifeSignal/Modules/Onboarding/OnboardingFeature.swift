import Foundation
import ComposableArchitecture
import FirebaseAuth

/// Feature for managing the onboarding process
@Reducer
struct OnboardingFeature {
    /// The state of the onboarding feature
    @ObservableState
    struct State: Equatable, Sendable {
        /// User input fields
        var name: String = ""
        var emergencyNote: String = ""

        /// UI state
        var isLoading: Bool = false
        var isComplete: Bool = false

        /// Error state
        var error: Error?

        /// Custom Equatable implementation to handle Error? property
        static func == (lhs: State, rhs: State) -> Bool {
            lhs.name == rhs.name &&
            lhs.emergencyNote == rhs.emergencyNote &&
            lhs.isLoading == rhs.isLoading &&
            lhs.isComplete == rhs.isComplete &&
            (lhs.error != nil) == (rhs.error != nil)
        }
    }

    /// Actions that can be performed on the onboarding feature
    enum Action: Equatable, Sendable {
        /// Input field actions
        case nameChanged(String)
        case emergencyNoteChanged(String)

        /// Button actions
        case completeSetupButtonTapped

        /// Response actions
        case profileUpdateResponse(TaskResult<Void>)

        /// Delegate actions for parent features
        case delegate(DelegateAction)

        enum DelegateAction: Equatable, Sendable {
            case onboardingCompleted
        }
    }

    /// Dependencies
    @Dependency(\.firebaseUserClient) var firebaseUserClient
    @Dependency(\.firebaseAuth) var firebaseAuth

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .nameChanged(name):
                state.name = name
                return .none

            case let .emergencyNoteChanged(note):
                state.emergencyNote = note
                return .none

            case .completeSetupButtonTapped:
                guard !state.name.isEmpty else { return .none }

                state.isLoading = true
                let profileUpdate = ProfileUpdate(name: state.name, emergencyNote: state.emergencyNote)

                return .run { [firebaseUserClient, firebaseAuth] send in
                    let result = await TaskResult {
                        let userId = try await firebaseAuth.currentUserId()

                        try await firebaseUserClient.updateProfile(userId, profileUpdate)
                    }
                    await send(.profileUpdateResponse(result))
                }

            case let .profileUpdateResponse(result):
                state.isLoading = false

                switch result {
                case .success:
                    state.isComplete = true
                    return .send(.delegate(.onboardingCompleted))

                case let .failure(error):
                    state.error = error
                    return .none
                }

            case .delegate:
                return .none
            }
        }
    }
}
