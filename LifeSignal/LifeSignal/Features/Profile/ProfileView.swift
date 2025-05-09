import SwiftUI
import Foundation

struct ProfileView: View {
    @EnvironmentObject private var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject private var appState: AppState
    @State private var showEditProfile = false
    @State private var showSignOutConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile header
                VStack(spacing: 16) {
                    AvatarView(name: userProfileViewModel.name, size: 100)

                    Text(userProfileViewModel.name)
                        .font(.title)
                        .fontWeight(.bold)

                    if !userProfileViewModel.profileDescription.isEmpty {
                        Text(userProfileViewModel.profileDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.top, 20)

                // Profile details
                VStack(spacing: 0) {
                    SettingRow(
                        title: "Name",
                        value: userProfileViewModel.name,
                        icon: "person.fill",
                        showDivider: true
                    )

                    SettingRow(
                        title: "Phone",
                        value: userProfileViewModel.phoneNumber,
                        icon: "phone.fill",
                        showDivider: true
                    )

                    SettingRow(
                        title: "Profile Note",
                        value: userProfileViewModel.profileDescription.isEmpty ? "None" : userProfileViewModel.profileDescription,
                        icon: "text.bubble.fill",
                        showDivider: false
                    )
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)

                // Edit profile button
                Button(action: {
                    showEditProfile = true
                }) {
                    Text("Edit Profile")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.top, 10)

                // Notification settings
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notification Settings")
                        .font(.headline)
                        .padding(.horizontal)

                    Toggle("Enable Notifications", isOn: Binding(
                        get: { userProfileViewModel.notificationEnabled },
                        set: { newValue in
                            userProfileViewModel.updateNotificationSettings(enabled: newValue)
                        }
                    ))
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }

                // Sign out button
                Button(action: {
                    showSignOutConfirmation = true
                }) {
                    Text("Sign Out")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.top, 20)

                Spacer()
            }
            .padding(.bottom, 30)
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(
                name: userProfileViewModel.name,
                phoneNumber: userProfileViewModel.phoneNumber,
                phoneRegion: userProfileViewModel.phoneRegion,
                profileDescription: userProfileViewModel.profileDescription,
                onSave: { name, phoneNumber, phoneRegion, profileDescription in
                    userProfileViewModel.name = name
                    userProfileViewModel.phoneNumber = phoneNumber
                    userProfileViewModel.phoneRegion = phoneRegion
                    userProfileViewModel.profileDescription = profileDescription
                    userProfileViewModel.saveUserData()
                }
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
    }
}

struct EditProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var name: String
    @State private var phoneNumber: String
    @State private var phoneRegion: String
    @State private var profileDescription: String
    let onSave: (String, String, String, String) -> Void

    init(name: String, phoneNumber: String, phoneRegion: String, profileDescription: String, onSave: @escaping (String, String, String, String) -> Void) {
        self._name = State(initialValue: name)
        self._phoneNumber = State(initialValue: phoneNumber)
        self._phoneRegion = State(initialValue: phoneRegion)
        self._profileDescription = State(initialValue: profileDescription)
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Personal Information")) {
                    TextField("Name", text: $name)
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)

                    Picker("Region", selection: $phoneRegion) {
                        Text("US").tag("US")
                        Text("CA").tag("CA")
                        Text("UK").tag("UK")
                        // Add more regions as needed
                    }
                }

                Section(header: Text("Profile Description")) {
                    TextEditor(text: $profileDescription)
                        .frame(minHeight: 100)
                }

                Section {
                    Button("Save Changes") {
                        onSave(name, phoneNumber, phoneRegion, profileDescription)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(UserProfileViewModel())
        .environmentObject(AppState())
}
