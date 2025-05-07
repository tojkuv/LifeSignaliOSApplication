import SwiftUI
import UIKit

/// Enum to specify the context in which a contact card is being displayed
enum ContactCardContext {
    case responder
    case dependent
}

/// A reusable card view for displaying contact information
struct ContactCardView: View {
    let contact: Contact
    let statusColor: Color
    let statusText: String
    let trailingContent: AnyView?
    let onTap: () -> Void
    let context: ContactCardContext

    init(
        contact: Contact,
        statusColor: Color = .secondary,
        statusText: String? = nil,
        context: ContactCardContext = .responder,
        @ViewBuilder trailingContent: @escaping () -> some View = { EmptyView() },
        onTap: @escaping () -> Void = {}
    ) {
        self.contact = contact
        self.statusColor = statusColor
        self.statusText = statusText ?? contact.formattedTimeRemaining
        self.trailingContent = AnyView(trailingContent())
        self.onTap = onTap
        self.context = context
    }

    var body: some View {
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

            if let trailingContent = trailingContent {
                trailingContent
            }
        }
        .padding()
        .background(
            contact.manualAlertActive ? Color.red.opacity(0.1) :
            contact.isNonResponsive ? Color.yellow.opacity(0.15) :
            // Only show blue background for responders with incoming pings when in responder context
            context == .responder && contact.isResponder && contact.hasIncomingPing ? Color.blue.opacity(0.1) :
            Color(UIColor.systemGray6)
        )
        .cornerRadius(12)
        .standardShadow(radius: 2, y: 1)
        .onTapGesture(perform: onTap)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: 16) {
        ContactCardView(
            contact: Contact(
                name: "Sarah Chen",
                phone: "555-123-4567",
                note: "Emergency contact",
                isResponder: true,
                isDependent: false
            ),
            statusText: "2d 5h",
            context: .responder
        )

        // Example with empty status text - name should be vertically centered
        ContactCardView(
            contact: Contact(
                name: "James Wilson",
                phone: "555-987-6543",
                note: "Friend",
                isResponder: true,
                isDependent: false
            ),
            statusText: "",
            context: .responder
        )

        ContactCardView(
            contact: Contact(
                name: "Robert Taylor",
                phone: "555-222-0001",
                note: "Solo backpacker",
                isResponder: false,
                isDependent: true,
                manualAlertActive: true
            ),
            statusColor: .red,
            statusText: "Alert Active",
            context: .dependent
        )

        // Responder with incoming ping - should have blue background in responder context
        ContactCardView(
            contact: Contact(
                name: "Daniel Kim",
                phone: "555-444-3333",
                note: "Mountain guide",
                isResponder: true,
                isDependent: false,
                hasIncomingPing: true,
                incomingPingTimestamp: Date().addingTimeInterval(-1800)
            ),
            statusColor: .blue,
            statusText: "Pinged 30m ago",
            context: .responder,
            trailingContent: {
                Circle()
                    .fill(Color(UIColor.systemBackground))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "bell.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 18))
                    )
            }
        )

        // Dual role contact with incoming ping - should NOT have blue background in dependent context
        ContactCardView(
            contact: Contact(
                name: "Mia Anderson",
                phone: "555-777-8888",
                note: "Dual role contact",
                isResponder: true,
                isDependent: true,
                hasIncomingPing: true,
                incomingPingTimestamp: Date().addingTimeInterval(-3600)
            ),
            statusColor: .secondary,
            statusText: "1d 12h",
            context: .dependent
        )
    }
    .padding()
}
