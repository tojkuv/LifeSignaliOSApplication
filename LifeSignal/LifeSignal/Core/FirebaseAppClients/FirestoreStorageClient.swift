import Foundation
@preconcurrency import FirebaseFirestore
import DependenciesMacros
import Dependencies
import XCTestDynamicOverlay
import OSLog

/// A client for interacting with Firestore storage
@DependencyClient
struct FirestoreStorageClient: Sendable {
    // MARK: - Document Operations

    /// Gets a document from Firestore and transforms it to the desired type
    var getDocument: @Sendable <T>(
        path: String,
        transform: @Sendable @escaping (DocumentSnapshot) throws -> T
    ) async throws -> T = { _, _ in
        throw FirebaseError.operationFailed
    }

    /// Sets document data at the specified path
    var setDocument: @Sendable (
        path: String,
        data: [String: Any],
        merge: Bool
    ) async throws -> Void = { _, _, _ in
        throw FirebaseError.operationFailed
    }

    /// Updates document data at the specified path
    var updateDocument: @Sendable (
        path: String,
        data: [String: Any]
    ) async throws -> Void = { _, _ in
        throw FirebaseError.operationFailed
    }

    /// Deletes a document at the specified path
    var deleteDocument: @Sendable (
        path: String
    ) async throws -> Void = { _ in
        throw FirebaseError.operationFailed
    }

    // MARK: - Collection Operations

    /// Gets all documents in a collection and transforms them to the desired type
    var getCollection: @Sendable <T>(
        path: String,
        transform: @Sendable @escaping (QueryDocumentSnapshot) throws -> T
    ) async throws -> [T] = { _, _ in
        throw FirebaseError.operationFailed
    }

    /// Adds a document to a collection
    var addDocument: @Sendable (
        path: String,
        data: [String: Any]
    ) async throws -> String = { _, _ in
        throw FirebaseError.operationFailed
    }

    // MARK: - Batch Operations

    /// Performs a batch write operation
    var performBatchOperation: @Sendable (
        operations: @Sendable @escaping (WriteBatch) -> Void
    ) async throws -> Void = { _ in
        throw FirebaseError.operationFailed
    }

    // MARK: - Transaction Operations

    /// Performs a transaction operation
    var performTransaction: @Sendable <T>(
        transaction: @Sendable @escaping (Transaction) throws -> T
    ) async throws -> T = { _ in
        throw FirebaseError.operationFailed
    }

    // MARK: - Stream Operations

    /// Creates an AsyncStream for a Firestore document
    var documentStream: @Sendable <T>(
        path: String,
        transform: @Sendable @escaping (DocumentSnapshot) throws -> T
    ) -> AsyncStream<T> = { _, _ in
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    /// Creates an AsyncStream for a Firestore collection
    var collectionStream: @Sendable <T>(
        path: String,
        transform: @Sendable @escaping (QuerySnapshot) async throws -> T
    ) -> AsyncStream<T> = { _, _ in
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}

// MARK: - Live Implementation

extension FirestoreStorageClient: DependencyKey {
    static let liveValue = Self(
        getDocument: { path, transform in
            FirebaseLogger.firestore.debug("Getting document at path: \(path)")

            let db = Firestore.firestore()
            let docRef = db.document(path)
            let snapshot = try await docRef.getDocument()

            guard snapshot.exists else {
                FirebaseLogger.firestore.error("Document not found at path: \(path)")
                throw FirebaseError.documentNotFound
            }

            do {
                let result = try transform(snapshot)
                FirebaseLogger.firestore.debug("Successfully retrieved and transformed document at path: \(path)")
                return result
            } catch {
                FirebaseLogger.firestore.error("Error transforming document data: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        setDocument: { path, data, merge in
            FirebaseLogger.firestore.debug("Setting document at path: \(path), merge: \(merge)")

            let db = Firestore.firestore()
            let docRef = db.document(path)

            if merge {
                try await docRef.setData(data, merge: true)
                FirebaseLogger.firestore.info("Successfully merged document data at path: \(path)")
            } else {
                try await docRef.setData(data)
                FirebaseLogger.firestore.info("Successfully set document data at path: \(path)")
            }
        },

        updateDocument: { path, data in
            FirebaseLogger.firestore.debug("Updating document at path: \(path)")

            let db = Firestore.firestore()
            let docRef = db.document(path)

            try await docRef.updateData(data)
            FirebaseLogger.firestore.info("Successfully updated document at path: \(path)")
        },

        deleteDocument: { path in
            FirebaseLogger.firestore.debug("Deleting document at path: \(path)")

            let db = Firestore.firestore()
            let docRef = db.document(path)

            try await docRef.delete()
            FirebaseLogger.firestore.info("Successfully deleted document at path: \(path)")
        },

        getCollection: { path, transform in
            FirebaseLogger.firestore.debug("Getting collection at path: \(path)")

            let db = Firestore.firestore()
            let collectionRef = db.collection(path)
            let snapshot = try await collectionRef.getDocuments()

            FirebaseLogger.firestore.debug("Retrieved \(snapshot.documents.count) documents from collection at path: \(path)")

            var results: [T] = []
            var transformErrors: [Error] = []

            for document in snapshot.documents {
                do {
                    let result = try transform(document)
                    results.append(result)
                } catch {
                    FirebaseLogger.firestore.error("Error transforming document \(document.documentID): \(error.localizedDescription)")
                    transformErrors.append(error)
                    // Continue processing other documents instead of failing the entire operation
                }
            }

            // If we couldn't transform any documents but had errors, throw the first error
            if results.isEmpty && !transformErrors.isEmpty {
                throw FirebaseError.from(transformErrors[0])
            }

            FirebaseLogger.firestore.debug("Successfully transformed \(results.count) documents from collection at path: \(path)")
            return results
        },

        addDocument: { path, data in
            FirebaseLogger.firestore.debug("Adding document to collection at path: \(path)")

            let db = Firestore.firestore()
            let collectionRef = db.collection(path)

            let documentRef = try await collectionRef.addDocument(data: data)
            FirebaseLogger.firestore.info("Successfully added document with ID: \(documentRef.documentID) to collection at path: \(path)")

            return documentRef.documentID
        },

        performBatchOperation: { operations in
            FirebaseLogger.firestore.debug("Starting batch operation")

            let db = Firestore.firestore()
            let batch = db.batch()

            operations(batch)

            try await batch.commit()
            FirebaseLogger.firestore.info("Successfully committed batch operation")
        },

        performTransaction: { transaction in
            FirebaseLogger.firestore.debug("Starting transaction")

            let db = Firestore.firestore()
            let result = try await db.runTransaction { firestoreTransaction -> T in
                do {
                    return try transaction(firestoreTransaction)
                } catch {
                    FirebaseLogger.firestore.error("Error in transaction: \(error.localizedDescription)")
                    throw error
                }
            }

            FirebaseLogger.firestore.info("Successfully completed transaction")
            return result
        },

        documentStream: { path, transform in
            FirebaseLogger.firestore.debug("Creating document stream for path: \(path)")

            return AsyncStream<T> { continuation in
                let db = Firestore.firestore()
                let docRef = db.document(path)

                // Set up listener options with metadata changes to handle cache/server state
                let options = SnapshotListenOptions()
                    .withIncludeMetadataChanges(true)

                // Create the listener
                let listener = docRef.addSnapshotListener(options: options) { snapshot, error in
                    if let error = error {
                        FirebaseLogger.firestore.error("Error listening for document changes: \(error.localizedDescription)")
                        // We don't emit errors in the stream, just log them
                        return
                    }

                    guard let snapshot = snapshot else {
                        FirebaseLogger.firestore.error("Document snapshot is nil")
                        return
                    }

                    // Log metadata information for debugging
                    if snapshot.metadata.hasPendingWrites {
                        FirebaseLogger.firestore.debug("Document snapshot has pending writes (local changes not yet committed to server)")
                    }

                    if snapshot.metadata.isFromCache {
                        FirebaseLogger.firestore.debug("Document snapshot is from cache (not from server)")
                    }

                    // Always process document snapshots, but log the source
                    if !snapshot.metadata.hasPendingWrites && !snapshot.metadata.isFromCache {
                        FirebaseLogger.firestore.debug("Processing document snapshot from server")
                    } else if snapshot.metadata.isFromCache {
                        FirebaseLogger.firestore.debug("Processing initial document snapshot from cache")
                    }

                    do {
                        let result = try transform(snapshot)
                        continuation.yield(result)
                    } catch {
                        FirebaseLogger.firestore.error("Error processing document data: \(error.localizedDescription)")
                        // We don't emit errors in the stream, just log them
                    }
                }

                // Set up cancellation
                continuation.onTermination = { [listener] _ in
                    FirebaseLogger.firestore.debug("Terminating document listener for path: \(path)")
                    listener.remove()
                }
            }
        },

        collectionStream: { path, transform in
            FirebaseLogger.firestore.debug("Creating collection stream for path: \(path)")

            return AsyncStream<T> { continuation in
                let db = Firestore.firestore()
                let collectionRef = db.collection(path)

                // Set up listener options with metadata changes to handle cache/server state
                let options = SnapshotListenOptions()
                    .withIncludeMetadataChanges(true)

                // Create the listener
                let listener = collectionRef.addSnapshotListener(options: options) { snapshot, error in
                    if let error = error {
                        FirebaseLogger.firestore.error("Error listening for collection changes: \(error.localizedDescription)")
                        // We don't emit errors in the stream, just log them
                        return
                    }

                    guard let snapshot = snapshot else {
                        FirebaseLogger.firestore.error("Collection snapshot is nil")
                        return
                    }

                    // Log metadata information for debugging
                    if snapshot.metadata.hasPendingWrites {
                        FirebaseLogger.firestore.debug("Snapshot has pending writes (local changes not yet committed to server)")
                    }

                    if snapshot.metadata.isFromCache {
                        FirebaseLogger.firestore.debug("Snapshot is from cache (not from server)")
                    }

                    // Only emit changes that are not just metadata updates
                    // This prevents duplicate emissions when data is first read from cache and then from server
                    if !snapshot.metadata.hasPendingWrites && !snapshot.metadata.isFromCache {
                        FirebaseLogger.firestore.debug("Emitting snapshot from server with \(snapshot.documents.count) documents")
                    } else if snapshot.metadata.isFromCache {
                        // For cache data, only emit if it's the first load (no previous data)
                        FirebaseLogger.firestore.debug("Emitting initial snapshot from cache with \(snapshot.documents.count) documents")
                    }

                    // Process data in a Task to allow for async operations
                    Task {
                        do {
                            let result = try await transform(snapshot)
                            continuation.yield(result)
                        } catch {
                            FirebaseLogger.firestore.error("Error processing collection data: \(error.localizedDescription)")
                            // We don't emit errors in the stream, just log them
                        }
                    }
                }

                // Set up cancellation
                continuation.onTermination = { [listener] _ in
                    FirebaseLogger.firestore.debug("Terminating collection listener for path: \(path)")
                    listener.remove()
                }
            }
        }
    )
}

// MARK: - Test Implementation

extension FirestoreStorageClient: TestDependencyKey {
    /// A test implementation that fails with an unimplemented error
    static let testValue = Self(
        getDocument: unimplemented("\(Self.self).getDocument"),
        setDocument: unimplemented("\(Self.self).setDocument"),
        updateDocument: unimplemented("\(Self.self).updateDocument"),
        deleteDocument: unimplemented("\(Self.self).deleteDocument"),
        getCollection: unimplemented("\(Self.self).getCollection", placeholder: { _, _ in [] }),
        addDocument: unimplemented("\(Self.self).addDocument", placeholder: { _, _ in UUID().uuidString }),
        performBatchOperation: unimplemented("\(Self.self).performBatchOperation"),
        performTransaction: unimplemented("\(Self.self).performTransaction"),
        documentStream: unimplemented("\(Self.self).documentStream", placeholder: { _, _ in
            AsyncStream { continuation in
                continuation.finish()
            }
        }),
        collectionStream: unimplemented("\(Self.self).collectionStream", placeholder: { _, _ in
            AsyncStream { continuation in
                continuation.finish()
            }
        })
    )
}

// MARK: - Mock Implementation

extension FirestoreStorageClient {
    /// A mock implementation that returns predefined values for testing
    static func mock(
        getDocument: @Sendable @escaping <T>(String, @Sendable @escaping (DocumentSnapshot) throws -> T) async throws -> T = { _, _ in
            throw FirebaseError.operationFailed
        },
        setDocument: @Sendable @escaping (String, [String: Any], Bool) async throws -> Void = { _, _, _ in },
        updateDocument: @Sendable @escaping (String, [String: Any]) async throws -> Void = { _, _ in },
        deleteDocument: @Sendable @escaping (String) async throws -> Void = { _ in },
        getCollection: @Sendable @escaping <T>(String, @Sendable @escaping (QueryDocumentSnapshot) throws -> T) async throws -> [T] = { _, _ in
            []
        },
        addDocument: @Sendable @escaping (String, [String: Any]) async throws -> String = { _, _ in
            UUID().uuidString
        },
        performBatchOperation: @Sendable @escaping (@Sendable @escaping (WriteBatch) -> Void) async throws -> Void = { _ in },
        performTransaction: @Sendable @escaping <T>(@Sendable @escaping (Transaction) throws -> T) async throws -> T = { _ in
            throw FirebaseError.operationFailed
        },
        documentStream: @Sendable @escaping <T>(String, @Sendable @escaping (DocumentSnapshot) throws -> T) -> AsyncStream<T> = { _, _ in
            AsyncStream { continuation in
                continuation.finish()
            }
        },
        collectionStream: @Sendable @escaping <T>(String, @Sendable @escaping (QuerySnapshot) async throws -> T) -> AsyncStream<T> = { _, _ in
            AsyncStream { continuation in
                continuation.finish()
            }
        }
    ) -> Self {
        Self(
            getDocument: getDocument,
            setDocument: setDocument,
            updateDocument: updateDocument,
            deleteDocument: deleteDocument,
            getCollection: getCollection,
            addDocument: addDocument,
            performBatchOperation: performBatchOperation,
            performTransaction: performTransaction,
            documentStream: documentStream,
            collectionStream: collectionStream
        )
    }
}

extension DependencyValues {
    var firestoreStorage: FirestoreStorageClient {
        get { self[FirestoreStorageClient.self] }
        set { self[FirestoreStorageClient.self] = newValue }
    }
}
