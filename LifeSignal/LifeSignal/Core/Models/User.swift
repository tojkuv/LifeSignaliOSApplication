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

    /// User's FCM token for push notifications
    var fcmToken: String?

    /// User's session ID for single-device authentication
    var sessionId: String?

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

    /// Array of contact references
    var contacts: [ContactReference] = []

    /// Timestamp when user data was last updated
    var lastUpdated: Date

    // MARK: - Check-in Properties

    /// User's check-in interval in seconds
    var _checkInInterval: TimeInterval?
    var checkInInterval: TimeInterval {
        get { return _checkInInterval ?? (24 * 60 * 60) }
        set { _checkInInterval = newValue }
    }

    /// Timestamp of user's last check-in
    var _lastCheckedIn: Date?
    var lastCheckedIn: Date {
        get { return _lastCheckedIn ?? Date() }
        set { _lastCheckedIn = newValue }
    }

    /// Flag indicating if user should be notified 30 minutes before check-in expiration
    var _notify30MinBefore: Bool?
    var notify30MinBefore: Bool {
        get { return _notify30MinBefore ?? true }
        set { _notify30MinBefore = newValue }
    }

    /// Flag indicating if user should be notified 2 hours before check-in expiration
    var _notify2HoursBefore: Bool?
    var notify2HoursBefore: Bool {
        get { return _notify2HoursBefore ?? true }
        set { _notify2HoursBefore = newValue }
    }

    // MARK: - Alert Properties

    /// Flag indicating if user has manually triggered an alert
    var _manualAlertActive: Bool?
    var manualAlertActive: Bool {
        get { return _manualAlertActive ?? false }
        set { _manualAlertActive = newValue }
    }

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
        self.contacts = []
        self.lastUpdated = Date()
    }
}

// MARK: - Builder Pattern
extension User {
    /// Apply a configuration closure to this User
    /// - Parameter configure: Closure that modifies the User
    /// - Returns: The modified User
    func with(_ configure: (inout User) -> Void) -> User {
        var copy = self
        configure(&copy)
        return copy
    }
}

// MARK: - Firestore Conversion
extension User {
    /// Create a User from a document
    /// - Parameter document: Another User instance to convert from
    /// - Returns: A new User instance
    static func from(document: User) -> User {
        return document
    }

    /// Convert to Firestore data
    /// - Returns: Dictionary representation for Firestore
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            Fields.name: name,
            Fields.phoneNumber: phoneNumber,
            Fields.phoneRegion: phoneRegion,
            Fields.note: note,
            Fields.qrCodeId: qrCodeId,
            Fields.profileComplete: profileComplete,
            Fields.notificationEnabled: notificationEnabled,
            Fields.testUser: testUser,
            Fields.lastUpdated: Timestamp(date: lastUpdated),
            Fields.createdAt: Timestamp(date: createdAt)
        ]

        // Add check-in related properties
        if let checkInInterval = _checkInInterval {
            data[Fields.checkInInterval] = checkInInterval
        }

        if let lastCheckedIn = _lastCheckedIn {
            data[Fields.lastCheckedIn] = Timestamp(date: lastCheckedIn)
        }

        if let notify30MinBefore = _notify30MinBefore {
            data[Fields.notify30MinBefore] = notify30MinBefore
        }

        if let notify2HoursBefore = _notify2HoursBefore {
            data[Fields.notify2HoursBefore] = notify2HoursBefore
        }

        // Add alert related properties
        if let manualAlertActive = _manualAlertActive {
            data[Fields.manualAlertActive] = manualAlertActive
        }

        if let manualAlertTimestamp = manualAlertTimestamp {
            data[Fields.manualAlertTimestamp] = Timestamp(date: manualAlertTimestamp)
        }

        // Add optional properties
        if let fcmToken = fcmToken {
            data[Fields.fcmToken] = fcmToken
        }

        if let sessionId = sessionId {
            data[Fields.sessionId] = sessionId
        }

        if let lastSignInTime = lastSignInTime {
            data[Fields.lastSignInTime] = Timestamp(date: lastSignInTime)
        }

        // Add contacts array
        if !contacts.isEmpty {
            data[Fields.contacts] = contacts.map { $0.toFirestoreData() }
        }

        return data
    }

    /// Create a User from Firestore data
    /// - Parameters:
    ///   - data: Dictionary containing user data from Firestore
    ///   - id: The user ID (Firestore document ID)
    /// - Returns: A new User instance, or nil if required data is missing
    static func fromFirestore(_ data: [String: Any], id: String) -> User? {
        guard let qrCodeId = data[Fields.qrCodeId] as? String else {
            return nil
        }

        var user = User(
            id: id,
            name: data[Fields.name] as? String ?? "",
            phoneNumber: data[Fields.phoneNumber] as? String ?? "",
            qrCodeId: qrCodeId
        )

        // Set basic properties
        user.phoneRegion = data[Fields.phoneRegion] as? String ?? "US"
        user.note = data[Fields.note] as? String ?? ""
        user.checkInInterval = data[Fields.checkInInterval] as? TimeInterval ?? (24 * 60 * 60)

        // Set timestamps
        if let lastCheckedIn = data[Fields.lastCheckedIn] as? Timestamp {
            user.lastCheckedIn = lastCheckedIn.dateValue()
        }

        if let createdAt = data[Fields.createdAt] as? Timestamp {
            user.createdAt = createdAt.dateValue()
        }

        if let lastSignInTime = data[Fields.lastSignInTime] as? Timestamp {
            user.lastSignInTime = lastSignInTime.dateValue()
        }

        if let lastUpdated = data[Fields.lastUpdated] as? Timestamp {
            user.lastUpdated = lastUpdated.dateValue()
        }

        if let manualAlertTimestamp = data[Fields.manualAlertTimestamp] as? Timestamp {
            user.manualAlertTimestamp = manualAlertTimestamp.dateValue()
        }

        // Set boolean flags
        user.notify30MinBefore = data[Fields.notify30MinBefore] as? Bool ?? true
        user.notify2HoursBefore = data[Fields.notify2HoursBefore] as? Bool ?? true
        user.profileComplete = data[Fields.profileComplete] as? Bool ?? false
        user.notificationEnabled = data[Fields.notificationEnabled] as? Bool ?? true
        user.testUser = data[Fields.testUser] as? Bool ?? false
        user.manualAlertActive = data[Fields.manualAlertActive] as? Bool ?? false

        // Set optional string properties
        user.fcmToken = data[Fields.fcmToken] as? String
        user.sessionId = data[Fields.sessionId] as? String

        // Process contacts array
        if let contactsArray = data[Fields.contacts] as? [[String: Any]] {
            user.contacts = contactsArray.compactMap { ContactReference.fromFirestore($0) }
        }

        return user
    }
}
