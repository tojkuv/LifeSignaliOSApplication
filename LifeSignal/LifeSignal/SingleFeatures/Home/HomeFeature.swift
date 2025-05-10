import Foundation
import ComposableArchitecture
import FirebaseFirestore
import UIKit

/// Feature for managing the home screen functionality
@Reducer
struct HomeFeature {
    /// The state of the home feature
    struct State: Equatable {
        /// User's notification lead time in minutes
        var notificationLeadTime: Int = 30

        /// Flag indicating if QR scanner is shown
        var showQRScanner: Bool = false

        /// Flag indicating if interval picker is shown
        var showIntervalPicker: Bool = false

        /// Flag indicating if instructions are shown
        var showInstructions: Bool = false

        /// Flag indicating if check-in confirmation is shown
        var showCheckInConfirmation: Bool = false

        /// Flag indicating if share sheet is shown
        var showShareSheet: Bool = false

        /// QR code image for sharing
        var qrCodeImage: UIImage? = nil

        /// Flag indicating if image is ready for sharing
        var isImageReady: Bool = false

        /// Flag indicating if image is being generated
        var isGeneratingImage: Bool = false

        /// Flag indicating if camera access was denied
        var showCameraDeniedAlert: Bool = false

        /// Pending scanned QR code
        var pendingScannedCode: String? = nil

        /// New contact from QR scan
        var newContact: Contact? = nil

        /// Loading state
        var isLoading: Bool = false

        /// Error state
        var error: Error? = nil

        /// Destination state for navigation
        @PresentationState var destination: Destination.State?

        /// Reference to the parent user state
        var _userState: UserFeature.State?

        /// Computed properties that access user state
        var name: String { _userState?.name ?? "" }
        var qrCodeId: String { _userState?.qrCodeId ?? "" }
        var checkInInterval: TimeInterval { _userState?.checkInInterval ?? TimeManager.defaultInterval }

        /// Convenience computed property for user's name in UI
        var userName: String { name }
    }

    /// Actions that can be performed on the home feature
    enum Action: Equatable {
        /// Parent user actions
        case userAction(UserFeature.Action)

        /// Check-in actions
        case checkIn

        /// Update check-in interval
        case updateInterval(TimeInterval)

        /// Update notification lead time
        case updateNotificationLeadTime(Int)

        /// QR code actions
        case generateQRCode
        case generateQRCodeResponse(TaskResult<UIImage?>)
        case showQRScanner(Bool)
        case handleQRScanResult(String?)

        /// Contact actions
        case lookupContact(String)
        case lookupContactResponse(TaskResult<Contact?>)
        case addContact(Contact, isResponder: Bool, isDependent: Bool)
        case addContactResponse(TaskResult<Bool>)

        /// UI state actions
        case setShowIntervalPicker(Bool)
        case setShowInstructions(Bool)
        case setShowCheckInConfirmation(Bool)
        case setShowShareSheet(Bool)
        case setShowCameraDeniedAlert(Bool)
        case clearNewContact

        /// Navigation actions
        case destination(PresentationAction<Destination.Action>)
    }

    /// Destination for navigation
    @Reducer
    struct Destination {
        enum State: Equatable {
            case addContact(AddContactFeature.State)
            case intervalPicker(IntervalPickerFeature.State)
            case instructions(BasicInstructionsFeature.State)
        }

        enum Action: Equatable {
            case addContact(AddContactFeature.Action)
            case intervalPicker(IntervalPickerFeature.Action)
            case instructions(BasicInstructionsFeature.Action)
        }

        var body: some ReducerOf<Self> {
            Scope(state: /State.addContact, action: /Action.addContact) {
                AddContactFeature()
            }
            Scope(state: /State.intervalPicker, action: /Action.intervalPicker) {
                IntervalPickerFeature()
            }
            Scope(state: /State.instructions, action: /Action.instructions) {
                BasicInstructionsFeature()
            }
        }
    }

    /// Dependencies
    @Dependency(\.userClient) var userClient
    @Dependency(\.contactsClient) var contactsClient

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

            case .checkIn:
                state.isLoading = true
                state.showCheckInConfirmation = false
                return .send(.userAction(.checkIn))

            case let .updateInterval(interval):
                state.isLoading = true
                state.showIntervalPicker = false
                return .send(.userAction(.updateCheckInInterval(interval)))

            case let .updateNotificationLeadTime(minutes):
                state.isLoading = true
                state.notificationLeadTime = minutes
                let notify30Min = minutes == 30
                let notify2Hours = minutes == 120
                return .send(.userAction(.updateNotificationPreferences(notify30Min: notify30Min, notify2Hours: notify2Hours)))

            case .generateQRCode:
                state.isGeneratingImage = true
                return .run { [qrCodeId = state.qrCodeId] send in
                    let result = await TaskResult {
                        // Generate QR code image
                        let data = qrCodeId.data(using: .utf8)
                        let context = CIContext()
                        let filter = CIFilter.qrCodeGenerator()

                        filter.setValue(data, forKey: "inputMessage")
                        filter.setValue("M", forKey: "inputCorrectionLevel")

                        guard let ciImage = filter.outputImage else {
                            return nil
                        }

                        let transform = CGAffineTransform(scaleX: 10, y: 10)
                        let scaledCIImage = ciImage.transformed(by: transform)

                        guard let cgImage = context.createCGImage(scaledCIImage, from: scaledCIImage.extent) else {
                            return nil
                        }

                        return UIImage(cgImage: cgImage)
                    }
                    await send(.generateQRCodeResponse(result))
                }

            case let .generateQRCodeResponse(result):
                state.isGeneratingImage = false
                switch result {
                case let .success(image):
                    state.qrCodeImage = image
                    state.isImageReady = image != nil
                    if image != nil {
                        state.showShareSheet = true
                    }
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }

            case let .showQRScanner(show):
                state.showQRScanner = show
                if !show {
                    // Handle QR scanner dismissal if needed
                }
                return .none

            case let .handleQRScanResult(code):
                state.pendingScannedCode = code
                if let code = code {
                    return .send(.lookupContact(code))
                }
                return .none

            case let .lookupContact(code):
                state.isLoading = true
                return .run { send in
                    let result = await TaskResult {
                        try await contactsClient.lookupUserByQRCode(code)
                    }
                    await send(.lookupContactResponse(result))
                }

            case let .lookupContactResponse(result):
                state.isLoading = false
                switch result {
                case let .success(contact):
                    state.newContact = contact
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }

            case let .addContact(contact, isResponder, isDependent):
                state.isLoading = true
                return .run { send in
                    let result = await TaskResult {
                        try await contactsClient.addContact(contact)
                    }
                    await send(.addContactResponse(result))
                }

            case let .addContactResponse(result):
                state.isLoading = false
                state.newContact = nil
                switch result {
                case .success:
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }

            case let .setShowIntervalPicker(show):
                state.showIntervalPicker = show
                return .none

            case let .setShowInstructions(show):
                state.showInstructions = show
                return .none

            case let .setShowCheckInConfirmation(show):
                state.showCheckInConfirmation = show
                return .none

            case let .setShowShareSheet(show):
                state.showShareSheet = show
                return .none

            case let .setShowCameraDeniedAlert(show):
                state.showCameraDeniedAlert = show
                return .none

            case .clearNewContact:
                state.newContact = nil
                return .none

            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: /Action.destination) {
            Destination()
        }
    }
}
