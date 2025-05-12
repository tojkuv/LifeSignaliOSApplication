import Foundation
import ComposableArchitecture

/// Feature for the responders screen
/// This feature is a child of ContactsFeature and focuses on responder-specific UI and operations
@Reducer
struct RespondersFeature {
    /// The state of the responders feature
    @ObservableState
    struct State: Equatable, Sendable {
        /// Parent contacts feature state
        var contacts: ContactsFeature.State = .init()

        /// UI State
        var isLoading: Bool = false
        var error: Error? = nil

        /// Child feature states
        var contactDetails: ContactDetailsSheetFeature.State = .init()
        var qrScanner: QRScannerFeature.State = .init()
        var addContact: AddContactFeature.State = .init()

        /// Alert states
        var alerts: Alerts = .init()

        /// Alert state container
        struct Alerts: Equatable, Sendable {
            var contactAdded: Bool = false
            var contactExists: Bool = false
            var contactError: Bool = false
            var contactErrorMessage: String = ""
        }

        /// Computed properties
        var pendingPingsCount: Int {
            contacts.responders.filter { $0.hasIncomingPing }.count
        }

        /// Initialize with default values
        init() {}
    }

    /// Actions that can be performed on the responders feature
    enum Action: Equatable, Sendable {
        // MARK: - Lifecycle Actions
        case onAppear

        // MARK: - Parent Feature Actions
        case contacts(ContactsFeature.Action)

        // MARK: - UI Actions
        case setContactAddedAlert(Bool)
        case setContactExistsAlert(Bool)
        case setContactErrorAlert(Bool)
        case setError(Error?)

        // MARK: - Child Feature Actions
        case contactDetails(ContactDetailsSheetFeature.Action)
        case qrScanner(QRScannerFeature.Action)
        case addContact(AddContactFeature.Action)

        // MARK: - Delegate Actions
        case delegate(DelegateAction)

        enum DelegateAction: Equatable, Sendable {
            case contactsUpdated
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

        Reduce { state, action in
            switch action {
            // MARK: - Lifecycle Actions

            case .onAppear:
                // Start by loading contacts and starting the stream
                return .concatenate(
                    .send(.contacts(.loadContacts)),
                    .send(.contacts(.startContactsStream))
                )

            // MARK: - Parent Feature Actions

            case .contacts(.delegate(.contactsUpdated)):
                // Contacts were updated, update loading state
                state.isLoading = state.contacts.isLoading
                return .none

            case .contacts(.delegate(.contactsLoadFailed(let error))):
                // Contacts loading failed, update error state
                state.error = error
                state.isLoading = false
                return .send(.setError(error))

            case .contacts:
                // Other contacts actions are handled by the parent feature
                return .none

            // MARK: - UI Actions

            case let .setError(error):
                state.error = error
                return .none

            case let .setContactAddedAlert(isPresented):
                state.alerts.contactAdded = isPresented
                return .none

            case let .setContactExistsAlert(isPresented):
                state.alerts.contactExists = isPresented
                return .none

            case let .setContactErrorAlert(isPresented):
                state.alerts.contactError = isPresented
                return .none

            // MARK: - Child Feature Actions

            case .contactDetails(.delegate(.removeContact(let id))):
                // When a contact is removed, delegate to parent feature
                return .send(.contacts(.deleteContact(id: id)))

            case .contactDetails(.delegate(.toggleContactRole(let id, let isResponder, let isDependent))):
                // When a contact's role is toggled, delegate to parent feature
                return .send(.contacts(.updateContactRoles(id: id, isResponder: isResponder, isDependent: isDependent)))

            case .contactDetails:
                return .none

            case .qrScanner(.qrCodeScanned):
                // When a QR code is scanned, show the add contact sheet
                state.addContact.isSheetPresented = true
                return .none

            case .qrScanner:
                return .none

            case .addContact(.contactAdded(let isResponder, _)):
                // When a contact is added, close the sheet and show confirmation
                state.addContact.isSheetPresented = false

                // Only show the "Contact Added" alert if the contact was added as a responder
                if isResponder {
                    state.alerts.contactAdded = true
                }

                return .none

            case .addContact:
                return .none

            case .delegate:
                return .none
            }
        }
    }

    /// Get sorted responders from the contacts feature
    /// - Returns: A sorted list of responders
    func sortedResponders(_ state: State) -> [ContactData] {
        return ContactsFeature().sortedResponders(state.contacts.responders)
    }
}
