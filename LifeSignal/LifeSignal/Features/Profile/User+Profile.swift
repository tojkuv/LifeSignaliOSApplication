import Foundation
import FirebaseFirestore

/// Extension to add profile-related functionality to the User model
extension User {
    /// User's FCM token for push notifications
    var fcmToken: String? {
        get { _fcmToken }
        set { _fcmToken = newValue }
    }
    private var _fcmToken: String?
    
    /// User's session ID for single-device authentication
    var sessionId: String? {
        get { _sessionId }
        set { _sessionId = newValue }
    }
    private var _sessionId: String?
    
    /// Update the user's profile information
    /// - Parameters:
    ///   - name: The user's name
    ///   - phoneNumber: The user's phone number
    ///   - phoneRegion: The user's phone region
    ///   - note: The user's profile note
    mutating func updateProfile(name: String, phoneNumber: String, phoneRegion: String, note: String) {
        self.name = name
        self.phoneNumber = phoneNumber
        self.phoneRegion = phoneRegion
        self.note = note
        self.profileComplete = true
        self.lastUpdated = Date()
    }
    
    /// Update the user's notification settings
    /// - Parameter enabled: Whether notifications are enabled
    mutating func updateNotificationSettings(enabled: Bool) {
        self.notificationEnabled = enabled
        self.lastUpdated = Date()
    }
    
    /// Update the user's FCM token for push notifications
    /// - Parameter token: The new FCM token
    mutating func updateFCMToken(_ token: String?) {
        self.fcmToken = token
        self.lastUpdated = Date()
    }
    
    /// Update the user's session ID
    /// - Parameter sessionId: The new session ID
    mutating func updateSessionId(_ sessionId: String?) {
        self.sessionId = sessionId
        self.lastUpdated = Date()
    }
    
    /// Convert to Firestore data
    /// - Returns: Dictionary representation for Firestore
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            UserFields.name: name,
            UserFields.phoneNumber: phoneNumber,
            UserFields.phoneRegion: phoneRegion,
            UserFields.note: note,
            UserFields.qrCodeId: qrCodeId,
            UserFields.profileComplete: profileComplete,
            UserFields.notificationEnabled: notificationEnabled,
            UserFields.testUser: testUser,
            UserFields.lastUpdated: Timestamp(date: lastUpdated),
            UserFields.createdAt: Timestamp(date: createdAt)
        ]
        
        // Add check-in related fields if they exist
        if let checkInInterval = _checkInInterval {
            data[UserFields.checkInInterval] = checkInInterval
        }
        
        if let lastCheckedIn = _lastCheckedIn {
            data[UserFields.lastCheckedIn] = Timestamp(date: lastCheckedIn)
        }
        
        if let notify30MinBefore = _notify30MinBefore {
            data[UserFields.notify30MinBefore] = notify30MinBefore
        }
        
        if let notify2HoursBefore = _notify2HoursBefore {
            data[UserFields.notify2HoursBefore] = notify2HoursBefore
        }
        
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
        
        // Add contacts-related fields if they exist
        if let manualAlertActive = _manualAlertActive {
            data[UserFields.manualAlertActive] = manualAlertActive
        }
        
        if let manualAlertTimestamp = manualAlertTimestamp {
            data[UserFields.manualAlertTimestamp] = Timestamp(date: manualAlertTimestamp)
        }
        
        // Convert contacts to Firestore data
        if let contacts = _contacts, !contacts.isEmpty {
            data[UserFields.contacts] = contacts.map { $0.toFirestoreData() }
        }
        
        return data
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
        
        // Set timestamps
        if let createdAt = data[UserFields.createdAt] as? Timestamp {
            user.createdAt = createdAt.dateValue()
        }
        
        if let lastSignInTime = data[UserFields.lastSignInTime] as? Timestamp {
            user.lastSignInTime = lastSignInTime.dateValue()
        }
        
        if let lastUpdated = data[UserFields.lastUpdated] as? Timestamp {
            user.lastUpdated = lastUpdated.dateValue()
        }
        
        // Set boolean flags
        user.profileComplete = data[UserFields.profileComplete] as? Bool ?? false
        user.notificationEnabled = data[UserFields.notificationEnabled] as? Bool ?? true
        user.testUser = data[UserFields.testUser] as? Bool ?? false
        
        // Set optional string properties
        user._fcmToken = data[UserFields.fcmToken] as? String
        user._sessionId = data[UserFields.sessionId] as? String
        
        // Set check-in related properties
        if let checkInInterval = data[UserFields.checkInInterval] as? TimeInterval {
            user._checkInInterval = checkInInterval
        }
        
        if let lastCheckedIn = data[UserFields.lastCheckedIn] as? Timestamp {
            user._lastCheckedIn = lastCheckedIn.dateValue()
        }
        
        user._notify30MinBefore = data[UserFields.notify30MinBefore] as? Bool
        user._notify2HoursBefore = data[UserFields.notify2HoursBefore] as? Bool
        
        // Set contacts-related properties
        user._manualAlertActive = data[UserFields.manualAlertActive] as? Bool
        
        if let manualAlertTimestamp = data[UserFields.manualAlertTimestamp] as? Timestamp {
            user._manualAlertTimestamp = manualAlertTimestamp.dateValue()
        }
        
        // Process contacts array
        if let contactsArray = data[UserFields.contacts] as? [[String: Any]] {
            user._contacts = contactsArray.compactMap { ContactReference.fromFirestore($0) }
        }
        
        return user
    }
}
