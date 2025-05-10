import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging
import FirebaseFunctions
import FirebaseAuth
import ComposableArchitecture
import UIKit
import Combine

/// Client for interacting with Firebase services
struct FirebaseClient: Sendable {
    // MARK: - Configuration

    /// Configure Firebase
    var configure: @Sendable () async -> Void

    /// Get Firebase initialization status
    var getInitializationStatus: @Sendable () async -> String

    // MARK: - User Management

    /// Update FCM token in Firestore
    var updateFCMToken: @Sendable (token: String, userId: String) async throws -> Void

    /// Get user data from Firestore
    var getUserData: @Sendable (userId: String) async throws -> [String: Any]

    /// Update user data in Firestore
    var updateUserData: @Sendable (userId: String, data: [String: Any]) async throws -> Void

    /// Create a new user in Firestore
    var createUser: @Sendable (userId: String, data: [String: Any]) async throws -> Void

    /// Delete a user from Firestore
    var deleteUser: @Sendable (userId: String) async throws -> Void

    // MARK: - Document Operations

    /// Get a document from Firestore
    var getDocument: @Sendable (collection: String, documentId: String) async throws -> [String: Any]

    /// Set a document in Firestore
    var setDocument: @Sendable (collection: String, documentId: String, data: [String: Any], merge: Bool) async throws -> Void

    /// Update a document in Firestore
    var updateDocument: @Sendable (collection: String, documentId: String, data: [String: Any]) async throws -> Void

    /// Delete a document from Firestore
    var deleteDocument: @Sendable (collection: String, documentId: String) async throws -> Void

    // MARK: - Query Operations

    /// Query documents from Firestore with a simple equality condition
    var queryDocuments: @Sendable (collection: String, field: String, isEqualTo: Any) async throws -> [[String: Any]]

    /// Query documents from Firestore with multiple conditions
    var queryDocumentsWithFilters: @Sendable (collection: String, filters: [(field: String, operation: String, value: Any)], orderBy: [(field: String, descending: Bool)]?, limit: Int?) async throws -> [[String: Any]]

    /// Query documents from Firestore with pagination
    var paginatedQuery: @Sendable (collection: String, filters: [(field: String, operation: String, value: Any)]?, orderBy: [(field: String, descending: Bool)]?, startAfterDocument: [String: Any]?, limit: Int) async throws -> (documents: [[String: Any]], lastDocument: [String: Any]?)

    // MARK: - Real-time Monitoring

    /// Monitor a document for changes
    /// - Parameters:
    ///   - collection: The collection name
    ///   - documentId: The document ID
    ///   - includeMetadata: Whether to include metadata changes
    /// - Returns: An AsyncStream of document snapshots
    var monitorDocument: @Sendable (collection: String, documentId: String, includeMetadata: Bool) -> AsyncStream<DocumentSnapshot>

    /// Monitor a collection for changes
    /// - Parameters:
    ///   - collection: The collection name
    ///   - filters: Optional filters to apply
    ///   - orderBy: Optional ordering to apply
    ///   - limit: Optional limit to apply
    ///   - includeMetadata: Whether to include metadata changes
    /// - Returns: An AsyncStream of query snapshots
    var monitorCollection: @Sendable (collection: String, filters: [(field: String, operation: String, value: Any)]?, orderBy: [(field: String, descending: Bool)]?, limit: Int?, includeMetadata: Bool) -> AsyncStream<QuerySnapshot>

    /// Monitor a user document for changes
    /// - Parameters:
    ///   - userId: The user ID
    ///   - includeMetadata: Whether to include metadata changes
    /// - Returns: An AsyncStream of document snapshots
    var monitorUserDocument: @Sendable (userId: String, includeMetadata: Bool) -> AsyncStream<DocumentSnapshot>

    /// Monitor a user's contacts for changes
    /// - Parameters:
    ///   - userId: The user ID
    ///   - includeMetadata: Whether to include metadata changes
    /// - Returns: An AsyncStream of query snapshots
    var monitorUserContacts: @Sendable (userId: String, includeMetadata: Bool) -> AsyncStream<[DocumentSnapshot]>

    // MARK: - Batch and Transaction Operations

    /// Perform a batch write operation
    var performBatchOperation: @Sendable (operations: [(type: String, collection: String, documentId: String, data: [String: Any]?)]) async throws -> Void

    /// Perform a transaction
    var performTransaction: @Sendable (updateHandler: @Sendable @escaping (Transaction) async throws -> Void) async throws -> Void

    // MARK: - Cloud Functions

    /// Call a Firebase Cloud Function
    var callFunction: @Sendable (name: String, data: [String: Any]?) async throws -> [String: Any]

    /// Call a Firebase Cloud Function with a specific region
    var callFunctionWithRegion: @Sendable (name: String, region: String, data: [String: Any]?) async throws -> [String: Any]

    // MARK: - Testing

    /// Test Firestore connection
    var testFirestoreConnection: @Sendable () async throws -> String
}

extension FirebaseClient {
    /// Live implementation of FirebaseClient
    static let live = Self(
        // MARK: - Configuration

        configure: {
            // Initialize Firebase if not already initialized
            if FirebaseApp.app() == nil {
                FirebaseApp.configure()
            }

            // Set up Firebase Functions
            let _ = Functions.functions(region: "us-central1")

            // Set up Firebase Messaging
            await setupFirebaseMessaging()
        },

        getInitializationStatus: {
            if let app = FirebaseApp.app() {
                let options = app.options
                return """
                Firebase is initialized!
                App name: \(app.name)
                Google App ID: \(options.googleAppID)
                GCM Sender ID: \(options.gcmSenderID)
                Project ID: \(options.projectID ?? "Not available")
                """
            } else {
                return "Firebase is NOT initialized!"
            }
        },

        // MARK: - User Management

        updateFCMToken: { token, userId in
            let db = Firestore.firestore()
            let userRef = db.collection(FirestoreConstants.Collections.users).document(userId)

            try await userRef.updateData([
                FirestoreConstants.UserFields.fcmToken: token,
                FirestoreConstants.UserFields.lastUpdated: FieldValue.serverTimestamp()
            ])
        },

        getUserData: { userId in
            let db = Firestore.firestore()
            let documentSnapshot = try await db.collection(FirestoreConstants.Collections.users).document(userId).getDocument()

            guard documentSnapshot.exists, let data = documentSnapshot.data() else {
                throw FirebaseError.documentNotFound
            }

            return data
        },

        updateUserData: { userId, data in
            let db = Firestore.firestore()
            let userRef = db.collection(FirestoreConstants.Collections.users).document(userId)

            // Add last updated timestamp
            var updatedData = data
            updatedData[FirestoreConstants.UserFields.lastUpdated] = FieldValue.serverTimestamp()

            try await userRef.updateData(updatedData)
        },

        createUser: { userId, data in
            let db = Firestore.firestore()
            let userRef = db.collection(FirestoreConstants.Collections.users).document(userId)

            // Add creation timestamp and user ID
            var userData = data
            userData[FirestoreConstants.UserFields.createdAt] = FieldValue.serverTimestamp()
            userData[FirestoreConstants.UserFields.uid] = userId

            try await userRef.setData(userData)
        },

        deleteUser: { userId in
            let db = Firestore.firestore()
            try await db.collection(FirestoreConstants.Collections.users).document(userId).delete()
        },

        // MARK: - Document Operations

        getDocument: { collection, documentId in
            let db = Firestore.firestore()
            let documentSnapshot = try await db.collection(collection).document(documentId).getDocument()

            guard documentSnapshot.exists, let data = documentSnapshot.data() else {
                throw FirebaseError.documentNotFound
            }

            return data
        },

        setDocument: { collection, documentId, data, merge in
            let db = Firestore.firestore()
            try await db.collection(collection).document(documentId).setData(data, merge: merge)
        },

        updateDocument: { collection, documentId, data in
            let db = Firestore.firestore()
            try await db.collection(collection).document(documentId).updateData(data)
        },

        deleteDocument: { collection, documentId in
            let db = Firestore.firestore()
            try await db.collection(collection).document(documentId).delete()
        },

        // MARK: - Query Operations

        queryDocuments: { collection, field, isEqualTo in
            let db = Firestore.firestore()
            let query = db.collection(collection).whereField(field, isEqualTo: isEqualTo)
            let querySnapshot = try await query.getDocuments()

            return querySnapshot.documents.compactMap { $0.data() }
        },

        queryDocumentsWithFilters: { collection, filters, orderBy, limit in
            let db = Firestore.firestore()
            var query: Query = db.collection(collection)

            // Apply filters
            for filter in filters {
                switch filter.operation {
                case "==":
                    query = query.whereField(filter.field, isEqualTo: filter.value)
                case ">":
                    query = query.whereField(filter.field, isGreaterThan: filter.value)
                case ">=":
                    query = query.whereField(filter.field, isGreaterThanOrEqualTo: filter.value)
                case "<":
                    query = query.whereField(filter.field, isLessThan: filter.value)
                case "<=":
                    query = query.whereField(filter.field, isLessThanOrEqualTo: filter.value)
                case "!=":
                    query = query.whereField(filter.field, isNotEqualTo: filter.value)
                case "array-contains":
                    query = query.whereField(filter.field, arrayContains: filter.value)
                case "array-contains-any":
                    if let values = filter.value as? [Any] {
                        query = query.whereField(filter.field, arrayContainsAny: values)
                    } else {
                        throw FirebaseError.invalidData
                    }
                case "in":
                    if let values = filter.value as? [Any] {
                        query = query.whereField(filter.field, in: values)
                    } else {
                        throw FirebaseError.invalidData
                    }
                case "not-in":
                    if let values = filter.value as? [Any] {
                        query = query.whereField(filter.field, notIn: values)
                    } else {
                        throw FirebaseError.invalidData
                    }
                default:
                    throw FirebaseError.invalidData
                }
            }

            // Apply ordering
            if let orderBy = orderBy {
                for order in orderBy {
                    query = query.order(by: order.field, descending: order.descending)
                }
            }

            // Apply limit
            if let limit = limit {
                query = query.limit(to: limit)
            }

            let querySnapshot = try await query.getDocuments()
            return querySnapshot.documents.compactMap { $0.data() }
        },

        paginatedQuery: { collection, filters, orderBy, startAfterDocument, limit in
            let db = Firestore.firestore()
            var query: Query = db.collection(collection)

            // Apply filters
            if let filters = filters {
                for filter in filters {
                    switch filter.operation {
                    case "==":
                        query = query.whereField(filter.field, isEqualTo: filter.value)
                    case ">":
                        query = query.whereField(filter.field, isGreaterThan: filter.value)
                    case ">=":
                        query = query.whereField(filter.field, isGreaterThanOrEqualTo: filter.value)
                    case "<":
                        query = query.whereField(filter.field, isLessThan: filter.value)
                    case "<=":
                        query = query.whereField(filter.field, isLessThanOrEqualTo: filter.value)
                    case "!=":
                        query = query.whereField(filter.field, isNotEqualTo: filter.value)
                    case "array-contains":
                        query = query.whereField(filter.field, arrayContains: filter.value)
                    case "array-contains-any":
                        if let values = filter.value as? [Any] {
                            query = query.whereField(filter.field, arrayContainsAny: values)
                        } else {
                            throw FirebaseError.invalidData
                        }
                    case "in":
                        if let values = filter.value as? [Any] {
                            query = query.whereField(filter.field, in: values)
                        } else {
                            throw FirebaseError.invalidData
                        }
                    case "not-in":
                        if let values = filter.value as? [Any] {
                            query = query.whereField(filter.field, notIn: values)
                        } else {
                            throw FirebaseError.invalidData
                        }
                    default:
                        throw FirebaseError.invalidData
                    }
                }
            }

            // Apply ordering (required for pagination)
            if let orderBy = orderBy, !orderBy.isEmpty {
                for order in orderBy {
                    query = query.order(by: order.field, descending: order.descending)
                }
            } else {
                // Default ordering by document ID if none provided
                query = query.order(by: FieldPath.documentID())
            }

            // Apply start after document for pagination
            if let startAfterDoc = startAfterDocument {
                // Create a document snapshot from the dictionary
                // This is a simplified approach - in a real app, you might need to
                // convert the dictionary to a proper DocumentSnapshot
                let fields = startAfterDoc.keys.sorted()
                let values = fields.map { startAfterDoc[$0]! }
                query = query.start(after: values)
            }

            // Apply limit
            query = query.limit(to: limit)

            let querySnapshot = try await query.getDocuments()
            let documents = querySnapshot.documents.compactMap { $0.data() }
            let lastDocument = querySnapshot.documents.last?.data()

            return (documents: documents, lastDocument: lastDocument)
        },

        // MARK: - Batch and Transaction Operations

        performBatchOperation: { operations in
            let db = Firestore.firestore()
            let batch = db.batch()

            for operation in operations {
                let docRef = db.collection(operation.collection).document(operation.documentId)

                switch operation.type {
                case "set":
                    if let data = operation.data {
                        batch.setData(data, forDocument: docRef)
                    } else {
                        throw FirebaseError.invalidData
                    }
                case "update":
                    if let data = operation.data {
                        batch.updateData(data, forDocument: docRef)
                    } else {
                        throw FirebaseError.invalidData
                    }
                case "delete":
                    batch.deleteDocument(docRef)
                default:
                    throw FirebaseError.invalidData
                }
            }

            try await batch.commit()
        },

        performTransaction: { updateHandler in
            let db = Firestore.firestore()
            try await db.runTransaction { transaction in
                try await updateHandler(transaction)
            }
        },

        // MARK: - Real-time Monitoring

        monitorDocument: { collection, documentId, includeMetadata in
            let db = Firestore.firestore()
            let docRef = db.collection(collection).document(documentId)

            return AsyncStream { continuation in
                let listener = docRef.addSnapshotListener(includeMetadataChanges: includeMetadata) { snapshot, error in
                    if let error = error {
                        print("Error listening for document changes: \(error.localizedDescription)")
                        return
                    }

                    if let snapshot = snapshot {
                        continuation.yield(snapshot)
                    }
                }

                continuation.onTermination = { _ in
                    listener.remove()
                }
            }
        },

        monitorCollection: { collection, filters, orderBy, limit, includeMetadata in
            let db = Firestore.firestore()
            var query: Query = db.collection(collection)

            // Apply filters
            if let filters = filters {
                for filter in filters {
                    switch filter.operation {
                    case "==":
                        query = query.whereField(filter.field, isEqualTo: filter.value)
                    case ">":
                        query = query.whereField(filter.field, isGreaterThan: filter.value)
                    case ">=":
                        query = query.whereField(filter.field, isGreaterThanOrEqualTo: filter.value)
                    case "<":
                        query = query.whereField(filter.field, isLessThan: filter.value)
                    case "<=":
                        query = query.whereField(filter.field, isLessThanOrEqualTo: filter.value)
                    case "!=":
                        query = query.whereField(filter.field, isNotEqualTo: filter.value)
                    case "array-contains":
                        query = query.whereField(filter.field, arrayContains: filter.value)
                    case "array-contains-any":
                        if let values = filter.value as? [Any] {
                            query = query.whereField(filter.field, arrayContainsAny: values)
                        }
                    case "in":
                        if let values = filter.value as? [Any] {
                            query = query.whereField(filter.field, in: values)
                        }
                    case "not-in":
                        if let values = filter.value as? [Any] {
                            query = query.whereField(filter.field, notIn: values)
                        }
                    default:
                        break
                    }
                }
            }

            // Apply ordering
            if let orderBy = orderBy {
                for order in orderBy {
                    query = query.order(by: order.field, descending: order.descending)
                }
            }

            // Apply limit
            if let limit = limit {
                query = query.limit(to: limit)
            }

            return AsyncStream { continuation in
                let listener = query.addSnapshotListener(includeMetadataChanges: includeMetadata) { snapshot, error in
                    if let error = error {
                        print("Error listening for collection changes: \(error.localizedDescription)")
                        return
                    }

                    if let snapshot = snapshot {
                        continuation.yield(snapshot)
                    }
                }

                continuation.onTermination = { _ in
                    listener.remove()
                }
            }
        },

        monitorUserDocument: { userId, includeMetadata in
            let db = Firestore.firestore()
            let userRef = db.collection(FirestoreConstants.Collections.users).document(userId)

            return AsyncStream { continuation in
                let listener = userRef.addSnapshotListener(includeMetadataChanges: includeMetadata) { snapshot, error in
                    if let error = error {
                        print("Error listening for user document changes: \(error.localizedDescription)")
                        return
                    }

                    if let snapshot = snapshot {
                        continuation.yield(snapshot)
                    }
                }

                continuation.onTermination = { _ in
                    listener.remove()
                }
            }
        },

        monitorUserContacts: { userId, includeMetadata in
            let db = Firestore.firestore()
            let userRef = db.collection(FirestoreConstants.Collections.users).document(userId)

            return AsyncStream { continuation in
                // First, get the user document to monitor the contacts array
                let userListener = userRef.addSnapshotListener(includeMetadataChanges: includeMetadata) { snapshot, error in
                    if let error = error {
                        print("Error listening for user contacts changes: \(error.localizedDescription)")
                        return
                    }

                    guard let snapshot = snapshot, snapshot.exists,
                          let contactsData = snapshot.data()?[FirestoreConstants.UserFields.contacts] as? [[String: Any]] else {
                        continuation.yield([])
                        return
                    }

                    // Extract contact references
                    let contactRefs = contactsData.compactMap { contactData -> DocumentReference? in
                        guard let refPath = contactData[FirestoreConstants.ContactFields.referencePath] as? String else {
                            return nil
                        }
                        return db.document(refPath)
                    }

                    if contactRefs.isEmpty {
                        continuation.yield([])
                        return
                    }

                    // Get all contact documents
                    Task {
                        do {
                            let contactSnapshots = try await withThrowingTaskGroup(of: DocumentSnapshot?.self) { group in
                                for contactRef in contactRefs {
                                    group.addTask {
                                        try await contactRef.getDocument()
                                    }
                                }

                                var snapshots: [DocumentSnapshot] = []
                                for try await snapshot in group {
                                    if let snapshot = snapshot {
                                        snapshots.append(snapshot)
                                    }
                                }
                                return snapshots
                            }

                            continuation.yield(contactSnapshots)
                        } catch {
                            print("Error fetching contact documents: \(error.localizedDescription)")
                            continuation.yield([])
                        }
                    }
                }

                continuation.onTermination = { _ in
                    userListener.remove()
                }
            }
        },

        // MARK: - Cloud Functions

        callFunction: { name, data in
            let functions = Functions.functions()
            let result = try await functions.httpsCallable(name).call(data ?? [:])

            guard let resultData = result.data as? [String: Any] else {
                throw FirebaseError.invalidData
            }

            return resultData
        },

        callFunctionWithRegion: { name, region, data in
            let functions = Functions.functions(region: region)
            let result = try await functions.httpsCallable(name).call(data ?? [:])

            guard let resultData = result.data as? [String: Any] else {
                throw FirebaseError.invalidData
            }

            return resultData
        },

        // MARK: - Testing

        testFirestoreConnection: {
            guard FirebaseApp.app() != nil else {
                throw FirebaseError.notInitialized
            }

            let db = Firestore.firestore()
            let testCollection = db.collection("test")
            let testDocRef = testCollection.document("test_document")

            let document = try await testDocRef.getDocument()

            if document.exists, let data = document.data() {
                let dataString = data.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
                return "Successfully accessed Firestore!\nTest document data:\n\(dataString)"
            } else {
                // Document doesn't exist, create it
                let testData: [String: Any] = [
                    "timestamp": FieldValue.serverTimestamp(),
                    "message": "This is a test document",
                    "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
                ]

                try await testDocRef.setData(testData)
                return "Successfully created test document in Firestore!\nData:\n\(testData.map { "\($0.key): \($0.value)" }.joined(separator: "\n"))"
            }
        }
    )

    /// Set up Firebase Messaging
    private static func setupFirebaseMessaging() async {
        // Request notification permissions
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: authOptions)
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        } catch {
            print("Error requesting notification authorization: \(error.localizedDescription)")
        }

        // Set up FCM token monitoring
        Messaging.messaging().delegate = MessagingDelegateAdapter.shared
    }
}

extension FirebaseClient {
    /// Test implementation for testing
    static let test = Self(
        // MARK: - Configuration

        configure: {
            // No-op for testing
        },

        getInitializationStatus: {
            return "Firebase is initialized (MOCK)"
        },

        // MARK: - User Management

        updateFCMToken: { _, _ in
            // No-op for testing
        },

        getUserData: { _ in
            return [
                "uid": "test-user-id",
                "name": "Test User",
                "phoneNumber": "+11234567890",
                "createdAt": Date(),
                "note": "Test user note",
                "checkInInterval": 86400, // 24 hours in seconds
                "lastCheckedIn": Date(),
                "qrCodeId": "test-qr-code-id",
                "notify30MinBefore": true,
                "notify2HoursBefore": false,
                "notificationEnabled": true,
                "profileComplete": true,
                "contacts": []
            ]
        },

        updateUserData: { _, _ in
            // No-op for testing
            return
        },

        createUser: { _, _ in
            // No-op for testing
            return
        },

        deleteUser: { _ in
            // No-op for testing
            return
        },

        // MARK: - Document Operations

        getDocument: { collection, _ in
            // Return different mock data based on collection
            switch collection {
            case FirestoreConstants.Collections.users:
                return [
                    "uid": "test-user-id",
                    "name": "Test User",
                    "phoneNumber": "+11234567890",
                    "createdAt": Date()
                ]
            case FirestoreConstants.Collections.qrLookup:
                return [
                    "userId": "test-user-id",
                    "createdAt": Date()
                ]
            case FirestoreConstants.Collections.sessions:
                return [
                    "userId": "test-user-id",
                    "deviceId": "test-device-id",
                    "createdAt": Date(),
                    "lastActive": Date()
                ]
            default:
                return [
                    "id": "test-document-id",
                    "createdAt": Date()
                ]
            }
        },

        setDocument: { _, _, _, _ in
            // No-op for testing
            return
        },

        updateDocument: { _, _, _ in
            // No-op for testing
            return
        },

        deleteDocument: { _, _ in
            // No-op for testing
            return
        },

        // MARK: - Query Operations

        queryDocuments: { collection, field, value in
            // Return different mock data based on collection and query
            switch collection {
            case FirestoreConstants.Collections.users:
                return [
                    [
                        "uid": "test-user-id-1",
                        "name": "Test User 1",
                        "phoneNumber": "+11234567890",
                        "createdAt": Date()
                    ],
                    [
                        "uid": "test-user-id-2",
                        "name": "Test User 2",
                        "phoneNumber": "+10987654321",
                        "createdAt": Date()
                    ]
                ]
            default:
                return [
                    [
                        "id": "test-document-1",
                        "createdAt": Date()
                    ],
                    [
                        "id": "test-document-2",
                        "createdAt": Date()
                    ]
                ]
            }
        },

        queryDocumentsWithFilters: { collection, filters, orderBy, limit in
            // Return mock data with the same structure as queryDocuments
            // but acknowledge the more complex filtering capabilities
            let mockData = [
                [
                    "id": "test-filtered-doc-1",
                    "name": "Filtered Test 1",
                    "createdAt": Date(),
                    "value": 100
                ],
                [
                    "id": "test-filtered-doc-2",
                    "name": "Filtered Test 2",
                    "createdAt": Date(),
                    "value": 200
                ]
            ]

            // If limit is specified, respect it
            if let limit = limit, limit < mockData.count {
                return Array(mockData[0..<limit])
            }

            return mockData
        },

        paginatedQuery: { collection, filters, orderBy, startAfterDocument, limit in
            // Mock data for pagination
            let mockData = [
                [
                    "id": "test-paginated-1",
                    "name": "Paginated Test 1",
                    "createdAt": Date(),
                    "value": 100
                ],
                [
                    "id": "test-paginated-2",
                    "name": "Paginated Test 2",
                    "createdAt": Date(),
                    "value": 200
                ]
            ]

            // Respect the limit
            let limitedData = limit < mockData.count ? Array(mockData[0..<limit]) : mockData

            // Return the documents and the last document for pagination
            return (documents: limitedData, lastDocument: limitedData.last)
        },

        // MARK: - Batch and Transaction Operations

        performBatchOperation: { operations in
            // No-op for testing
            return
        },

        performTransaction: { updateHandler in
            // Create a mock transaction that does nothing
            struct MockTransaction: Transaction {
                func getDocument(_ document: DocumentReference) throws -> DocumentSnapshot {
                    throw NSError(domain: "MockTransaction", code: 0, userInfo: [NSLocalizedDescriptionKey: "Mock transaction does not support getDocument"])
                }

                func setData(_ data: [String: Any], forDocument document: DocumentReference) throws {
                    // No-op
                }

                func setData(_ data: [String: Any], forDocument document: DocumentReference, merge: Bool) throws {
                    // No-op
                }

                func updateData(_ fields: [AnyHashable: Any], forDocument document: DocumentReference) throws {
                    // No-op
                }

                func deleteDocument(_ document: DocumentReference) throws {
                    // No-op
                }
            }

            // Call the update handler with our mock transaction
            try await updateHandler(MockTransaction())
        },

        // MARK: - Real-time Monitoring

        monitorDocument: { collection, documentId, includeMetadata in
            // Create a mock document snapshot
            let mockData: [String: Any]

            switch collection {
            case FirestoreConstants.Collections.users:
                mockData = [
                    "uid": documentId,
                    "name": "Test User",
                    "phoneNumber": "+11234567890",
                    "createdAt": Date(),
                    "note": "Test user note",
                    "checkInInterval": 86400, // 24 hours in seconds
                    "lastCheckedIn": Date(),
                    "qrCodeId": "test-qr-code-id",
                    "notify30MinBefore": true,
                    "notify2HoursBefore": false,
                    "notificationEnabled": true,
                    "profileComplete": true,
                    "contacts": []
                ]
            default:
                mockData = [
                    "id": documentId,
                    "createdAt": Date()
                ]
            }

            // Create a mock document reference
            let mockDocRef = Firestore.firestore().collection(collection).document(documentId)

            // Create a mock document snapshot
            let mockSnapshot = MockDocumentSnapshot(
                exists: true,
                data: mockData,
                reference: mockDocRef
            )

            // Return an AsyncStream that yields the mock snapshot once
            return AsyncStream { continuation in
                // Yield the initial snapshot
                continuation.yield(mockSnapshot)

                // Simulate periodic updates if needed
                let timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                    // Update some fields to simulate changes
                    var updatedData = mockData
                    updatedData["lastUpdated"] = Date()

                    let updatedSnapshot = MockDocumentSnapshot(
                        exists: true,
                        data: updatedData,
                        reference: mockDocRef
                    )

                    continuation.yield(updatedSnapshot)
                }

                continuation.onTermination = { _ in
                    timer.invalidate()
                }
            }
        },

        monitorCollection: { collection, filters, orderBy, limit, includeMetadata in
            // Create mock documents
            let mockDocuments: [MockDocumentSnapshot]

            switch collection {
            case FirestoreConstants.Collections.users:
                mockDocuments = [
                    MockDocumentSnapshot(
                        exists: true,
                        data: [
                            "uid": "test-user-id-1",
                            "name": "Test User 1",
                            "phoneNumber": "+11234567890",
                            "createdAt": Date()
                        ],
                        reference: Firestore.firestore().collection(collection).document("test-user-id-1")
                    ),
                    MockDocumentSnapshot(
                        exists: true,
                        data: [
                            "uid": "test-user-id-2",
                            "name": "Test User 2",
                            "phoneNumber": "+10987654321",
                            "createdAt": Date()
                        ],
                        reference: Firestore.firestore().collection(collection).document("test-user-id-2")
                    )
                ]
            default:
                mockDocuments = [
                    MockDocumentSnapshot(
                        exists: true,
                        data: [
                            "id": "test-document-1",
                            "createdAt": Date()
                        ],
                        reference: Firestore.firestore().collection(collection).document("test-document-1")
                    ),
                    MockDocumentSnapshot(
                        exists: true,
                        data: [
                            "id": "test-document-2",
                            "createdAt": Date()
                        ],
                        reference: Firestore.firestore().collection(collection).document("test-document-2")
                    )
                ]
            }

            // Create a mock query snapshot
            let mockQuerySnapshot = MockQuerySnapshot(
                documents: mockDocuments,
                documentChanges: []
            )

            // Return an AsyncStream that yields the mock snapshot once
            return AsyncStream { continuation in
                // Yield the initial snapshot
                continuation.yield(mockQuerySnapshot)

                // Simulate periodic updates if needed
                let timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                    // Update some fields to simulate changes
                    let updatedDocuments = mockDocuments.map { doc -> MockDocumentSnapshot in
                        var updatedData = doc.data
                        updatedData["lastUpdated"] = Date()

                        return MockDocumentSnapshot(
                            exists: true,
                            data: updatedData,
                            reference: doc.reference
                        )
                    }

                    let updatedSnapshot = MockQuerySnapshot(
                        documents: updatedDocuments,
                        documentChanges: []
                    )

                    continuation.yield(updatedSnapshot)
                }

                continuation.onTermination = { _ in
                    timer.invalidate()
                }
            }
        },

        monitorUserDocument: { userId, includeMetadata in
            // Delegate to the monitorDocument implementation
            return FirebaseClient.test.monitorDocument(
                collection: FirestoreConstants.Collections.users,
                documentId: userId,
                includeMetadata: includeMetadata
            )
        },

        monitorUserContacts: { userId, includeMetadata in
            // Create mock contact documents
            let mockContactDocuments = [
                MockDocumentSnapshot(
                    exists: true,
                    data: [
                        "uid": "test-contact-id-1",
                        "name": "Test Contact 1",
                        "phoneNumber": "+11234567890",
                        "createdAt": Date()
                    ],
                    reference: Firestore.firestore().collection(FirestoreConstants.Collections.users).document("test-contact-id-1")
                ),
                MockDocumentSnapshot(
                    exists: true,
                    data: [
                        "uid": "test-contact-id-2",
                        "name": "Test Contact 2",
                        "phoneNumber": "+10987654321",
                        "createdAt": Date()
                    ],
                    reference: Firestore.firestore().collection(FirestoreConstants.Collections.users).document("test-contact-id-2")
                )
            ]

            // Return an AsyncStream that yields the mock snapshots
            return AsyncStream { continuation in
                // Yield the initial snapshots
                continuation.yield(mockContactDocuments)

                // Simulate periodic updates if needed
                let timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                    // Update some fields to simulate changes
                    let updatedDocuments = mockContactDocuments.map { doc -> MockDocumentSnapshot in
                        var updatedData = doc.data
                        updatedData["lastUpdated"] = Date()

                        return MockDocumentSnapshot(
                            exists: true,
                            data: updatedData,
                            reference: doc.reference
                        )
                    }

                    continuation.yield(updatedDocuments)
                }

                continuation.onTermination = { _ in
                    timer.invalidate()
                }
            }
        },

        // MARK: - Cloud Functions

        callFunction: { name, data in
            // Return different mock data based on the function name
            switch name {
            case "addContactRelation":
                return [
                    "success": true,
                    "contactId": "test-contact-id"
                ]
            case "updateContactRoles":
                return [
                    "success": true
                ]
            case "deleteContactRelation":
                return [
                    "success": true
                ]
            case "pingDependent":
                return [
                    "success": true
                ]
            case "clearPing":
                return [
                    "success": true
                ]
            case "respondToPing":
                return [
                    "success": true
                ]
            case "respondToAllPings":
                return [
                    "success": true
                ]
            default:
                return [
                    "success": true,
                    "message": "Mock function call successful"
                ]
            }
        },

        callFunctionWithRegion: { name, region, data in
            // Delegate to the regular callFunction implementation
            return try await FirebaseClient.test.callFunction(name: name, data: data)
        },

        // MARK: - Testing

        testFirestoreConnection: {
            return "Successfully connected to Firestore (MOCK)"
        }
    )
}

/// Firebase-related errors
enum FirebaseError: Error, LocalizedError {
    // General errors
    case notInitialized
    case unknownError
    case networkError

    // Authentication errors
    case authenticationRequired
    case invalidCredentials
    case userNotFound
    case emailAlreadyInUse
    case weakPassword
    case invalidVerificationCode

    // Firestore errors
    case documentNotFound
    case collectionNotFound
    case invalidData
    case invalidQuery
    case invalidOperation
    case permissionDenied
    case documentAlreadyExists
    case transactionFailed
    case batchOperationFailed
    case firestoreError(String)

    // Cloud Functions errors
    case functionNotFound
    case functionExecutionFailed(String)
    case invalidFunctionArguments
    case functionTimeout

    // Messaging errors
    case messagingNotInitialized
    case invalidToken
    case tokenRegistrationFailed

    // Storage errors
    case storageError(String)
    case fileNotFound
    case invalidFileFormat
    case uploadFailed
    case downloadFailed
    case insufficientStorage

    // App Check errors
    case appCheckFailed

    var errorDescription: String? {
        switch self {
        // General errors
        case .notInitialized:
            return "Firebase is not initialized"
        case .unknownError:
            return "Unknown error occurred"
        case .networkError:
            return "Network error - please check your internet connection"

        // Authentication errors
        case .authenticationRequired:
            return "Authentication required - please sign in"
        case .invalidCredentials:
            return "Invalid credentials provided"
        case .userNotFound:
            return "User not found"
        case .emailAlreadyInUse:
            return "Email is already in use"
        case .weakPassword:
            return "Password is too weak"
        case .invalidVerificationCode:
            return "Invalid verification code"

        // Firestore errors
        case .documentNotFound:
            return "Document not found"
        case .collectionNotFound:
            return "Collection not found"
        case .invalidData:
            return "Invalid data format"
        case .invalidQuery:
            return "Invalid query parameters"
        case .invalidOperation:
            return "Invalid operation"
        case .permissionDenied:
            return "Permission denied - you don't have access to this resource"
        case .documentAlreadyExists:
            return "Document already exists"
        case .transactionFailed:
            return "Transaction failed"
        case .batchOperationFailed:
            return "Batch operation failed"
        case .firestoreError(let message):
            return "Firestore error: \(message)"

        // Cloud Functions errors
        case .functionNotFound:
            return "Function not found"
        case .functionExecutionFailed(let message):
            return "Function execution failed: \(message)"
        case .invalidFunctionArguments:
            return "Invalid function arguments"
        case .functionTimeout:
            return "Function timed out"

        // Messaging errors
        case .messagingNotInitialized:
            return "Firebase Messaging is not initialized"
        case .invalidToken:
            return "Invalid FCM token"
        case .tokenRegistrationFailed:
            return "Failed to register FCM token"

        // Storage errors
        case .storageError(let message):
            return "Storage error: \(message)"
        case .fileNotFound:
            return "File not found"
        case .invalidFileFormat:
            return "Invalid file format"
        case .uploadFailed:
            return "File upload failed"
        case .downloadFailed:
            return "File download failed"
        case .insufficientStorage:
            return "Insufficient storage space"

        // App Check errors
        case .appCheckFailed:
            return "App Check verification failed"
        }
    }

    /// Convert Firebase errors to FirebaseError
    static func from(_ error: Error) -> FirebaseError {
        // If it's already a FirebaseError, return it
        if let firebaseError = error as? FirebaseError {
            return firebaseError
        }

        // Handle NSError
        if let nsError = error as NSError {
            // Handle Firebase Auth errors
            if nsError.domain == AuthErrorDomain {
                switch nsError.code {
                case AuthErrorCode.userNotFound.rawValue:
                    return .userNotFound
                case AuthErrorCode.wrongPassword.rawValue:
                    return .invalidCredentials
                case AuthErrorCode.invalidCredential.rawValue:
                    return .invalidCredentials
                case AuthErrorCode.emailAlreadyInUse.rawValue:
                    return .emailAlreadyInUse
                case AuthErrorCode.weakPassword.rawValue:
                    return .weakPassword
                case AuthErrorCode.invalidVerificationCode.rawValue:
                    return .invalidVerificationCode
                default:
                    return .firestoreError("Auth error: \(nsError.localizedDescription)")
                }
            }

            // Handle Firestore errors
            if nsError.domain == FirestoreErrorDomain {
                switch nsError.code {
                case FirestoreErrorCode.notFound.rawValue:
                    return .documentNotFound
                case FirestoreErrorCode.permissionDenied.rawValue:
                    return .permissionDenied
                case FirestoreErrorCode.aborted.rawValue:
                    return .transactionFailed
                case FirestoreErrorCode.alreadyExists.rawValue:
                    return .documentAlreadyExists
                case FirestoreErrorCode.invalidArgument.rawValue:
                    return .invalidData
                case FirestoreErrorCode.unavailable.rawValue, FirestoreErrorCode.deadlineExceeded.rawValue:
                    return .networkError
                default:
                    return .firestoreError("Firestore error: \(nsError.localizedDescription)")
                }
            }

            // Handle Functions errors
            if nsError.domain == FunctionsErrorDomain {
                switch nsError.code {
                case FunctionsErrorCode.functionNotFound.rawValue:
                    return .functionNotFound
                case FunctionsErrorCode.invalidArgument.rawValue:
                    return .invalidFunctionArguments
                case FunctionsErrorCode.deadlineExceeded.rawValue:
                    return .functionTimeout
                case FunctionsErrorCode.unavailable.rawValue:
                    return .networkError
                case FunctionsErrorCode.internal.rawValue:
                    return .functionExecutionFailed(nsError.localizedDescription)
                default:
                    return .functionExecutionFailed(nsError.localizedDescription)
                }
            }

            // Handle network errors
            if nsError.domain == NSURLErrorDomain {
                return .networkError
            }
        }

        // Default to unknown error with the original error description
        return .firestoreError(error.localizedDescription)
    }
}

/// Adapter for Firebase Messaging delegate
class MessagingDelegateAdapter: NSObject, MessagingDelegate {
    static let shared = MessagingDelegateAdapter()

    // Notification name for FCM token updates
    static let fcmTokenUpdatedNotification = Notification.Name("FCMTokenUpdated")

    private override init() {
        super.init()
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(fcmToken ?? "nil")")

        // Post notification with token
        if let token = fcmToken {
            NotificationCenter.default.post(
                name: MessagingDelegateAdapter.fcmTokenUpdatedNotification,
                object: nil,
                userInfo: ["token": token]
            )
        }
    }
}

/// Mock DocumentSnapshot for testing
class MockDocumentSnapshot: DocumentSnapshot {
    private let _exists: Bool
    private let _data: [String: Any]
    private let _reference: DocumentReference

    init(exists: Bool, data: [String: Any], reference: DocumentReference) {
        self._exists = exists
        self._data = data
        self._reference = reference
        super.init()
    }

    override var exists: Bool {
        return _exists
    }

    override func data() -> [String: Any]? {
        return _exists ? _data : nil
    }

    override var reference: DocumentReference {
        return _reference
    }

    override func get(_ field: String) -> Any? {
        return _data[field]
    }

    override var documentID: String {
        return _reference.documentID
    }
}

/// Mock DocumentChange for testing
class MockDocumentChange: DocumentChange {
    private let _type: DocumentChangeType
    private let _document: DocumentSnapshot
    private let _oldIndex: Int
    private let _newIndex: Int

    init(type: DocumentChangeType, document: DocumentSnapshot, oldIndex: Int, newIndex: Int) {
        self._type = type
        self._document = document
        self._oldIndex = oldIndex
        self._newIndex = newIndex
        super.init()
    }

    override var type: DocumentChangeType {
        return _type
    }

    override var document: DocumentSnapshot {
        return _document
    }

    override var oldIndex: Int {
        return _oldIndex
    }

    override var newIndex: Int {
        return _newIndex
    }
}

/// Mock QuerySnapshot for testing
class MockQuerySnapshot: QuerySnapshot {
    private let _documents: [DocumentSnapshot]
    private let _documentChanges: [DocumentChange]

    init(documents: [DocumentSnapshot], documentChanges: [DocumentChange]) {
        self._documents = documents
        self._documentChanges = documentChanges
        super.init()
    }

    override var documents: [DocumentSnapshot] {
        return _documents
    }

    override var documentChanges: [DocumentChange] {
        return _documentChanges
    }

    override var count: Int {
        return _documents.count
    }

    override var isEmpty: Bool {
        return _documents.isEmpty
    }
}

// TCA dependency registration
extension DependencyValues {
    var firebaseClient: FirebaseClient {
        get { self[FirebaseClientKey.self] }
        set { self[FirebaseClientKey.self] = newValue }
    }

    private enum FirebaseClientKey: DependencyKey {
        static let liveValue = FirebaseClient.live
        static let testValue = FirebaseClient.test
    }
}
