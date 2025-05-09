import SwiftUI

struct AddContactSheet: View {
    @State var contact: ContactReference
    var onAdd: ((ContactReference) -> Void)? = nil
    var onClose: (() -> Void)? = nil
    @State private var showRoleAlert: Bool = false
    @FocusState private var focusedField: Field?

    enum Field { case name, phone, note }

    init(contact: ContactReference, onAdd: ((ContactReference) -> Void)? = nil, onClose: (() -> Void)? = nil) {
        self._contact = State(initialValue: contact)
        self.onAdd = onAdd
        self.onClose = onClose
    }

    var body: some View {
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
                                    Text(String(contact.name.isEmpty ? "?" : contact.name.prefix(1)))
                                        .foregroundColor(.blue)
                                        .font(.title)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.blue, lineWidth: 2)
                                )
                                .padding(.top, 24)
                            TextField("Name", text: $contact.name)
                                .font(.headline)
                                .bold()
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .focused($focusedField, equals: .name)
                                .textContentType(.name)
                                .submitLabel(.next)
                            TextField("Phone", text: $contact.phone)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .keyboardType(.phonePad)
                                .multilineTextAlignment(.center)
                                .focused($focusedField, equals: .phone)
                                .textContentType(.telephoneNumber)
                                .submitLabel(.next)
                        }
                        .frame(maxWidth: .infinity)

                        // Note Card (not editable)
                        VStack(spacing: 0) {
                            HStack {
                                Text(contact.note.isEmpty ? "No emergency information provided yet." : contact.note)
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
                                    Toggle("", isOn: $contact.isDependent)
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
                                    Toggle("", isOn: $contact.isResponder)
                                        .labelsHidden()
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal)
                            }
                            .background(Color(UIColor.systemGray5))
                            .cornerRadius(12)
                            .padding(.horizontal)

                            if !contact.isDependent && !contact.isResponder {
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
                        onAdd?(contact)
                        onClose?()
                    }) {
                        Text("Add")
                            .font(.headline)
                    }
                    .disabled(!contact.isDependent && !contact.isResponder)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { onClose?() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }
}

#Preview {
    let contact = ContactReference.createDefault(
        name: "Cameron Lee",
        phone: "555-123-4567",
        note: "I live alone and work from home. If I don't respond, please check my apartment first (spare key under blue flowerpot). Medical info: allergic to penicillin, blood type O+. My emergency contact is my brother David (555-888-9999). I have a cat named Whiskers who needs feeding twice daily.",
        isResponder: false,
        isDependent: false
    )
    return AddContactSheet(contact: contact)
}