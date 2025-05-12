import SwiftUI
import ComposableArchitecture
import UIKit

/// A SwiftUI view for displaying dependents using TCA
struct DependentsView: View {
    /// The store for the dependents feature
    @Bindable var store: StoreOf<DependentsFeature>

    /// Get the sorted dependents from the contacts feature
    private var sortedDependents: [ContactData] {
        store.sortedDependents(store.state)
    }

    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if store.contacts.dependents.isEmpty {
                        Text("No dependents yet")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    } else {
                        // Use the sorted dependents
                        ForEach(sortedDependents) { dependent in
                            DependentCardView(
                                dependent: dependent,
                                onTap: { store.send(.selectContact(dependent)) },
                                onPing: { store.send(.contacts(.pingDependent(id: dependent.id))) },
                                onClearPing: { store.send(.contacts(.clearPing(id: dependent.id))) },
                                isDisabled: store.isLoading
                            )
                        }
                    }
                }
                .padding()
                .padding(.bottom, 30)
            }
            .background(Color(.systemBackground))
        }
        .navigationTitle("Dependents")
        .toolbar {
            // Add button
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    store.send(.setShowQRScanner(true))
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
                    contactsStore: appStore.scope(state: \.contacts, action: \.contacts),
                    userStore: userStore
                )
            }
        }
        .sheet(isPresented: $store.addContact.isSheetPresented.sending(\.addContact.setSheetPresented)) {
            AddContactSheet(
                store: store.scope(state: \.addContact, action: \.addContact)
            )
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
            Label("Dependents", systemImage: "person.3.fill")
        }
        .badge(store.nonResponsiveDependentsCount)
    }
}

/// Extension for DependentsView with convenience initializers
extension DependentsView {
    /// Initialize with a store for the dependents feature
    /// - Parameter store: The store for the dependents feature
    init(store: StoreOf<DependentsFeature>) {
        self._store = Bindable(wrappedValue: store)
    }
}

