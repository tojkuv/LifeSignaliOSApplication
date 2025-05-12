import Foundation
import FirebaseFirestore
import OSLog

/// Helper for creating Firestore streams
enum FirestoreStreamHelper {
    /// Creates an AsyncStream for a Firestore document
    /// - Parameters:
    ///   - path: The document path
    ///   - logger: The logger to use
    ///   - transform: A closure that transforms the document data into the desired type
    /// - Returns: An AsyncStream of TaskResult with the transformed data
    static func documentStream<T>(
        path: String,
        logger: Logger,
        transform: @escaping (DocumentSnapshot) throws -> T
    ) -> AsyncStream<TaskResult<T>> {
        AsyncStream { continuation in
            let db = Firestore.firestore()
            let docRef = db.document(path)

            // Set up listener options with metadata changes to handle cache/server state
            let options = SnapshotListenOptions()
                .withIncludeMetadataChanges(true)

            // Create the listener
            let listener = docRef.addSnapshotListener(options: options) { snapshot, error in
                if let error = error {
                    logger.error("Error listening for document changes: \(error.localizedDescription)")
                    continuation.yield(.failure(FirebaseError.from(error)))
                    return
                }

                guard let snapshot = snapshot else {
                    continuation.yield(.failure(FirebaseError.documentNotFound))
                    return
                }

                // Log metadata information for debugging
                if snapshot.metadata.hasPendingWrites {
                    logger.debug("Document snapshot has pending writes (local changes not yet committed to server)")
                }

                if snapshot.metadata.isFromCache {
                    logger.debug("Document snapshot is from cache (not from server)")
                }

                // Always process document snapshots, but log the source
                if !snapshot.metadata.hasPendingWrites && !snapshot.metadata.isFromCache {
                    logger.debug("Processing document snapshot from server")
                } else if snapshot.metadata.isFromCache {
                    logger.debug("Processing initial document snapshot from cache")
                }

                do {
                    let result = try transform(snapshot)
                    continuation.yield(.success(result))
                } catch {
                    logger.error("Error processing document data: \(error.localizedDescription)")
                    continuation.yield(.failure(FirebaseError.from(error)))
                }
            }

            // Set up cancellation
            continuation.onTermination = { _ in
                logger.debug("Terminating document listener for path: \(path)")
                listener.remove()
            }
        }
    }

    /// Creates an AsyncStream for a Firestore collection
    /// - Parameters:
    ///   - path: The collection path
    ///   - logger: The logger to use
    ///   - transform: A closure that transforms the query snapshot into the desired type
    /// - Returns: An AsyncStream of TaskResult with the transformed data
    static func collectionStream<T>(
        path: String,
        logger: Logger,
        transform: @escaping (QuerySnapshot) async throws -> T
    ) -> AsyncStream<TaskResult<T>> {
        AsyncStream { continuation in
            let db = Firestore.firestore()
            let collectionRef = db.collection(path)

            // Set up listener options with metadata changes to handle cache/server state
            let options = SnapshotListenOptions()
                .withIncludeMetadataChanges(true)

            // Create the listener
            let listener = collectionRef.addSnapshotListener(options: options) { snapshot, error in
                if let error = error {
                    logger.error("Error listening for collection changes: \(error.localizedDescription)")
                    continuation.yield(.failure(FirebaseError.from(error)))
                    return
                }

                guard let snapshot = snapshot else {
                    continuation.yield(.failure(FirebaseError.documentNotFound))
                    return
                }

                // Log metadata information for debugging
                if snapshot.metadata.hasPendingWrites {
                    logger.debug("Snapshot has pending writes (local changes not yet committed to server)")
                }

                if snapshot.metadata.isFromCache {
                    logger.debug("Snapshot is from cache (not from server)")
                }

                // Only emit changes that are not just metadata updates
                // This prevents duplicate emissions when data is first read from cache and then from server
                if !snapshot.metadata.hasPendingWrites && !snapshot.metadata.isFromCache {
                    logger.debug("Emitting snapshot from server with \(snapshot.documents.count) documents")
                } else if snapshot.metadata.isFromCache {
                    // For cache data, only emit if it's the first load (no previous data)
                    logger.debug("Emitting initial snapshot from cache with \(snapshot.documents.count) documents")
                }

                // Process data in a Task to allow for async operations
                Task {
                    do {
                        let result = try await transform(snapshot)
                        continuation.yield(.success(result))
                    } catch {
                        logger.error("Error processing collection data: \(error.localizedDescription)")
                        continuation.yield(.failure(FirebaseError.from(error)))
                    }
                }
            }

            // Set up cancellation
            continuation.onTermination = { _ in
                logger.debug("Terminating collection listener for path: \(path)")
                listener.remove()
            }
        }
    }
}
