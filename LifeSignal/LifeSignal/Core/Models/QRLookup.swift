import Foundation
import FirebaseFirestore

/// Constants for QR lookup document field names
struct QRLookupFields {
    /// QR code ID
    static let qrCodeId = "qrCodeId"

    /// Timestamp when QR code was last updated
    static let updatedAt = "updatedAt"
}

/// Model representing a QR lookup document for Firestore operations
///
/// This model is used internally for Firestore operations and is converted
/// to/from the QRLookup model as needed. The document ID in Firestore is the user ID.
struct QRLookupDocument {
    /// QR code ID
    var qrCodeId: String

    /// Timestamp when QR code was last updated
    var updatedAt: Date

    /// Initialize a new QRLookupDocument
    /// - Parameters:
    ///   - qrCodeId: QR code ID
    ///   - updatedAt: Timestamp when QR code was last updated
    init(qrCodeId: String, updatedAt: Date = Date()) {
        self.qrCodeId = qrCodeId
        self.updatedAt = updatedAt
    }

    /// Convert to Firestore data
    /// - Returns: Dictionary representation for Firestore
    func toFirestoreData() -> [String: Any] {
        return [
            QRLookupFields.qrCodeId: qrCodeId,
            QRLookupFields.updatedAt: Timestamp(date: updatedAt)
        ]
    }
}

/// Model representing a QR code lookup document in Firestore
///
/// This model is used to map QR codes to user IDs for contact discovery.
/// It is stored in the qr_lookup collection in Firestore.
/// The document ID is the user ID, so there's no need for a separate userId field.
struct QRLookup: Codable, Identifiable {
    /// Document ID (same as user ID)
    var id: String

    /// QR code ID
    var qrCodeId: String

    /// Timestamp when QR code was last updated
    var updatedAt: Date

    /// Initialize a new QRLookup
    /// - Parameters:
    ///   - id: Document ID (user ID)
    ///   - qrCodeId: QR code ID
    init(id: String, qrCodeId: String) {
        self.id = id
        self.qrCodeId = qrCodeId
        self.updatedAt = Date()
    }

    /// Convert to Firestore data
    /// - Returns: Dictionary representation for Firestore
    func toFirestoreData() -> [String: Any] {
        return [
            QRLookupFields.qrCodeId: qrCodeId,
            QRLookupFields.updatedAt: Timestamp(date: updatedAt)
        ]
    }

    /// Create a QRLookup from Firestore data
    /// - Parameters:
    ///   - data: Dictionary containing QR lookup data from Firestore
    ///   - id: The document ID (user ID)
    /// - Returns: A new QRLookup instance, or nil if required data is missing
    static func fromFirestore(_ data: [String: Any], id: String) -> QRLookup? {
        guard let qrCodeId = data[QRLookupFields.qrCodeId] as? String else {
            return nil
        }

        var qrLookup = QRLookup(id: id, qrCodeId: qrCodeId)

        if let updatedAt = data[QRLookupFields.updatedAt] as? Timestamp {
            qrLookup.updatedAt = updatedAt.dateValue()
        }

        return qrLookup
    }
}
