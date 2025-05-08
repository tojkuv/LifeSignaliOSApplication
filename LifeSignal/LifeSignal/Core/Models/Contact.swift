import Foundation
import UIKit

/// Model representing a contact in the LifeSignal app.
struct Contact: Identifiable, Codable, Equatable {
    // MARK: - Properties

    /// Unique identifier for the contact
    let id: UUID

    /// Optional avatar image (not persisted)
    var avatar: UIImage? = nil

    /// Contact's full name
    var name: String

    /// Contact's phone number
    var phone: String

    /// Note associated with the contact
    var note: String

    /// Optional QR code identifier (only used for lookup, not stored)
    var qrCodeId: String? = nil

    /// True if the contact is a responder
    var isResponder: Bool

    /// True if the contact is a dependent
    var isDependent: Bool

    /// Last check-in date (optional)
    var lastCheckIn: Date?

    /// Check-in interval in seconds (defaults to 24 hours if nil)
    var interval: TimeInterval?

    /// Timestamp when the contact was added
    var addedAt: Date

    /// True if a manual alert is active for this contact
    var manualAlertActive: Bool

    /// Timestamp of the most recent manual alert (if any)
    var manualAlertTimestamp: Date?

    /// True if the contact has sent a ping to the user that hasn't been responded to (incoming ping)
    var hasIncomingPing: Bool

    /// True if the user has sent a ping to the contact that hasn't been responded to (outgoing ping)
    var hasOutgoingPing: Bool

    /// Timestamp of the most recent incoming ping (if any)
    var incomingPingTimestamp: Date?

    /// Timestamp of the most recent outgoing ping (if any)
    var outgoingPingTimestamp: Date?

    // MARK: - Backward Compatibility

    /// Backward compatibility property - true if either incoming or outgoing ping is pending
    var hasPendingPing: Bool {
        return hasIncomingPing || hasOutgoingPing
    }

    /// Backward compatibility property - returns the most recent ping timestamp
    var pingTimestamp: Date? {
        if let incoming = incomingPingTimestamp, let outgoing = outgoingPingTimestamp {
            return incoming > outgoing ? incoming : outgoing
        }
        return incomingPingTimestamp ?? outgoingPingTimestamp
    }

    // MARK: - Computed Properties

    /// Returns true if the contact has at least one role
    var hasRole: Bool { isResponder || isDependent }

    /// Returns the effective interval, using the default if none is set
    var effectiveInterval: TimeInterval {
        return interval ?? TimeManager.defaultInterval
    }

    /// Returns true if the contact is non-responsive based on their check-in status
    var isNonResponsive: Bool {
        return TimeManager.shared.isNonResponsive(lastCheckIn: lastCheckIn, interval: effectiveInterval)
    }

    /// Returns the time remaining until the contact's check-in expires
    var timeRemaining: TimeInterval {
        guard let lastCheckIn = lastCheckIn else { return 0 }
        return TimeManager.shared.timeRemaining(lastCheckIn: lastCheckIn, interval: effectiveInterval)
    }

    /// Returns the formatted time remaining string
    var formattedTimeRemaining: String {
        return TimeManager.shared.formatTimeInterval(timeRemaining)
    }

    // MARK: - Codable

    // Custom CodingKeys to ignore avatar for Codable
    enum CodingKeys: String, CodingKey {
        case id, name, phone, note, qrCodeId, isResponder, isDependent, lastCheckIn, interval, addedAt, manualAlertActive, manualAlertTimestamp
        case hasIncomingPing, hasOutgoingPing, incomingPingTimestamp, outgoingPingTimestamp
    }

    // Custom initializer for Decodable
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode standard properties
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        phone = try container.decode(String.self, forKey: .phone)
        note = try container.decode(String.self, forKey: .note)
        qrCodeId = try container.decodeIfPresent(String.self, forKey: .qrCodeId)
        isResponder = try container.decode(Bool.self, forKey: .isResponder)
        isDependent = try container.decode(Bool.self, forKey: .isDependent)
        lastCheckIn = try container.decodeIfPresent(Date.self, forKey: .lastCheckIn)
        interval = try container.decodeIfPresent(TimeInterval.self, forKey: .interval)
        addedAt = try container.decode(Date.self, forKey: .addedAt)
        manualAlertActive = try container.decode(Bool.self, forKey: .manualAlertActive)
        manualAlertTimestamp = try container.decodeIfPresent(Date.self, forKey: .manualAlertTimestamp)

        // Try to decode new ping properties
        if container.contains(.hasIncomingPing) {
            hasIncomingPing = try container.decode(Bool.self, forKey: .hasIncomingPing)
            hasOutgoingPing = try container.decode(Bool.self, forKey: .hasOutgoingPing)
            incomingPingTimestamp = try container.decodeIfPresent(Date.self, forKey: .incomingPingTimestamp)
            outgoingPingTimestamp = try container.decodeIfPresent(Date.self, forKey: .outgoingPingTimestamp)
        } else {
            // Handle legacy format
            enum LegacyKeys: String, CodingKey {
                case hasPendingPing, pingTimestamp
            }

            let legacyContainer = try decoder.container(keyedBy: LegacyKeys.self)
            let legacyHasPendingPing = try legacyContainer.decodeIfPresent(Bool.self, forKey: .hasPendingPing) ?? false
            let legacyPingTimestamp = try legacyContainer.decodeIfPresent(Date.self, forKey: .pingTimestamp)

            // Set new properties based on legacy values
            hasIncomingPing = isResponder && legacyHasPendingPing
            hasOutgoingPing = isDependent && legacyHasPendingPing
            incomingPingTimestamp = isResponder && legacyHasPendingPing ? legacyPingTimestamp : nil
            outgoingPingTimestamp = isDependent && legacyHasPendingPing ? legacyPingTimestamp : nil
        }
    }

    // Custom encode method for Encodable
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Encode standard properties
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(phone, forKey: .phone)
        try container.encode(note, forKey: .note)
        try container.encodeIfPresent(qrCodeId, forKey: .qrCodeId)
        try container.encode(isResponder, forKey: .isResponder)
        try container.encode(isDependent, forKey: .isDependent)
        try container.encodeIfPresent(lastCheckIn, forKey: .lastCheckIn)
        try container.encodeIfPresent(interval, forKey: .interval)
        try container.encode(addedAt, forKey: .addedAt)
        try container.encode(manualAlertActive, forKey: .manualAlertActive)
        try container.encodeIfPresent(manualAlertTimestamp, forKey: .manualAlertTimestamp)

        // Encode new ping properties
        try container.encode(hasIncomingPing, forKey: .hasIncomingPing)
        try container.encode(hasOutgoingPing, forKey: .hasOutgoingPing)
        try container.encodeIfPresent(incomingPingTimestamp, forKey: .incomingPingTimestamp)
        try container.encodeIfPresent(outgoingPingTimestamp, forKey: .outgoingPingTimestamp)
    }

    // MARK: - Equatable

    static func == (lhs: Contact, rhs: Contact) -> Bool {
        return lhs.id == rhs.id
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        avatar: UIImage? = nil,
        name: String,
        phone: String,
        note: String,
        qrCodeId: String? = nil,
        isResponder: Bool = false,
        isDependent: Bool = false,
        lastCheckIn: Date? = nil,
        interval: TimeInterval? = nil,
        addedAt: Date? = nil,
        manualAlertActive: Bool = false,
        manualAlertTimestamp: Date? = nil,
        hasIncomingPing: Bool = false,
        hasOutgoingPing: Bool = false,
        incomingPingTimestamp: Date? = nil,
        outgoingPingTimestamp: Date? = nil,
        // Backward compatibility parameters
        hasPendingPing: Bool? = nil,
        pingTimestamp: Date? = nil
    ) {
        self.id = id
        self.avatar = avatar
        self.name = name
        self.phone = phone
        self.note = note
        self.qrCodeId = qrCodeId
        self.isResponder = isResponder
        self.isDependent = isDependent
        self.lastCheckIn = lastCheckIn

        // Ensure interval is valid if provided
        if let interval = interval {
            self.interval = max(TimeManager.minimumInterval, interval)
        } else {
            self.interval = nil
        }

        // Use current date if addedAt is nil
        self.addedAt = addedAt ?? Date()
        self.manualAlertActive = manualAlertActive
        self.manualAlertTimestamp = manualAlertTimestamp

        // Handle ping properties with backward compatibility
        if let legacyHasPendingPing = hasPendingPing {
            // If using legacy parameter, set both new flags to the same value
            self.hasIncomingPing = isResponder && legacyHasPendingPing
            self.hasOutgoingPing = isDependent && legacyHasPendingPing
            self.incomingPingTimestamp = isResponder && legacyHasPendingPing ? pingTimestamp : nil
            self.outgoingPingTimestamp = isDependent && legacyHasPendingPing ? pingTimestamp : nil
        } else {
            // Otherwise use the new parameters
            self.hasIncomingPing = hasIncomingPing
            self.hasOutgoingPing = hasOutgoingPing
            self.incomingPingTimestamp = incomingPingTimestamp
            self.outgoingPingTimestamp = outgoingPingTimestamp
        }
    }

    // MARK: - Factory Methods

    /// Creates a new contact with safe default values
    static func createDefault(
        name: String,
        phone: String,
        note: String,
        qrCodeId: String? = nil,
        isResponder: Bool = false,
        isDependent: Bool = false
    ) -> Contact {
        return Contact(
            name: name,
            phone: phone,
            note: note,
            qrCodeId: qrCodeId,
            isResponder: isResponder,
            isDependent: isDependent,
            lastCheckIn: nil,
            interval: TimeManager.defaultInterval,
            addedAt: Date(),
            manualAlertActive: false,
            manualAlertTimestamp: nil,
            hasIncomingPing: false,
            hasOutgoingPing: false,
            incomingPingTimestamp: nil,
            outgoingPingTimestamp: nil
        )
    }
}