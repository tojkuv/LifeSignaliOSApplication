import Foundation
import FirebaseFirestore

/// Domain model for user data
struct UserData: Equatable, Sendable {
    // MARK: - Profile Data
    var id: String = ""
    var name: String = ""
    var phoneNumber: String = ""
    var phoneRegion: String = "US"
    var emergencyNote: String = ""
    var qrCodeId: String = ""
    var notificationEnabled: Bool = true
    var profileComplete: Bool = false

    // MARK: - Check-in Data
    var lastCheckedIn: Date = Date()
    var checkInInterval: TimeInterval = TimeConstants.defaultCheckInInterval
    var notify30MinBefore: Bool = true
    var notify2HoursBefore: Bool = false
    var manualAlertActive: Bool = false
    var manualAlertTimestamp: Date? = nil

    // MARK: - Computed Properties
    var checkInExpiration: Date {
        return lastCheckedIn.addingTimeInterval(checkInInterval)
    }

    var timeRemaining: TimeInterval {
        return checkInExpiration.timeIntervalSince(Date())
    }

    // MARK: - Static Properties
    static let empty = UserData()

    // MARK: - Firestore Conversion

    /// Create UserData from Firestore document data
    static func fromFirestore(_ data: [String: Any], userId: String) -> UserData {
        var userData = UserData()

        // Set user ID
        userData.id = userId

        // Parse profile data
        userData.name = data[FirestoreConstants.UserFields.name] as? String ?? ""
        userData.phoneNumber = data[FirestoreConstants.UserFields.phoneNumber] as? String ?? ""
        userData.phoneRegion = data[FirestoreConstants.UserFields.phoneRegion] as? String ?? "US"
        userData.emergencyNote = data[FirestoreConstants.UserFields.emergencyNote] as? String ?? ""
        userData.qrCodeId = data[FirestoreConstants.UserFields.qrCodeId] as? String ?? ""
        userData.notificationEnabled = data[FirestoreConstants.UserFields.notificationEnabled] as? Bool ?? true
        userData.profileComplete = data[FirestoreConstants.UserFields.profileComplete] as? Bool ?? false

        // Parse check-in data
        userData.lastCheckedIn = (data[FirestoreConstants.UserFields.lastCheckedIn] as? Timestamp)?.dateValue() ?? Date()
        userData.checkInInterval = data[FirestoreConstants.UserFields.checkInInterval] as? TimeInterval ?? TimeConstants.defaultCheckInInterval
        userData.notify30MinBefore = data[FirestoreConstants.UserFields.notify30MinBefore] as? Bool ?? true
        userData.notify2HoursBefore = data[FirestoreConstants.UserFields.notify2HoursBefore] as? Bool ?? false
        userData.manualAlertActive = data[FirestoreConstants.UserFields.manualAlertActive] as? Bool ?? false
        userData.manualAlertTimestamp = (data[FirestoreConstants.UserFields.manualAlertTimestamp] as? Timestamp)?.dateValue()

        return userData
    }

    /// Convert to Firestore data
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            FirestoreConstants.UserFields.name: name,
            FirestoreConstants.UserFields.phoneNumber: phoneNumber,
            FirestoreConstants.UserFields.phoneRegion: phoneRegion,
            FirestoreConstants.UserFields.emergencyNote: emergencyNote,
            FirestoreConstants.UserFields.qrCodeId: qrCodeId,
            FirestoreConstants.UserFields.notificationEnabled: notificationEnabled,
            FirestoreConstants.UserFields.profileComplete: profileComplete,
            FirestoreConstants.UserFields.lastCheckedIn: Timestamp(date: lastCheckedIn),
            FirestoreConstants.UserFields.checkInInterval: checkInInterval,
            FirestoreConstants.UserFields.notify30MinBefore: notify30MinBefore,
            FirestoreConstants.UserFields.notify2HoursBefore: notify2HoursBefore,
            FirestoreConstants.UserFields.manualAlertActive: manualAlertActive,
            FirestoreConstants.UserFields.lastUpdated: Timestamp(date: Date())
        ]

        // Add manual alert timestamp if present
        if let timestamp = manualAlertTimestamp {
            data[FirestoreConstants.UserFields.manualAlertTimestamp] = Timestamp(date: timestamp)
        }

        return data
    }
}

// MARK: - Domain Models

/// Model for profile updates
struct ProfileUpdate: Equatable {
    var name: String
    var emergencyNote: String
}

/// Model for notification preferences
struct NotificationPreferences: Equatable {
    var enabled: Bool
    var notify30MinBefore: Bool
    var notify2HoursBefore: Bool
}

/// Model for check-in interval update
struct CheckInIntervalUpdate: Equatable {
    var interval: TimeInterval
}
