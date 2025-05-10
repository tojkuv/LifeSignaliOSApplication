import SwiftUI
import UIKit

/// Enum to specify the context in which a contact card is being displayed
enum ContactCardContext {
    case responder
    case dependent
}

/// A reusable card view for displaying contact information
struct ContactCardView: View {
    let contact: ContactReference
    let statusColor: Color
    let statusText: String
    let trailingContent: AnyView?
    let onTap: () -> Void
    let context: ContactCardContext

    init(
        contact: ContactReference,
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