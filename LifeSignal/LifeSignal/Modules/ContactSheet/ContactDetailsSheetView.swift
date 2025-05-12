import SwiftUI
import ComposableArchitecture

/// A SwiftUI view for displaying contact details using TCA
struct ContactDetailsSheet: View {
    /// The store for the contact details sheet feature
    @Bindable var store: StoreOf<ContactDetailsSheetFeature>

    /// Computed property to safely access the contact
    private var contact: ContactData? {
        store.contact
    }

    var body: some View {
        NavigationStack {
            Group {
                if let contact = contact {
                    Form {
                        Section(header: Text("Contact Information")) {
                            HStack {
                                Text("Name")
                                Spacer()
                                Text(contact.name)
                                    .foregroundColor(.secondary)
                            }

                            if let emergencyNote = contact.emergencyNote, !emergencyNote.isEmpty {
                                HStack {
                                    Text("Emergency Note")
                                    Spacer()
                                    Text(emergencyNote)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                        }

                        Section(header: Text("Relationship")) {
                            Toggle("This person can respond to my alerts", isOn: Binding(
                                get: { contact.isResponder },
                                set: {
                                    store.send(.delegate(.toggleContactRole(
                                        id: contact.id,
                                        isResponder: $0,
                                        isDependent: contact.isDependent
                                    )))
                                }
                            ))

                            Toggle("I can check on this person", isOn: Binding(
                                get: { contact.isDependent },
                                set: {
                                    store.send(.delegate(.toggleContactRole(
                                        id: contact.id,
                                        isResponder: contact.isResponder,
                                        isDependent: $0
                                    )))
                                }
                            ))
                        }

                        Section {
                            Button(action: {
                                store.send(.setShowRemoveContactConfirmation(true))
                            }) {
                                HStack {
                                    Spacer()
                                    Text("Remove Contact")
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                            }
                        }

                        if store.isLoading {
                            Section {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .padding(.vertical, 8)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .alert(
                        "Remove Contact",
                        isPresented: $store.alerts.showRemoveContactConfirmation.sending(\.setShowRemoveContactConfirmation)
                    ) {
                        Button("Cancel", role: .cancel) { }
                        Button("Remove", role: .destructive) {
                            store.send(.delegate(.removeContact(id: contact.id)))
                            store.send(.setActive(false))
                        }
                    } message: {
                        Text("Are you sure you want to remove \(contact.name) from your contacts?")
                    }
                } else {
                    // Fallback view when contact is nil
                    ContentUnavailableView(
                        "Contact Not Available",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text("The contact information could not be loaded.")
                    )
                }
            }
            .navigationTitle("Contact Details")
            .navigationBarItems(trailing: Button("Done") {
                store.send(.setActive(false))
            })
            .disabled(store.isLoading)
        }
    }
}

/// Extension for ContactDetailsSheet with convenience initializers
extension ContactDetailsSheet {
    /// Initialize with contact and store
    /// - Parameters:
    ///   - contact: The contact to display
    ///   - store: The store for the contact details sheet feature
    init(
        contact: ContactData,
        store: StoreOf<ContactDetailsSheetFeature>
    ) {
        // Set the contact in the store if it's not already set
        if store.contact == nil {
            store.send(.setContact(contact))
        }
        self._store = Bindable(wrappedValue: store)
    }

    /// Initialize with contact and parent store (for backward compatibility)
    /// - Parameters:
    ///   - contact: The contact to display
    ///   - store: The store for the contacts feature
    ///   - onDismiss: Callback for when the sheet should be dismissed
    init(
        contact: ContactData,
        store: StoreOf<ContactsFeature>,
        onDismiss: @escaping () -> Void
    ) {
        // Create a ContactDetailsSheetFeature store with the contact
        let detailsStore = Store(
            initialState: ContactDetailsSheetFeature.State(contact: contact)
        ) {
            ContactDetailsSheetFeature()
        }

        self._store = Bindable(wrappedValue: detailsStore)

        // Set up a task to handle the dismiss action
        Task {
            for await _ in detailsStore.scope(state: \.isActive, action: \.self).publisher.filter({ !$0 }) {
                onDismiss()
            }
        }
    }
}
