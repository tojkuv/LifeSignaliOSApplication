import Foundation

/// Data model for user data
struct UserData: Equatable {
    var name: String
    var qrCodeId: String
    var checkInInterval: TimeInterval
    var notificationLeadTime: Int
}
