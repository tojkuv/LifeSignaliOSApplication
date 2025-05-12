import SwiftUI
import ComposableArchitecture
import UIKit
import Combine

/// A SwiftUI view for the home screen
struct HomeView: View {
    /// The store for the home feature
    @Bindable var store: StoreOf<HomeFeature>

    /// The user feature store from environment
    @Environment(\.store) private var appStore

    /// The user feature store scoped from app store
    @Bindable private var user: StoreOf<UserFeature> {
        appStore.scope(state: \.user, action: \.user)
    }

    /// The check-in feature store scoped from user store
    private var checkIn: StoreOf<CheckInFeature>? {
        if let checkInState = user.checkIn {
            return user.scope(state: \.checkIn, action: \.checkIn)
        }
        return nil
    }

    // Main body of the view
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // QR Code Section
                qrCodeSection(user)

                // Add Contact Button
                addContactButton()

                // Check-in Status Section
                checkInStatusSection(user)

                // Settings Section
                settingsSection(user)
            }
            .padding(.bottom, 60)
        }
        .background(Color(.systemBackground))
        // Alerts
        .alert(
            title: { _ in Text("Check-in Confirmation") },
            isPresented: $store.showCheckInConfirmation.sending(\.setShowCheckInConfirmation),
            actions: { _ in
                Button("Check In", role: .none) {
                    user.send(.checkIn)
                }
                Button("Cancel", role: .cancel) { }
            },
            message: { _ in Text("Are you sure you want to check in now?") }
        )
        // Sheet presentations
        .sheet(isPresented: $store.qrScanner.showScanner.sending(\.qrScanner.setShowScanner)) {
            if let contactsStore = user.scope(state: \.contacts, action: \.contacts) {
                QRScannerView(
                    store: store.scope(state: \.qrScanner, action: \.qrScanner),
                    addContactStore: store.scope(state: \.addContact, action: \.addContact),
                    contactsStore: contactsStore,
                    userStore: user
                )
            }
        }
        .sheet(isPresented: $store.addContact.isSheetPresented.sending(\.addContact.setSheetPresented)) {
            AddContactSheet(store: store.scope(state: \.addContact, action: \.addContact))
        }
        .sheet(isPresented: $store.showIntervalPicker.sending(\.setShowIntervalPicker)) {
            IntervalPickerView(
                interval: user.userData.checkInInterval,
                onSave: { interval in
                    user.send(.updateCheckInInterval(interval))
                    store.send(.setShowIntervalPicker(false))
                },
                onCancel: {
                    store.send(.setShowIntervalPicker(false))
                }
            )
        }
        .sheet(isPresented: $store.showInstructions.sending(\.setShowInstructions)) {
            InstructionsView(
                onDismiss: {
                    store.send(.setShowInstructions(false))
                }
            )
        }
        .sheet(isPresented: $store.showShareQRCode.sending(\.setShowShareQRCode)) {
            if let profileStore = user.scope(state: \.profile, action: \.profile) {
                profileStore.send(.showQRCodeShareSheet)

                if let qrCodeShareStore = profileStore.scope(state: \.qrCodeShare, action: \.qrCodeShare) {
                    QRCodeShareSheet(store: qrCodeShareStore)
                        .onDisappear {
                            store.send(.setShowShareQRCode(false))
                        }
                } else {
                    Text("QR Code not available")
                        .onDisappear {
                            store.send(.setShowShareQRCode(false))
                        }
                }
            } else {
                Text("Profile not available")
                    .onDisappear {
                        store.send(.setShowShareQRCode(false))
                    }
            }
        }
    }

    /// QR code section of the home view
    /// - Parameter user: The user store
    /// - Returns: A view containing the QR code section
    private func qrCodeSection(_ user: StoreOf<UserFeature>) -> some View {
        VStack(spacing: 16) {
            Text("My QR Code")
                .font(.headline)
                .padding(.top, 16)

            QRCodeView(qrCodeId: user.userData.qrCodeId, size: 200)

            Text("Scan this code to add \(user.userData.name) as a contact")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                store.send(.shareQRCodeButtonTapped)
            }) {
                Label("Share QR Code", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    /// Add contact button section of the home view
    /// - Returns: A view containing the add contact button
    private func addContactButton() -> some View {
        Button(action: {
            store.send(.addContactButtonTapped)
        }) {
            Label("Add Contact", systemImage: "person.badge.plus")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green)
                .cornerRadius(10)
        }
        .padding(.horizontal)
    }

    /// Check-in status section of the home view
    /// - Parameter user: The user store
    /// - Returns: A view containing the check-in status section
    private func checkInStatusSection(_ user: StoreOf<UserFeature>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Check-in interval")
                .foregroundColor(.primary)
                .padding(.horizontal)
                .padding(.leading)

            Button(action: {
                store.send(.showIntervalPickerButtonTapped)
            }) {
                HStack {
                    Text(store.formatInterval(user.userData.checkInInterval))
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)

            Text("This is how long you have until your responders are notified if you don't check in.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    /// Settings section of the home view
    /// - Parameter user: The user store
    /// - Returns: A view containing the settings section
    private func settingsSection(_ user: StoreOf<UserFeature>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Check-in notification")
                .foregroundColor(.primary)
                .padding(.horizontal)
                .padding(.leading)

            Picker("Check-in notification", selection: Binding(
                get: { user.userData.notify2HoursBefore ? 120 : 30 },
                set: { newValue in
                    let notify30Min = newValue == 30
                    let notify2Hours = newValue == 120
                    user.send(.updateNotificationPreferences(enabled: true, notify30MinBefore: notify30Min, notify2HoursBefore: notify2Hours))
                }
            )) {
                Text("30 mins").tag(30)
                Text("2 hours").tag(120)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Text("Choose when you'd like to be reminded before your countdown expires.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .center)

            Button(action: {
                store.send(.showInstructionsButtonTapped)
            }) {
                Label("How LifeSignal Works", systemImage: "info.circle")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
}
