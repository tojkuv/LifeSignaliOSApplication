import SwiftUI
import Foundation
import UIKit

struct ResponderCard: View {
    let contact: ContactReference
    let refreshID: UUID // Used to force refresh when ping state changes
    @EnvironmentObject var contactsViewModel: ContactsViewModel
    @State private var showContactDetails = false
    @State private var selectedContactID: String = ""

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
                showContactDetails = true
            }
        )
        .sheet(isPresented: $showContactDetails) {
            if let _ = contactsViewModel.getContact(by: selectedContactID) {
                ContactDetailsSheet(contactID: selectedContactID)
            }
        }
    }
}



