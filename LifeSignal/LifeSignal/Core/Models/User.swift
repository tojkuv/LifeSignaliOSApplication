import Foundation
import FirebaseFirestore

/// Model representing a user in the LifeSignal app
///
/// This model represents the current user and contains all their profile information.
/// It is used throughout the app to display user information and manage user settings.
/// The document ID in Firestore is the user ID, so there's no need for a separate uid field in the document.
struct User: Identifiable, Equatable, Hashable {
    /// Constants for user document field names
    struct Fields {
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

        /// Flag indicating if this is a test user
        static let testUser = "testUser"

        /// Array of contact references
        static let contacts = "contacts"

        /// Timestamp when user data was last updated
        static let lastUpdated = "lastUpdated"

        /// Flag indicating if user has manually triggered an alert
        static let manualAlertActive = "manualAlertActive"

        /// Timestamp when user manually triggered an alert
        static let manualAlertTimestamp = "manualAlertTimestamp"
    }

    // MARK: - Hashable and Equatable

    /// Hash function for Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Equality function for Equatable conformance
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id
    }

    // MARK: - Core Properties

    /// Unique identifier for the user (Firestore document ID)
    let id: String

    /// User's full name
    var name: String

    /// User's phone number (E.164 format)
    var phoneNumber: String

    /// User's phone region (ISO country code)
    var phoneRegion: String

    /// User's emergency profile description/note
    var note: String

    /// User's unique QR code identifier
    var qrCodeId: String

    /// Timestamp when user was created
    var createdAt: Date

    /// Timestamp when user last signed in
    var lastSignInTime: Date?

    /// Flag indicating if user has completed profile setup
    var profileComplete: Bool

    /// Flag indicating if user has enabled notifications
    var notificationEnabled: Bool

    /// Flag indicating if this is a test user
    var testUser: Bool

    /// Timestamp when user data was last updated
    var lastUpdated: Date

    // MARK: - Profile Properties (from User+Profile.swift)

    /// User's FCM token for push notifications
    var fcmToken: String?

    /// User's session ID for single-device authentication
    var sessionId: String?

    // MARK: - Check-in Properties (from User+CheckIn.swift)

    /// User's check-in interval in seconds
    var checkInInterval: TimeInterval = 24 * 60 * 60

    /// Timestamp of user's last check-in
    var lastCheckedIn: Date = Date()

    /// Flag indicating if user should be notified 30 minutes before check-in expiration
    var notify30MinBefore: Bool = true

    /// Flag indicating if user should be notified 2 hours before check-in expiration
    var notify2HoursBefore: Bool = true

    // MARK: - Contacts Properties (from User+Contacts.swift)

    /// Array of contact references
    var contacts: [ContactReference] = []

    /// Flag indicating if user has manually triggered an alert
    var manualAlertActive: Bool = false

    /// Timestamp when user manually triggered an alert
    var manualAlertTimestamp: Date?

    // MARK: - Initialization

    /// Initialize a new User with default values
    init(id: String, name: String = "", phoneNumber: String = "", qrCodeId: String) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.phoneRegion = "US"
        self.note = ""
        self.qrCodeId = qrCodeId
        self.createdAt = Date()
        self.profileComplete = false
        self.notificationEnabled = true
        self.testUser = false
        self.lastUpdated = Date()
    }
}
