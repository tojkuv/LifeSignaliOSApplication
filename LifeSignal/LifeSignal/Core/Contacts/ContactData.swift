
import FirebaseFirestore

/// Domain model for a contact in the TCA architecture
struct ContactData: Identifiable, Equatable, Codable, Sendable {
    // MARK: - Identifiable Conformance
    var id: String

    // MARK: - Relationship Properties
    var isResponder: Bool
    var isDependent: Bool
    var emergencyNote: String?
    var lastUpdated: Date
    var addedAt: Date

    // MARK: - Cached User Data Properties
    var name: String

    // MARK: - Status Properties
    var lastCheckedIn: Date?
    var checkInInterval: TimeInterval?
    var hasIncomingPing: Bool
    var hasOutgoingPing: Bool
    var incomingPingTimestamp: Date?
    var outgoingPingTimestamp: Date?
    var manualAlertActive: Bool
    var manualAlertTimestamp: Date?

    // MARK: - Computed Properties
    var isNonResponsive: Bool {
        guard let lastCheckedIn = lastCheckedIn, let checkInInterval = checkInInterval else {
            return false
        }

        let expirationTime = lastCheckedIn.addingTimeInterval(checkInInterval)
        return Date() > expirationTime
    }

    // MARK: - Formatted Properties
    var formattedIncomingPingTime: String?
    var formattedOutgoingPingTime: String?
    var formattedTimeRemaining: String?

    // MARK: - Initialization
    init(
        id: String,
        name: String = "Unknown User",
        isResponder: Bool = false,
        isDependent: Bool = false,
        emergencyNote: String? = nil,
        lastCheckedIn: Date? = nil,
        checkInInterval: TimeInterval? = nil,
        hasIncomingPing: Bool = false,
        hasOutgoingPing: Bool = false,
        incomingPingTimestamp: Date? = nil,
        outgoingPingTimestamp: Date? = nil,
        manualAlertActive: Bool = false,
        manualAlertTimestamp: Date? = nil,
        formattedIncomingPingTime: String? = nil,
        formattedOutgoingPingTime: String? = nil,
        formattedTimeRemaining: String? = nil,
        addedAt: Date = Date(),
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.isResponder = isResponder
        self.isDependent = isDependent
        self.emergencyNote = emergencyNote
        self.lastCheckedIn = lastCheckedIn
        self.checkInInterval = checkInInterval
        self.hasIncomingPing = hasIncomingPing
        self.hasOutgoingPing = hasOutgoingPing
        self.incomingPingTimestamp = incomingPingTimestamp
        self.outgoingPingTimestamp = outgoingPingTimestamp
        self.manualAlertActive = manualAlertActive
        self.manualAlertTimestamp = manualAlertTimestamp
        self.formattedIncomingPingTime = formattedIncomingPingTime
        self.formattedOutgoingPingTime = formattedOutgoingPingTime
        self.formattedTimeRemaining = formattedTimeRemaining
        self.addedAt = addedAt
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Firestore Conversion
extension ContactData {
    /// Create a ContactData instance from Firestore data
    /// - Parameters:
    ///   - data: The Firestore document data
    ///   - id: The document ID
    /// - Returns: A new ContactData instance
    static func fromFirestore(_ data: [String: Any], id: String) -> ContactData {
        let contact = ContactData(id: id)

        // Set basic properties
        if let name = data["name"] as? String {
            contact.name = name
        }

        // Set relationship properties
        contact.isResponder = data[FirestoreConstants.ContactFields.isResponder] as? Bool ?? false
        contact.isDependent = data[FirestoreConstants.ContactFields.isDependent] as? Bool ?? false

        // Set emergency note
        contact.emergencyNote = data["emergencyNote"] as? String

        // Set timestamps
        if let lastUpdatedTimestamp = data[FirestoreConstants.ContactFields.lastUpdated] as? Timestamp {
            contact.lastUpdated = lastUpdatedTimestamp.dateValue()
        }

        if let addedAtTimestamp = data[FirestoreConstants.ContactFields.addedAt] as? Timestamp {
            contact.addedAt = addedAtTimestamp.dateValue()
        }

        // Set check-in data
        if let lastCheckedInTimestamp = data["lastCheckedIn"] as? Timestamp {
            contact.lastCheckedIn = lastCheckedInTimestamp.dateValue()
        }

        contact.checkInInterval = data["checkInInterval"] as? TimeInterval

        // Set ping properties
        contact.hasIncomingPing = data[FirestoreConstants.ContactFields.hasIncomingPing] as? Bool ?? false
        contact.hasOutgoingPing = data[FirestoreConstants.ContactFields.hasOutgoingPing] as? Bool ?? false

        // Set ping timestamps
        if let incomingPingTimestamp = data[FirestoreConstants.ContactFields.incomingPingTimestamp] as? Timestamp {
            contact.incomingPingTimestamp = incomingPingTimestamp.dateValue()
        }

        if let outgoingPingTimestamp = data[FirestoreConstants.ContactFields.outgoingPingTimestamp] as? Timestamp {
            contact.outgoingPingTimestamp = outgoingPingTimestamp.dateValue()
        }

        // Set manual alert properties
        contact.manualAlertActive = data[FirestoreConstants.ContactFields.manualAlertActive] as? Bool ?? false
        if let manualAlertTimestamp = data[FirestoreConstants.ContactFields.manualAlertTimestamp] as? Timestamp {
            contact.manualAlertTimestamp = manualAlertTimestamp.dateValue()
        }

        return contact
    }

    /// Convert the ContactData instance to Firestore data
    /// - Returns: A dictionary of Firestore data
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "name": name,
            FirestoreConstants.ContactFields.isResponder: isResponder,
            FirestoreConstants.ContactFields.isDependent: isDependent,
            FirestoreConstants.ContactFields.lastUpdated: Timestamp(date: lastUpdated),
            FirestoreConstants.ContactFields.addedAt: Timestamp(date: addedAt),
            FirestoreConstants.ContactFields.hasIncomingPing: hasIncomingPing,
            FirestoreConstants.ContactFields.hasOutgoingPing: hasOutgoingPing,
            FirestoreConstants.ContactFields.manualAlertActive: manualAlertActive
        ]

        // Add optional fields
        if let emergencyNote = emergencyNote {
            data["emergencyNote"] = emergencyNote
        }

        if let lastCheckedIn = lastCheckedIn {
            data["lastCheckedIn"] = Timestamp(date: lastCheckedIn)
        }

        if let checkInInterval = checkInInterval {
            data["checkInInterval"] = checkInInterval
        }

        // Add ping timestamps
        if let incomingPingTimestamp = incomingPingTimestamp {
            data[FirestoreConstants.ContactFields.incomingPingTimestamp] = Timestamp(date: incomingPingTimestamp)
        }

        if let outgoingPingTimestamp = outgoingPingTimestamp {
            data[FirestoreConstants.ContactFields.outgoingPingTimestamp] = Timestamp(date: outgoingPingTimestamp)
        }

        // Add manual alert timestamp
        if let manualAlertTimestamp = manualAlertTimestamp {
            data[FirestoreConstants.ContactFields.manualAlertTimestamp] = Timestamp(date: manualAlertTimestamp)
        }

        return data
    }
}

