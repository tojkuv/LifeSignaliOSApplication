import Foundation
import FirebaseFirestore

/// Model representing a contact reference in a user's contacts array in Firestore
///
/// This model is used to represent the relationship between two users in the Firestore database.
/// It contains information about the relationship type (responder/dependent) and additional
/// settings for the relationship such as notification preferences.
///
/// This model is primarily used when reading from and writing to Firestore.
struct ContactReference: Identifiable, Codable {
    /// Constants for contact reference field names
    struct Fields {
        // MARK: - Relationship Properties

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

        /// Optional nickname for this contact
        static let nickname = "nickname"

        /// Optional notes about this contact
        static let notes = "notes"

        /// When this contact was last updated
        static let lastUpdated = "lastUpdated"

        // MARK: - User Data Properties

        /// User's full name
        static let name = "name"

        /// User's phone number
        static let phone = "phone"

        /// User's emergency profile description
        static let note = "note"

        /// User's QR code ID
        static let qrCodeId = "qrCodeId"

        /// When this contact was added
        static let addedAt = "addedAt"

        /// User's last check-in time
        static let lastCheckIn = "lastCheckIn"

        /// User's check-in interval in seconds
        static let interval = "interval"

        // MARK: - Alert and Ping Properties

        /// Whether this contact has an active manual alert
        static let manualAlertActive = "manualAlertActive"

        /// Timestamp when the manual alert was activated
        static let manualAlertTimestamp = "manualAlertTimestamp"

        /// Whether this contact has an incoming ping
        static let hasIncomingPing = "hasIncomingPing"

        /// Whether this contact has an outgoing ping
        static let hasOutgoingPing = "hasOutgoingPing"

        /// Timestamp when the incoming ping was received
        static let incomingPingTimestamp = "incomingPingTimestamp"

        /// Timestamp when the outgoing ping was sent
        static let outgoingPingTimestamp = "outgoingPingTimestamp"
    }

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

    /// Initialize a new ContactReference with all properties
    /// - Parameters:
    ///   - userId: The user ID of the contact
    ///   - isResponder: Whether this contact is a responder
    ///   - isDependent: Whether this contact is a dependent
    ///   - name: User's full name
    ///   - phone: User's phone number
    ///   - note: User's emergency profile description
    ///   - qrCodeId: User's QR code ID
    ///   - sendPings: Whether to send pings to this contact
    ///   - receivePings: Whether to receive pings from this contact
    init(
        userId: String,
        isResponder: Bool,
        isDependent: Bool,
        name: String = "Unknown User",
        phone: String = "",
        note: String = "",
        qrCodeId: String? = nil,
        sendPings: Bool = true,
        receivePings: Bool = true
    ) {
        self.referencePath = "users/\(userId)"
        self.isResponder = isResponder
        self.isDependent = isDependent
        self.name = name
        self.phone = phone
        self.note = note
        self.qrCodeId = qrCodeId
        self.sendPings = sendPings
        self.receivePings = receivePings
    }

    /// Create a default ContactReference for display in UI previews
    /// - Parameters:
    ///   - name: User's full name
    ///   - phone: User's phone number
    ///   - note: User's emergency profile description
    ///   - qrCodeId: User's QR code ID
    ///   - isResponder: Whether this contact is a responder
    ///   - isDependent: Whether this contact is a dependent
    static func createDefault(
        name: String,
        phone: String = "",
        note: String = "",
        qrCodeId: String? = nil,
        isResponder: Bool = false,
        isDependent: Bool = false
    ) -> ContactReference {
        return ContactReference(
            userId: UUID().uuidString,
            isResponder: isResponder,
            isDependent: isDependent,
            name: name,
            phone: phone,
            note: note,
            qrCodeId: qrCodeId
        )
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
}

// MARK: - Firestore Methods
extension ContactReference {
    /// Convert to Firestore data
    /// - Returns: Dictionary representation for Firestore
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            Fields.referencePath: referencePath,
            Fields.isResponder: isResponder,
            Fields.isDependent: isDependent,
            Fields.sendPings: sendPings,
            Fields.receivePings: receivePings,
            Fields.lastUpdated: Timestamp(date: lastUpdated)
        ]

        // Add optional fields if they exist
        if let nickname = nickname {
            data[Fields.nickname] = nickname
        }

        if let notes = notes {
            data[Fields.notes] = notes
        }

        // Add user data properties
        data[Fields.name] = name
        data[Fields.phone] = phone
        data[Fields.note] = note

        if let qrCodeId = qrCodeId {
            data[Fields.qrCodeId] = qrCodeId
        }

        data[Fields.addedAt] = Timestamp(date: addedAt)

        if let lastCheckIn = lastCheckIn {
            data[Fields.lastCheckIn] = Timestamp(date: lastCheckIn)
        }

        if let interval = interval {
            data[Fields.interval] = interval
        }

        // Add alert and ping properties
        data[Fields.manualAlertActive] = manualAlertActive

        if let manualAlertTimestamp = manualAlertTimestamp {
            data[Fields.manualAlertTimestamp] = Timestamp(date: manualAlertTimestamp)
        }

        data[Fields.hasIncomingPing] = hasIncomingPing
        data[Fields.hasOutgoingPing] = hasOutgoingPing

        if let incomingPingTimestamp = incomingPingTimestamp {
            data[Fields.incomingPingTimestamp] = Timestamp(date: incomingPingTimestamp)
        }

        if let outgoingPingTimestamp = outgoingPingTimestamp {
            data[Fields.outgoingPingTimestamp] = Timestamp(date: outgoingPingTimestamp)
        }

        return data
    }

    /// Create a ContactReference from Firestore data
    /// - Parameter data: Dictionary containing contact reference data from Firestore
    /// - Returns: A new ContactReference instance, or nil if required data is missing
    static func fromFirestore(_ data: [String: Any]) -> ContactReference? {
        guard let referencePath = data[Fields.referencePath] as? String,
              let isResponder = data[Fields.isResponder] as? Bool,
              let isDependent = data[Fields.isDependent] as? Bool else {
            return nil
        }

        // Extract the user ID from the path (format: "users/userId")
        let components = referencePath.components(separatedBy: "/")
        guard components.count == 2 && components[0] == "users" else {
            return nil
        }

        let userId = components[1]

        // Get optional properties
        let sendPings = data[Fields.sendPings] as? Bool ?? true
        let receivePings = data[Fields.receivePings] as? Bool ?? true
        let name = data[Fields.name] as? String ?? "Unknown User"
        let phone = data[Fields.phone] as? String ?? ""
        let note = data[Fields.note] as? String ?? ""
        let qrCodeId = data[Fields.qrCodeId] as? String

        // Create contact with the consolidated initializer
        var contactRef = ContactReference(
            userId: userId,
            isResponder: isResponder,
            isDependent: isDependent,
            name: name,
            phone: phone,
            note: note,
            qrCodeId: qrCodeId,
            sendPings: sendPings,
            receivePings: receivePings
        )

        // Set additional properties
        contactRef.nickname = data[Fields.nickname] as? String
        contactRef.notes = data[Fields.notes] as? String

        if let lastUpdated = data[Fields.lastUpdated] as? Timestamp {
            contactRef.lastUpdated = lastUpdated.dateValue()
        }

        // Additional user data properties already set in initializer

        if let addedAt = data[Fields.addedAt] as? Timestamp {
            contactRef.addedAt = addedAt.dateValue()
        }

        if let lastCheckIn = data[Fields.lastCheckIn] as? Timestamp {
            contactRef.lastCheckIn = lastCheckIn.dateValue()
        }

        if let interval = data[Fields.interval] as? TimeInterval {
            contactRef.interval = interval
        }

        // Set alert and ping properties if available
        contactRef.manualAlertActive = data[Fields.manualAlertActive] as? Bool ?? false

        if let manualAlertTimestamp = data[Fields.manualAlertTimestamp] as? Timestamp {
            contactRef.manualAlertTimestamp = manualAlertTimestamp.dateValue()
        }

        contactRef.hasIncomingPing = data[Fields.hasIncomingPing] as? Bool ?? false
        contactRef.hasOutgoingPing = data[Fields.hasOutgoingPing] as? Bool ?? false

        if let incomingPingTimestamp = data[Fields.incomingPingTimestamp] as? Timestamp {
            contactRef.incomingPingTimestamp = incomingPingTimestamp.dateValue()
        }

        if let outgoingPingTimestamp = data[Fields.outgoingPingTimestamp] as? Timestamp {
            contactRef.outgoingPingTimestamp = outgoingPingTimestamp.dateValue()
        }

        return contactRef
    }
}
