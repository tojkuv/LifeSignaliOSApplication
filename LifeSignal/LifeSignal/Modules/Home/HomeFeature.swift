import Foundation
import ComposableArchitecture
import Dependencies

/// Feature for the home screen
@Reducer
struct HomeFeature {
    /// The state of the home feature
    @ObservableState
    struct State: Equatable, Sendable {
        /// Sheet presentation states using @Presents
        @Presents var intervalPicker: IntervalPickerFeature.State?
        @Presents var instructions: InstructionsFeature.State?
        @Presents var shareQRCode: QRCodeShareFeature.State?
        @Presents var checkInConfirmation: CheckInConfirmationFeature.State?

        /// Child feature states
        var qrScanner: QRScannerFeature.State = .init()
        var addContact: AddContactFeature.State = .init()

        /// Loading state
        var isLoading: Bool = false

        /// Error state
        var error: UserFacingError? = nil

        /// Initialize with default values
        init() {}
    }

    /// Feature for interval picker
    @Reducer
    struct IntervalPickerFeature {
        @ObservableState
        struct State: Equatable, Sendable {}

        @CasePathable
        enum Action: Equatable, Sendable {
            case intervalSelected(TimeInterval)
            case dismiss
        }

        var body: some ReducerOf<Self> {
            Reduce { state, action in
                switch action {
                case .intervalSelected, .dismiss:
                    return .none
                }
            }
        }
    }

    /// Feature for instructions
    @Reducer
    struct InstructionsFeature {
        @ObservableState
        struct State: Equatable, Sendable {}

        @CasePathable
        enum Action: Equatable, Sendable {
            case dismiss
        }

        var body: some ReducerOf<Self> {
            Reduce { state, action in
                switch action {
                case .dismiss:
                    return .none
                }
            }
        }
    }

    /// Feature for QR code sharing
    @Reducer
    struct QRCodeShareFeature {
        @ObservableState
        struct State: Equatable, Sendable {}

        @CasePathable
        enum Action: Equatable, Sendable {
            case dismiss
        }

        var body: some ReducerOf<Self> {
            Reduce { state, action in
                switch action {
                case .dismiss:
                    return .none
                }
            }
        }
    }

    /// Feature for check-in confirmation
    @Reducer
    struct CheckInConfirmationFeature {
        @ObservableState
        struct State: Equatable, Sendable {}

        @CasePathable
        enum Action: Equatable, Sendable {
            case confirm
            case dismiss
        }

        var body: some ReducerOf<Self> {
            Reduce { state, action in
                switch action {
                case .confirm, .dismiss:
                    return .none
                }
            }
        }
    }

    /// Actions that can be performed on the home feature
    @CasePathable
    enum Action: Equatable, Sendable, BindableAction {
        /// Sheet presentation actions with PresentationAction
        case intervalPicker(PresentationAction<IntervalPickerFeature.Action>)
        case instructions(PresentationAction<InstructionsFeature.Action>)
        case shareQRCode(PresentationAction<QRCodeShareFeature.Action>)
        case checkInConfirmation(PresentationAction<CheckInConfirmationFeature.Action>)

        /// Button actions
        case checkInButtonTapped
        case shareQRCodeButtonTapped
        case addContactButtonTapped
        case showIntervalPickerButtonTapped
        case showInstructionsButtonTapped

        /// State management
        case setLoading(Bool)
        case setError(UserFacingError?)

        /// Child feature actions
        case qrScanner(QRScannerFeature.Action)
        case addContact(AddContactFeature.Action)

        /// Delegate actions to communicate with parent features
        case delegate(Delegate)

        /// Binding action for SwiftUI bindings
        case binding(BindingAction<State>)

        /// Delegate actions enum
        @CasePathable
        enum Delegate: Equatable, Sendable {
            case updateCheckInInterval(TimeInterval)
            case checkInRequested
            case errorOccurred(UserFacingError)
        }
    }

    /// Dependencies
    @Dependency(\.timeFormatter) var timeFormatter

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        BindingReducer()

        Scope(state: \.qrScanner, action: \.qrScanner) {
            QRScannerFeature()
        }

        Scope(state: \.addContact, action: \.addContact) {
            AddContactFeature()
        }

        // Use the presentation reducers
        .presents(state: \.intervalPicker, action: \.intervalPicker) {
            IntervalPickerFeature()
        }

        .presents(state: \.instructions, action: \.instructions) {
            InstructionsFeature()
        }

        .presents(state: \.shareQRCode, action: \.shareQRCode) {
            QRCodeShareFeature()
        }

        .presents(state: \.checkInConfirmation, action: \.checkInConfirmation) {
            CheckInConfirmationFeature()
        }

        Reduce { state, action in
            switch action {
            // Button actions
            case .checkInButtonTapped:
                state.checkInConfirmation = CheckInConfirmationFeature.State()
                return .none

            case .shareQRCodeButtonTapped:
                state.shareQRCode = QRCodeShareFeature.State()
                return .none

            case .addContactButtonTapped:
                return .send(.qrScanner(.setShowScanner(true)))

            case .showIntervalPickerButtonTapped:
                state.intervalPicker = IntervalPickerFeature.State()
                return .none

            case .showInstructionsButtonTapped:
                state.instructions = InstructionsFeature.State()
                return .none

            // State management
            case let .setLoading(isLoading):
                state.isLoading = isLoading
                return .none

            case let .setError(error):
                state.error = error
                return .none

            // Presentation actions
            case .intervalPicker(.presented(.intervalSelected(let interval))):
                // Use delegate pattern to communicate with parent
                return .send(.delegate(.updateCheckInInterval(interval)))

            case .intervalPicker(.dismiss):
                // Handle dismiss action
                return .none

            case .instructions(.dismiss), .shareQRCode(.dismiss), .checkInConfirmation(.dismiss):
                // Handle dismiss actions
                return .none

            case .checkInConfirmation(.presented(.confirm)):
                // Handle check-in confirmation
                state.checkInConfirmation = nil
                return .send(.delegate(.checkInRequested))

            // QR scanner actions
            case .qrScanner(.qrCodeScanned(let code)):
                // When a QR code is scanned, show the add contact sheet
                state.addContact.qrCode = code
                return .send(.addContact(.setSheetPresented(true)))

            case .qrScanner:
                // Other QR scanner actions are handled by the QRScannerFeature
                return .none

            // Add contact actions
            case .addContact(.contactAdded):
                // When a contact is added, close the sheet
                return .send(.addContact(.setSheetPresented(false)))

            case .addContact:
                // Other add contact actions are handled by the AddContactFeature
                return .none

            // Handle binding actions
            case .binding:
                return .none

            // Delegate actions
            case .delegate:
                return .none
            }
        }
    }

    /// Format a time interval for display
    /// - Parameter interval: The time interval in seconds
    /// - Returns: A formatted string representation of the interval
    func formatInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600

        if hours < 24 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            let days = hours / 24
            return "\(days) day\(days == 1 ? "" : "s")"
        }
    }
}
