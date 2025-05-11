import SwiftUI
import ComposableArchitecture
import UIKit

/// A SwiftUI view for displaying dependents using TCA
struct DependentsView: View {
    /// The store for the contacts feature
    let store: StoreOf<ContactsFeature>

    /// State for UI controls
    @State private var showQRScanner = false
    @State private var pendingScannedCode: String? = nil
    @State private var showContactAddedAlert = false
    @State private var showContactExistsAlert = false
    @State private var showContactErrorAlert = false
    @State private var contactErrorMessage = ""
    @State private var refreshID = UUID() // Used to force refresh the view

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack {
                if viewStore.isLoading {
                    // Show loading indicator
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Loading dependents...")
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if viewStore.dependents.isEmpty {
                                Text("No dependents yet")
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 40)
                            } else {
                                // Use the sorted dependents
                                ForEach(sortedDependents(viewStore.dependents)) { dependent in
                                    DependentCardView(
                                        contact: dependent,
                                        store: store
                                    )
                                }
                            }
                        }
                        .padding()
                        .padding(.bottom, 30)
                    }
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle("Dependents")
            .toolbar {
                // Add button
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showQRScanner = true
                    }) {
                        Image(systemName: "qrcode.viewfinder")
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showQRScanner, onDismiss: {
                if let qrCode = pendingScannedCode {
                    // Use the scanned QR code to look up the contact ID via Firebase function
                    // The QR code is not the contact ID itself
                    let sheet = AddContactSheet(
                        qrCode: qrCode,
                        store: store,
                        onAdd: { isResponder, isDependent in
                            showContactAddedAlert = true
                        },
                        onClose: { }
                    )

                    // Present the sheet
                    let hostingController = UIHostingController(rootView: sheet)
                    UIApplication.shared.windows.first?.rootViewController?.present(hostingController, animated: true)

                    pendingScannedCode = nil
                }
            }) {
                QRScannerView(
                    store: Store(initialState: QRScannerFeature.State()) {
                        QRScannerFeature()
                    },
                    onScanned: { result in
                        pendingScannedCode = result
                    }
                )
            }
            .alert("Contact Added", isPresented: $showContactAddedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The contact has been added to your dependents.")
            }
            .alert("Contact Already Exists", isPresented: $showContactExistsAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This contact is already in your contacts list.")
            }
            .alert("Error Adding Contact", isPresented: $showContactErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(contactErrorMessage)
            }
            .onAppear {
                viewStore.send(.loadContacts)
            }
        }
    }

    /// Sort dependents based on status (manual alert, non-responsive, pinged, responsive)
    /// - Parameter dependents: The list of dependents to sort
    /// - Returns: A sorted list of dependents
    private func sortedDependents(_ dependents: [Contact]) -> [Contact] {
        // Partition into manual alert, non-responsive, pinged, and responsive
        let (manualAlert, rest1) = dependents.partitioned { $0.manualAlertActive }
        let (nonResponsive, rest2) = rest1.partitioned { $0.isNonResponsive }
        let (pinged, responsive) = rest2.partitioned { $0.hasOutgoingPing }

        // Sort manual alerts by most recent alert timestamp
        let sortedManualAlert = manualAlert.sorted {
            ($0.manualAlertTimestamp ?? .distantPast) > ($1.manualAlertTimestamp ?? .distantPast)
        }

        // Sort non-responsive by most expired first
        let sortedNonResponsive = nonResponsive.sorted {
            guard let lastCheckIn0 = $0.lastCheckIn, let interval0 = $0.interval,
                  let lastCheckIn1 = $1.lastCheckIn, let interval1 = $1.interval else {
                return false
            }
            let expiration0 = lastCheckIn0.addingTimeInterval(interval0)
            let expiration1 = lastCheckIn1.addingTimeInterval(interval1)
            return expiration0 < expiration1
        }

        // Sort pinged by most recent ping timestamp
        let sortedPinged = pinged.sorted {
            ($0.outgoingPingTimestamp ?? .distantPast) > ($1.outgoingPingTimestamp ?? .distantPast)
        }

        // Sort responsive alphabetically
        let sortedResponsive = responsive.sorted { $0.name < $1.name }

        // Combine all sorted groups
        return sortedManualAlert + sortedNonResponsive + sortedPinged + sortedResponsive
    }
}



#Preview {
    NavigationStack {
        DependentsView(
            store: Store(initialState: ContactsFeature.State()) {
                ContactsFeature()
            }
        )
    }
}
