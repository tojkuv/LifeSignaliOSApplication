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
    var serverTimestamp: @Sendable () -> FieldValue = {
        FieldValue.serverTimestamp()
    }

    /// Create an increment field value
    var increment: @Sendable (Int) -> FieldValue = { value in
        FieldValue.increment(Int64(value))
    }

    /// Create an increment field value for double values
    var incrementDouble: @Sendable (Double) -> FieldValue = { value in
        FieldValue.increment(value)
    }

    /// Create an array union field value
    var arrayUnion: @Sendable ([Any]) -> FieldValue = { elements in
        FieldValue.arrayUnion(elements)
    }

    /// Create an array remove field value
    var arrayRemove: @Sendable ([Any]) -> FieldValue = { elements in
        FieldValue.arrayRemove(elements)
    }

    /// Create a delete field value
    var deleteField: @Sendable () -> FieldValue = {
        FieldValue.delete()
    }

    /// Convert a Timestamp to a Date
    var timestampToDate: @Sendable (Timestamp) -> Date = { timestamp in
        timestamp.dateValue()
    }

    /// Convert a Date to a Timestamp
    var dateToTimestamp: @Sendable (Date) -> Timestamp = { date in
        Timestamp(date: date)
    }

    /// Get document data with server timestamp behavior
    var getDocumentWithTimestampBehavior: @Sendable (DocumentReference, ServerTimestampBehavior) async throws -> DocumentSnapshot = { _, _ in
        throw FirebaseError.operationFailed
    }

    /// Handle server timestamp in document data
    var handleServerTimestamp: @Sendable ([String: Any], ServerTimestampBehavior) -> [String: Any] = { data, _ in
        data
    }
}

// MARK: - Live Implementation

extension FirebaseTimestampManager: DependencyKey {
    static let liveValue: Self = Self(
        serverTimestamp: {
            FirebaseLogger.app.debug("Creating server timestamp field value")
            return FieldValue.serverTimestamp()
        },

        increment: { (value: Int) -> FieldValue in
            FirebaseLogger.app.debug("Creating increment field value: \(value)")
            return FieldValue.increment(Int64(value))
        },

        incrementDouble: { (value: Double) -> FieldValue in
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
        serverTimestamp: @Sendable @escaping () -> FieldValue = { FieldValue.serverTimestamp() },
        increment: @Sendable @escaping (Int) -> FieldValue = { value in FieldValue.increment(Int64(value)) },
        incrementDouble: @Sendable @escaping (Double) -> FieldValue = { value in FieldValue.increment(value) },
        arrayUnion: @Sendable @escaping ([Any]) -> FieldValue = { elements in FieldValue.arrayUnion(elements) },
        arrayRemove: @Sendable @escaping ([Any]) -> FieldValue = { elements in FieldValue.arrayRemove(elements) },
        deleteField: @Sendable @escaping () -> FieldValue = { FieldValue.delete() },
        timestampToDate: @Sendable @escaping (Timestamp) -> Date = { timestamp in timestamp.dateValue() },
        dateToTimestamp: @Sendable @escaping (Date) -> Timestamp = { date in Timestamp(date: date) },
        getDocumentWithTimestampBehavior: @Sendable @escaping (DocumentReference, ServerTimestampBehavior) async throws -> DocumentSnapshot = { _, _ in
            throw FirebaseError.operationFailed
        },
        handleServerTimestamp: @Sendable @escaping ([String: Any], ServerTimestampBehavior) -> [String: Any] = { data, _ in data }
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
}

extension FirebaseTimestampManager: TestDependencyKey {
    /// A test implementation that fails with an unimplemented error
    static let testValue = Self(
        serverTimestamp: unimplemented("\(Self.self).serverTimestamp", placeholder: FieldValue.serverTimestamp()),
        increment: unimplemented("\(Self.self).increment", placeholder: { value in FieldValue.increment(Int64(value)) }),
        incrementDouble: unimplemented("\(Self.self).incrementDouble", placeholder: { value in FieldValue.increment(value) }),
        arrayUnion: unimplemented("\(Self.self).arrayUnion", placeholder: { elements in FieldValue.arrayUnion(elements) }),
        arrayRemove: unimplemented("\(Self.self).arrayRemove", placeholder: { elements in FieldValue.arrayRemove(elements) }),
        deleteField: unimplemented("\(Self.self).deleteField", placeholder: FieldValue.delete()),
        timestampToDate: unimplemented("\(Self.self).timestampToDate", placeholder: { timestamp in timestamp.dateValue() }),
        dateToTimestamp: unimplemented("\(Self.self).dateToTimestamp", placeholder: { date in Timestamp(date: date) }),
        getDocumentWithTimestampBehavior: unimplemented("\(Self.self).getDocumentWithTimestampBehavior"),
        handleServerTimestamp: unimplemented("\(Self.self).handleServerTimestamp", placeholder: { data, _ in data })
    )
}

// MARK: - Dependency Registration

extension DependencyValues {
    var firebaseTimestampManager: FirebaseTimestampManager {
        get { self[FirebaseTimestampManager.self] }
        set { self[FirebaseTimestampManager.self] = newValue }
    }
}
