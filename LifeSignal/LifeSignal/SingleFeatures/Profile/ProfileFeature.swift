import Foundation
import ComposableArchitecture
import FirebaseFirestore

/// Feature for managing user profile functionality
@Reducer
struct ProfileFeature {
    /// The state of the profile feature
    struct State: Equatable {
        /// Flag indicating if the profile is in edit mode
        var isEditing: Bool = false

        /// Temporary name for editing
        var editingName: String = ""

        /// Temporary note for editing
        var editingNote: String = ""

        /// Loading state
        var isLoading: Bool = false

        /// Error state
        var error: Error? = nil

        /// QR code presentation state
        @PresentationState var qrCode: QRCodeFeature.State?

        /// Destination state for navigation
        @PresentationState var destination: Destination.State?

        /// Computed properties that access user state
        var name: String { _userState?.name ?? "" }
        var phoneNumber: String { _userState?.phoneNumber ?? "" }
        var phoneRegion: String { _userState?.phoneRegion ?? "US" }
        var note: String { _userState?.note ?? "" }
        var qrCodeId: String { _userState?.qrCodeId ?? "" }
        var notificationEnabled: Bool { _userState?.notificationEnabled ?? true }
        var profileComplete: Bool { _userState?.profileComplete ?? false }

        /// Reference to the parent user state
        var _userState: UserFeature.State?
    }

    /// Actions that can be performed on the profile feature
    enum Action: Equatable {
        /// Parent user actions
        case userAction(UserFeature.Action)

        /// Edit mode actions
        case setEditMode(Bool)
        case updateEditingName(String)
        case updateEditingNote(String)
        case saveEdit
        case cancelEdit

        /// QR code actions
        case showQRCode
        case qrCode(PresentationAction<QRCodeFeature.Action>)

        /// Navigation actions
        case showSettings
        case destination(PresentationAction<Destination.Action>)

        /// Sign out action
        case signOut
    }

    /// Destination for navigation
    @Reducer
    struct Destination {
        enum State: Equatable {
            case settings(SettingsFeature.State)
        }

        enum Action: Equatable {
            case settings(SettingsFeature.Action)
        }

        var body: some ReducerOf<Self> {
            Scope(state: /State.settings, action: /Action.settings) {
                SettingsFeature()
            }
        }
    }

    /// Dependencies
    @Dependency(\.userClient) var userClient

    /// Connect to parent user state
    @ObservableState
    struct _UserState {
        var userState: UserFeature.State?
    }

    /// Property wrapper for connecting to parent user state
    func _userState(
        get: @escaping (State) -> UserFeature.State?,
        set: @escaping (inout State, UserFeature.State?) -> Void
    ) -> some ReducerOf<Self> {
        Reduce { state, action in
            if case let .userAction(userAction) = action {
                return .send(.user(userAction))
            }
            return self.reduce(into: &state, action: action)
        }
        .transformDependency(\.self) { dependency in
            var dependency = dependency
            let userState = _UserState(userState: get(dependency.state))

            dependency.state._userState = userState.userState

            return dependency
        }
    }

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .userAction:
                // Forward to parent
                return .none

            case let .setEditMode(isEditing):
                state.isEditing = isEditing
                if isEditing {
                    state.editingName = state.name
                    state.editingNote = state.note
                }
                return .none

            case let .updateEditingName(name):
                state.editingName = name
                return .none

            case let .updateEditingNote(note):
                state.editingNote = note
                return .none

            case .saveEdit:
                state.isLoading = true
                return .send(.userAction(.updateProfile(name: state.editingName, note: state.editingNote)))

            case .cancelEdit:
                state.isEditing = false
                return .none

            case .showQRCode:
                state.qrCode = QRCodeFeature.State(
                    qrCodeId: state.qrCodeId,
                    userName: state.name
                )
                return .none

            case .qrCode:
                return .none

            case .showSettings:
                state.destination = .settings(SettingsFeature.State())
                return .none

            case .destination:
                return .none

            case .signOut:
                state.isLoading = true
                return .send(.userAction(.signOut))
            }
        }
        .ifLet(\.$qrCode, action: /Action.qrCode) {
            QRCodeFeature()
        }
        .ifLet(\.$destination, action: /Action.destination) {
            Destination()
        }
    }
}
