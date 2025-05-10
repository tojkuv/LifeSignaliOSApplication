import SwiftUI
import ComposableArchitecture

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
                        TextField("Contact ID", text: viewStore.binding(
                            get: \.contactId,
                            send: AddContactFeature.Action.updateContactId
                        ))
                    }

                    Section(header: Text("Relationship")) {
                        Toggle("This person can respond to my alerts", isOn: viewStore.binding(
                            get: \.isResponder,
                            send: AddContactFeature.Action.updateIsResponder
                        ))

                        Toggle("I can check on this person", isOn: viewStore.binding(
                            get: \.isDependent,
                            send: AddContactFeature.Action.updateIsDependent
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
                        .disabled(viewStore.contactId.isEmpty || (!viewStore.isResponder && !viewStore.isDependent))
                    }
                }
                .navigationTitle("Add Contact")
                .navigationBarItems(trailing: Button("Cancel") {
                    viewStore.send(.dismiss)
                    onClose()
                })
            }
        }
    }
}

/// A SwiftUI view for adding a contact using TCA (convenience initializer)
extension AddContactSheet {
    /// Initialize with a contact ID
    /// - Parameters:
    ///   - contactId: The ID of the contact to add
    ///   - onAdd: Callback for when the contact is added
    ///   - onClose: Callback for when adding is canceled
    init(contactId: String, onAdd: @escaping (Bool, Bool) -> Void, onClose: @escaping () -> Void) {
        self.store = Store(initialState: AddContactFeature.State(
            contactId: contactId,
            isResponder: true,
            isDependent: false
        )) {
            AddContactFeature()
        }
        self.onAdd = onAdd
        self.onClose = onClose
    }
}

#Preview {
    AddContactSheet(
        contactId: "user123",
        onAdd: { _, _ in },
        onClose: { }
    )
}
