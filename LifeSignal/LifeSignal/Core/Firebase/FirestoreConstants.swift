import Foundation

/// Constants for Firestore collections and fields
enum FirestoreConstants {
    /// Firestore collection names
    enum Collections {
        /// Users collection
        static let users = "users"

        /// QR lookup collection
        static let qrLookup = "qr_lookup"

        /// Sessions collection
        static let sessions = "sessions"
    }

    /// User document field names
    enum UserFields {
        /// User ID (document ID)
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

        /// Array of contact references (array of maps containing relationship data)
        static let contacts = "contacts"

        /// Timestamp when user data was last updated
        static let lastUpdated = "lastUpdated"

        /// Flag indicating if user has manually triggered an alert
        static let manualAlertActive = "manualAlertActive"

        /// Timestamp when user manually triggered an alert
        static let manualAlertTimestamp = "manualAlertTimestamp"
    }

    /// Contact reference field names (fields within each map in the user's contacts array)
    enum ContactFields {
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

        /// When this contact was added
        static let addedAt = "addedAt"

        // MARK: - Cached User Data Properties
        // These fields store cached copies of the contact's user data

        /// User's full name (cached)
        static let name = "name"

        /// User's phone number (cached)
        static let phoneNumber = "phoneNumber"

        /// User's phone region (cached)
        static let phoneRegion = "phoneRegion"

        /// User's emergency profile description (cached)
        static let note = "note"

        /// User's QR code ID (cached)
        static let qrCodeId = "qrCodeId"

        /// User's last check-in time (cached)
        static let lastCheckedIn = "lastCheckedIn"

        /// User's check-in interval in seconds (cached)
        static let checkInInterval = "checkInInterval"

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
}
