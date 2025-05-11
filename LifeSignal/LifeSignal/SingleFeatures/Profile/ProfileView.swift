import SwiftUI
import ComposableArchitecture

/// A SwiftUI view for displaying the user profile using TCA
struct ProfileView: View {
    /// The store for the user feature
    let store: StoreOf<UserFeature>

    /// State variables to manage UI state that was previously in ProfileFeature
    @State private var showEditNameSheet = false
    @State private var editingName = ""
    @State private var showEditDescriptionSheet = false
    @State private var editingDescription = ""
    @State private var showEditPhoneSheet = false
    @State private var editingPhone = ""
    @State private var showEditAvatarSheet = false
    @State private var showSignOutConfirmation = false
    @State private var showFirebaseTest = false

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            if viewStore.name.isEmpty && viewStore.isLoading {
                // Show loading view when user data is not available
                ProgressView("Loading profile...")
            } else {
                    ScrollView {
                        VStack {
                            // Profile Header
                            VStack(spacing: 16) {
                                Circle()
                                    .fill(Color(UIColor.systemBackground))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Text(String(viewStore.name.prefix(1)))
                                            .foregroundColor(.blue)
                                            .font(.title)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color.blue, lineWidth: 2)
                                    )
                                Text(viewStore.name)
                                    .font(.headline)
                                Text(viewStore.phoneNumber.isEmpty ? "(954) 234-5678" : viewStore.phoneNumber)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 20)

                            // Description Setting Card
                            Button(action: {
                                editingDescription = viewStore.note
                                showEditDescriptionSheet = true
                            }) {
                                HStack(alignment: .top) {
                                    Text(viewStore.note.isEmpty ? "This is simply a note for contacts." : viewStore.note)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal)
                                .background(Color(UIColor.systemGray5))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .padding(.bottom, 8)

                            // Grouped Update Cards
                            VStack(spacing: 0) {
                                Button(action: {
                                    showEditAvatarSheet = true
                                }) {
                                    HStack {
                                        Text("Update Avatar")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal)
                                }
                                Divider().padding(.leading)
                                Button(action: {
                                    editingName = viewStore.name
                                    showEditNameSheet = true
                                }) {
                                    HStack {
                                        Text("Update Name")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal)
                                }
                            }
                            .background(Color(UIColor.systemGray5))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .padding(.bottom, 8)

                            // Phone Number Card
                            Button(action: {
                                editingPhone = viewStore.phoneNumber
                                showEditPhoneSheet = true
                            }) {
                                HStack {
                                    Text("Change Phone Number")
                                        .font(.body)
                                        .foregroundColor(.green)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal)
                                .background(Color(UIColor.systemGray5))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)

                            // Firebase Test Card
                            Button(action: {
                                showFirebaseTest = true
                            }) {
                                HStack {
                                    Text("Firebase Test")
                                        .font(.body)
                                        .foregroundColor(.blue)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal)
                                .background(Color(UIColor.systemGray5))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)

                            // Sign Out Setting Card
                            Button(action: {
                                showSignOutConfirmation = true
                            }) {
                                Text("Sign Out")
                                    .font(.body)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal)
                                    .background(Color(UIColor.systemGray5))
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)

                            Spacer()
                        }
                        .padding(.bottom, 5)
                    }
                    .background(Color(.systemBackground))
                    .navigationTitle("Profile")

                    // Edit name sheet
                    .sheet(isPresented: $showEditNameSheet) {
                        NavigationStack {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    TextField("Name", text: $editingName)
                                    .font(.body)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal)
                                    .background(Color(UIColor.systemGray5))
                                    .cornerRadius(12)
                                    .foregroundColor(.primary)

                                    Text("People will see this name if you interact with them and they don't have you saved as a contact.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 4)
                                }
                                .padding(.horizontal)
                                .padding(.top, 24)
                                Spacer(minLength: 0)
                            }
                            .navigationBarTitleDisplayMode(.inline)
                            .navigationTitle("Name")
                            .navigationBarItems(
                                leading: Button("Cancel") {
                                    showEditNameSheet = false
                                },
                                trailing: Button("Save") {
                                    viewStore.send(.updateProfile(
                                        name: editingName,
                                        note: viewStore.note
                                    ))
                                    showEditNameSheet = false
                                }
                                .disabled(editingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || editingName == viewStore.name)
                            )
                        }
                        .presentationDetents([.medium])
                    }

                    // Edit description sheet
                    .sheet(isPresented: $showEditDescriptionSheet) {
                        NavigationStack {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    TextEditor(text: $editingDescription)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .frame(minHeight: 120)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal)
                                    .scrollContentBackground(.hidden)
                                    .background(Color(UIColor.systemGray5))
                                    .cornerRadius(12)

                                    Text("This note is visible to your contacts when they view your profile.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 4)
                                }
                                .padding(.horizontal)
                                Spacer(minLength: 0)
                            }
                            .navigationBarTitleDisplayMode(.inline)
                            .navigationTitle("Emergency Note")
                            .navigationBarItems(
                                leading: Button("Cancel") {
                                    showEditDescriptionSheet = false
                                },
                                trailing: Button("Save") {
                                    viewStore.send(.updateProfile(
                                        name: viewStore.name,
                                        note: editingDescription
                                    ))
                                    showEditDescriptionSheet = false
                                }
                                .disabled(editingDescription == viewStore.note)
                            )
                        }
                        .presentationDetents([.medium])
                    }

                    // Edit phone sheet
                    .sheet(isPresented: $showEditPhoneSheet) {
                        NavigationStack {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    TextField("Phone Number", text: $editingPhone)
                                    .keyboardType(.phonePad)
                                    .font(.body)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal)
                                    .background(Color(UIColor.systemGray5))
                                    .cornerRadius(12)
                                    .foregroundColor(.primary)

                                    Text("This is your phone number for account recovery and contact purposes.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 4)
                                }
                                .padding(.horizontal)
                                .padding(.top, 24)
                                Spacer(minLength: 0)
                            }
                            .navigationBarTitleDisplayMode(.inline)
                            .navigationTitle("Phone Number")
                            .navigationBarItems(
                                leading: Button("Cancel") {
                                    showEditPhoneSheet = false
                                },
                                trailing: Button("Save") {
                                    // Note: In a real app, we would update the phone number
                                    // This would require adding a new action to UserFeature
                                    showEditPhoneSheet = false
                                }
                                .disabled(editingPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || editingPhone == viewStore.phoneNumber)
                            )
                        }
                        .presentationDetents([.medium])
                    }

                    // Edit avatar sheet
                    .sheet(isPresented: $showEditAvatarSheet) {
                        VStack(spacing: 20) {
                            Text("Avatar")
                                .font(.headline.bold())
                                .foregroundColor(.primary)
                            VStack(spacing: 0) {
                                Button(action: {
                                    // In a real implementation, we would add photo taking functionality
                                    showEditAvatarSheet = false
                                }) {
                                    HStack {
                                        Text("Take photo")
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "camera")
                                            .foregroundColor(.primary)
                                    }
                                    .padding()
                                }
                                Divider().padding(.leading)
                                Button(action: {
                                    // In a real implementation, we would add photo choosing functionality
                                    showEditAvatarSheet = false
                                }) {
                                    HStack {
                                        Text("Choose photo")
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "photo")
                                            .foregroundColor(.primary)
                                    }
                                    .padding()
                                }
                            }
                            .background(Color(UIColor.systemGray5))
                            .cornerRadius(18)
                            .padding(.horizontal)
                            Button(action: {
                                // In a real implementation, we would add photo deletion functionality
                                showEditAvatarSheet = false
                            }) {
                                HStack {
                                    Text("Delete photo")
                                        .foregroundColor(.red)
                                    Spacer()
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .padding()
                                .background(Color(UIColor.systemGray5))
                                .cornerRadius(18)
                            }
                            .padding(.horizontal)
                            Spacer(minLength: 0)
                        }
                        .padding(.top, 24)
                        .background(Color(.systemBackground))
                        .presentationDetents([.medium])
                    }

                    // Sign out confirmation alert
                    .alert(isPresented: $showSignOutConfirmation) {
                        Alert(
                            title: Text("Sign Out"),
                            message: Text("Are you sure you want to sign out?"),
                            primaryButton: .destructive(Text("Sign Out")) {
                                viewStore.send(.signOut)
                            },
                            secondaryButton: .cancel()
                        )
                    }

                    // Firebase test navigation
                    .navigationDestination(isPresented: $showFirebaseTest) {
                        Text("Firebase Test View")
                            .navigationTitle("Firebase Test")
                    }
                }
            }
        }
    }
}



#Preview {
    NavigationStack {
        ProfileView(
            store: Store(initialState: UserFeature.State(
                name: "John Doe",
                phoneNumber: "+1 (555) 123-4567",
                note: "Emergency contact information",
                qrCodeId: "user123"
            )) {
                UserFeature()
            }
        )
    }
}
