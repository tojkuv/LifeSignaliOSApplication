import Foundation
import FirebaseFirestore
import SwiftUI
import Combine
import ComposableArchitecture

/// A helper class for monitoring Firestore documents and collections
@Observable class FirestoreMonitor<T: Decodable> {
    /// The current value
    private(set) var value: T?
    
    /// The loading state
    private(set) var isLoading = true
    
    /// The error state
    private(set) var error: Error?
    
    /// The task that manages the stream
    private var task: Task<Void, Never>?
    
    /// Initialize with a document stream
    /// - Parameters:
    ///   - documentStream: The document stream to monitor
    ///   - decoder: The decoder to use for decoding the document data
    init(documentStream: AsyncStream<DocumentSnapshot>, decoder: JSONDecoder = JSONDecoder()) {
        task = Task {
            for await snapshot in documentStream {
                do {
                    if snapshot.exists, let data = snapshot.data() {
                        // Convert Firestore data to JSON data
                        let jsonData = try JSONSerialization.data(withJSONObject: data)
                        
                        // Decode the JSON data to the generic type
                        self.value = try decoder.decode(T.self, from: jsonData)
                        self.isLoading = false
                        self.error = nil
                    } else {
                        self.value = nil
                        self.isLoading = false
                        self.error = FirebaseError.documentNotFound
                    }
                } catch {
                    self.value = nil
                    self.isLoading = false
                    self.error = error
                }
            }
        }
    }
    
    /// Initialize with a collection stream
    /// - Parameters:
    ///   - collectionStream: The collection stream to monitor
    ///   - decoder: The decoder to use for decoding the collection data
    init(collectionStream: AsyncStream<QuerySnapshot>, decoder: JSONDecoder = JSONDecoder()) where T: Collection, T.Element: Decodable {
        task = Task {
            for await snapshot in collectionStream {
                do {
                    var items = [T.Element]()
                    
                    for document in snapshot.documents {
                        if let data = document.data() {
                            // Convert Firestore data to JSON data
                            let jsonData = try JSONSerialization.data(withJSONObject: data)
                            
                            // Decode the JSON data to the element type
                            let item = try decoder.decode(T.Element.self, from: jsonData)
                            items.append(item)
                        }
                    }
                    
                    // Create the collection from the items
                    if let collection = items as? T {
                        self.value = collection
                        self.isLoading = false
                        self.error = nil
                    } else {
                        self.value = nil
                        self.isLoading = false
                        self.error = FirebaseError.invalidData
                    }
                } catch {
                    self.value = nil
                    self.isLoading = false
                    self.error = error
                }
            }
        }
    }
    
    /// Initialize with a user contacts stream
    /// - Parameters:
    ///   - contactsStream: The contacts stream to monitor
    ///   - decoder: The decoder to use for decoding the contacts data
    init(contactsStream: AsyncStream<[DocumentSnapshot]>, decoder: JSONDecoder = JSONDecoder()) where T: Collection, T.Element: Decodable {
        task = Task {
            for await snapshots in contactsStream {
                do {
                    var items = [T.Element]()
                    
                    for snapshot in snapshots {
                        if snapshot.exists, let data = snapshot.data() {
                            // Convert Firestore data to JSON data
                            let jsonData = try JSONSerialization.data(withJSONObject: data)
                            
                            // Decode the JSON data to the element type
                            let item = try decoder.decode(T.Element.self, from: jsonData)
                            items.append(item)
                        }
                    }
                    
                    // Create the collection from the items
                    if let collection = items as? T {
                        self.value = collection
                        self.isLoading = false
                        self.error = nil
                    } else {
                        self.value = nil
                        self.isLoading = false
                        self.error = FirebaseError.invalidData
                    }
                } catch {
                    self.value = nil
                    self.isLoading = false
                    self.error = error
                }
            }
        }
    }
    
    deinit {
        // Cancel the task when the monitor is deallocated
        task?.cancel()
    }
}

/// A SwiftUI view that monitors a Firestore document
struct FirestoreDocumentMonitor<T: Decodable, Content: View>: View {
    /// The document stream to monitor
    private let documentStream: AsyncStream<DocumentSnapshot>
    
    /// The content view builder
    private let content: (T?, Bool, Error?) -> Content
    
    /// The monitor
    @State private var monitor: FirestoreMonitor<T>?
    
    /// Initialize with a document stream
    /// - Parameters:
    ///   - documentStream: The document stream to monitor
    ///   - content: The content view builder
    init(documentStream: AsyncStream<DocumentSnapshot>, @ViewBuilder content: @escaping (T?, Bool, Error?) -> Content) {
        self.documentStream = documentStream
        self.content = content
    }
    
    var body: some View {
        Group {
            if let monitor = monitor {
                content(monitor.value, monitor.isLoading, monitor.error)
            } else {
                content(nil, true, nil)
                    .onAppear {
                        monitor = FirestoreMonitor<T>(documentStream: documentStream)
                    }
            }
        }
    }
}

/// A SwiftUI view that monitors a Firestore collection
struct FirestoreCollectionMonitor<T: Collection, Content: View> where T.Element: Decodable {
    /// The collection stream to monitor
    private let collectionStream: AsyncStream<QuerySnapshot>
    
    /// The content view builder
    private let content: (T?, Bool, Error?) -> Content
    
    /// The monitor
    @State private var monitor: FirestoreMonitor<T>?
    
    /// Initialize with a collection stream
    /// - Parameters:
    ///   - collectionStream: The collection stream to monitor
    ///   - content: The content view builder
    init(collectionStream: AsyncStream<QuerySnapshot>, @ViewBuilder content: @escaping (T?, Bool, Error?) -> Content) {
        self.collectionStream = collectionStream
        self.content = content
    }
    
    var body: some View {
        Group {
            if let monitor = monitor {
                content(monitor.value, monitor.isLoading, monitor.error)
            } else {
                content(nil, true, nil)
                    .onAppear {
                        monitor = FirestoreMonitor<T>(collectionStream: collectionStream)
                    }
            }
        }
    }
}

/// A SwiftUI view that monitors a user's contacts
struct FirestoreContactsMonitor<T: Collection, Content: View> where T.Element: Decodable {
    /// The contacts stream to monitor
    private let contactsStream: AsyncStream<[DocumentSnapshot]>
    
    /// The content view builder
    private let content: (T?, Bool, Error?) -> Content
    
    /// The monitor
    @State private var monitor: FirestoreMonitor<T>?
    
    /// Initialize with a contacts stream
    /// - Parameters:
    ///   - contactsStream: The contacts stream to monitor
    ///   - content: The content view builder
    init(contactsStream: AsyncStream<[DocumentSnapshot]>, @ViewBuilder content: @escaping (T?, Bool, Error?) -> Content) {
        self.contactsStream = contactsStream
        self.content = content
    }
    
    var body: some View {
        Group {
            if let monitor = monitor {
                content(monitor.value, monitor.isLoading, monitor.error)
            } else {
                content(nil, true, nil)
                    .onAppear {
                        monitor = FirestoreMonitor<T>(contactsStream: contactsStream)
                    }
            }
        }
    }
}
