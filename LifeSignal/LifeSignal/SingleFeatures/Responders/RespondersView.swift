import SwiftUI
import ComposableArchitecture
import UIKit

/// A SwiftUI view for displaying responders using TCA
struct RespondersView: View {
    /// The store for the contacts feature
    let store: StoreOf<ContactsFeature>

    /// State for UI controls
    @State private var showQRScanner = false
    @State private var pendingScannedCode: String? = nil
    @State private var showContactAddedAlert = false
    @State private var showContactExistsAlert = false
    @State private var showContactErrorAlert = false
    @State private var contactErrorMessage = ""
    @State private var refreshID = UUID() // Used to force refresh the view

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack {
                if viewStore.isLoading {
                    // Show loading indicator
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Loading responders...")
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if viewStore.responders.isEmpty {
                                Text("No responders yet")
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 40)
                            } else {
                                // Use the sorted responders
                                ForEach(sortedResponders(viewStore.responders)) { responder in
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
            }
            .navigationTitle("Responders")
            .toolbar {
                // Respond to All button (only shown when there are pending pings)
                if viewStore.pendingPingsCount > 0 {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            viewStore.send(.respondToAllPings)
                        }) {
                            Text("Respond to All")
                                .foregroundColor(.blue)
                        }
                    }
                }

                // Add button
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showQRScanner = true
                    }) {
                        Image(systemName: "qrcode.viewfinder")
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showQRScanner, onDismiss: {
                if let qrCode = pendingScannedCode {
                    // Use the scanned QR code to look up the contact ID via Firebase function
                    // The QR code is not the contact ID itself
                    let sheet = AddContactSheet(
                        qrCode: qrCode,
                        store: store,
                        onAdd: { isResponder, isDependent in
                            showContactAddedAlert = true
                        },
                        onClose: { }
                    )

                    // Present the sheet
                    let hostingController = UIHostingController(rootView: sheet)
                    UIApplication.shared.windows.first?.rootViewController?.present(hostingController, animated: true)

                    pendingScannedCode = nil
                }
            }) {
                QRScannerView(
                    onScanned: { result in
                        pendingScannedCode = result
                    }
                )
            }
            .alert("Contact Added", isPresented: $showContactAddedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The contact has been added to your responders.")
            }
            .alert("Contact Already Exists", isPresented: $showContactExistsAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This contact is already in your contacts list.")
            }
            .alert("Error Adding Contact", isPresented: $showContactErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(contactErrorMessage)
            }
            .onAppear {
                viewStore.send(.loadContacts)
            }
        }
    }

    /// Sort responders with pending pings first, then alphabetically
    /// - Parameter responders: The list of responders to sort
    /// - Returns: A sorted list of responders
    private func sortedResponders(_ responders: [Contact]) -> [Contact] {
        // Partition into pending pings and others
        let (pendingPings, others) = responders.partitioned { $0.hasIncomingPing }

        // Sort pending pings by most recent ping timestamp
        let sortedPendingPings = pendingPings.sorted {
            ($0.incomingPingTimestamp ?? .distantPast) > ($1.incomingPingTimestamp ?? .distantPast)
        }

        // Sort others alphabetically
        let sortedOthers = others.sorted { $0.name < $1.name }

        // Combine with pending pings at the top
        return sortedPendingPings + sortedOthers
    }
}



/// Extension to add partitioning to arrays
extension Array {
    /// Partition an array into two arrays based on a predicate
    /// - Parameter predicate: The predicate to use for partitioning
    /// - Returns: A tuple containing the elements that satisfy the predicate and those that don't
    func partitioned(by predicate: (Element) -> Bool) -> ([Element], [Element]) {
        var matching: [Element] = []
        var nonMatching: [Element] = []

        for element in self {
            if predicate(element) {
                matching.append(element)
            } else {
                nonMatching.append(element)
            }
        }

        return (matching, nonMatching)
    }
}

#Preview {
    NavigationStack {
        RespondersView(
            store: Store(initialState: ContactsFeature.State()) {
                ContactsFeature()
            }
        )
    }
}
