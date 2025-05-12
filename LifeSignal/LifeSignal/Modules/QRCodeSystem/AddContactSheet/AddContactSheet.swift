import SwiftUI
import ComposableArchitecture

/// A SwiftUI view for adding a new contact using TCA
struct AddContactSheet: View {
    /// The store for the add contact feature
    @Bindable var store: StoreOf<AddContactFeature>

    var body: some View {
        NavigationStack {
            Form {
                // Contact info section
                Section(header: Text("Contact Information")) {
                    if store.isLoading {
                        HStack {
                            Spacer()
                            ProgressView("Looking up contact...")
                            Spacer()
                        }
                        .padding()
                    } else if !store.name.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(store.name)
                                .font(.body)
                        }
                        .padding(.vertical, 4)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Phone")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(store.phone)
                                .font(.body)
                        }
                        .padding(.vertical, 4)

                        if !store.emergencyNote.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Emergency Note")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(store.emergencyNote)
                                    .font(.body)
                            }
                            .padding(.vertical, 4)
                        }
                    } else {
                        Text("No contact found for this QR code")
                            .foregroundColor(.secondary)
                    }
                }

                // Roles section
                if !store.name.isEmpty {
                    Section(header: Text("Roles")) {
                        Toggle("Responder", isOn: $store.isResponder.sending(\.updateIsResponder))
                            .toggleStyle(SwitchToggleStyle(tint: .blue))

                        Toggle("Dependent", isOn: $store.isDependent.sending(\.updateIsDependent))
                            .toggleStyle(SwitchToggleStyle(tint: .blue))

                        if !store.isDependent && !store.isResponder {
                            Text("You must select at least one role.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    // Add button
                    Section {
                        Button(action: {
                            store.send(.addContact)
                        }) {
                            HStack {
                                Spacer()
                                Text("Add Contact")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.isLoading || (!store.isResponder && !store.isDependent))
                    }
                }
            }
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        store.send(.dismiss)
                        store.send(.setSheetPresented(false))
                    }
                }
            }
            .alert(
                title: { _ in Text("Error") },
                unwrapping: Binding(
                    get: { store.error },
                    set: { error in store.send(.setError(error)) }
                ),
                actions: { _ in
                    Button("OK", role: .cancel) { }
                },
                message: { error in
                    Text(error.localizedDescription)
                }
            )
            .disabled(store.isLoading)
        }
    }
}
