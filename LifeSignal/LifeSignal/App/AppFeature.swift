import Foundation
import ComposableArchitecture

/// Root feature for the app using TCA
@Reducer
struct AppFeature {
    /// The state of the app feature
    struct State: Equatable {
        /// Authentication feature state
        var authentication: AuthenticationFeature.State?

        /// User feature state (shared across features)
        var user: UserFeature.State?

        /// Home feature state
        var home: HomeFeature.State?

        /// Contacts feature state
        var contacts: ContactsFeature.State?

        /// Check-in feature state
        var checkIn: CheckInFeature.State?

        /// Profile feature state
        var profile: ProfileFeature.State?

        /// Flag indicating if user is authenticated
        var isAuthenticated: Bool = false

        /// Flag indicating if user needs to complete onboarding
        var needsOnboarding: Bool = false
    }

    /// Actions that can be performed on the app feature
    enum Action: Equatable {
        /// Authentication actions
        case authentication(AuthenticationFeature.Action)

        /// User actions (shared across features)
        case user(UserFeature.Action)

        /// Home actions
        case home(HomeFeature.Action)

        /// Contacts actions
        case contacts(ContactsFeature.Action)

        /// Check-in actions
        case checkIn(CheckInFeature.Action)

        /// Profile actions
        case profile(ProfileFeature.Action)

        /// Set authentication state
        case authenticate

        /// Set onboarding state
        case setNeedsOnboarding(Bool)

        /// Complete onboarding
        case completeOnboarding
    }

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .authenticate:
                state.isAuthenticated = true

                // Initialize user feature state first
                if state.user == nil {
                    state.user = UserFeature.State()
                }

                // Initialize feature states if they don't exist
                if state.home == nil {
                    state.home = HomeFeature.State()
                }

                if state.contacts == nil {
                    state.contacts = ContactsFeature.State()
                }

                if state.checkIn == nil {
                    state.checkIn = CheckInFeature.State()
                }

                if state.profile == nil {
                    state.profile = ProfileFeature.State()
                }

                // Start streaming user data and contacts
                return .concatenate(
                    .send(.user(.startUserDataStream)),
                    .send(.contacts(.startContactsStream))
                )

            case .setNeedsOnboarding(let needsOnboarding):
                state.needsOnboarding = needsOnboarding
                return .none

            case .completeOnboarding:
                state.needsOnboarding = false

                // In a real implementation, we would save the profile information
                // to Firebase here

                return .none

            case .authentication(.verifyCodeResponse(.success(true))):
                // User successfully authenticated
                return .send(.authenticate)

            case .authentication:
                // Handle other authentication actions
                if state.authentication == nil {
                    state.authentication = AuthenticationFeature.State()
                }

                return .none

            case let .home(.userAction(userAction)):
                // Forward user actions from home to user feature
                return .send(.user(userAction))

            case .home:
                // Handle other home actions
                return .none

            case .contacts(.startContactsStream), .contacts(.stopContactsStream), .contacts(.contactsStreamResponse):
                // These actions are handled directly in the contacts feature
                return .none

            case .contacts:
                // Handle other contacts actions
                return .none

            case let .checkIn(.userAction(userAction)):
                // Forward user actions from check-in to user feature
                return .send(.user(userAction))

            case .checkIn:
                // Handle other check-in actions
                return .none

            case .user(.signOutResponse(.success)):
                // Handle successful sign out
                state.isAuthenticated = false
                state.user = nil
                state.home = nil
                state.contacts = nil
                state.checkIn = nil
                state.profile = nil
                return .none

            case .user(.signOut):
                // Stop all streams before signing out
                return .concatenate(
                    .send(.user(.stopUserDataStream)),
                    .send(.contacts(.stopContactsStream))
                )

            case .user:
                // Handle other user actions
                return .none

            case let .profile(.userAction(userAction)):
                // Forward user actions from profile to user feature
                return .send(.user(userAction))

            case .profile:
                // Handle other profile actions
                return .none
            }
        }
        .ifLet(\.authentication, action: /Action.authentication) {
            AuthenticationFeature()
        }
        .ifLet(\.user, action: /Action.user) {
            UserFeature()
        }
        .ifLet(\.home, action: /Action.home) {
            HomeFeature()
                ._userState(
                    get: { appState in
                        appState.user
                    },
                    set: { _, _ in }
                )
        }
        .ifLet(\.contacts, action: /Action.contacts) {
            ContactsFeature()
        }
        .ifLet(\.checkIn, action: /Action.checkIn) {
            CheckInFeature()
                ._userState(
                    get: { appState in
                        appState.user
                    },
                    set: { _, _ in }
                )
        }
        .ifLet(\.profile, action: /Action.profile) {
            ProfileFeature()
                ._userState(
                    get: { appState in
                        appState.user
                    },
                    set: { _, _ in }
                )
        }
    }
}
