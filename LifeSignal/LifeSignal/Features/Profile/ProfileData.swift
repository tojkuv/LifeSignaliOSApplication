import Foundation

/// Data model for profile information
struct ProfileData: Equatable {
    var name: String
    var phoneNumber: String
    var phoneRegion: String
    var note: String
    var qrCodeId: String
    var notificationEnabled: Bool
    var profileComplete: Bool
}

/// Data model for settings
struct SettingsData: Equatable {
    var notificationsEnabled: Bool
}
