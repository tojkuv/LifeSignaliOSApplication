import SwiftUI
import ComposableArchitecture
import CoreImage.CIFilterBuiltins
import UIKit

/// A SwiftUI view for the home screen using TCA
struct HomeView: View {
    /// The store for the home feature
    let store: StoreOf<HomeFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            ScrollView {
                LazyVStack(spacing: 16) {
                    // QR Code Section
                    qrCodeSection(viewStore)

                    // Add Contact Button
                    addContactButton(viewStore)

                    // Check-in Status Section
                    checkInStatusSection(viewStore)

                    // Settings Section
                    settingsSection(viewStore)
                }
                .padding(.bottom, 60)
            }
            .background(Color(.systemBackground))
            .sheet(isPresented: viewStore.binding(
                get: \.showQRScanner,
                send: HomeFeature.Action.showQRScanner
            )) {
                QRScannerView(
                    store: Store(initialState: QRScannerFeature.State()) {
                        QRScannerFeature()
                    },
                    onScanned: { result in
                        viewStore.send(.handleQRScanResult(result))
                    }
                )
            }
            .sheet(item: Binding(
                get: { viewStore.newContact },
                set: { newContact in
                    if newContact == nil {
                        viewStore.send(.clearNewContact)
                    }
                }
            )) { contact in
                AddContactSheet(
                    contactId: contact.id,
                    onAdd: { isResponder, isDependent in
                        viewStore.send(.addContact(contact, isResponder: isResponder, isDependent: isDependent))
                    },
                    onClose: {
                        viewStore.send(.clearNewContact)
                    }
                )
            }
            .sheet(isPresented: viewStore.binding(
                get: \.showIntervalPicker,
                send: HomeFeature.Action.setShowIntervalPicker
            )) {
                IntervalPickerView(
                    interval: viewStore.checkInInterval,
                    onSave: { interval in
                        viewStore.send(.updateInterval(interval))
                    },
                    onCancel: {
                        viewStore.send(.setShowIntervalPicker(false))
                    }
                )
            }
            .sheet(isPresented: viewStore.binding(
                get: \.showInstructions,
                send: HomeFeature.Action.setShowInstructions
            )) {
                InstructionsView(
                    onDismiss: {
                        viewStore.send(.setShowInstructions(false))
                    }
                )
            }
            .alert(isPresented: viewStore.binding(
                get: \.showCheckInConfirmation,
                send: HomeFeature.Action.setShowCheckInConfirmation
            )) {
                Alert(
                    title: Text("Check In Now?"),
                    message: Text("This will reset your countdown timer. Are you sure you want to check in now?"),
                    primaryButton: .default(Text("Check In")) {
                        viewStore.send(.checkIn)
                    },
                    secondaryButton: .cancel()
                )
            }
            .alert(isPresented: viewStore.binding(
                get: \.showCameraDeniedAlert,
                send: HomeFeature.Action.setShowCameraDeniedAlert
            )) {
                Alert(
                    title: Text("Camera Access Denied"),
                    message: Text("Please enable camera access in Settings to scan QR codes."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: viewStore.binding(
                get: \.showShareSheet,
                send: HomeFeature.Action.setShowShareSheet
            )) {
                if let image = viewStore.qrCodeImage {
                    ShareSheet(items: [image])
                }
            }
            .onAppear {
                viewStore.send(.loadUserData)
            }
        }
    }

    /// QR code section of the home view
    /// - Parameter viewStore: The view store
    /// - Returns: A view containing the QR code section
    private func qrCodeSection(_ viewStore: ViewStoreOf<HomeFeature>) -> some View {
        VStack(spacing: 16) {
            Text("My QR Code")
                .font(.headline)
                .padding(.top, 16)

            if viewStore.isGeneratingImage {
                ProgressView()
                    .frame(width: 200, height: 200)
            } else {
                Image(uiImage: generateQRCode(from: viewStore.qrCodeId))
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
            }

            Text("Scan this code to add \(viewStore.userName) as a contact")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                viewStore.send(.generateQRCode)
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
    /// - Parameter viewStore: The view store
    /// - Returns: A view containing the add contact button
    private func addContactButton(_ viewStore: ViewStoreOf<HomeFeature>) -> some View {
        Button(action: {
            viewStore.send(.showQRScanner(true))
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
    /// - Parameter viewStore: The view store
    /// - Returns: A view containing the check-in status section
    private func checkInStatusSection(_ viewStore: ViewStoreOf<HomeFeature>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Check-in interval")
                .foregroundColor(.primary)
                .padding(.horizontal)
                .padding(.leading)

            Button(action: {
                viewStore.send(.setShowIntervalPicker(true))
            }) {
                HStack {
                    Text(formatInterval(viewStore.checkInInterval))
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
    /// - Parameter viewStore: The view store
    /// - Returns: A view containing the settings section
    private func settingsSection(_ viewStore: ViewStoreOf<HomeFeature>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Check-in notification")
                .foregroundColor(.primary)
                .padding(.horizontal)
                .padding(.leading)

            Picker("Check-in notification", selection: viewStore.binding(
                get: \.notificationLeadTime,
                send: { HomeFeature.Action.updateNotificationLeadTime($0) }
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
                viewStore.send(.setShowInstructions(true))
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
