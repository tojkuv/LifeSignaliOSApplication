import SwiftUI
import ComposableArchitecture
import UIKit

/// A SwiftUI view for displaying responders using TCA
struct RespondersView: View {
    /// The store for the responders feature
    @Bindable var store: StoreOf<RespondersFeature>

    /// Get the sorted responders from the contacts feature
    private var sortedResponders: [ContactData] {
        store.sortedResponders(store.state)
    }

    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if store.contacts.responders.isEmpty {
                        Text("No responders yet")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    } else {
                        // Use the sorted responders from the feature
                        ForEach(sortedResponders) { responder in
                            ResponderCardView(
                                contact: responder,
                                store: store
                            )
                        }
                    }
                }
                .padding()
                .padding(.bottom, 30)
            }
            .background(Color(.systemBackground))
        }
        .navigationTitle("Responders")
        .toolbar {
            // Respond to All button (only shown when there are pending pings)
            if store.pendingPingsCount > 0 {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        store.send(.contacts(.respondToAllPings))
                    } label: {
                        Text("Respond to All")
                            .foregroundColor(.blue)
                    }
                }
            }

            // Add button
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    store.send(.qrScanner(.setShowScanner(true)))
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                        .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $store.qrScanner.showScanner.sending(\.qrScanner.setShowScanner)) {
            // Get the user store from the environment
            @Environment(\.store) var appStore
            if let userStore = appStore.scope(state: \.user, action: \.user) {
                QRScannerView(
                    store: store.scope(state: \.qrScanner, action: \.qrScanner),
                    addContactStore: store.scope(state: \.addContact, action: \.addContact),
                    userStore: userStore
                )
            }
        }
        .sheet(isPresented: $store.addContact.isSheetPresented.sending(\.addContact.setSheetPresented)) {
            AddContactSheet(store: store.scope(state: \.addContact, action: \.addContact))
        }
        .alert(
            "Contact Added",
            isPresented: $store.alerts.contactAdded.sending(\.setContactAddedAlert)
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The contact has been added to your responders.")
        }
        .alert(
            "Contact Already Exists",
            isPresented: $store.alerts.contactExists.sending(\.setContactExistsAlert)
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This contact is already in your contacts list.")
        }
        .alert(
            "Error Adding Contact",
            isPresented: $store.alerts.contactError.sending(\.setContactErrorAlert)
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(store.alerts.contactErrorMessage)
        }
        .sheet(isPresented: $store.contactDetails.isActive.sending(\.contactDetails.setActive)) {
            // Use the contact details store directly
            ContactDetailsSheet(
                store: store.scope(state: \.contactDetails, action: \.contactDetails)
            )
        }
        .onAppear {
            store.send(.onAppear)
        }
        .tabItem {
            Label("Responders", systemImage: "person.2.fill")
        }
        .badge(store.pendingPingsCount)
    }
}
