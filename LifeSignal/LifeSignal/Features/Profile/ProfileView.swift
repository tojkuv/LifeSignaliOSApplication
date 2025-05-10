import SwiftUI
import ComposableArchitecture
import LifeSignal.Features.Profile

/// A SwiftUI view for displaying the user profile using TCA
struct ProfileView: View {
    /// The store for the profile feature
    let store: StoreOf<ProfileFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            ScrollView {
                VStack(spacing: 20) {
                    // Profile header
                    VStack(spacing: 16) {
                        AvatarView(name: viewStore.name, size: 100)

                        Text(viewStore.name)
                            .font(.title)
                            .fontWeight(.bold)

                        if !viewStore.note.isEmpty {
                            Text(viewStore.note)
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
                            value: viewStore.name,
                            icon: "person.fill",
                            showDivider: true
                        )

                        SettingRow(
                            title: "Phone",
                            value: viewStore.phoneNumber,
                            icon: "phone.fill",
                            showDivider: true
                        )

                        SettingRow(
                            title: "Profile Note",
                            value: viewStore.note.isEmpty ? "None" : viewStore.note,
                            icon: "text.bubble.fill",
                            showDivider: false
                        )
                    }
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)

                    // Edit profile button
                    Button(action: {
                        viewStore.send(.setEditMode(true))
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

                    // Settings section
                    VStack(spacing: 12) {
                        ToggleSettingRow(
                            icon: "bell.fill",
                            title: "Notifications",
                            isOn: viewStore.notificationEnabled,
                            action: { enabled in
                                viewStore.send(.updateNotificationSettings(enabled: enabled))
                            }
                        )

                        Button(action: {
                            viewStore.send(.showSettings)
                        }) {
                            HStack {
                                Image(systemName: "gear")
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(.blue)

                                Text("Settings")
                                    .font(.body)
                                    .foregroundColor(.primary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                        }
                        .background(Color(UIColor.systemGray5))
                        .cornerRadius(12)

                        Button(action: {
                            viewStore.send(.showQRCode)
                        }) {
                            HStack {
                                Image(systemName: "qrcode")
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(.blue)

                                Text("My QR Code")
                                    .font(.body)
                                    .foregroundColor(.primary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                        }
                        .background(Color(UIColor.systemGray5))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    // Sign out button
                    Button(action: {
                        viewStore.send(.signOut)
                    }) {
                        Text("Sign Out")
                            .font(.headline)
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(UIColor.systemGray5))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Profile")
            .onAppear {
                viewStore.send(.loadProfile)
            }
            .sheet(isPresented: viewStore.binding(
                get: \.isEditing,
                send: ProfileFeature.Action.setEditMode
            )) {
                EditProfileView(store: store)
            }
        }
    }
}

/// A setting row for TCA views
struct SettingRow: View {
    let title: String
    let value: String
    let icon: String
    let showDivider: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 30, height: 30)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(value)
                        .font(.body)
                        .foregroundColor(.primary)
                }

                Spacer()
            }
            .padding()

            if showDivider {
                Divider()
                    .padding(.leading, 60)
            }
        }
    }
}

/// A toggle setting row for TCA views
struct ToggleSettingRow: View {
    let icon: String
    let title: String
    let isOn: Bool
    let action: (Bool) -> Void

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 30, height: 30)
                .foregroundColor(.blue)

            Text(title)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()

            Toggle(isOn: .constant(isOn)) {
                EmptyView()
            }
            .onChange(of: isOn) { oldValue, newValue in
                action(newValue)
            }
            .labelsHidden()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemGray5))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        ProfileView(
            store: Store(initialState: ProfileFeature.State()) {
                ProfileFeature()
            }
        )
    }
}
