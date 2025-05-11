import SwiftUI
import UIKit
import ComposableArchitecture

/// A SwiftUI view for displaying a dependent card
struct DependentCardView: View {
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
            if let lastCheckedIn = contact.lastCheckedIn, let interval = contact.checkInInterval {
                let expiration = lastCheckedIn.addingTimeInterval(interval)
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
            HStack(spacing: 12) {
                AvatarView(name: contact.name)

                VStack(alignment: .leading, spacing: 4) {
                    Text(contact.name)
                        .font(.body)
                        .foregroundColor(.primary)

                    if !statusText.isEmpty {
                        Text(statusText)
                            .font(.footnote)
                            .foregroundColor(statusColor)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)

                Spacer()

                // Trailing content (ping button)
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
            }
            .padding()
            .background(
                contact.manualAlertActive ? Color.red.opacity(0.1) :
                contact.isNonResponsive ? Color.yellow.opacity(0.15) :
                Color(UIColor.systemGray6)
            )
            .cornerRadius(12)
            .standardShadow(radius: 2, y: 1)
            .onTapGesture {
                showContactDetails = true
            }
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
    DependentCardView(
        contact: Contact(
            id: "test",
            name: "John Doe",
            isDependent: true,
            lastCheckedIn: Date(),
            checkInInterval: 3600 * 24
        ),
        store: Store(initialState: ContactsFeature.State()) {
            ContactsFeature()
        }
    )
    .padding()
}
