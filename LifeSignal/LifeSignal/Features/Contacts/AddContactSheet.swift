import SwiftUI
import ComposableArchitecture
import LifeSignal.Features.Contacts

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

        /// Flag indicating if the role alert is showing
        var showRoleAlert: Bool = false

        /// Loading state
        var isLoading: Bool = false

        /// Error state
        var error: Error? = nil

        /// Currently focused field
        var focusedField: Field? = nil
    }

    /// Field enum for focus state
    enum Field: Equatable {
        case name
        case phone
        case note
    }

    /// Actions that can be performed on the add contact feature
    enum Action: Equatable {
        /// Update the contact name
        case updateName(String)

        /// Update the contact phone
        case updatePhone(String)

        /// Update the contact note
        case updateNote(String)

        /// Update the responder status
        case updateResponder(Bool)

        /// Update the dependent status
        case updateDependent(Bool)

        /// Set the focused field
        case setFocusedField(Field?)

        /// Set the role alert
        case setRoleAlert(Bool)

        /// Add the contact
        case addContact

        /// Cancel adding the contact
        case cancel
    }

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .updateName(name):
                state.contact.name = name
                return .none

            case let .updatePhone(phone):
                state.contact.phoneNumber = phone
                return .none

            case let .updateNote(note):
                state.contact.note = note
                return .none

            case let .updateResponder(isResponder):
                state.isResponder = isResponder
                return .none

            case let .updateDependent(isDependent):
                state.isDependent = isDependent
                return .none

            case let .setFocusedField(field):
                state.focusedField = field
                return .none

            case let .setRoleAlert(show):
                state.showRoleAlert = show
                return .none

            case .addContact:
                // Check if at least one role is selected
                if !state.isResponder && !state.isDependent {
                    state.showRoleAlert = true
                    return .none
                }

                // Update the contact with the selected roles
                state.contact.isResponder = state.isResponder
                state.contact.isDependent = state.isDependent

                return .none

            case .cancel:
                return .none
            }
        }
    }
}

/// A SwiftUI view for adding a contact using TCA
struct AddContactSheet: View {
    /// The store for the add contact feature
    let store: StoreOf<AddContactFeature>

    /// Callback for when a contact is added
    let onAdd: (Bool, Bool) -> Void

    /// Callback for when adding a contact is canceled
    let onClose: () -> Void

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                Form {
                    Section(header: Text("Contact Information")) {
                        TextField("Name", text: viewStore.binding(
                            get: \.contact.name,
                            send: AddContactFeature.Action.updateName
                        ))
                        .focused(viewStore.binding(
                            get: { $0.focusedField == .name },
                            send: { focused in
                                .setFocusedField(focused ? .name : nil)
                            }
                        ))

                        TextField("Phone", text: viewStore.binding(
                            get: \.contact.phoneNumber,
                            send: AddContactFeature.Action.updatePhone
                        ))
                        .keyboardType(.phonePad)
                        .focused(viewStore.binding(
                            get: { $0.focusedField == .phone },
                            send: { focused in
                                .setFocusedField(focused ? .phone : nil)
                            }
                        ))

                        TextField("Note (Optional)", text: viewStore.binding(
                            get: \.contact.note,
                            send: AddContactFeature.Action.updateNote
                        ))
                        .focused(viewStore.binding(
                            get: { $0.focusedField == .note },
                            send: { focused in
                                .setFocusedField(focused ? .note : nil)
                            }
                        ))
                    }

                    Section(header: Text("Relationship")) {
                        Toggle("This person can respond to my alerts", isOn: viewStore.binding(
                            get: \.isResponder,
                            send: AddContactFeature.Action.updateResponder
                        ))

                        Toggle("I can check on this person", isOn: viewStore.binding(
                            get: \.isDependent,
                            send: AddContactFeature.Action.updateDependent
                        ))
                    }

                    Section {
                        Button("Add Contact") {
                            viewStore.send(.addContact)

                            // Check if at least one role is selected
                            if viewStore.isResponder || viewStore.isDependent {
                                onAdd(viewStore.isResponder, viewStore.isDependent)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .navigationTitle("Add Contact")
                .navigationBarItems(trailing: Button("Cancel") {
                    viewStore.send(.cancel)
                    onClose()
                })
                .alert("Select at least one role", isPresented: viewStore.binding(
                    get: \.showRoleAlert,
                    send: AddContactFeature.Action.setRoleAlert
                )) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Please select at least one role for this contact.")
                }
            }
        }
    }
}

/// A SwiftUI view for adding a contact using TCA (convenience initializer)
extension AddContactSheet {
    /// Initialize with a contact
    /// - Parameters:
    ///   - contact: The contact to add
    ///   - onAdd: Callback for when the contact is added
    ///   - onClose: Callback for when adding is canceled
    init(contact: ContactReference, onAdd: @escaping (Bool, Bool) -> Void, onClose: @escaping () -> Void) {
        self.store = Store(initialState: AddContactFeature.State(
            contact: contact,
            isResponder: contact.isResponder,
            isDependent: contact.isDependent
        )) {
            AddContactFeature()
        }
        self.onAdd = onAdd
        self.onClose = onClose
    }
}

#Preview {
    AddContactSheet(
        contact: ContactReference.createDefault(
            name: "John Doe",
            phone: "+1 (555) 123-4567",
            note: "Emergency contact",
            isResponder: true,
            isDependent: false
        ),
        onAdd: { _, _ in },
        onClose: { }
    )
}
