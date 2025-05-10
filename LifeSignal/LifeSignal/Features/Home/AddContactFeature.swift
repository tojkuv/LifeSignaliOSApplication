import Foundation
import ComposableArchitecture

/// Feature for adding a contact
@Reducer
struct AddContactFeature {
    /// The state of the add contact feature
    struct State: Equatable {
        /// The contact to add
        var contact: ContactReference
        
        /// Flag indicating if the contact should be a responder
        var isResponder: Bool = true
        
        /// Flag indicating if the contact should be a dependent
        var isDependent: Bool = false
        
        /// Loading state
        var isLoading: Bool = false
        
        /// Error state
        var error: Error? = nil
    }
    
    /// Actions that can be performed on the add contact feature
    enum Action: Equatable {
        /// Update responder status
        case updateResponder(Bool)
        
        /// Update dependent status
        case updateDependent(Bool)
        
        /// Add the contact
        case addContact
        case addContactResponse(TaskResult<Bool>)
        
        /// Cancel adding the contact
        case cancel
    }
    
    /// Dependencies
    @Dependency(\.contactsClient) var contactsClient
    
    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .updateResponder(isResponder):
                state.isResponder = isResponder
                return .none
                
            case let .updateDependent(isDependent):
                state.isDependent = isDependent
                return .none
                
            case .addContact:
                state.isLoading = true
                return .run { [contact = state.contact, isResponder = state.isResponder, isDependent = state.isDependent] send in
                    let result = await TaskResult {
                        try await contactsClient.addContact(contact)
                    }
                    await send(.addContactResponse(result))
                }
                
            case let .addContactResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }
                
            case .cancel:
                return .none
            }
        }
    }
}
