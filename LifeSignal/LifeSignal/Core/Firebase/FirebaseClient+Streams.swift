import Foundation
import ComposableArchitecture
import FirebaseFirestore

extension FirebaseClient {
    /// Monitor a document and send actions when it changes
    /// - Parameters:
    ///   - collection: The collection name
    ///   - documentId: The document ID
    ///   - includeMetadata: Whether to include metadata changes
    ///   - onInitial: The action to send when the initial document is received
    ///   - onUpdate: The action to send when the document is updated
    ///   - onError: The action to send when an error occurs
    /// - Returns: An effect that sends actions when the document changes
    func monitorDocumentEffect<Action>(
        collection: String,
        documentId: String,
        includeMetadata: Bool = false,
        onInitial: @escaping (DocumentSnapshot) -> Action,
        onUpdate: @escaping (DocumentSnapshot) -> Action,
        onError: @escaping (Error) -> Action
    ) -> Effect<Action> {
        let documentStream = self.monitorDocument(
            collection: collection,
            documentId: documentId,
            includeMetadata: includeMetadata
        )
        
        return .run { send in
            var isInitial = true
            
            for await snapshot in documentStream {
                do {
                    if isInitial {
                        await send(onInitial(snapshot))
                        isInitial = false
                    } else {
                        await send(onUpdate(snapshot))
                    }
                } catch {
                    await send(onError(error))
                }
            }
        }
    }
    
    /// Monitor a collection and send actions when it changes
    /// - Parameters:
    ///   - collection: The collection name
    ///   - filters: Optional filters to apply
    ///   - orderBy: Optional ordering to apply
    ///   - limit: Optional limit to apply
    ///   - includeMetadata: Whether to include metadata changes
    ///   - onInitial: The action to send when the initial collection is received
    ///   - onUpdate: The action to send when the collection is updated
    ///   - onError: The action to send when an error occurs
    /// - Returns: An effect that sends actions when the collection changes
    func monitorCollectionEffect<Action>(
        collection: String,
        filters: [(field: String, operation: String, value: Any)]? = nil,
        orderBy: [(field: String, descending: Bool)]? = nil,
        limit: Int? = nil,
        includeMetadata: Bool = false,
        onInitial: @escaping (QuerySnapshot) -> Action,
        onUpdate: @escaping (QuerySnapshot) -> Action,
        onError: @escaping (Error) -> Action
    ) -> Effect<Action> {
        let collectionStream = self.monitorCollection(
            collection: collection,
            filters: filters,
            orderBy: orderBy,
            limit: limit,
            includeMetadata: includeMetadata
        )
        
        return .run { send in
            var isInitial = true
            
            for await snapshot in collectionStream {
                do {
                    if isInitial {
                        await send(onInitial(snapshot))
                        isInitial = false
                    } else {
                        await send(onUpdate(snapshot))
                    }
                } catch {
                    await send(onError(error))
                }
            }
        }
    }
    
    /// Monitor a user document and send actions when it changes
    /// - Parameters:
    ///   - userId: The user ID
    ///   - includeMetadata: Whether to include metadata changes
    ///   - onInitial: The action to send when the initial user document is received
    ///   - onUpdate: The action to send when the user document is updated
    ///   - onError: The action to send when an error occurs
    /// - Returns: An effect that sends actions when the user document changes
    func monitorUserDocumentEffect<Action>(
        userId: String,
        includeMetadata: Bool = false,
        onInitial: @escaping (DocumentSnapshot) -> Action,
        onUpdate: @escaping (DocumentSnapshot) -> Action,
        onError: @escaping (Error) -> Action
    ) -> Effect<Action> {
        let userStream = self.monitorUserDocument(
            userId: userId,
            includeMetadata: includeMetadata
        )
        
        return .run { send in
            var isInitial = true
            
            for await snapshot in userStream {
                do {
                    if isInitial {
                        await send(onInitial(snapshot))
                        isInitial = false
                    } else {
                        await send(onUpdate(snapshot))
                    }
                } catch {
                    await send(onError(error))
                }
            }
        }
    }
    
    /// Monitor a user's contacts and send actions when they change
    /// - Parameters:
    ///   - userId: The user ID
    ///   - includeMetadata: Whether to include metadata changes
    ///   - onInitial: The action to send when the initial contacts are received
    ///   - onUpdate: The action to send when the contacts are updated
    ///   - onError: The action to send when an error occurs
    /// - Returns: An effect that sends actions when the contacts change
    func monitorUserContactsEffect<Action>(
        userId: String,
        includeMetadata: Bool = false,
        onInitial: @escaping ([DocumentSnapshot]) -> Action,
        onUpdate: @escaping ([DocumentSnapshot]) -> Action,
        onError: @escaping (Error) -> Action
    ) -> Effect<Action> {
        let contactsStream = self.monitorUserContacts(
            userId: userId,
            includeMetadata: includeMetadata
        )
        
        return .run { send in
            var isInitial = true
            
            for await snapshots in contactsStream {
                do {
                    if isInitial {
                        await send(onInitial(snapshots))
                        isInitial = false
                    } else {
                        await send(onUpdate(snapshots))
                    }
                } catch {
                    await send(onError(error))
                }
            }
        }
    }
}
