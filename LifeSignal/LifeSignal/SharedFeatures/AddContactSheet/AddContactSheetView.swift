import SwiftUI
import ComposableArchitecture

/// A SwiftUI view for adding a contact using TCA
struct AddContactSheet: View {
    /// The store for the contacts feature
    let store: StoreOf<ContactsFeature>

    /// Callback for when a contact is added
    let onAdd: (Bool, Bool) -> Void

    /// Callback for when adding a contact is canceled
    let onClose: () -> Void

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                ZStack {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header (avatar, name, phone) - centered, stacked
                            VStack(spacing: 12) {
                                Circle()
                                    .fill(Color(UIColor.systemBackground))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Text(String(viewStore.newContactName.isEmpty ? "?" : viewStore.newContactName.prefix(1)))
                                            .foregroundColor(.blue)
                                            .font(.title)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color.blue, lineWidth: 2)
                                    )
                                    .padding(.top, 24)

                                Text(viewStore.newContactName.isEmpty ? "Unknown User" : viewStore.newContactName)
                                    .font(.headline)
                                    .bold()
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)

                                Text(viewStore.newContactPhone.isEmpty ? "No phone number" : viewStore.newContactPhone)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)

                            // Note Card (not editable in this implementation)
                            VStack(spacing: 0) {
                                HStack {
                                    Text("No emergency information provided yet.")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal)
                            }
                            .background(Color(UIColor.systemGray5))
                            .cornerRadius(12)
                            .padding(.horizontal)

                            // Roles Card (with validation logic)
                            VStack(alignment: .leading, spacing: 4) {
                                VStack(spacing: 0) {
                                    HStack {
                                        Text("Dependent")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Toggle("", isOn: viewStore.binding(
                                            get: \.newContactIsDependent,
                                            send: ContactsFeature.Action.updateNewContactIsDependent
                                        ))
                                        .labelsHidden()
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal)

                                    Divider().padding(.leading)

                                    HStack {
                                        Text("Responder")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Toggle("", isOn: viewStore.binding(
                                            get: \.newContactIsResponder,
                                            send: ContactsFeature.Action.updateNewContactIsResponder
                                        ))
                                        .labelsHidden()
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal)
                                }
                                .background(Color(UIColor.systemGray5))
                                .cornerRadius(12)
                                .padding(.horizontal)

                                if !viewStore.newContactIsDependent && !viewStore.newContactIsResponder {
                                    Text("You must select at least one role.")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .padding(.horizontal)
                                        .padding(.leading, 4)
                                }
                            }
                        }
                    }
                }
                .background(Color(.systemBackground).ignoresSafeArea())
                .navigationTitle("New Contact")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            viewStore.send(.addNewContact)

                            // Check if at least one role is selected
                            if viewStore.newContactIsResponder || viewStore.newContactIsDependent {
                                onAdd(viewStore.newContactIsResponder, viewStore.newContactIsDependent)
                            }
                        }) {
                            Text("Add")
                                .font(.headline)
                        }
                        .disabled(!viewStore.newContactIsResponder && !viewStore.newContactIsDependent)
                    }

                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            viewStore.send(.dismissAddContactSheet)
                            onClose()
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.secondary)
                        }
                        .accessibilityLabel("Close")
                    }
                }
            }
        }
    }
}

/// A SwiftUI view for adding a contact using TCA (convenience initializers)
extension AddContactSheet {
    /// Initialize with a contact ID
    /// - Parameters:
    ///   - contactId: The ID of the contact to add
    ///   - store: The store for the contacts feature
    ///   - onAdd: Callback for when the contact is added
    ///   - onClose: Callback for when adding is canceled
    init(contactId: String, store: StoreOf<ContactsFeature>, onAdd: @escaping (Bool, Bool) -> Void, onClose: @escaping () -> Void) {
        self.init(qrCode: contactId, store: store, onAdd: onAdd, onClose: onClose)
    }

    /// Initialize with a QR code
    /// - Parameters:
    ///   - qrCode: The QR code to use for looking up the contact
    ///   - store: The store for the contacts feature
    ///   - onAdd: Callback for when the contact is added
    ///   - onClose: Callback for when adding is canceled
    init(qrCode: String, store: StoreOf<ContactsFeature>, onAdd: @escaping (Bool, Bool) -> Void, onClose: @escaping () -> Void) {
        self.store = store
        self.onAdd = onAdd
        self.onClose = onClose

        // Set the QR code as the contact ID
        // The Firebase function will look up the actual contact ID
        store.send(.updateNewContactId(qrCode))
    }
}

#Preview {
    AddContactSheet(
        contactId: "user123",
        store: Store(initialState: ContactsFeature.State(
            newContactId: "user123",
            newContactName: "John Doe",
            newContactPhone: "555-123-4567"
        )) {
            ContactsFeature()
        },
        onAdd: { _, _ in },
        onClose: { }
    )
}
