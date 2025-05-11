import Foundation
import ComposableArchitecture
import FirebaseFirestore

/// Feature for streaming user document data from Firebase
@Reducer
struct UserStreamFeature {
    /// Cancellation IDs for long-running effects
    enum CancelID: Hashable {
        case userDocumentStream
    }

    /// The state of the user stream feature
    struct State: Equatable, Sendable {
        /// User document data
        var userData: [String: Any]?
        
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
            
            // Compare userData (if both are nil, they're equal)
            if lhs.userData == nil && rhs.userData == nil {
                return true
            }
            
            // If one is nil and the other isn't, they're not equal
            if lhs.userData == nil || rhs.userData == nil {
                return false
            }
            
            // Compare the keys in userData
            guard lhs.userData!.keys.count == rhs.userData!.keys.count else { return false }
            
            // This is a simplified comparison - in a real app, you might want to compare specific fields
            return true
        }
    }

    /// Actions that can be performed on the user stream feature
    enum Action: Equatable, Sendable {
        /// Start streaming user document
        case startStream(userId: String)
        /// User document updated
        case userDocumentUpdated([String: Any])
        /// Stop streaming user document
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
                        let userRef = db.collection(FirestoreConstants.Collections.users).document(userId)
                        
                        // Set up listener options
                        let options = SnapshotListenOptions()
                            .withIncludeMetadataChanges(false)
                        
                        // Create a stream of user document snapshots
                        for await snapshot in AsyncStream<DocumentSnapshot> { continuation in
                            let listener = userRef.addSnapshotListener(options: options) { snapshot, error in
                                if let error = error {
                                    print("Error listening for user document changes: \(error.localizedDescription)")
                                    Task { await send(.streamError(error.localizedDescription)) }
                                    return
                                }
                                
                                if let snapshot = snapshot {
                                    continuation.yield(snapshot)
                                }
                            }
                            
                            continuation.onTermination = { _ in
                                print("Terminating user document listener for user \(userId)")
                                listener.remove()
                            }
                        } {
                            if let data = snapshot.data() {
                                await send(.userDocumentUpdated(data))
                            } else {
                                await send(.streamError("Document exists but has no data"))
                            }
                        }
                    } catch {
                        await send(.streamError(error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.userDocumentStream)
                
            case let .userDocumentUpdated(data):
                state.isLoading = false
                state.userData = data
                return .none
                
            case .stopStream:
                return .cancel(id: CancelID.userDocumentStream)
                
            case let .streamError(message):
                state.isLoading = false
                state.error = NSError(domain: "UserStreamFeature", code: 500, userInfo: [NSLocalizedDescriptionKey: message])
                return .none
            }
        }
    }
}

// MARK: - Dependency Registration

/// Register UserStreamFeature as a dependency
private enum UserStreamFeatureKey: DependencyKey {
    static let liveValue = UserStreamFeature()
}

extension DependencyValues {
    var userStreamFeature: UserStreamFeature {
        get { self[UserStreamFeatureKey.self] }
        set { self[UserStreamFeatureKey.self] = newValue }
    }
}
