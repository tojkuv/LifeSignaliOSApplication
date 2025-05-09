import SwiftUI
import Foundation
import AVFoundation
import UIKit

struct RespondersView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    @State private var showQRScanner = false
    @State private var showCheckInConfirmation = false
    @State private var showCameraDeniedAlert = false
    @State private var newContact: Contact? = nil
    @State private var pendingScannedCode: String? = nil
    @State private var showContactAddedAlert = false
    @State private var showContactExistsAlert = false
    @State private var showContactErrorAlert = false
    @State private var contactErrorMessage = ""
    @State private var refreshID = UUID() // Used to force refresh the view

    /// Computed property to sort responders with pending pings at the top
    private var sortedResponders: [Contact] {
        let responders = userViewModel.responders

        // Safety check - if responders is empty, return an empty array
        if responders.isEmpty {
            return []
        }

        // Partition into responders with incoming pings and others
        let (pendingPings, others) = responders.partitioned { $0.hasIncomingPing }

        // Sort pending pings by most recent incoming ping timestamp
        let sortedPendingPings = pendingPings.sorted {
            ($0.incomingPingTimestamp ?? .distantPast) > ($1.incomingPingTimestamp ?? .distantPast)
        }

        // Sort others alphabetically
        let sortedOthers = others.sorted { $0.name < $1.name }

        // Combine with pending pings at the top
        return sortedPendingPings + sortedOthers
    }

    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if userViewModel.responders.isEmpty {
                        Text("No responders yet")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    } else {
                        // Use the sortedResponders directly
                        ForEach(sortedResponders) { responder in
                            ResponderCard(contact: responder, refreshID: refreshID)
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
            NotificationCenter.default.addObserver(forName: NSNotification.Name("RefreshRespondersView"), object: nil, queue: .main) { _ in
                refreshID = UUID()
            }

            // Force refresh the view when it appears
            refreshID = UUID()
        }
        .toolbar {
            // Respond to All button (only shown when there are pending pings)
            if userViewModel.pendingPingsCount > 0 {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        userViewModel.respondToAllPings()
                    }) {
                        Text("Respond to All")
                            .foregroundColor(.blue)
                    }
                }
            }

            // QR Scanner button
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
                            isResponder: true,
                            isDependent: false
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
                                if let error = error as NSError?,
                                   error.domain == "UserViewModel",
                                   error.code == UserViewModel.ErrorCode.invalidArgument.rawValue,
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
        .onAppear {
            // Refresh the view when it appears
            refreshID = UUID()
        }
    }
}

struct ResponderCard: View {
    let contact: Contact
    let refreshID: UUID // Used to force refresh when ping state changes
    @EnvironmentObject private var userViewModel: UserViewModel
    @State private var selectedContactID: ContactID?

    var statusText: String {
        if contact.hasIncomingPing, let pingTime = contact.incomingPingTimestamp {
            return "Pinged \(TimeManager.shared.formatTimeAgo(pingTime))"
        }
        return ""
    }

    var body: some View {
        ContactCardView(
            contact: contact,
            statusColor: contact.hasIncomingPing ? .blue : .secondary,
            statusText: statusText,
            context: .responder,
            trailingContent: {
                if contact.hasIncomingPing {
                    Button(action: {
                        userViewModel.respondToPing(from: contact)
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
                    .accessibilityLabel("Respond to ping from \(contact.name)")
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
    }
}

// Add the Array extension to fix the 'partitioned' accessibility issue
extension Array {
    func partitioned(by belongsInFirstPartition: (Element) throws -> Bool) rethrows -> ([Element], [Element]) {
        var first: [Element] = []
        var second: [Element] = []
        for element in self {
            if try belongsInFirstPartition(element) {
                first.append(element)
            } else {
                second.append(element)
            }
        }
        return (first, second)
    }
}