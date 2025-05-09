import SwiftUI
import Foundation
import FirebaseCore
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject private var userProfileViewModel: UserProfileViewModel
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var appState: AppState
    @State private var showEditPhoneSheet = false
    @State private var newPhone = ""
    @State private var showSignOutConfirmation = false
    @State private var showCheckInConfirmation = false
    @State private var showEditDescriptionSheet = false
    @State private var newDescription = ""
    @State private var showEditNameSheet = false
    @State private var newName = ""
    @State private var showEditAvatarSheet = false

    var body: some View {
        ScrollView {
            VStack {
                // Profile Header
                VStack(spacing: 16) {
                    Circle()
                        .fill(Color(UIColor.systemBackground))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text(String(userProfileViewModel.name.prefix(1)))
                                .foregroundColor(.blue)
                                .font(.title)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.blue, lineWidth: 2)
                        )
                    Text(userProfileViewModel.name)
                        .font(.headline)
                    Text(userProfileViewModel.phone.isEmpty ? "(954) 234-5678" : userProfileViewModel.phone)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                // Description Setting Card
                Button(action: {
                    newDescription = userProfileViewModel.profileDescription
                    showEditDescriptionSheet = true
                }) {
                    HStack(alignment: .top) {
                        Text(userProfileViewModel.profileDescription.isEmpty ? "This is simply a note for contacts." : userProfileViewModel.profileDescription)
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
                        newName = userProfileViewModel.name
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
                NavigationLink(destination: FirebaseTestView()) {
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
        .sheet(isPresented: $showEditPhoneSheet) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Phone Number", text: $newPhone)
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
                        userProfileViewModel.phone = newPhone
                        showEditPhoneSheet = false
                    }
                    .disabled(newPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newPhone == userProfileViewModel.phone)
                )
            }
            .presentationDetents([.medium])
        }
        .alert(isPresented: $showCheckInConfirmation) {
            Alert(
                title: Text("Confirm Check-in"),
                message: Text("Are you sure you want to check in now? This will reset your timer."),
                primaryButton: .default(Text("Check In")) {
                    userProfileViewModel.updateLastCheckedIn()
                },
                secondaryButton: .cancel()
            )
        }
        .alert(isPresented: $showSignOutConfirmation) {
            Alert(
                title: Text("Sign Out"),
                message: Text("Are you sure you want to sign out?"),
                primaryButton: .destructive(Text("Sign Out")) {
                    appState.signOut()
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showEditDescriptionSheet) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: $newDescription)
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
                        // Use the new updateEmergencyNote method to persist to Firestore
                        userProfileViewModel.updateEmergencyNote(newDescription) { success, error in
                            if let error = error {
                                print("Error updating emergency note: \(error.localizedDescription)")
                                // Could show an alert here if needed
                            }
                        }
                        showEditDescriptionSheet = false
                    }
                    .disabled(newDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newDescription == userProfileViewModel.profileDescription)
                )
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showEditNameSheet) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Name", text: $newName)
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
                        // Use the new updateName method to persist to Firestore
                        userProfileViewModel.updateName(newName) { success, error in
                            if let error = error {
                                print("Error updating name: \(error.localizedDescription)")
                                // Could show an alert here if needed
                            }
                        }
                        showEditNameSheet = false
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newName == userProfileViewModel.name)
                )
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showEditAvatarSheet) {
            VStack(spacing: 20) {
                Text("Avatar")
                    .font(.headline.bold())
                    .foregroundColor(.primary)
                VStack(spacing: 0) {
                    Button(action: { /* TODO: Take photo */ }) {
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
                    Button(action: { /* TODO: Upload photo */ }) {
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
                Button(action: { /* TODO: Delete photo */ }) {
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
    }
}