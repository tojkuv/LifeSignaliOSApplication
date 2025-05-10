import SwiftUI
import ComposableArchitecture

/// A SwiftUI view for editing the user profile using TCA
struct EditProfileView: View {
    /// The store for the profile feature
    let store: StoreOf<ProfileFeature>
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                Form {
                    Section(header: Text("Personal Information")) {
                        TextField("Name", text: viewStore.binding(
                            get: \.editingName,
                            send: ProfileFeature.Action.updateEditingName
                        ))
                        
                        TextField("Phone Number", text: viewStore.binding(
                            get: \.phoneNumber,
                            send: { _ in }
                        ))
                        .disabled(true)
                        .foregroundColor(.gray)
                    }
                    
                    Section(header: Text("Profile Description")) {
                        TextEditor(text: viewStore.binding(
                            get: \.editingNote,
                            send: ProfileFeature.Action.updateEditingNote
                        ))
                        .frame(minHeight: 100)
                    }
                    
                    Section {
                        Button("Save Changes") {
                            viewStore.send(.saveEdit)
                        }
                        .disabled(viewStore.editingName.isEmpty)
                    }
                }
                .navigationTitle("Edit Profile")
                .navigationBarItems(trailing: Button("Cancel") {
                    viewStore.send(.cancelEdit)
                })
            }
        }
    }
}

#Preview {
    EditProfileView(
        store: Store(initialState: ProfileFeature.State()) {
            ProfileFeature()
        }
    )
}
