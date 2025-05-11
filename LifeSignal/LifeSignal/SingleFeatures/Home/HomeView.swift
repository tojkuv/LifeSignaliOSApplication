import SwiftUI
import ComposableArchitecture
import CoreImage.CIFilterBuiltins
import UIKit
import Combine

/// A SwiftUI view for the home screen using TCA
struct HomeView: View {
    /// The store for the app feature
    let store: StoreOf<AppFeature>

    /// State for UI controls
    @State private var showQRScanner = false
    @State private var showIntervalPicker = false
    @State private var showInstructions = false
    @State private var showCheckInConfirmation = false
    @State private var showCameraDeniedAlert = false
    @State private var showShareSheet = false
    @State private var isGeneratingImage = false
    @State private var qrCodeImage: UIImage? = nil
    @State private var pendingScannedCode: String? = nil
    @State private var newContact: Contact? = nil

    var body: some View {
        WithViewStore(store, observe: \.user) { viewStore in
            if let user = viewStore.state {
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
                } else {
                    // Show loading or placeholder view when user data is not available
                    ProgressView("Loading home...")
                }
            }
            .background(Color(.systemBackground))
            .sheet(isPresented: $showQRScanner) {
                QRScannerView(
                    onScanned: { qrCode in
                        pendingScannedCode = qrCode
                        showQRScanner = false
                        // Create a temporary contact with the QR code as the ID
                        // The Firebase function will look up the actual contact ID
                        newContact = Contact(id: qrCode, name: "Unknown User")
                    }
                )
            }
            .sheet(item: $newContact) { contact in
                AddContactSheet(
                    qrCode: contact.id, // This is the QR code, not the contact ID
                    store: store.scope(state: \.contacts, action: AppFeature.Action.contacts),
                    onAdd: { isResponder, isDependent in
                        newContact = nil
                    },
                    onClose: {
                        newContact = nil
                    }
                )
            }
            .sheet(isPresented: $showIntervalPicker) {
                IntervalPickerView(
                    interval: user.checkInInterval,
                    onSave: { interval in
                        store.send(.user(.updateCheckInInterval(interval)))
                        showIntervalPicker = false
                    },
                    onCancel: {
                        showIntervalPicker = false
                    }
                )
            }
            .sheet(isPresented: $showInstructions) {
                InstructionsView(
                    onDismiss: {
                        showInstructions = false
                    }
                )
            }
            .alert(isPresented: $showCheckInConfirmation) {
                Alert(
                    title: Text("Check In Now?"),
                    message: Text("This will reset your countdown timer. Are you sure you want to check in now?"),
                    primaryButton: .default(Text("Check In")) {
                        store.send(.user(.checkIn))
                    },
                    secondaryButton: .cancel()
                )
            }
            .alert(isPresented: $showCameraDeniedAlert) {
                Alert(
                    title: Text("Camera Access Denied"),
                    message: Text("Please enable camera access in Settings to scan QR codes."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = qrCodeImage {
                    ShareSheet(items: [image])
                }
            }
        }
    }

    /// QR code section of the home view
    /// - Parameter user: The user state
    /// - Returns: A view containing the QR code section
    private func qrCodeSection(_ user: UserFeature.State) -> some View {
        VStack(spacing: 16) {
            Text("My QR Code")
                .font(.headline)
                .padding(.top, 16)

            if isGeneratingImage {
                ProgressView()
                    .frame(width: 200, height: 200)
            } else {
                Image(uiImage: generateQRCode(from: user.qrCodeId))
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
            }

            Text("Scan this code to add \(user.name) as a contact")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                isGeneratingImage = true
                // Generate QR code image
                qrCodeImage = generateQRCode(from: user.qrCodeId)
                isGeneratingImage = false
                showShareSheet = true
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
            showQRScanner = true
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
    /// - Parameter user: The user state
    /// - Returns: A view containing the check-in status section
    private func checkInStatusSection(_ user: UserFeature.State) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Check-in interval")
                .foregroundColor(.primary)
                .padding(.horizontal)
                .padding(.leading)

            Button(action: {
                showIntervalPicker = true
            }) {
                HStack {
                    Text(formatInterval(user.checkInInterval))
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
    /// - Parameter user: The user state
    /// - Returns: A view containing the settings section
    private func settingsSection(_ user: UserFeature.State) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Check-in notification")
                .foregroundColor(.primary)
                .padding(.horizontal)
                .padding(.leading)

            Picker("Check-in notification", selection: Binding(
                get: { user.notify2HoursBefore ? 120 : 30 },
                set: { newValue in
                    let notify30Min = newValue == 30
                    let notify2Hours = newValue == 120
                    store.send(.user(.updateNotificationPreferences(notify30Min: notify30Min, notify2Hours: notify2Hours)))
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
                showInstructions = true
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

    /// Generate a QR code image from a string
    /// - Parameter string: The string to encode in the QR code
    /// - Returns: A UIImage containing the QR code
    private func generateQRCode(from string: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        if let outputImage = filter.outputImage {
            if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }

        return UIImage(systemName: "qrcode") ?? UIImage()
    }

    /// Format a time interval for display
    /// - Parameter interval: The time interval in seconds
    /// - Returns: A formatted string representation of the interval
    private func formatInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600

        if hours < 24 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            let days = hours / 24
            return "\(days) day\(days == 1 ? "" : "s")"
        }
    }
}
