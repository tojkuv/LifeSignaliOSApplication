import SwiftUI
import Foundation
import AVFoundation
import UIKit

struct DependentsView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    @State private var showQRScanner = false
    @State private var showCheckInConfirmation = false
    @State private var showCameraDeniedAlert = false
    @State private var newContact: Contact? = nil
    @State private var pendingScannedCode: String? = nil
    @State private var showContactAddedAlert = false
    @State private var refreshID = UUID() // Used to force refresh the view

    enum SortMode: String, CaseIterable, Identifiable {
        // Order matters for UI presentation
        case countdown = "Time Left"
        case recentlyAdded = "Recently Added"
        case alphabetical = "Alphabetical"
        var id: String { self.rawValue }
    }
    @State private var sortMode: SortMode = .countdown

    /// Computed property to sort dependents based on the selected sort mode
    private var sortedDependents: [Contact] {
        // This will be recalculated when refreshID changes
        let dependents = userViewModel.dependents

        // Partition into manual alert, non-responsive, pinged, and responsive
        let (manualAlert, rest1) = dependents.partitioned { $0.manualAlertActive }
        let (nonResponsive, rest2) = rest1.partitioned { $0.isNonResponsive }
        let (pinged, responsive) = rest2.partitioned { $0.hasOutgoingPing }

        // Sort manual alerts by most recent alert timestamp
        let sortedManualAlert = manualAlert.sorted {
            ($0.manualAlertTimestamp ?? .distantPast) > ($1.manualAlertTimestamp ?? .distantPast)
        }

        // Sort non-responsive contacts alphabetically
        let sortedNonResponsive = nonResponsive.sorted { $0.name < $1.name }

        // Sort pinged contacts by most recent outgoing ping timestamp
        let sortedPinged = pinged.sorted {
            ($0.outgoingPingTimestamp ?? .distantPast) > ($1.outgoingPingTimestamp ?? .distantPast)
        }

        // Sort responsive contacts based on the selected sort mode
        let sortedResponsive: [Contact]
        switch sortMode {
        case .recentlyAdded:
            sortedResponsive = responsive.sorted { $0.addedAt > $1.addedAt }

        case .countdown:
            // Sort by time remaining (shortest time first)
            sortedResponsive = responsive.sorted {
                // Handle nil lastCheckIn (should be at the top)
                if $0.lastCheckIn == nil && $1.lastCheckIn == nil {
                    return $0.name < $1.name // If both have nil, sort alphabetically
                } else if $0.lastCheckIn == nil {
                    return true // $0 comes first if it has nil lastCheckIn
                } else if $1.lastCheckIn == nil {
                    return false // $1 comes first if it has nil lastCheckIn
                }

                // Normal case: sort by time remaining
                return $0.timeRemaining < $1.timeRemaining
            }

        case .alphabetical:
            sortedResponsive = responsive.sorted { $0.name < $1.name }
        }

        // Combine all sorted groups with priority: manual alert > non-responsive > pinged > responsive
        return sortedManualAlert + sortedNonResponsive + sortedPinged + sortedResponsive
    }

    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if userViewModel.dependents.isEmpty {
                        Text("No dependents yet")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    } else {
                        ForEach(sortedDependents) { dependent in
                            DependentCard(contact: dependent, refreshID: refreshID)
                        }
                    }
                }
                .padding()
                .padding(.bottom, 30)
            }
            .background(Color(.systemBackground))
        }
        .background(Color(.systemBackground))
        .onAppear {
            // Add observer for refresh notifications
            NotificationCenter.default.addObserver(forName: NSNotification.Name("RefreshDependentsView"), object: nil, queue: .main) { _ in
                refreshID = UUID()
            }

            // Force refresh when view appears to ensure sort is applied
            refreshID = UUID()
            print("DependentsView appeared with sort mode: \(sortMode.rawValue)")
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    ForEach(SortMode.allCases) { mode in
                        Button(action: {
                            sortMode = mode
                            // Force refresh when sort mode changes
                            refreshID = UUID()
                            print("Sort mode changed to: \(mode.rawValue)")
                        }) {
                            Label(mode.rawValue, systemImage: sortMode == mode ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(sortMode.rawValue)
                            .font(.caption)
                    }
                }
                .accessibilityLabel("Sort Dependents")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    AVCaptureDevice.requestAccess(for: .video) { granted in
                        if granted {
                            DispatchQueue.main.async {
                                showQRScanner = true
                            }
                        } else {
                            DispatchQueue.main.async {
                                showCameraDeniedAlert = true
                            }
                        }
                    }
                }) {
                    Image(systemName: "qrcode.viewfinder")
                }
            }
        }
        .sheet(isPresented: $showQRScanner, onDismiss: {
            if let code = pendingScannedCode {
                // Look up the user by QR code
                userViewModel.lookupUserByQRCode(code) { userData, error in
                    if let error = error {
                        print("Error looking up user by QR code: \(error.localizedDescription)")
                        return
                    }

                    guard let userData = userData else {
                        print("No user found with QR code: \(code)")
                        return
                    }

                    // Extract user data
                    let name = userData[FirestoreSchema.User.name] as? String ?? "Unknown Name"
                    let phone = userData[FirestoreSchema.User.phoneNumber] as? String ?? ""
                    let note = userData[FirestoreSchema.User.note] as? String ?? ""

                    // Create a new contact with the user data
                    DispatchQueue.main.async {
                        self.newContact = Contact(
                            name: name,
                            phone: phone,
                            note: note,
                            qrCodeId: code,
                            isResponder: false,
                            isDependent: true
                        )
                    }
                }
                pendingScannedCode = nil
            }
        }) {
            QRScannerView { result in
                pendingScannedCode = result
            }
        }
        .sheet(item: $newContact, onDismiss: {
            newContact = nil
        }) { contact in
            AddContactSheet(
                contact: .constant(contact),
                onAdd: { confirmedContact in
                    // Use the QR code to add the contact via Firebase
                    if let qrCodeId = confirmedContact.qrCodeId {
                        userViewModel.addContact(
                            qrCodeId: qrCodeId,
                            isResponder: confirmedContact.isResponder,
                            isDependent: confirmedContact.isDependent
                        ) { success, error in
                            if success {
                                // Show alert after sheet closes
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showContactAddedAlert = true
                                }
                            } else if let error = error {
                                print("Error adding contact: \(error.localizedDescription)")
                            }
                        }
                    }
                },
                onClose: { newContact = nil }
            )
        }

        .alert(isPresented: $showCheckInConfirmation) {
            Alert(
                title: Text("Confirm Check-in"),
                message: Text("Are you sure you want to check in now? This will reset your timer."),
                primaryButton: .default(Text("Check In")) {
                    userViewModel.updateLastCheckedIn()
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
        .alert(isPresented: $showContactAddedAlert) {
            Alert(
                title: Text("Contact Added"),
                message: Text("The contact was successfully added."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct DependentCard: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    let contact: Contact
    let refreshID: UUID // Used to force refresh when ping state changes

    // Use @State for alert control
    @State private var showPingAlert = false
    @State private var isPingConfirmation = false
    @State private var selectedContactID: ContactID?

    var statusColor: Color {
        if contact.manualAlertActive {
            return .red
        } else if contact.isNonResponsive {
            return .yellow
        } else {
            return .secondary
        }
    }

    var statusText: String {
        if contact.manualAlertActive {
            return "Alert Active"
        } else if contact.isNonResponsive {
            return "Not responsive"
        } else {
            return contact.formattedTimeRemaining
        }
    }

    var body: some View {
        ContactCardView(
            contact: contact,
            statusColor: statusColor,
            statusText: statusText,
            context: .dependent,
            trailingContent: {
                if contact.hasOutgoingPing {
                    Button(action: {
                        // Show clear ping alert
                        isPingConfirmation = false
                        showPingAlert = true
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
                    .accessibilityLabel("Clear ping to \(contact.name)")
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 40, height: 40)
                }
            },
            onTap: {
                triggerHaptic()
                selectedContactID = ContactID(id: contact.id)
            }
        )
        .sheet(item: $selectedContactID) { id in
            if let contact = userViewModel.contacts.first(where: { $0.id == id.id }) {
                ContactDetailsSheet(contact: contact)
            }
        }
        .alert(isPresented: $showPingAlert) {
            if isPingConfirmation {
                return Alert(
                    title: Text("Ping Sent"),
                    message: Text("The contact was successfully pinged."),
                    dismissButton: .default(Text("OK"))
                )
            } else if contact.hasOutgoingPing {
                return Alert(
                    title: Text("Clear Ping"),
                    message: Text("Do you want to clear the pending ping to this contact?"),
                    primaryButton: .default(Text("Clear")) {
                        // Use the view model to clear the ping
                        userViewModel.clearPing(for: contact)

                        // Debug print
                        print("Clearing ping for contact: \(contact.name)")

                        // Force refresh immediately
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshDependentsView"), object: nil)
                    },
                    secondaryButton: .cancel()
                )
            } else {
                return Alert(
                    title: Text("Send Ping"),
                    message: Text("Are you sure you want to ping this contact?"),
                    primaryButton: .default(Text("Ping")) {
                        // Use the view model to ping the dependent
                        userViewModel.pingDependent(contact)

                        // Debug print
                        print("Setting ping for contact: \(contact.name)")

                        // Force refresh immediately
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshDependentsView"), object: nil)

                        // Show confirmation alert
                        isPingConfirmation = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showPingAlert = true
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}

// The partitioned(by:) extension is now defined in RespondersView.swift