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

/// Base model representing a user in the LifeSignal app
///
/// This model contains the core user properties that are essential across all features.
/// It is extended by feature-specific extensions to add functionality.
struct User: Identifiable, Equatable, Hashable {
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // Equatable conformance
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id
    }
    
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
