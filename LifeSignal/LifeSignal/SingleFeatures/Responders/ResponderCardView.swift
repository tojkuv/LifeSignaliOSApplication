import SwiftUI
import UIKit
import ComposableArchitecture

/// A SwiftUI view for displaying a responder card
struct ResponderCardView: View {
    /// The contact to display
    let contact: Contact
    
    /// The store for the contacts feature
    let store: StoreOf<ContactsFeature>
    
    /// State for UI controls
    @State private var showContactDetails = false
    
    var statusText: String {
        if contact.hasIncomingPing, let pingTime = contact.incomingPingTimestamp {
            return "Pinged \(TimeManager.shared.formatTimeAgo(pingTime))"
        }
        return ""
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
                            .foregroundColor(contact.hasIncomingPing ? .blue : .secondary)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
                
                Spacer()
                
                // Trailing content (respond to ping button)
                if contact.hasIncomingPing {
                    Button(action: {
                        viewStore.send(.respondToPing(id: contact.id))
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
            }
            .padding()
            .background(
                contact.isResponder && contact.hasIncomingPing ? Color.blue.opacity(0.1) :
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
    ResponderCardView(
        contact: Contact(
            id: "test",
            name: "Jane Smith",
            isResponder: true,
            hasIncomingPing: true,
            incomingPingTimestamp: Date().addingTimeInterval(-1800)
        ),
        store: Store(initialState: ContactsFeature.State()) {
            ContactsFeature()
        }
    )
    .padding()
}
