import SwiftUI
import ComposableArchitecture

/// A SwiftUI view for displaying contact details using TCA
struct ContactDetailsSheet: View {
    /// The contact to display
    let contact: Contact

    /// The store for the contacts feature
    let store: StoreOf<ContactsFeature>

    /// Binding to control the presentation of the sheet
    @Binding var isPresented: Bool

    /// State for the contact roles
    @State private var isResponder: Bool
    @State private var isDependent: Bool
    @State private var showDeleteConfirmation = false

    /// Initialize the view
    /// - Parameters:
    ///   - contact: The contact to display
    ///   - store: The store for the contacts feature
    ///   - isPresented: Binding to control the presentation of the sheet
    init(contact: Contact, store: StoreOf<ContactsFeature>, isPresented: Binding<Bool>) {
        self.contact = contact
        self.store = store
        self._isPresented = isPresented
        self._isResponder = State(initialValue: contact.isResponder)
        self._isDependent = State(initialValue: contact.isDependent)
    }

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                Form {
                    Section(header: Text("Contact Information")) {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(contact.name)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Phone")
                            Spacer()
                            Text(contact.phone)
                                .foregroundColor(.secondary)
                        }

                        if !contact.note.isEmpty {
                            HStack {
                                Text("Note")
                                Spacer()
                                Text(contact.note)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }

                    Section(header: Text("Relationship")) {
                        Toggle("This person can respond to my alerts", isOn: $isResponder)
                            .onChange(of: isResponder) { oldValue, newValue in
                                viewStore.send(.updateContactRoles(id: contact.id, isResponder: newValue, isDependent: isDependent))
                            }

                        Toggle("I can check on this person", isOn: $isDependent)
                            .onChange(of: isDependent) { oldValue, newValue in
                                viewStore.send(.updateContactRoles(id: contact.id, isResponder: isResponder, isDependent: newValue))
                            }
                    }

                    Section {
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            HStack {
                                Spacer()
                                Text("Remove Contact")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    }

                    if viewStore.isLoading {
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
                .navigationTitle("Contact Details")
                .navigationBarItems(trailing: Button("Done") {
                    isPresented = false
                })
                .alert("Remove Contact", isPresented: $showDeleteConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Remove", role: .destructive) {
                        viewStore.send(.deleteContact(id: contact.id))
                        isPresented = false
                    }
                } message: {
                    Text("Are you sure you want to remove \(contact.name) from your contacts?")
                }
            }
        }
    }
}

#Preview {
    ContactDetailsSheet(
        contact: Contact.createDefault(
            name: "John Doe",
            isResponder: true,
            isDependent: false
        ),
        store: Store(initialState: ContactsFeature.State()) {
            ContactsFeature()
        },
        isPresented: .constant(true)
    )
}
