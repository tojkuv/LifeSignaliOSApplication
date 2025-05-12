import Foundation
import FirebaseFirestore
import DependenciesMacros
import Dependencies
import XCTestDynamicOverlay
import OSLog

/// A client for managing Firebase server timestamps
@DependencyClient
struct FirebaseTimestampManager: Sendable {
    /// Create a server timestamp field value
    var serverTimestamp: @Sendable () -> FieldValue

    /// Create an increment field value
    var increment: @Sendable (_ value: Int) -> FieldValue

    /// Create an increment field value for double values
    var incrementDouble: @Sendable (_ value: Double) -> FieldValue

    /// Create an array union field value
    var arrayUnion: @Sendable (_ elements: [Any]) -> FieldValue

    /// Create an array remove field value
    var arrayRemove: @Sendable (_ elements: [Any]) -> FieldValue

    /// Create a delete field value
    var deleteField: @Sendable () -> FieldValue

    /// Convert a Timestamp to a Date
    var timestampToDate: @Sendable (_ timestamp: Timestamp) -> Date

    /// Convert a Date to a Timestamp
    var dateToTimestamp: @Sendable (_ date: Date) -> Timestamp

    /// Get document data with server timestamp behavior
    var getDocumentWithTimestampBehavior: @Sendable (_ docRef: DocumentReference, _ behavior: ServerTimestampBehavior) async throws -> DocumentSnapshot

    /// Handle server timestamp in document data
    var handleServerTimestamp: @Sendable (_ data: [String: Any], _ behavior: ServerTimestampBehavior) -> [String: Any]
}

// MARK: - Live Implementation

extension FirebaseTimestampManager: DependencyKey {
    static let liveValue = Self(
        serverTimestamp: {
            FirebaseLogger.app.debug("Creating server timestamp field value")
            return FieldValue.serverTimestamp()
        },

        increment: { value in
            FirebaseLogger.app.debug("Creating increment field value: \(value)")
            return FieldValue.increment(Int64(value))
        },

        incrementDouble: { value in
            FirebaseLogger.app.debug("Creating increment field value: \(value)")
            return FieldValue.increment(value)
        },

        arrayUnion: { elements in
            FirebaseLogger.app.debug("Creating array union field value")
            return FieldValue.arrayUnion(elements)
        },

        arrayRemove: { elements in
            FirebaseLogger.app.debug("Creating array remove field value")
            return FieldValue.arrayRemove(elements)
        },

        deleteField: {
            FirebaseLogger.app.debug("Creating delete field value")
            return FieldValue.delete()
        },

        timestampToDate: { timestamp in
            return timestamp.dateValue()
        },

        dateToTimestamp: { date in
            return Timestamp(date: date)
        },

        getDocumentWithTimestampBehavior: { docRef, behavior in
            FirebaseLogger.app.debug("Getting document with timestamp behavior: \(behavior)")
            do {
                let snapshot = try await docRef.getDocument()
                FirebaseLogger.app.debug("Retrieved document with timestamp behavior")
                return snapshot
            } catch {
                FirebaseLogger.app.error("Failed to get document: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        handleServerTimestamp: { data, behavior in
            FirebaseLogger.app.debug("Handling server timestamps with behavior: \(behavior)")
            // Create a mutable copy of the data
            var result = data

            // Process each field to handle server timestamps
            for (key, value) in data {
                if let timestamp = value as? Timestamp {
                    // Keep timestamp as is
                    result[key] = timestamp
                } else if let serverTimestamp = value as? FieldValue {
                    // For server timestamps that haven't been resolved yet
                    switch behavior {
                    case .estimate:
                        // Use current date as an estimate
                        result[key] = Timestamp(date: Date())
                    case .previous:
                        // Keep previous value if available, otherwise use nil
                        result[key] = nil
                    case .none:
                        // Use nil for unresolved server timestamps
                        result[key] = nil
                    @unknown default:
                        // Default to nil for unknown behaviors
                        result[key] = nil
                    }
                } else if let nestedDict = value as? [String: Any] {
                    // Recursively handle nested dictionaries
                    result[key] = handleServerTimestamp(nestedDict, behavior)
                }
            }

            return result
        }
    )
}

// MARK: - Mock Implementation

extension FirebaseTimestampManager {
    /// A mock implementation that returns predefined values for testing
    static func mock(
        serverTimestamp: @escaping () -> FieldValue = { FieldValue.serverTimestamp() },
        increment: @escaping (_ value: Int) -> FieldValue = { _ in FieldValue.increment(1) },
        incrementDouble: @escaping (_ value: Double) -> FieldValue = { _ in FieldValue.increment(1.0) },
        arrayUnion: @escaping (_ elements: [Any]) -> FieldValue = { _ in FieldValue.arrayUnion([]) },
        arrayRemove: @escaping (_ elements: [Any]) -> FieldValue = { _ in FieldValue.arrayRemove([]) },
        deleteField: @escaping () -> FieldValue = { FieldValue.delete() },
        timestampToDate: @escaping (_ timestamp: Timestamp) -> Date = { timestamp in timestamp.dateValue() },
        dateToTimestamp: @escaping (_ date: Date) -> Timestamp = { date in Timestamp(date: date) },
        getDocumentWithTimestampBehavior: @escaping (_ docRef: DocumentReference, _ behavior: ServerTimestampBehavior) async throws -> DocumentSnapshot = { _, _ in
            throw NSError(domain: "MockError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Mock not implemented"])
        },
        handleServerTimestamp: @escaping (_ data: [String: Any], _ behavior: ServerTimestampBehavior) -> [String: Any] = { data, _ in data }
    ) -> Self {
        Self(
            serverTimestamp: serverTimestamp,
            increment: increment,
            incrementDouble: incrementDouble,
            arrayUnion: arrayUnion,
            arrayRemove: arrayRemove,
            deleteField: deleteField,
            timestampToDate: timestampToDate,
            dateToTimestamp: dateToTimestamp,
            getDocumentWithTimestampBehavior: getDocumentWithTimestampBehavior,
            handleServerTimestamp: handleServerTimestamp
        )
    }

    /// A test implementation that fails with an unimplemented error
    static let testValue = Self(
        serverTimestamp: XCTUnimplemented("\(Self.self).serverTimestamp", placeholder: FieldValue.serverTimestamp()),
        increment: XCTUnimplemented("\(Self.self).increment", placeholder: { _ in FieldValue.increment(1) }),
        incrementDouble: XCTUnimplemented("\(Self.self).incrementDouble", placeholder: { _ in FieldValue.increment(1.0) }),
        arrayUnion: XCTUnimplemented("\(Self.self).arrayUnion", placeholder: { _ in FieldValue.arrayUnion([]) }),
        arrayRemove: XCTUnimplemented("\(Self.self).arrayRemove", placeholder: { _ in FieldValue.arrayRemove([]) }),
        deleteField: XCTUnimplemented("\(Self.self).deleteField", placeholder: FieldValue.delete()),
        timestampToDate: XCTUnimplemented("\(Self.self).timestampToDate", placeholder: { timestamp in timestamp.dateValue() }),
        dateToTimestamp: XCTUnimplemented("\(Self.self).dateToTimestamp", placeholder: { date in Timestamp(date: date) }),
        getDocumentWithTimestampBehavior: XCTUnimplemented("\(Self.self).getDocumentWithTimestampBehavior"),
        handleServerTimestamp: XCTUnimplemented("\(Self.self).handleServerTimestamp", placeholder: { data, _ in data })
    )
}

// MARK: - Dependency Registration

extension DependencyValues {
    var firebaseTimestampManager: FirebaseTimestampManager {
        get { self[FirebaseTimestampManager.self] }
        set { self[FirebaseTimestampManager.self] = newValue }
    }
}
