import Foundation
import FirebaseFirestore

/// Firestore database schema definitions
struct FirestoreSchema {

    /// Root collections in Firestore
    struct Collections {
        /// Users collection
        static let users = "users"

        /// Test collection for Firebase connection testing
        static let test = "test"

        /// Contacts subcollection
        static let contacts = "contacts"

        /// QR code lookup collection
        static let qrLookup = "qr_lookup"
    }

    /// User document schema
    struct User {
        /// User ID (document ID, same as Firebase Auth UID)
        static let uid = "uid"

        /// User's full name
        static let name = "name"

        /// User's phone number (E.164 format)
        static let phoneNumber = "phoneNumber"

        /// User's phone region (ISO country code)
        static let phoneRegion = "phoneRegion"

        /// User's emergency profile description/note
        static let note = "note"

        /// User's check-in interval in seconds
        static let checkInInterval = "checkInInterval"

        /// Timestamp of user's last check-in
        static let lastCheckedIn = "lastCheckedIn"

        /// User's unique QR code identifier
        static let qrCodeId = "qrCodeId"

        /// Flag indicating if user should be notified 30 minutes before check-in expiration
        static let notify30MinBefore = "notify30MinBefore"

        /// Flag indicating if user should be notified 2 hours before check-in expiration
        static let notify2HoursBefore = "notify2HoursBefore"

        /// User's FCM token for push notifications
        static let fcmToken = "fcmToken"

        /// User's session ID for single-device authentication
        static let sessionId = "sessionId"

        /// Timestamp when user was created
        static let createdAt = "createdAt"

        /// Timestamp when user last signed in
        static let lastSignInTime = "lastSignInTime"

        /// Flag indicating if user has completed profile setup
        static let profileComplete = "profileComplete"

        /// Flag indicating if user has enabled notifications
        static let notificationEnabled = "notificationEnabled"

        /// Flag indicating if this is a test user
        static let testUser = "testUser"

        /// Array of contact references
        static let contacts = "contacts"

        /// Timestamp when user data was last updated
        static let lastUpdated = "lastUpdated"
    }

    /// Contact document schema (stored as subcollection or embedded in user document)
    struct Contact {
        /// Contact ID
        static let id = "id"

        /// Contact's full name
        static let name = "name"

        /// Contact's phone number
        static let phoneNumber = "phoneNumber"

        /// Note associated with the contact
        static let note = "note"

        /// Contact's QR code identifier
        static let qrCodeId = "qrCodeId"

        /// Flag indicating if contact is a responder
        static let isResponder = "isResponder"

        /// Flag indicating if contact is a dependent
        static let isDependent = "isDependent"

        /// Timestamp of contact's last check-in
        static let lastCheckedIn = "lastCheckedIn"

        /// Contact's check-in interval in seconds
        static let checkInInterval = "checkInInterval"

        /// Timestamp when contact was added
        static let addedAt = "addedAt"

        /// Flag indicating if manual alert is active for this contact
        static let manualAlertActive = "manualAlertActive"

        /// Timestamp when manual alert was activated
        static let manualAlertTimestamp = "manualAlertTimestamp"

        /// Flag indicating if contact has an incoming ping
        static let hasIncomingPing = "hasIncomingPing"

        /// Flag indicating if contact has an outgoing ping
        static let hasOutgoingPing = "hasOutgoingPing"

        /// Timestamp of incoming ping
        static let incomingPingTimestamp = "incomingPingTimestamp"

        /// Timestamp of outgoing ping
        static let outgoingPingTimestamp = "outgoingPingTimestamp"
    }

    /// QR code lookup document schema
    struct QRLookup {
        /// QR code ID
        static let qrCodeId = "qrCodeId"

        /// Timestamp when QR code was last updated
        static let updatedAt = "updatedAt"
    }
}

/// User document model for Firestore
struct UserDocument: Codable {
    /// User ID (same as Firebase Auth UID)
    var uid: String

    /// User's full name
    var name: String

    /// User's phone number (E.164 format)
    var phoneNumber: String

    /// User's phone region (ISO country code)
    var phoneRegion: String = "US"

    /// User's emergency profile description/note
    var note: String

    /// User's check-in interval in seconds (default: 24 hours)
    var checkInInterval: TimeInterval = 86400

    /// Timestamp of user's last check-in
    var lastCheckedIn: Date = Date()

    /// User's unique QR code identifier
    var qrCodeId: String

    /// Flag indicating if user should be notified 30 minutes before check-in expiration
    var notify30MinBefore: Bool = true

    /// Flag indicating if user should be notified 2 hours before check-in expiration
    var notify2HoursBefore: Bool = false

    /// User's FCM token for push notifications
    var fcmToken: String?

    /// User's session ID for single-device authentication
    var sessionId: String?

    /// Timestamp when user was created
    var createdAt: Date

    /// Timestamp when user last signed in
    var lastSignInTime: Date

    /// Flag indicating if user has completed profile setup
    var profileComplete: Bool = false

    /// Flag indicating if user has enabled notifications
    var notificationEnabled: Bool = true

    /// Flag indicating if this is a test user
    var testUser: Bool = false

    /// Timestamp when user data was last updated
    var lastUpdated: Date = Date()

    /// Convert to Firestore data
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            FirestoreSchema.User.uid: uid,
            FirestoreSchema.User.name: name,
            FirestoreSchema.User.phoneNumber: phoneNumber,
            FirestoreSchema.User.phoneRegion: phoneRegion,
            FirestoreSchema.User.note: note,
            FirestoreSchema.User.checkInInterval: checkInInterval,
            FirestoreSchema.User.lastCheckedIn: lastCheckedIn,
            FirestoreSchema.User.qrCodeId: qrCodeId,
            FirestoreSchema.User.notify30MinBefore: notify30MinBefore,
            FirestoreSchema.User.notify2HoursBefore: notify2HoursBefore,
            FirestoreSchema.User.createdAt: createdAt,
            FirestoreSchema.User.lastSignInTime: lastSignInTime,
            FirestoreSchema.User.profileComplete: profileComplete,
            FirestoreSchema.User.notificationEnabled: notificationEnabled,
            FirestoreSchema.User.testUser: testUser,
            FirestoreSchema.User.lastUpdated: lastUpdated
        ]

        if let fcmToken = fcmToken {
            data[FirestoreSchema.User.fcmToken] = fcmToken
        }

        if let sessionId = sessionId {
            data[FirestoreSchema.User.sessionId] = sessionId
        }

        return data
    }
}

/// Contact document model for Firestore
struct ContactDocument: Codable {
    /// Contact ID (UUID as string)
    var id: String

    /// Contact's full name
    var name: String

    /// Contact's phone number
    var phoneNumber: String

    /// Note associated with the contact
    var note: String

    /// Contact's QR code identifier
    var qrCodeId: String?

    /// Flag indicating if contact is a responder
    var isResponder: Bool

    /// Flag indicating if contact is a dependent
    var isDependent: Bool

    /// Timestamp of contact's last check-in
    var lastCheckedIn: Date?

    /// Contact's check-in interval in seconds
    var checkInInterval: TimeInterval?

    /// Timestamp when contact was added
    var addedAt: Date

    /// Flag indicating if manual alert is active for this contact
    var manualAlertActive: Bool = false

    /// Timestamp when manual alert was activated
    var manualAlertTimestamp: Date?

    /// Flag indicating if contact has an incoming ping
    var hasIncomingPing: Bool = false

    /// Flag indicating if contact has an outgoing ping
    var hasOutgoingPing: Bool = false

    /// Timestamp of incoming ping
    var incomingPingTimestamp: Date?

    /// Timestamp of outgoing ping
    var outgoingPingTimestamp: Date?

    /// Convert to Firestore data
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            FirestoreSchema.Contact.id: id,
            FirestoreSchema.Contact.name: name,
            FirestoreSchema.Contact.phoneNumber: phoneNumber,
            FirestoreSchema.Contact.note: note,
            FirestoreSchema.Contact.isResponder: isResponder,
            FirestoreSchema.Contact.isDependent: isDependent,
            FirestoreSchema.Contact.addedAt: addedAt,
            FirestoreSchema.Contact.manualAlertActive: manualAlertActive,
            FirestoreSchema.Contact.hasIncomingPing: hasIncomingPing,
            FirestoreSchema.Contact.hasOutgoingPing: hasOutgoingPing
        ]

        if let qrCodeId = qrCodeId {
            data[FirestoreSchema.Contact.qrCodeId] = qrCodeId
        }

        if let lastCheckedIn = lastCheckedIn {
            data[FirestoreSchema.Contact.lastCheckedIn] = lastCheckedIn
        }

        if let checkInInterval = checkInInterval {
            data[FirestoreSchema.Contact.checkInInterval] = checkInInterval
        }

        if let manualAlertTimestamp = manualAlertTimestamp {
            data[FirestoreSchema.Contact.manualAlertTimestamp] = manualAlertTimestamp
        }

        if let incomingPingTimestamp = incomingPingTimestamp {
            data[FirestoreSchema.Contact.incomingPingTimestamp] = incomingPingTimestamp
        }

        if let outgoingPingTimestamp = outgoingPingTimestamp {
            data[FirestoreSchema.Contact.outgoingPingTimestamp] = outgoingPingTimestamp
        }

        return data
    }

    /// Create a ContactDocument from a Contact model
    static func fromContact(_ contact: Contact) -> ContactDocument {
        return ContactDocument(
            id: contact.id.uuidString,
            name: contact.name,
            phoneNumber: contact.phone,
            note: contact.note,
            qrCodeId: nil, // Don't store QR code ID in contact document
            isResponder: contact.isResponder,
            isDependent: contact.isDependent,
            lastCheckedIn: contact.lastCheckIn,
            checkInInterval: contact.interval,
            addedAt: contact.addedAt,
            manualAlertActive: contact.manualAlertActive,
            manualAlertTimestamp: contact.manualAlertTimestamp,
            hasIncomingPing: contact.hasIncomingPing,
            hasOutgoingPing: contact.hasOutgoingPing,
            incomingPingTimestamp: contact.incomingPingTimestamp,
            outgoingPingTimestamp: contact.outgoingPingTimestamp
        )
    }
}

/// QR code lookup document model for Firestore
struct QRLookupDocument: Codable {
    /// QR code ID
    var qrCodeId: String

    /// Timestamp when QR code was last updated
    var updatedAt: Date

    /// Convert to Firestore data
    func toFirestoreData() -> [String: Any] {
        return [
            FirestoreSchema.QRLookup.qrCodeId: qrCodeId,
            FirestoreSchema.QRLookup.updatedAt: updatedAt
        ]
    }
}