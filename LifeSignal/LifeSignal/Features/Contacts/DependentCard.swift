import SwiftUI
import Foundation
import UIKit

struct DependentCard: View {
    let contact: ContactReference
    let refreshID: UUID // Used to force refresh when status changes
    @EnvironmentObject var contactsViewModel: ContactsViewModel
    @State private var showContactDetails = false
    @State private var selectedContactID: String = ""

    var statusText: String {
        if contact.manualAlertActive, let alertTime = contact.manualAlertTimestamp {
            return "Alert sent \(TimeManager.shared.formatTimeAgo(alertTime))"
        } else if contact.isNonResponsive, let lastCheckIn = contact.lastCheckIn, let interval = contact.interval {
            let expirationTime = lastCheckIn.addingTimeInterval(interval)
            return "Expired \(TimeManager.shared.formatTimeAgo(expirationTime))"
        } else if contact.hasOutgoingPing, let pingTime = contact.outgoingPingTimestamp {
            return "Pinged \(TimeManager.shared.formatTimeAgo(pingTime))"
        } else if let lastCheckIn = contact.lastCheckIn, let interval = contact.interval {
            let expirationTime = lastCheckIn.addingTimeInterval(interval)
            let timeRemaining = expirationTime.timeIntervalSince(Date())

            if timeRemaining <= 0 {
                return "Check-in expired"
            } else {
                // Format the time remaining
                let hours = Int(timeRemaining / 3600)
                let minutes = Int((timeRemaining.truncatingRemainder(dividingBy: 3600)) / 60)

                if hours > 0 {
                    return "\(hours)h \(minutes)m remaining"
                } else {
                    return "\(minutes)m remaining"
                }
            }
        }
        return "No check-in scheduled"
    }

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

    var body: some View {
        ContactCardView(
            contact: contact,
            statusColor: statusColor,
            statusText: statusText,
            context: .dependent,
            trailingContent: {
                if !contact.hasOutgoingPing {
                    Button(action: {
                        contactsViewModel.pingDependent(contact) { success, error in
                            if let error = error {
                                print("Error pinging dependent: \(error.localizedDescription)")
                                return
                            }

                            if success {
                                print("Successfully pinged dependent: \(contact.name)")
                            }
                        }
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
                        contactsViewModel.clearPing(for: contact) { success, error in
                            if let error = error {
                                print("Error clearing ping: \(error.localizedDescription)")
                                return
                            }

                            if success {
                                print("Successfully cleared ping for dependent: \(contact.name)")
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
                    .accessibilityLabel("Clear ping for \(contact.name)")
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



