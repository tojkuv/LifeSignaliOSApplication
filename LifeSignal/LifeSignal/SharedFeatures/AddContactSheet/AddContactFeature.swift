import SwiftUI
import ComposableArchitecture

/// Feature for adding a contact
@Reducer
struct AddContactFeature {
    /// The state of the add contact feature
    struct State: Equatable {
        /// The contact ID
        var contactId: String = ""

        /// Flag indicating if the contact is a responder
        var isResponder: Bool = false

        /// Flag indicating if the contact is a dependent
        var isDependent: Bool = false

        /// Flag indicating if the sheet is showing
        var isShowing: Bool = false

        /// Flag indicating if the contact is being added
        var isAddingContact: Bool = false

        /// Error state
        var error: Error? = nil

        /// Custom Equatable implementation to handle Error? property
        static func == (lhs: State, rhs: State) -> Bool {
            lhs.contactId == rhs.contactId &&
            lhs.isResponder == rhs.isResponder &&
            lhs.isDependent == rhs.isDependent &&
            lhs.isShowing == rhs.isShowing &&
            lhs.isAddingContact == rhs.isAddingContact &&
            (lhs.error != nil) == (rhs.error != nil)
        }
    }

    /// Actions that can be performed on the add contact feature
    enum Action: Equatable {
        /// Update the contact ID
        case updateContactId(String)

        /// Update the responder flag
        case updateIsResponder(Bool)

        /// Update the dependent flag
        case updateIsDependent(Bool)

        /// Add the contact
        case addContact
        case addContactResponse(TaskResult<Bool>)

        /// Show or hide the sheet
        case setShowing(Bool)

        /// Dismiss the sheet
        case dismiss
    }

    /// Dependencies
    @Dependency(\.contactsClient) var contactsClient

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .updateContactId(contactId):
                state.contactId = contactId
                return .none

            case let .updateIsResponder(isResponder):
                state.isResponder = isResponder
                return .none

            case let .updateIsDependent(isDependent):
                state.isDependent = isDependent
                return .none

            case .addContact:
                state.isAddingContact = true
                state.error = nil

                return .run { [contactId = state.contactId, isResponder = state.isResponder, isDependent = state.isDependent] send in
                    let result = await TaskResult {
                        // Create a Contact object from the ID and role flags
                        let contact = Contact(
                            id: contactId,
                            name: "Unknown User", // This will be updated from Firestore
                            isResponder: isResponder,
                            isDependent: isDependent
                        )
                        return try await contactsClient.addContact(contact)
                    }
                    await send(.addContactResponse(result))
                }

            case let .addContactResponse(result):
                state.isAddingContact = false

                switch result {
                case .success:
                    state.isShowing = false
                    return .none

                case let .failure(error):
                    state.error = error
                    return .none
                }

            case let .setShowing(isShowing):
                state.isShowing = isShowing

                if !isShowing {
                    // Reset state when hiding
                    state.contactId = ""
                    state.isResponder = false
                    state.isDependent = false
                    state.error = nil
                }

                return .none

            case .dismiss:
                state.isShowing = false
                return .none
            }
        }
    }
}
