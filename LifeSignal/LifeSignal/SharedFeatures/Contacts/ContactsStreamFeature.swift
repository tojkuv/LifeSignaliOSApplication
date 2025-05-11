import Foundation
import ComposableArchitecture
import FirebaseFirestore

/// Feature for streaming contacts subcollection data from Firebase
@Reducer
struct ContactsStreamFeature {
    /// Cancellation IDs for long-running effects
    enum CancelID: Hashable {
        case contactsStream
    }

    /// The state of the contacts stream feature
    struct State: Equatable, Sendable {
        /// Contacts data (document snapshots)
        var contactsData: [DocumentSnapshot] = []
        
        /// Document changes for tracking additions/removals
        var changes: [DocumentChange]?
        
        /// Loading state
        var isLoading: Bool = false
        
        /// Error state
        var error: Error?
        
        /// Custom Equatable implementation to handle Error? property
        static func == (lhs: State, rhs: State) -> Bool {
            // Compare loading state
            guard lhs.isLoading == rhs.isLoading else { return false }
            
            // Compare error state (just check if both are nil or both are non-nil)
            guard (lhs.error != nil) == (rhs.error != nil) else { return false }
            
            // Compare contactsData count
            guard lhs.contactsData.count == rhs.contactsData.count else { return false }
            
            // This is a simplified comparison - in a real app, you might want to compare document IDs
            return true
        }
    }

    /// Actions that can be performed on the contacts stream feature
    enum Action: Equatable, Sendable {
        /// Start streaming contacts subcollection
        case startStream(userId: String)
        /// Contacts updated
        case contactsUpdated(contacts: [DocumentSnapshot], changes: [DocumentChange]?)
        /// Stop streaming contacts
        case stopStream
        /// Stream error
        case streamError(String)
    }

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .startStream(userId):
                state.isLoading = true
                return .run { send in
                    do {
                        let db = Firestore.firestore()
                        let contactsPath = "\(FirestoreConstants.Collections.users)/\(userId)/\(FirestoreConstants.Collections.contacts)"
                        let contactsCollectionRef = db.collection(contactsPath)
                        
                        // Set up listener options
                        let options = SnapshotListenOptions()
                            .withIncludeMetadataChanges(false)
                        
                        // Track previous contacts for change detection
                        var previousContactIds = Set<String>()
                        
                        // Create a stream of contacts snapshots
                        for await _ in AsyncStream<Void> { continuation in
                            let listener = contactsCollectionRef.addSnapshotListener(options: options) { snapshot, error in
                                if let error = error {
                                    print("Error listening for contacts changes: \(error.localizedDescription)")
                                    Task { await send(.streamError(error.localizedDescription)) }
                                    return
                                }
                                
                                guard let snapshot = snapshot else {
                                    Task { await send(.contactsUpdated(contacts: [], changes: nil)) }
                                    return
                                }
                                
                                // Get the current set of contact IDs
                                let currentContactIds = Set(snapshot.documents.map { $0.documentID })
                                
                                // Detect changes
                                var changes: [DocumentChange]? = nil
                                if !previousContactIds.isEmpty {
                                    changes = []
                                    
                                    // Find added contacts
                                    let addedContactIds = currentContactIds.subtracting(previousContactIds)
                                    for contactId in addedContactIds {
                                        if let document = snapshot.documents.first(where: { $0.documentID == contactId }) {
                                            changes?.append(DocumentChange(type: .added, document: document))
                                        }
                                    }
                                    
                                    // Find removed contacts
                                    let removedContactIds = previousContactIds.subtracting(currentContactIds)
                                    for contactId in removedContactIds {
                                        // Create a placeholder document for removed contacts
                                        let data: [String: Any] = ["id": contactId]
                                        let document = DocumentSnapshot(reference: contactsCollectionRef.document(contactId), data: data)
                                        changes?.append(DocumentChange(type: .removed, document: document))
                                    }
                                }
                                
                                // Update previous contacts for next change detection
                                previousContactIds = currentContactIds
                                
                                Task {
                                    await send(.contactsUpdated(contacts: snapshot.documents, changes: changes))
                                }
                                
                                continuation.yield(())
                            }
                            
                            continuation.onTermination = { _ in
                                print("Terminating contacts collection listener for user \(userId)")
                                listener.remove()
                            }
                        } {
                            // This is just to keep the stream alive
                        }
                    } catch {
                        await send(.streamError(error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.contactsStream)
                
            case let .contactsUpdated(contacts, changes):
                state.isLoading = false
                state.contactsData = contacts
                state.changes = changes
                return .none
                
            case .stopStream:
                return .cancel(id: CancelID.contactsStream)
                
            case let .streamError(message):
                state.isLoading = false
                state.error = NSError(domain: "ContactsStreamFeature", code: 500, userInfo: [NSLocalizedDescriptionKey: message])
                return .none
            }
        }
    }
}

// MARK: - Dependency Registration

/// Register ContactsStreamFeature as a dependency
private enum ContactsStreamFeatureKey: DependencyKey {
    static let liveValue = ContactsStreamFeature()
}

extension DependencyValues {
    var contactsStreamFeature: ContactsStreamFeature {
        get { self[ContactsStreamFeatureKey.self] }
        set { self[ContactsStreamFeatureKey.self] = newValue }
    }
}
