import Foundation
import ComposableArchitecture

/// Feature for managing user contacts
@Reducer
struct ContactsFeature {
    /// The state of the contacts feature
    struct State: Equatable {
        /// List of all contacts (both responders and dependents)
        var contacts: IdentifiedArrayOf<ContactReference> = []

        /// Loading state
        var isLoading: Bool = false

        /// Error state
        var error: Error? = nil

        /// Count of non-responsive dependents
        var nonResponsiveDependentsCount: Int = 0

        /// Count of pending pings
        var pendingPingsCount: Int = 0

        /// Computed property for responders
        var responders: [ContactReference] {
            contacts.filter { $0.isResponder }
        }

        /// Computed property for dependents
        var dependents: [ContactReference] {
            contacts.filter { $0.isDependent }
        }
    }

    /// Actions that can be performed on the contacts feature
    enum Action: Equatable {
        /// Load contacts from Firestore
        case loadContacts
        case loadContactsResponse(TaskResult<[ContactReference]>)

        /// Add a contact
        case addContact(ContactReference)
        case addContactResponse(TaskResult<Bool>)

        /// Update a contact's roles
        case updateContactRoles(id: String, isResponder: Bool, isDependent: Bool)
        case updateContactRolesResponse(TaskResult<Bool>)

        /// Delete a contact
        case deleteContact(id: String)
        case deleteContactResponse(TaskResult<Bool>)

        /// Ping a dependent
        case pingDependent(id: String)
        case pingDependentResponse(TaskResult<Bool>)

        /// Clear a ping for a dependent
        case clearPing(id: String)
        case clearPingResponse(TaskResult<Bool>)

        /// Respond to a ping
        case respondToPing(id: String)
        case respondToPingResponse(TaskResult<Bool>)

        /// Respond to all pings
        case respondToAllPings
        case respondToAllPingsResponse(TaskResult<Bool>)

        /// Look up a user by QR code
        case lookupUserByQRCode(String)
        case lookupUserByQRCodeResponse(TaskResult<ContactReference?>)
    }

    /// Dependencies for the contacts feature
    @Dependency(\.contactsClient) var contactsClient

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadContacts:
                state.isLoading = true
                return .run { send in
                    let result = await TaskResult {
                        try await contactsClient.loadContacts()
                    }
                    await send(.loadContactsResponse(result))
                }

            case let .loadContactsResponse(result):
                state.isLoading = false
                switch result {
                case let .success(contacts):
                    state.contacts = IdentifiedArray(uniqueElements: contacts)
                    state.nonResponsiveDependentsCount = contacts.filter { $0.isDependent && $0.checkInExpired }.count
                    state.pendingPingsCount = contacts.filter { $0.hasIncomingPing }.count
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }

            case let .addContact(contact):
                state.isLoading = true
                return .run { send in
                    let result = await TaskResult {
                        try await contactsClient.addContact(contact)
                    }
                    await send(.addContactResponse(result))
                }

            case let .addContactResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Reload contacts to get the updated list
                    return .send(.loadContacts)
                case let .failure(error):
                    state.error = error
                    return .none
                }

            case let .updateContactRoles(id, isResponder, isDependent):
                state.isLoading = true

                // Update local state immediately for better UX
                if let index = state.contacts.index(id: id) {
                    state.contacts[index].isResponder = isResponder
                    state.contacts[index].isDependent = isDependent
                }

                return .run { send in
                    let result = await TaskResult {
                        try await contactsClient.updateContactRoles(id: id, isResponder: isResponder, isDependent: isDependent)
                    }
                    await send(.updateContactRolesResponse(result))
                }

            case let .updateContactRolesResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Roles were already updated in state when action was dispatched
                    return .none
                case let .failure(error):
                    state.error = error
                    // Reload contacts to revert changes if there was an error
                    return .send(.loadContacts)
                }

            case let .deleteContact(id):
                state.isLoading = true

                // Remove from local state immediately for better UX
                state.contacts.remove(id: id)

                return .run { send in
                    let result = await TaskResult {
                        try await contactsClient.deleteContact(id: id)
                    }
                    await send(.deleteContactResponse(result))
                }

            case let .deleteContactResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Contact was already removed from state when action was dispatched
                    return .none
                case let .failure(error):
                    state.error = error
                    // Reload contacts to revert changes if there was an error
                    return .send(.loadContacts)
                }

            case let .pingDependent(id):
                state.isLoading = true

                // Update local state immediately for better UX
                if let index = state.contacts.index(id: id) {
                    state.contacts[index].hasOutgoingPing = true
                }

                return .run { send in
                    let result = await TaskResult {
                        try await contactsClient.pingDependent(id: id)
                    }
                    await send(.pingDependentResponse(result))
                }

            case let .pingDependentResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Ping was already updated in state when action was dispatched
                    return .none
                case let .failure(error):
                    state.error = error
                    // Reload contacts to revert changes if there was an error
                    return .send(.loadContacts)
                }

            case let .clearPing(id):
                state.isLoading = true

                // Update local state immediately for better UX
                if let index = state.contacts.index(id: id) {
                    state.contacts[index].hasOutgoingPing = false
                }

                return .run { send in
                    let result = await TaskResult {
                        try await contactsClient.clearPing(id: id)
                    }
                    await send(.clearPingResponse(result))
                }

            case let .clearPingResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Ping was already cleared in state when action was dispatched
                    return .none
                case let .failure(error):
                    state.error = error
                    // Reload contacts to revert changes if there was an error
                    return .send(.loadContacts)
                }

            case let .respondToPing(id):
                state.isLoading = true

                // Update local state immediately for better UX
                if let index = state.contacts.index(id: id) {
                    state.contacts[index].hasIncomingPing = false
                    state.pendingPingsCount = max(0, state.pendingPingsCount - 1)
                }

                return .run { send in
                    let result = await TaskResult {
                        try await contactsClient.respondToPing(id: id)
                    }
                    await send(.respondToPingResponse(result))
                }

            case let .respondToPingResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Response was already updated in state when action was dispatched
                    return .none
                case let .failure(error):
                    state.error = error
                    // Reload contacts to revert changes if there was an error
                    return .send(.loadContacts)
                }

            case .respondToAllPings:
                state.isLoading = true

                // Update local state immediately for better UX
                for i in state.contacts.indices where state.contacts[i].hasIncomingPing {
                    state.contacts[i].hasIncomingPing = false
                }
                state.pendingPingsCount = 0

                return .run { send in
                    let result = await TaskResult {
                        try await contactsClient.respondToAllPings()
                    }
                    await send(.respondToAllPingsResponse(result))
                }

            case let .respondToAllPingsResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Responses were already updated in state when action was dispatched
                    return .none
                case let .failure(error):
                    state.error = error
                    // Reload contacts to revert changes if there was an error
                    return .send(.loadContacts)
                }

            case let .lookupUserByQRCode(code):
                state.isLoading = true
                return .run { send in
                    let result = await TaskResult {
                        try await contactsClient.lookupUserByQRCode(code)
                    }
                    await send(.lookupUserByQRCodeResponse(result))
                }

            case let .lookupUserByQRCodeResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Handle in the view
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }
            }
        }
    }
}
