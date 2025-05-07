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
                newContact = Contact(
                    name: "Riley Johnson",
                    phone: "555-123-4567",
                    note: "I live with my elderly mother who needs daily medication. If I'm unresponsive, please check my house first - spare key with neighbor John at 123 Oak St. Medical conditions: Type 1 diabetes, insulin in kitchen fridge. I also have a rescue inhaler in my purse for occasional asthma.",
                    qrCodeId: code,
                    isResponder: true,
                    isDependent: false
                )
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
                    userViewModel.contacts.append(confirmedContact)
                    // Show alert after sheet closes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showContactAddedAlert = true
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