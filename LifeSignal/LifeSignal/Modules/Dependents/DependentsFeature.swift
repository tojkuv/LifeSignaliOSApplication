import Foundation
import ComposableArchitecture
import Dependencies

/// Feature for the dependents screen
/// This feature is a child of ContactsFeature and focuses on dependent-specific UI and operations
@Reducer
struct DependentsFeature {
    /// The state of the dependents feature
    @ObservableState
    struct State: Equatable, Sendable {
        /// Parent contacts feature state
        var contacts: ContactsFeature.State = .init()

        /// UI State
        var isLoading: Bool = false
        var error: UserFacingError? = nil

        /// Child feature states
        var contactDetails: ContactDetailsSheetFeature.State = .init()
        var qrScanner: QRScannerFeature.State = .init()
        var addContact: AddContactFeature.State = .init()

        /// Computed properties
        var nonResponsiveDependentsCount: Int {
            contacts.dependents.filter { $0.isNonResponsive || $0.manualAlertActive }.count
        }

        /// Initialize with default values
        init() {}
    }

    /// Actions that can be performed on the dependents feature
    @CasePathable
    enum Action: Equatable, Sendable {
        // MARK: - Lifecycle Actions
        case onAppear

        // MARK: - State Management
        case setLoading(Bool)
        case setError(UserFacingError?)

        // MARK: - Parent Feature Actions
        case contacts(ContactsFeature.Action)
        case ping(PingFeature.Action)

        // MARK: - UI Actions
        case setShowQRScanner(Bool)
        case selectContact(ContactData?)

        // MARK: - Child Feature Actions
        case contactDetails(ContactDetailsSheetFeature.Action)
        case qrScanner(QRScannerFeature.Action)
        case addContact(AddContactFeature.Action)

        // MARK: - Delegate Actions
        case delegate(DelegateAction)

        @CasePathable
        enum DelegateAction: Equatable, Sendable {
            case contactsUpdated
            case errorOccurred(UserFacingError)
        }
    }

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        // Include the parent ContactsFeature
        Scope(state: \.contacts, action: \.contacts) {
            ContactsFeature()
        }

        // Include child features
        Scope(state: \.contactDetails, action: \.contactDetails) {
            ContactDetailsSheetFeature()
        }

        Scope(state: \.qrScanner, action: \.qrScanner) {
            QRScannerFeature()
        }

        Scope(state: \.addContact, action: \.addContact) {
            AddContactFeature()
        }

        // Forward ping actions to the AppFeature
        Reduce { state, action in
            switch action {
            case .ping:
                // Forward ping actions to the AppFeature
                return .none
            default:
                return .none
            }
        }

        Reduce { state, action in
            switch action {
            // MARK: - Lifecycle Actions

            case .onAppear:
                // Start by loading contacts - stream is now handled at the AppFeature level
                return .send(.contacts(.loadContacts))

            // MARK: - State Management

            case let .setLoading(isLoading):
                state.isLoading = isLoading
                return .none

            case let .setError(error):
                state.error = error
                if let error = error {
                    return .send(.delegate(.errorOccurred(error)))
                }
                return .none

            // MARK: - Parent Feature Actions

            case .contacts(.delegate(.contactsUpdated)):
                // Contacts were updated, update loading state
                state.isLoading = state.contacts.isLoading
                return .none

            case .contacts(.delegate(.contactsLoadFailed(let error))):
                // Contacts loading failed, update error state
                state.error = error
                state.isLoading = false
                return .send(.delegate(.errorOccurred(error)))

            case .contacts:
                // Other contacts actions are handled by the parent feature
                return .none

            // MARK: - UI Actions

            case let .setShowQRScanner(show):
                state.qrScanner.showScanner = show
                return .none

            case let .selectContact(contact):
                if let contact = contact {
                    state.contactDetails.contact = contact
                    state.contactDetails.isActive = true
                } else {
                    state.contactDetails.isActive = false
                }
                return .none

            // MARK: - Child Feature Actions

            case .contactDetails(.setActive(false)):
                // When contact details sheet is dismissed, clear the contact
                state.contactDetails.contact = nil
                return .none

            case .contactDetails(.delegate(.removeContact(let id))):
                // When a contact is removed, delegate to parent feature
                return .send(.contacts(.deleteContact(id: id)))

            case .contactDetails(.delegate(.toggleContactRole(let id, let isResponder, let isDependent))):
                // When a contact's role is toggled, delegate to parent feature
                return .send(.contacts(.updateContactRoles(id: id, isResponder: isResponder, isDependent: isDependent)))

            case .contactDetails:
                return .none

            case .qrScanner(.qrCodeScanned(let code)):
                // When a QR code is scanned, show the add contact sheet
                state.addContact.qrCode = code
                state.addContact.isSheetPresented = true
                return .none

            case .qrScanner:
                return .none

            case .addContact(.contactAdded):
                // When a contact is added, close the sheet
                state.addContact.isSheetPresented = false
                return .none

            case .addContact:
                return .none

            case .delegate:
                return .none
            }
        }
    }

    /// Get sorted dependents from the contacts feature
    /// - Returns: A sorted list of dependents
    func sortedDependents(_ state: State) -> [ContactData] {
        return ContactsFeature().sortedDependents(state.contacts.dependents)
    }
}
