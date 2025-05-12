import Foundation
import ComposableArchitecture

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
        var error: Error? = nil

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
    enum Action: Equatable, Sendable {
        // MARK: - Lifecycle Actions
        case onAppear

        // MARK: - Parent Feature Actions
        case contacts(ContactsFeature.Action)

        // MARK: - UI Actions
        case setShowQRScanner(Bool)
        case selectContact(ContactData?)
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

            case .qrScanner(.qrCodeScanned):
                // When a QR code is scanned, show the add contact sheet
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
