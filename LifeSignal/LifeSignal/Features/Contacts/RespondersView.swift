import SwiftUI
import Foundation
import AVFoundation
import UIKit

struct RespondersView: View {
    @EnvironmentObject var contactsViewModel: ContactsViewModel
    @State private var showQRScanner = false
    @State private var showCameraDeniedAlert = false
    @State private var newContact: ContactReference? = nil
    @State private var pendingScannedCode: String? = nil
    @State private var showContactAddedAlert = false
    @State private var showContactExistsAlert = false
    @State private var showContactErrorAlert = false
    @State private var contactErrorMessage = ""
    @State private var refreshID = UUID() // Used to force refresh the view

    /// Computed property to sort responders with pending pings at the top
    private var sortedResponders: [ContactReference] {
        let responders = contactsViewModel.responders

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
            if contactsViewModel.isLoadingContacts {
                // Show loading indicator
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Loading responders...")
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

                    Text("Error Loading Responders")
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
                        if contactsViewModel.responders.isEmpty {
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
        }
        .background(Color(.systemBackground))
        .onAppear {
            // Add observer for refresh notifications
            NotificationCenter.default.addObserver(forName: NSNotification.Name("RefreshRespondersView"), object: nil, queue: .main) { _ in
                refreshID = UUID()
            }

            // Force refresh the view when it appears
            refreshID = UUID()

            // Only reload contacts if they haven't been loaded yet or if there was an error
            if contactsViewModel.contacts.isEmpty || contactsViewModel.contactError != nil {
                contactsViewModel.forceReloadContacts()
            }
        }
        .toolbar {
            // Respond to All button (only shown when there are pending pings)
            if contactsViewModel.pendingPingsCount > 0 {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        contactsViewModel.respondToAllPings() { success, error in
                            if let error = error {
                                print("Error responding to all pings: \(error.localizedDescription)")
                                return
                            }

                            if success {
                                print("Successfully responded to all pings")
                            }
                        }
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
                            name: userData[User.Fields.name] as? String ?? "Unknown Name",
                            phone: userData[User.Fields.phoneNumber] as? String ?? "",
                            note: userData[User.Fields.note] as? String ?? "",
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

struct ResponderCard: View {
    let contact: ContactReference
    let refreshID: UUID // Used to force refresh when ping state changes
    @EnvironmentObject var contactsViewModel: ContactsViewModel
    @State private var selectedContactID: String?

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
                        contactsViewModel.respondToPing(from: contact) { success, error in
                            if let error = error {
                                print("Error responding to ping: \(error.localizedDescription)")
                                return
                            }

                            if success {
                                print("Successfully responded to ping from: \(contact.name)")
                            }
                        }
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
                selectedContactID = contact.id
            }
        )
        .sheet(item: $selectedContactID) { id in
            if let _ = contactsViewModel.getContact(by: id) {
                ContactDetailsSheet(contactID: id)
            }
        }
    }
}

#Preview {
    RespondersView()
        .environmentObject(ContactsViewModel())
}
