import Foundation
import FirebaseFirestore

/// Constants for contact reference field names
struct ContactReferenceFields {
    /// Path to the contact's user document
    static let referencePath = "referencePath"

    /// Whether this contact is a responder for the user
    static let isResponder = "isResponder"

    /// Whether this contact is a dependent of the user
    static let isDependent = "isDependent"

    /// Whether to send pings to this contact
    static let sendPings = "sendPings"

    /// Whether to receive pings from this contact
    static let receivePings = "receivePings"

    /// Whether to notify this contact on check-in
    static let notifyOnCheckIn = "notifyOnCheckIn"

    /// Whether to notify this contact on check-in expiry
    static let notifyOnExpiry = "notifyOnExpiry"

    /// Optional nickname for this contact
    static let nickname = "nickname"

    /// Optional notes about this contact
    static let notes = "notes"

    /// When this contact was last updated
    static let lastUpdated = "lastUpdated"
}

/// Model representing a contact reference in a user's contacts array in Firestore
///
/// This model is used to represent the relationship between two users in the Firestore database.
/// It contains information about the relationship type (responder/dependent) and additional
/// settings for the relationship such as notification preferences.
///
/// This model is primarily used when reading from and writing to Firestore.
struct ContactReference: Identifiable, Codable {
    // MARK: - Relationship Properties

    /// Whether this contact is a responder for the user
    var isResponder: Bool

    /// Whether this contact is a dependent of the user
    var isDependent: Bool

    /// Path to the contact's user document (format: "users/userId")
    var referencePath: String

    /// Whether to send pings to this contact
    var sendPings: Bool = true

    /// Whether to receive pings from this contact
    var receivePings: Bool = true

    /// Whether to notify this contact on check-in
    var notifyOnCheckIn: Bool = true

    /// Whether to notify this contact on check-in expiry
    var notifyOnExpiry: Bool = true

    /// Optional nickname for this contact
    var nickname: String?

    /// Optional notes about this contact
    var notes: String?

    /// When this contact was last updated
    var lastUpdated: Date = Date()

    // MARK: - User Data Properties

    /// User's full name
    var name: String = "Unknown User"

    /// User's phone number
    var phone: String = ""

    /// User's emergency profile description
    var note: String = ""

    /// User's QR code ID
    var qrCodeId: String?

    /// When this contact was added
    var addedAt: Date = Date()

    /// User's last check-in time
    var lastCheckIn: Date?

    /// User's check-in interval in seconds
    var interval: TimeInterval?

    // MARK: - Alert and Ping Properties

    /// Whether this contact has an active manual alert
    var manualAlertActive: Bool = false

    /// Timestamp when the manual alert was activated
    var manualAlertTimestamp: Date?

    /// Whether this contact has an incoming ping
    var hasIncomingPing: Bool = false

    /// Whether this contact has an outgoing ping
    var hasOutgoingPing: Bool = false

    /// Timestamp when the incoming ping was received
    var incomingPingTimestamp: Date?

    /// Timestamp when the outgoing ping was sent
    var outgoingPingTimestamp: Date?

    // MARK: - Identifiable Conformance

    /// Unique identifier for the contact (user ID)
    var id: String {
        return userId ?? referencePath
    }

    // MARK: - Initialization

    /// Initialize a new ContactReference
    /// - Parameters:
    ///   - userId: The user ID of the contact
    ///   - isResponder: Whether this contact is a responder
    ///   - isDependent: Whether this contact is a dependent
    init(userId: String, isResponder: Bool, isDependent: Bool) {
        self.referencePath = "users/\(userId)"
        self.isResponder = isResponder
        self.isDependent = isDependent
    }

    /// Initialize a new ContactReference with user data
    /// - Parameters:
    ///   - userId: The user ID of the contact
    ///   - name: User's full name
    ///   - phone: User's phone number
    ///   - note: User's emergency profile description
    ///   - qrCodeId: User's QR code ID
    ///   - isResponder: Whether this contact is a responder
    ///   - isDependent: Whether this contact is a dependent
    init(userId: String, name: String, phone: String = "", note: String = "", qrCodeId: String? = nil, isResponder: Bool, isDependent: Bool) {
        self.referencePath = "users/\(userId)"
        self.isResponder = isResponder
        self.isDependent = isDependent
        self.name = name
        self.phone = phone
        self.note = note
        self.qrCodeId = qrCodeId
    }

    /// Create a default ContactReference for display in UI
    /// - Parameters:
    ///   - name: User's full name
    ///   - phone: User's phone number
    ///   - note: User's emergency profile description
    ///   - qrCodeId: User's QR code ID
    ///   - isResponder: Whether this contact is a responder
    ///   - isDependent: Whether this contact is a dependent
    static func createDefault(name: String, phone: String = "", note: String = "", qrCodeId: String? = nil, isResponder: Bool = false, isDependent: Bool = false) -> ContactReference {
        var contact = ContactReference(userId: UUID().uuidString, isResponder: isResponder, isDependent: isDependent)
        contact.name = name
        contact.phone = phone
        contact.note = note
        contact.qrCodeId = qrCodeId
        return contact
    }

    // MARK: - Computed Properties

    /// Get the user ID from the reference path
    var userId: String? {
        let components = referencePath.components(separatedBy: "/")
        guard components.count == 2 && components[0] == "users" else {
            return nil
        }
        return components[1]
    }

    /// Whether this contact is non-responsive (past check-in time)
    var isNonResponsive: Bool {
        guard let lastCheckIn = lastCheckIn, let interval = interval else {
            return false
        }

        let expirationTime = lastCheckIn.addingTimeInterval(interval)
        return Date() > expirationTime
    }

    /// Formatted time remaining until check-in expiration
    var formattedTimeRemaining: String {
        guard let lastCheckIn = lastCheckIn, let interval = interval else {
            return ""
        }

        let expirationTime = lastCheckIn.addingTimeInterval(interval)
        let timeRemaining = expirationTime.timeIntervalSince(Date())

        if timeRemaining <= 0 {
            return "Overdue"
        }

        // Format the time remaining
        let days = Int(timeRemaining / (60 * 60 * 24))
        let hours = Int((timeRemaining.truncatingRemainder(dividingBy: 60 * 60 * 24)) / (60 * 60))

        if days > 0 {
            return "\(days)d \(hours)h"
        } else {
            let minutes = Int((timeRemaining.truncatingRemainder(dividingBy: 60 * 60)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }

    // MARK: - Firestore Methods

    /// Convert to Firestore data
    /// - Returns: Dictionary representation for Firestore
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            ContactReferenceFields.referencePath: referencePath,
            ContactReferenceFields.isResponder: isResponder,
            ContactReferenceFields.isDependent: isDependent,
            ContactReferenceFields.sendPings: sendPings,
            ContactReferenceFields.receivePings: receivePings,
            ContactReferenceFields.notifyOnCheckIn: notifyOnCheckIn,
            ContactReferenceFields.notifyOnExpiry: notifyOnExpiry,
            ContactReferenceFields.lastUpdated: Timestamp(date: lastUpdated)
        ]

        // Add optional fields if they exist
        if let nickname = nickname {
            data[ContactReferenceFields.nickname] = nickname
        }

        if let notes = notes {
            data[ContactReferenceFields.notes] = notes
        }

        return data
    }

    /// Create a ContactReference from Firestore data
    /// - Parameter data: Dictionary containing contact reference data from Firestore
    /// - Returns: A new ContactReference instance, or nil if required data is missing
    static func fromFirestore(_ data: [String: Any]) -> ContactReference? {
        guard let referencePath = data[ContactReferenceFields.referencePath] as? String,
              let isResponder = data[ContactReferenceFields.isResponder] as? Bool,
              let isDependent = data[ContactReferenceFields.isDependent] as? Bool else {
            return nil
        }

        // Extract the user ID from the path (format: "users/userId")
        let components = referencePath.components(separatedBy: "/")
        guard components.count == 2 && components[0] == "users" else {
            return nil
        }

        let userId = components[1]
        var contactRef = ContactReference(userId: userId, isResponder: isResponder, isDependent: isDependent)

        // Set optional properties if available
        contactRef.sendPings = data[ContactReferenceFields.sendPings] as? Bool ?? true
        contactRef.receivePings = data[ContactReferenceFields.receivePings] as? Bool ?? true
        contactRef.notifyOnCheckIn = data[ContactReferenceFields.notifyOnCheckIn] as? Bool ?? true
        contactRef.notifyOnExpiry = data[ContactReferenceFields.notifyOnExpiry] as? Bool ?? true
        contactRef.nickname = data[ContactReferenceFields.nickname] as? String
        contactRef.notes = data[ContactReferenceFields.notes] as? String

        if let lastUpdated = data[ContactReferenceFields.lastUpdated] as? Timestamp {
            contactRef.lastUpdated = lastUpdated.dateValue()
        }

        return contactRef
    }
}
