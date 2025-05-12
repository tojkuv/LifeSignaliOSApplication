import SwiftUI
import UIKit
import ComposableArchitecture
import LifeSignal

/// A SwiftUI view for displaying a responder card using TCA
struct ResponderCardView: View {
    /// The contact to display
    let contact: ContactData

    /// The store for the responders feature
    @Bindable var store: StoreOf<RespondersFeature>

    var body: some View {
        // Use the contact passed directly to the view
        let currentContact = contact

        HStack(spacing: 12) {
            AvatarView(name: currentContact.name)

            VStack(alignment: .leading, spacing: 4) {
                Text(currentContact.name)
                    .font(.body)
                    .foregroundColor(.primary)

                if currentContact.hasIncomingPing, let formattedTime = currentContact.formattedIncomingPingTime {
                    Text("Pinged \(formattedTime)")
                        .font(.footnote)
                        .foregroundColor(.blue)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)

            Spacer()

            // Trailing content (respond to ping button)
            if currentContact.hasIncomingPing {
                Button {
                    store.send(.contacts(.respondToPing(id: currentContact.id)))
                } label: {
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
                .accessibilityLabel("Respond to ping from \(currentContact.name)")
            }
        }
        .padding()
        .background(
            currentContact.isResponder && currentContact.hasIncomingPing ? Color.blue.opacity(0.1) :
            Color(UIColor.systemGray6)
        )
        .cornerRadius(12)
        .standardShadow(radius: 2, y: 1)
        .onTapGesture {
            // Use the ContactDetailsSheetFeature through the parent store
            store.send(.contactDetails(.setContact(currentContact)))
            store.send(.contactDetails(.setActive(true)))
        }
        .disabled(store.isLoading)
    }
}

/// Extension for ResponderCardView with convenience initializers
extension ResponderCardView {
    /// Initialize with contact and store
    /// - Parameters:
    ///   - contact: The contact to display
    ///   - store: The store for the responders feature
    init(
        contact: ContactData,
        store: StoreOf<RespondersFeature>
    ) {
        self.contact = contact
        self._store = Bindable(wrappedValue: store)
    }
}
