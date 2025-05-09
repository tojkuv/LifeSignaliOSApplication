import SwiftUI
import Foundation
import AVFoundation
import UIKit

struct DependentsView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    @EnvironmentObject private var contactsViewModel: ContactsViewModel
    @State private var showQRScanner = false
    @State private var showCheckInConfirmation = false
    @State private var showCameraDeniedAlert = false
    @State private var newContact: ContactReference? = nil
    @State private var pendingScannedCode: String? = nil
    @State private var showContactAddedAlert = false
    @State private var showContactExistsAlert = false
    @State private var showContactErrorAlert = false
    @State private var contactErrorMessage = ""
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
    private var sortedDependents: [ContactReference] {
        // This will be recalculated when refreshID changes
        let dependents = contactsViewModel.dependents

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
        let sortedResponsive: [ContactReference]
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

                // Calculate time remaining for each contact
                guard let lastCheckIn0 = $0.lastCheckIn, let interval0 = $0.interval,
                      let lastCheckIn1 = $1.lastCheckIn, let interval1 = $1.interval else {
                    return $0.name < $1.name // Fallback to alphabetical if missing data
                }

                let expirationTime0 = lastCheckIn0.addingTimeInterval(interval0)
                let expirationTime1 = lastCheckIn1.addingTimeInterval(interval1)
                let timeRemaining0 = expirationTime0.timeIntervalSince(Date())
                let timeRemaining1 = expirationTime1.timeIntervalSince(Date())

                return timeRemaining0 < timeRemaining1
            }

        case .alphabetical:
            sortedResponsive = responsive.sorted { $0.name < $1.name }
        }

        // Combine all sorted groups with priority: manual alert > non-responsive > pinged > responsive
        return sortedManualAlert + sortedNonResponsive + sortedPinged + sortedResponsive
    }

    var body: some View {
        VStack {
            if contactsViewModel.isLoadingContacts {
                // Show loading indicator
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Loading dependents...")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = contactsViewModel.contactError {
                // Show error view
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.red)

                    Text("Error Loading Dependents")
                        .font(.headline)

                    Text(error.localizedDescription)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)

                    Button("Retry") {
                        contactsViewModel.forceReloadContacts()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if contactsViewModel.dependents.isEmpty {
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
        }
        .background(Color(.systemBackground))
        .onAppear {
            // Add observer for refresh notifications
            NotificationCenter.default.addObserver(forName: NSNotification.Name("RefreshDependentsView"), object: nil, queue: .main) { _ in
                refreshID = UUID()
            }

            // Force refresh when view appears to ensure sort is applied
            refreshID = UUID()

            // Only reload contacts if they haven't been loaded yet or if there was an error
            if contactsViewModel.contacts.isEmpty || contactsViewModel.contactError != nil {
                contactsViewModel.forceReloadContacts()
            }
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
                contactsViewModel.lookupUserByQRCode(code) { userData, error in
                    if let error = error {
                        print("Error looking up user by QR code: \(error.localizedDescription)")
                        return
                    }

                    guard let userData = userData else {
                        print("No user found with QR code: \(code)")
                        return
                    }

                    // Create a new contact with the user data
                    DispatchQueue.main.async {
                        self.newContact = ContactReference.createDefault(
                            name: userData[UserFields.name] as? String ?? "Unknown Name",
                            phone: userData[UserFields.phoneNumber] as? String ?? "",
                            note: userData[UserFields.note] as? String ?? "",
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
                contact: contact,
                onAdd: { confirmedContact in
                    // Use the QR code to add the contact via Firebase
                    if let qrCodeId = confirmedContact.qrCodeId {
                        contactsViewModel.addContact(
                            qrCodeId: qrCodeId,
                            isResponder: confirmedContact.isResponder,
                            isDependent: confirmedContact.isDependent
                        ) { success, error in
                            if success {
                                if let error = error as NSError?,
                                   error.domain == "ContactsViewModel",
                                   error.code == 400,
                                   error.localizedDescription.contains("already exists") {
                                    // Contact already exists - show appropriate alert
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showContactExistsAlert = true
                                    }
                                } else {
                                    // Contact was added successfully
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showContactAddedAlert = true
                                    }
                                }
                            } else if let error = error {
                                print("Error adding contact: \(error.localizedDescription)")
                                // Show error alert to the user
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    contactErrorMessage = error.localizedDescription
                                    showContactErrorAlert = true
                                }
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
        .alert(isPresented: $showContactExistsAlert) {
            Alert(
                title: Text("Contact Already Exists"),
                message: Text("This user is already in your contacts list."),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $showContactErrorAlert) {
            Alert(
                title: Text("Error Adding Contact"),
                message: Text(contactErrorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct DependentCard: View {
    @EnvironmentObject private var contactsViewModel: ContactsViewModel
    let contact: ContactReference
    let refreshID: UUID // Used to force refresh when ping state changes

    // Use @State for alert control
    @State private var showPingAlert = false
    @State private var isPingConfirmation = false
    @State private var selectedContactID: String?

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
                selectedContactID = contact.id
            }
        )
        .sheet(item: $selectedContactID) { id in
            if let contact = contactsViewModel.getContact(by: id) {
                ContactDetailsSheet(contactID: id)
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
                        // Use the view model to clear the ping with completion handler
                        contactsViewModel.clearPing(for: contact) { success, error in
                            if let error = error {
                                print("Error clearing ping: \(error.localizedDescription)")
                                return
                            }

                            if success {
                                print("Ping cleared successfully for contact: \(contact.name)")
                            }
                        }
                    },
                    secondaryButton: .cancel()
                )
            } else {
                return Alert(
                    title: Text("Send Ping"),
                    message: Text("Are you sure you want to ping this contact?"),
                    primaryButton: .default(Text("Ping")) {
                        // Use the view model to ping the dependent with completion handler
                        contactsViewModel.pingDependent(contact) { success, error in
                            if let error = error {
                                print("Error sending ping: \(error.localizedDescription)")
                                return
                            }

                            if success {
                                print("Ping sent successfully to contact: \(contact.name)")

                                // Show confirmation alert
                                DispatchQueue.main.async {
                                    isPingConfirmation = true
                                    showPingAlert = true
                                }
                            }
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}

// The partitioned(by:) extension is now defined in ArrayExtensions.swift