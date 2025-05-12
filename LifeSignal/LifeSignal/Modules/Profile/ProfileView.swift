import SwiftUI
import ComposableArchitecture
import UIKit

/// A SwiftUI view for displaying the user profile using TCA
struct ProfileView: View {
    /// The store for the user feature
    @Bindable var store: StoreOf<UserFeature>

    var body: some View {
        if store.profile == nil || (store.userData.name.isEmpty && store.isLoading) {
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
                                Text(String(store.userData.name.prefix(1)))
                                    .foregroundColor(.blue)
                                    .font(.title)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.blue, lineWidth: 2)
                            )
                        Text(store.userData.name)
                            .font(.headline)
                        Text(store.userData.phoneNumber.isEmpty ? "(954) 234-5678" : store.userData.phoneNumber)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)

                    // Emergency Note Setting Card
                    Button(action: {
                        store.send(.profile(.setShowEditDescriptionSheet(true)))
                    }) {
                        HStack(alignment: .top) {
                            Text(store.userData.emergencyNote.isEmpty ? "This is your emergency note for contacts." : store.userData.emergencyNote)
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
                            store.send(.profile(.setShowEditAvatarSheet(true)))
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
                            store.send(.profile(.setShowEditNameSheet(true)))
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
                        store.send(.profile(.setShowEditPhoneSheet(true)))
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

                    // QR Code Card
                    VStack(spacing: 16) {
                        Text("Your QR Code")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .center)

                        if !store.userData.qrCodeId.isEmpty {
                            QRCodeView(qrCodeId: store.userData.qrCodeId, size: 200, branded: true)
                                .padding(.bottom, 8)

                            Button(action: {
                                // Show QR code sharing sheet
                                store.send(.profile(.showQRCodeShareSheet))
                            }) {
                                Label("Share QR Code", systemImage: "square.and.arrow.up")
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 20)
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                        } else {
                            Text("QR Code not available")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal)
                    .background(Color(UIColor.systemGray5))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 16)

                    // Sign Out Setting Card
                    Button(action: {
                        store.send(.profile(.setShowSignOutConfirmation(true)))
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
            .sheet(isPresented: $store.profile!.showEditNameSheet.sending(\.profile.setShowEditNameSheet)) {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Name", text: $store.profile!.editingName.sending(\.profile.updateEditingName))
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
                            store.send(.profile(.setShowEditNameSheet(false)))
                        },
                        trailing: Button("Save") {
                            store.send(.profile(.updateProfile))
                            store.send(.profile(.setShowEditNameSheet(false)))
                        }
                        .disabled(store.profile!.editingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.profile!.editingName == store.userData.name)
                    )
                }
                .presentationDetents([.medium])
            }

            // Edit description sheet
            .sheet(isPresented: $store.profile!.showEditDescriptionSheet.sending(\.profile.setShowEditDescriptionSheet)) {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            TextEditor(text: $store.profile!.editingDescription.sending(\.profile.updateEditingDescription))
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
                            store.send(.profile(.setShowEditDescriptionSheet(false)))
                        },
                        trailing: Button("Save") {
                            store.send(.profile(.updateProfile))
                            store.send(.profile(.setShowEditDescriptionSheet(false)))
                        }
                        .disabled(store.profile!.editingDescription == store.userData.emergencyNote)
                    )
                }
                .presentationDetents([.medium])
            }

            // Edit phone sheet
            .sheet(isPresented: $store.profile!.showEditPhoneSheet.sending(\.profile.setShowEditPhoneSheet)) {
                NavigationStack {
                    ScrollView {
                        if !store.profile!.isChangingPhoneNumber {
                            // Initial phone number view
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Current Phone Number")
                                    .font(.headline)
                                    .padding(.horizontal, 4)

                                Text(store.userData.phoneNumber)
                                    .font(.body)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(UIColor.systemGray5))
                                    .cornerRadius(12)
                                    .foregroundColor(.primary)

                                Button(action: {
                                    store.send(.profile(.startPhoneNumberChange))
                                }) {
                                    Text("Change Phone Number")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .cornerRadius(10)
                                }
                                .padding(.top, 8)
                            }
                            .padding(.horizontal)
                            .padding(.top, 24)
                        } else if !store.profile!.isCodeSent {
                            // Phone number change view
                            VStack(alignment: .leading, spacing: 16) {
                                Text("New Phone Number")
                                    .font(.headline)
                                    .padding(.horizontal, 4)

                                // Region picker
                                Picker("Region", selection: $store.profile!.editingPhoneRegion.sending(\.profile.updateEditingPhoneRegion)) {
                                    Text("US (+1)").tag("US")
                                    Text("CA (+1)").tag("CA")
                                    Text("UK (+44)").tag("GB")
                                    Text("AU (+61)").tag("AU")
                                }
                                .pickerStyle(MenuPickerStyle())
                                .padding(.horizontal, 4)

                                TextField("Phone Number", text: $store.profile!.editingPhone.sending(\.profile.updateEditingPhone))
                                    .keyboardType(.phonePad)
                                    .font(.body)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal)
                                    .background(Color(UIColor.systemGray5))
                                    .cornerRadius(12)
                                    .foregroundColor(.primary)

                                Text("Enter your new phone number. We'll send a verification code to confirm.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 4)

                                Button(action: {
                                    store.send(.profile(.sendPhoneChangeVerificationCode))
                                }) {
                                    Text(store.isLoading ? "Sending..." : "Send Verification Code")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .cornerRadius(10)
                                }
                                .disabled(store.isLoading || store.profile!.editingPhone.isEmpty)
                                .padding(.top, 8)

                                Button(action: {
                                    store.send(.profile(.cancelPhoneNumberChange))
                                }) {
                                    Text("Cancel")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                        .frame(maxWidth: .infinity)
                                }
                                .padding(.top, 8)
                            }
                            .padding(.horizontal)
                            .padding(.top, 24)
                        } else {
                            // Verification code view
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Verification Code")
                                    .font(.headline)
                                    .padding(.horizontal, 4)

                                Text("Enter the verification code sent to \(PhoneFormatter.formatPhoneNumber(store.profile!.editingPhone, region: store.profile!.editingPhoneRegion))")
                                    .font(.body)
                                    .padding(.horizontal, 4)

                                TextField("Verification Code", text: $store.profile!.verificationCode.sending(\.profile.updateVerificationCode))
                                    .keyboardType(.numberPad)
                                    .font(.body)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal)
                                    .background(Color(UIColor.systemGray5))
                                    .cornerRadius(12)
                                    .foregroundColor(.primary)

                                Button(action: {
                                    store.send(.profile(.verifyPhoneChangeCode))
                                }) {
                                    Text(store.isLoading ? "Verifying..." : "Verify Code")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .cornerRadius(10)
                                }
                                .disabled(store.isLoading || store.profile!.verificationCode.isEmpty)
                                .padding(.top, 8)

                                Button(action: {
                                    store.send(.profile(.cancelPhoneNumberChange))
                                }) {
                                    Text("Cancel")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                        .frame(maxWidth: .infinity)
                                }
                                .padding(.top, 8)
                            }
                            .padding(.horizontal)
                            .padding(.top, 24)
                        }

                        Spacer(minLength: 0)
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationTitle("Phone Number")
                    .navigationBarItems(
                        leading: Button("Close") {
                            store.send(.profile(.setShowEditPhoneSheet(false)))
                        }
                    )
                    .alert(
                        title: { _ in Text("Error") },
                        isPresented: .init(
                            get: { store.profile?.error != nil },
                            set: { _ in }
                        ),
                        actions: { _ in
                            Button("OK") { }
                        },
                        message: { _ in Text(store.profile?.error?.localizedDescription ?? "An unknown error occurred") }
                    )
                }
                .presentationDetents([.medium])
            }

            // Edit avatar sheet
            .sheet(isPresented: $store.profile!.showEditAvatarSheet.sending(\.profile.setShowEditAvatarSheet)) {
                VStack(spacing: 20) {
                    Text("Avatar")
                        .font(.headline.bold())
                        .foregroundColor(.primary)
                    VStack(spacing: 0) {
                        Button(action: {
                            // In a real implementation, we would add photo taking functionality
                            store.send(.profile(.setShowEditAvatarSheet(false)))
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
                            store.send(.profile(.setShowEditAvatarSheet(false)))
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
                        store.send(.profile(.setShowEditAvatarSheet(false)))
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
            .alert(isPresented: $store.profile!.showSignOutConfirmation.sending(\.profile.setShowSignOutConfirmation)) {
                Alert(
                    title: Text("Sign Out"),
                    message: Text("Are you sure you want to sign out?"),
                    primaryButton: .destructive(Text("Sign Out")) {
                        store.send(.profile(.signOut))
                    },
                    secondaryButton: .cancel()
                )
            }

            // QR Code Share Sheet
            .sheet(item: $store.profile!.qrCodeShare.sending(\.profile.qrCodeShare)) { qrCodeShareState in
                QRCodeShareSheet(
                    store: store.scope(
                        state: \.profile!.qrCodeShare,
                        action: \.profile.qrCodeShare
                    )
                )
            }

            // Firebase test navigation
            .navigationDestination(isPresented: $store.profile!.showFirebaseTest.sending(\.profile.setShowFirebaseTest)) {
                Text("Firebase Test View")
                    .navigationTitle("Firebase Test")
            }
            .onAppear {
                store.send(.profile(.onAppear))
            }
        }
    }
}

extension QRCodeShareFeature.State: Identifiable {
    public var id: String {
        qrCodeId
    }
}
