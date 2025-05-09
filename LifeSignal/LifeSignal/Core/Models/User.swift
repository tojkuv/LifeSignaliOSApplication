import Foundation
import FirebaseFirestore

/// Constants for user document field names
struct UserFields {
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

/// Model representing a user document for Firestore operations
///
/// This model is used internally for Firestore operations and is converted
/// to/from the User model as needed. The document ID in Firestore is the user ID (uid).
struct UserDocument {
    /// User ID (document ID)
    var uid: String

    /// User's full name
    var name: String

    /// User's phone number (E.164 format)
    var phoneNumber: String

    /// User's phone region (ISO country code)
    var phoneRegion: String = "US"

    /// User's emergency profile description/note
    var note: String = ""

    /// User's check-in interval in seconds
    var checkInInterval: TimeInterval = 24 * 60 * 60 // 24 hours in seconds

    /// Timestamp of user's last check-in
    var lastCheckedIn: Date = Date()

    /// User's unique QR code identifier
    var qrCodeId: String

    /// Flag indicating if user should be notified 30 minutes before check-in expiration
    var notify30MinBefore: Bool = true

    /// Flag indicating if user should be notified 2 hours before check-in expiration
    var notify2HoursBefore: Bool = true

    /// User's FCM token for push notifications
    var fcmToken: String?

    /// User's session ID for single-device authentication
    var sessionId: String?

    /// Timestamp when user was created
    var createdAt: Date

    /// Timestamp when user last signed in
    var lastSignInTime: Date?

    /// Flag indicating if user has completed profile setup
    var profileComplete: Bool = false

    /// Flag indicating if user has enabled notifications
    var notificationEnabled: Bool = true

    /// Flag indicating if this is a test user
    var testUser: Bool = false

    /// Array of contact references
    var contacts: [ContactReference] = []

    /// Timestamp when user data was last updated
    var lastUpdated: Date = Date()

    /// Flag indicating if user has manually triggered an alert
    var manualAlertActive: Bool = false

    /// Timestamp when user manually triggered an alert
    var manualAlertTimestamp: Date?

    /// Initialize a new UserDocument with required fields
    /// - Parameters:
    ///   - uid: User ID (document ID)
    ///   - name: User's full name
    ///   - phoneNumber: User's phone number
    ///   - note: User's emergency profile description
    ///   - qrCodeId: User's QR code ID
    ///   - createdAt: Timestamp when user was created
    ///   - lastSignInTime: Timestamp when user last signed in
    init(uid: String, name: String, phoneNumber: String, note: String = "", qrCodeId: String, createdAt: Date = Date(), lastSignInTime: Date? = nil) {
        self.uid = uid
        self.name = name
        self.phoneNumber = phoneNumber
        self.note = note
        self.qrCodeId = qrCodeId
        self.createdAt = createdAt
        self.lastSignInTime = lastSignInTime
    }

    /// Convert to a User model
    /// - Returns: A User instance
    func toUser() -> User {
        return User(
            id: uid,
            name: name,
            phoneNumber: phoneNumber,
            qrCodeId: qrCodeId
        ).with {
            $0.phoneRegion = phoneRegion
            $0.note = note
            $0.checkInInterval = checkInInterval
            $0.lastCheckedIn = lastCheckedIn
            $0.notify30MinBefore = notify30MinBefore
            $0.notify2HoursBefore = notify2HoursBefore
            $0.fcmToken = fcmToken
            $0.sessionId = sessionId
            $0.createdAt = createdAt
            $0.lastSignInTime = lastSignInTime
            $0.profileComplete = profileComplete
            $0.notificationEnabled = notificationEnabled
            $0.testUser = testUser
            $0.contacts = contacts
            $0.lastUpdated = lastUpdated
            $0.manualAlertActive = manualAlertActive
            $0.manualAlertTimestamp = manualAlertTimestamp
        }
    }

    /// Convert to Firestore data
    /// - Returns: Dictionary representation for Firestore
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            UserFields.name: name,
            UserFields.phoneNumber: phoneNumber,
            UserFields.phoneRegion: phoneRegion,
            UserFields.note: note,
            UserFields.checkInInterval: checkInInterval,
            UserFields.lastCheckedIn: Timestamp(date: lastCheckedIn),
            UserFields.qrCodeId: qrCodeId,
            UserFields.notify30MinBefore: notify30MinBefore,
            UserFields.notify2HoursBefore: notify2HoursBefore,
            UserFields.profileComplete: profileComplete,
            UserFields.notificationEnabled: notificationEnabled,
            UserFields.testUser: testUser,
            UserFields.lastUpdated: Timestamp(date: lastUpdated),
            UserFields.manualAlertActive: manualAlertActive,
            UserFields.createdAt: Timestamp(date: createdAt)
        ]

        // Add optional fields if they exist
        if let fcmToken = fcmToken {
            data[UserFields.fcmToken] = fcmToken
        }

        if let sessionId = sessionId {
            data[UserFields.sessionId] = sessionId
        }

        if let lastSignInTime = lastSignInTime {
            data[UserFields.lastSignInTime] = Timestamp(date: lastSignInTime)
        }

        if let manualAlertTimestamp = manualAlertTimestamp {
            data[UserFields.manualAlertTimestamp] = Timestamp(date: manualAlertTimestamp)
        }

        // Convert contacts to Firestore data
        if !contacts.isEmpty {
            data[UserFields.contacts] = contacts.map { $0.toFirestoreData() }
        }

        return data
    }
}

/// Model representing a user in the LifeSignal app
///
/// This model represents the current user and contains all their profile information.
/// It is used throughout the app to display user information and manage user settings.
/// The document ID in Firestore is the user ID, so there's no need for a separate uid field in the document.
struct User: Identifiable, Equatable, Hashable {
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

    /// User's check-in interval in seconds
    var checkInInterval: TimeInterval

    /// Timestamp of user's last check-in
    var lastCheckedIn: Date

    /// User's unique QR code identifier
    var qrCodeId: String

    /// Flag indicating if user should be notified 30 minutes before check-in expiration
    var notify30MinBefore: Bool

    /// Flag indicating if user should be notified 2 hours before check-in expiration
    var notify2HoursBefore: Bool

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
    var contacts: [ContactReference]

    /// Timestamp when user data was last updated
    var lastUpdated: Date

    /// Flag indicating if user has manually triggered an alert
    var manualAlertActive: Bool

    /// Timestamp when user manually triggered an alert
    var manualAlertTimestamp: Date?

    /// Initialize a new User with default values
    init(id: String, name: String = "", phoneNumber: String = "", qrCodeId: String) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.phoneRegion = "US"
        self.note = ""
        self.checkInInterval = 24 * 60 * 60 // 24 hours in seconds
        self.lastCheckedIn = Date()
        self.qrCodeId = qrCodeId
        self.notify30MinBefore = true
        self.notify2HoursBefore = true
        self.createdAt = Date()
        self.profileComplete = false
        self.notificationEnabled = true
        self.testUser = false
        self.contacts = []
        self.lastUpdated = Date()
        self.manualAlertActive = false
    }

    /// Computed property for check-in expiration time
    var checkInExpiration: Date {
        return lastCheckedIn.addingTimeInterval(checkInInterval)
    }

    /// Computed property for time remaining until check-in expiration
    var timeRemaining: TimeInterval {
        return checkInExpiration.timeIntervalSince(Date())
    }

    /// Computed property for formatted time remaining until check-in expiration
    var formattedTimeRemaining: String {
        let timeRemaining = checkInExpiration.timeIntervalSince(Date())

        if timeRemaining <= 0 {
            return "Expired"
        }

        return TimeManager.shared.formatTimeInterval(timeRemaining)
    }

    /// Create a User from a UserDocument
    /// - Parameter document: The UserDocument to convert
    /// - Returns: A new User instance
    static func from(document: UserDocument) -> User {
        return document.toUser()
    }

    /// Create a User from Firestore data
    /// - Parameters:
    ///   - data: Dictionary containing user data from Firestore
    ///   - id: The user ID (Firestore document ID)
    /// - Returns: A new User instance, or nil if required data is missing
    static func fromFirestore(_ data: [String: Any], id: String) -> User? {
        guard let qrCodeId = data[UserFields.qrCodeId] as? String else {
            return nil
        }

        var user = User(
            id: id,
            name: data[UserFields.name] as? String ?? "",
            phoneNumber: data[UserFields.phoneNumber] as? String ?? "",
            qrCodeId: qrCodeId
        )

        // Set basic properties
        user.phoneRegion = data[UserFields.phoneRegion] as? String ?? "US"
        user.note = data[UserFields.note] as? String ?? ""
        user.checkInInterval = data[UserFields.checkInInterval] as? TimeInterval ?? (24 * 60 * 60)

        // Set timestamps
        if let lastCheckedIn = data[UserFields.lastCheckedIn] as? Timestamp {
            user.lastCheckedIn = lastCheckedIn.dateValue()
        }

        if let createdAt = data[UserFields.createdAt] as? Timestamp {
            user.createdAt = createdAt.dateValue()
        }

        if let lastSignInTime = data[UserFields.lastSignInTime] as? Timestamp {
            user.lastSignInTime = lastSignInTime.dateValue()
        }

        if let lastUpdated = data[UserFields.lastUpdated] as? Timestamp {
            user.lastUpdated = lastUpdated.dateValue()
        }

        if let manualAlertTimestamp = data[UserFields.manualAlertTimestamp] as? Timestamp {
            user.manualAlertTimestamp = manualAlertTimestamp.dateValue()
        }

        // Set boolean flags
        user.notify30MinBefore = data[UserFields.notify30MinBefore] as? Bool ?? true
        user.notify2HoursBefore = data[UserFields.notify2HoursBefore] as? Bool ?? true
        user.profileComplete = data[UserFields.profileComplete] as? Bool ?? false
        user.notificationEnabled = data[UserFields.notificationEnabled] as? Bool ?? true
        user.testUser = data[UserFields.testUser] as? Bool ?? false
        user.manualAlertActive = data[UserFields.manualAlertActive] as? Bool ?? false

        // Set optional string properties
        user.fcmToken = data[UserFields.fcmToken] as? String
        user.sessionId = data[UserFields.sessionId] as? String

        // Process contacts array
        if let contactsArray = data[UserFields.contacts] as? [[String: Any]] {
            user.contacts = contactsArray.compactMap { ContactReference.fromFirestore($0) }
        }

        return user
    }

    /// Convert to a UserDocument
    /// - Returns: A UserDocument instance
    func toUserDocument() -> UserDocument {
        var document = UserDocument(
            uid: id,
            name: name,
            phoneNumber: phoneNumber,
            note: note,
            qrCodeId: qrCodeId,
            createdAt: createdAt,
            lastSignInTime: lastSignInTime
        )

        document.phoneRegion = phoneRegion
        document.checkInInterval = checkInInterval
        document.lastCheckedIn = lastCheckedIn
        document.notify30MinBefore = notify30MinBefore
        document.notify2HoursBefore = notify2HoursBefore
        document.fcmToken = fcmToken
        document.sessionId = sessionId
        document.profileComplete = profileComplete
        document.notificationEnabled = notificationEnabled
        document.testUser = testUser
        document.contacts = contacts
        document.lastUpdated = lastUpdated
        document.manualAlertActive = manualAlertActive
        document.manualAlertTimestamp = manualAlertTimestamp

        return document
    }

    /// Convert to Firestore data
    /// - Returns: Dictionary representation for Firestore
    func toFirestoreData() -> [String: Any] {
        return toUserDocument().toFirestoreData()
    }
}

/// Extension to provide a builder pattern for User
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
