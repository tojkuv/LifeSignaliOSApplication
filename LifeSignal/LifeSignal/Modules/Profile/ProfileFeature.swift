import Foundation
import ComposableArchitecture
import FirebaseAuth

/// Feature for the profile screen
/// This feature is a child of UserFeature and focuses on profile-specific UI and operations
@Reducer
struct ProfileFeature {
    /// The state of the profile feature
    @ObservableState
    struct State: Equatable, Sendable {
        /// User data reference from parent feature
        var userData: UserData = .empty

        /// Child feature states
        var qrCodeShare: QRCodeShareFeature.State?

        /// Profile UI state for managing UI-specific state
        var showEditNameSheet: Bool = false
        var editingName: String = ""
        var showEditDescriptionSheet: Bool = false
        var editingDescription: String = ""
        var showEditPhoneSheet: Bool = false
        var editingPhone: String = ""
        var editingPhoneRegion: String = "US"
        var showEditAvatarSheet: Bool = false
        var showSignOutConfirmation: Bool = false
        var showFirebaseTest: Bool = false

        /// Phone number change state
        var isChangingPhoneNumber: Bool = false
        var verificationID: String = ""
        var verificationCode: String = ""
        var isCodeSent: Bool = false

        /// Initialize with default values
        init() {}

        /// Initialize with user data
        init(userData: UserData) {
            self.userData = userData
        }

        /// Custom Equatable implementation to handle Error? property
        static func == (lhs: State, rhs: State) -> Bool {
            lhs.userData == rhs.userData &&
            lhs.qrCodeShare == rhs.qrCodeShare &&
            lhs.showEditNameSheet == rhs.showEditNameSheet &&
            lhs.editingName == rhs.editingName &&
            lhs.showEditDescriptionSheet == rhs.showEditDescriptionSheet &&
            lhs.editingDescription == rhs.editingDescription &&
            lhs.showEditPhoneSheet == rhs.showEditPhoneSheet &&
            lhs.editingPhone == rhs.editingPhone &&
            lhs.editingPhoneRegion == rhs.editingPhoneRegion &&
            lhs.showEditAvatarSheet == rhs.showEditAvatarSheet &&
            lhs.showSignOutConfirmation == rhs.showSignOutConfirmation &&
            lhs.showFirebaseTest == rhs.showFirebaseTest &&
            lhs.isChangingPhoneNumber == rhs.isChangingPhoneNumber &&
            lhs.verificationID == rhs.verificationID &&
            lhs.verificationCode == rhs.verificationCode &&
            lhs.isCodeSent == rhs.isCodeSent
        }
    }

    /// Actions that can be performed on the profile feature
    enum Action: BindableAction, Equatable, Sendable {
        // MARK: - Binding Action

        /// Binding action for two-way binding with the view
        case binding(BindingAction<State>)
        // MARK: - Lifecycle Actions

        /// Called when the view appears
        case onAppear

        // MARK: - Profile Operations

        /// Update profile (delegated to parent)
        case updateProfile

        /// Sign out
        case signOut
        case signOutResponse(TaskResult<Void>)

        // MARK: - Phone Number Change Actions

        /// Start phone number change process
        case startPhoneNumberChange

        /// Cancel phone number change
        case cancelPhoneNumberChange

        // Phone region is now handled by binding

        /// Send verification code for phone change
        case sendPhoneChangeVerificationCode
        case sendPhoneChangeVerificationCodeResponse(TaskResult<String>)

        // Verification code is now handled by binding

        /// Verify phone change code
        case verifyPhoneChangeCode
        case verifyPhoneChangeCodeResponse(TaskResult<Bool>)

        /// Update user phone number in Firestore
        case updateUserPhoneNumber
        case updateUserPhoneNumberResponse(TaskResult<Void>)

        // MARK: - Profile UI Actions

        /// Set whether to show the edit name sheet
        case setShowEditNameSheet(Bool)

        /// Set whether to show the edit description sheet
        case setShowEditDescriptionSheet(Bool)

        /// Set whether to show the edit phone sheet
        case setShowEditPhoneSheet(Bool)

        /// Set whether to show the edit avatar sheet
        case setShowEditAvatarSheet(Bool)

        /// Set whether to show the sign out confirmation
        case setShowSignOutConfirmation(Bool)

        /// Set whether to show the Firebase test
        case setShowFirebaseTest(Bool)

        // MARK: - QR Code Share Actions

        /// Show QR code share sheet
        case showQRCodeShareSheet

        /// QR code share feature actions
        case qrCodeShare(QRCodeShareFeature.Action)

        // MARK: - Delegate Actions

        /// Delegate actions to parent features
        case delegate(DelegateAction)

        enum DelegateAction: Equatable, Sendable {
            /// User signed out
            case userSignedOut

            /// Update profile
            case updateProfile(name: String, emergencyNote: String)

            /// Update phone number
            case updatePhoneNumber(phone: String, region: String)
        }
    }

    /// Dependencies for the profile feature
    @Dependency(\.firebaseAuth) var firebaseAuth
    @Dependency(\.phoneFormatter) var phoneFormatter

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            // MARK: - Lifecycle Actions

            case .onAppear:
                // Initialize UI state with current user data
                return .none

            // MARK: - Profile Operations

            case .updateProfile:
                // Delegate to parent feature
                return .send(.delegate(.updateProfile(
                    name: state.editingName,
                    emergencyNote: state.editingDescription
                )))

            case .signOut:
                return .run { [firebaseAuth] send in
                    let result = await TaskResult {
                        try await firebaseAuth.signOut()
                    }
                    await send(.signOutResponse(result))
                }

            case let .signOutResponse(result):
                switch result {
                case .success:
                    return .send(.delegate(.userSignedOut))

                case let .failure(error):
                    // Handle error locally
                    return .none
                }

            // MARK: - Profile UI Actions

            case let .setShowEditNameSheet(show):
                state.showEditNameSheet = show
                if show {
                    // Initialize editing name with current name
                    state.editingName = state.userData.name
                }
                return .none

            case .binding:
                return .none

            case let .setShowEditDescriptionSheet(show):
                state.showEditDescriptionSheet = show
                if show {
                    // Initialize editing description with current description
                    state.editingDescription = state.userData.emergencyNote
                }
                return .none

            case let .setShowEditPhoneSheet(show):
                state.showEditPhoneSheet = show
                if show {
                    // Initialize editing phone with current phone
                    state.editingPhone = state.userData.phoneNumber
                    state.editingPhoneRegion = state.userData.phoneRegion
                    state.isChangingPhoneNumber = false
                    state.isCodeSent = false
                    state.verificationCode = ""
                    state.verificationID = ""
                }
                return .none

            // MARK: - Phone Number Change Actions

            case .startPhoneNumberChange:
                state.isChangingPhoneNumber = true
                return .none

            case .cancelPhoneNumberChange:
                state.isChangingPhoneNumber = false
                state.isCodeSent = false
                state.verificationCode = ""
                state.verificationID = ""
                return .none

            case .sendPhoneChangeVerificationCode:
                return .run { [phoneNumber = state.editingPhone, phoneRegion = state.editingPhoneRegion, phoneFormatter, firebaseAuth] send in
                    let result = await TaskResult {
                        let formattedPhoneNumber = phoneFormatter.formatPhoneNumber(phoneNumber, region: phoneRegion)
                        return try await firebaseAuth.verifyPhoneNumber(formattedPhoneNumber)
                    }
                    await send(.sendPhoneChangeVerificationCodeResponse(result))
                }

            case let .sendPhoneChangeVerificationCodeResponse(result):
                switch result {
                case let .success(verificationID):
                    state.verificationID = verificationID
                    state.isCodeSent = true
                    return .none
                case let .failure(error):
                    // Handle error locally
                    return .none
                }

            // Verification code is now handled by binding

            case .verifyPhoneChangeCode:
                return .run { [verificationID = state.verificationID, verificationCode = state.verificationCode, firebaseAuth] send in
                    let result = await TaskResult {
                        // Create credential using the auth client
                        let credential = firebaseAuth.phoneAuthCredential(
                            verificationID: verificationID,
                            verificationCode: verificationCode
                        )

                        // Update phone number with the credential
                        try await firebaseAuth.updatePhoneNumber(credential)

                        return true
                    }
                    await send(.verifyPhoneChangeCodeResponse(result))
                }

            case let .verifyPhoneChangeCodeResponse(result):
                switch result {
                case .success:
                    return .send(.updateUserPhoneNumber)
                case let .failure(error):
                    // Handle error locally
                    return .none
                }

            case .updateUserPhoneNumber:
                // Delegate to parent feature
                return .send(.delegate(.updatePhoneNumber(
                    phone: state.editingPhone,
                    region: state.editingPhoneRegion
                )))

            case let .updateUserPhoneNumberResponse(result):
                switch result {
                case .success:
                    // Reset phone change state
                    state.isChangingPhoneNumber = false
                    state.isCodeSent = false
                    state.verificationCode = ""
                    state.verificationID = ""
                    state.showEditPhoneSheet = false
                    return .none
                case let .failure(error):
                    // Handle error locally
                    return .none
                }

            case let .setShowEditAvatarSheet(show):
                state.showEditAvatarSheet = show
                return .none

            case let .setShowSignOutConfirmation(show):
                state.showSignOutConfirmation = show
                return .none

            case let .setShowFirebaseTest(show):
                state.showFirebaseTest = show
                return .none

            // MARK: - QR Code Share Actions

            case .showQRCodeShareSheet:
                state.qrCodeShare = QRCodeShareFeature.State(
                    name: state.userData.name,
                    qrCodeId: state.userData.qrCodeId
                )
                return .none

            case .qrCodeShare(.dismiss):
                state.qrCodeShare = nil
                return .none

            case .qrCodeShare:
                return .none

            // MARK: - Delegate Actions

            case .delegate:
                return .none
            }
        }
        .ifLet(\.qrCodeShare, action: \.qrCodeShare) {
            QRCodeShareFeature()
        }
    }
}


