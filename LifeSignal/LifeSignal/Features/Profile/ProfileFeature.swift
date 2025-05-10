import Foundation
import ComposableArchitecture
import FirebaseFirestore

/// Feature for managing user profile functionality
@Reducer
struct ProfileFeature {
    /// The state of the profile feature
    struct State: Equatable {
        /// User's full name
        var name: String = ""
        
        /// User's phone number (E.164 format)
        var phoneNumber: String = ""
        
        /// User's phone region (ISO country code)
        var phoneRegion: String = "US"
        
        /// User's emergency profile description/note
        var note: String = ""
        
        /// User's unique QR code identifier
        var qrCodeId: String = ""
        
        /// Flag indicating if user has enabled notifications
        var notificationEnabled: Bool = true
        
        /// Flag indicating if user has completed profile setup
        var profileComplete: Bool = false
        
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
    }
    
    /// Actions that can be performed on the profile feature
    enum Action: Equatable {
        /// Load the user's profile data
        case loadProfile
        case loadProfileResponse(TaskResult<ProfileData>)
        
        /// Update the user's profile
        case updateProfile(name: String, note: String)
        case updateProfileResponse(TaskResult<Bool>)
        
        /// Update notification settings
        case updateNotificationSettings(enabled: Bool)
        case updateNotificationSettingsResponse(TaskResult<Bool>)
        
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
        case signOutResponse(TaskResult<Bool>)
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
    @Dependency(\.profileClient) var profileClient
    
    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadProfile:
                state.isLoading = true
                return .run { send in
                    let result = await TaskResult {
                        try await profileClient.loadProfile()
                    }
                    await send(.loadProfileResponse(result))
                }
                
            case let .loadProfileResponse(result):
                state.isLoading = false
                switch result {
                case let .success(data):
                    state.name = data.name
                    state.phoneNumber = data.phoneNumber
                    state.phoneRegion = data.phoneRegion
                    state.note = data.note
                    state.qrCodeId = data.qrCodeId
                    state.notificationEnabled = data.notificationEnabled
                    state.profileComplete = data.profileComplete
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }
                
            case let .updateProfile(name, note):
                state.isLoading = true
                return .run { send in
                    let result = await TaskResult {
                        try await profileClient.updateProfile(name: name, note: note)
                    }
                    await send(.updateProfileResponse(result))
                }
                
            case let .updateProfileResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    state.name = state.editingName
                    state.note = state.editingNote
                    state.isEditing = false
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }
                
            case let .updateNotificationSettings(enabled):
                state.isLoading = true
                return .run { send in
                    let result = await TaskResult {
                        try await profileClient.updateNotificationSettings(enabled: enabled)
                    }
                    await send(.updateNotificationSettingsResponse(result))
                }
                
            case let .updateNotificationSettingsResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }
                
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
                return .send(.updateProfile(name: state.editingName, note: state.editingNote))
                
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
                return .run { send in
                    let result = await TaskResult {
                        try await profileClient.signOut()
                    }
                    await send(.signOutResponse(result))
                }
                
            case let .signOutResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // The app feature will handle the sign out state change
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }
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
