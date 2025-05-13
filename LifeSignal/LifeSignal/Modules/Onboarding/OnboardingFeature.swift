import Foundation
import ComposableArchitecture
import FirebaseAuth
import Dependencies

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
    }

    /// Actions that can be performed on the onboarding feature
    @CasePathable
    enum Action: Equatable, Sendable {
        /// Input field actions
        case nameChanged(String)
        case emergencyNoteChanged(String)

        /// Button actions
        case completeSetupButtonTapped

        /// Response actions
        case profileUpdateSucceeded
        case profileUpdateFailed(UserFacingError)

        /// Delegate actions for parent features
        case delegate(DelegateAction)

        @CasePathable
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
                    do {
                        // Get the authenticated user ID or throw if not available
                        let userId = try await firebaseAuth.currentUserId()

                        // Update the profile using the client
                        let success = try await firebaseUserClient.updateProfile(userId, profileUpdate)

                        if success {
                            // Send success response
                            await send(.profileUpdateSucceeded)
                        } else {
                            // Handle the case where the operation returned false but didn't throw
                            let userFacingError = UserFacingError.operationFailed
                            await send(.profileUpdateFailed(userFacingError))
                        }
                    } catch {
                        // Map the error to a user-facing error
                        let userFacingError = UserFacingError.from(error)

                        // Handle error directly in the effect
                        await send(.profileUpdateFailed(userFacingError))
                    }
                }

            case .profileUpdateSucceeded:
                state.isLoading = false
                state.isComplete = true
                return .send(.delegate(.onboardingCompleted))

            case let .profileUpdateFailed(error):
                state.isLoading = false

                // Log the error
                FirebaseLogger.user.error("Profile update failed during onboarding: \(error)")
                return .none

            case .delegate:
                return .none
            }
        }

        ._printChanges()
    }
}
