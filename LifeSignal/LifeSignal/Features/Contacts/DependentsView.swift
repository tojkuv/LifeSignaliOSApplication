import SwiftUI
import ComposableArchitecture

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
                                    DependentCard(
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
                if let code = pendingScannedCode {
                    // Look up the user by QR code
                    viewStore.send(.lookupUserByQRCode(code))
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

/// A SwiftUI view for displaying a dependent card using TCA
struct DependentCard: View {
    /// The contact to display
    let contact: Contact

    /// The store for the contacts feature
    let store: StoreOf<ContactsFeature>

    /// State for UI controls
    @State private var showContactDetails = false

    var statusColor: Color {
        if contact.manualAlertActive {
            return .red
        } else if contact.isNonResponsive {
            return .yellow
        } else if contact.hasOutgoingPing {
            return .blue
        } else {
            return .secondary
        }
    }

    var statusText: String {
        if contact.manualAlertActive {
            if let alertTime = contact.manualAlertTimestamp {
                return "Alert sent \(TimeManager.shared.formatTimeAgo(alertTime))"
            }
            return "Alert active"
        } else if contact.isNonResponsive {
            if let lastCheckIn = contact.lastCheckIn, let interval = contact.interval {
                let expiration = lastCheckIn.addingTimeInterval(interval)
                return "Expired \(TimeManager.shared.formatTimeAgo(expiration))"
            }
            return "Check-in expired"
        } else if contact.hasOutgoingPing {
            if let pingTime = contact.outgoingPingTimestamp {
                return "Pinged \(TimeManager.shared.formatTimeAgo(pingTime))"
            }
            return "Ping sent"
        } else {
            return contact.formattedTimeRemaining
        }
    }

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            ContactCardView(
                contact: contact,
                statusColor: statusColor,
                statusText: statusText,
                context: .dependent,
                trailingContent: {
                    if !contact.hasOutgoingPing {
                        Button(action: {
                            viewStore.send(.pingDependent(id: contact.id))
                        }) {
                            Circle()
                                .fill(Color(UIColor.systemBackground))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "bell")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 18))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityLabel("Ping \(contact.name)")
                    } else {
                        Button(action: {
                            viewStore.send(.clearPing(id: contact.id))
                        }) {
                            Circle()
                                .fill(Color(UIColor.systemBackground))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "bell.fill")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 18))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityLabel("Clear ping for \(contact.name)")
                    }
                },
                onTap: {
                    showContactDetails = true
                }
            )
            .sheet(isPresented: $showContactDetails) {
                ContactDetailsSheet(
                    contact: contact,
                    store: store,
                    isPresented: $showContactDetails
                )
            }
        }
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
