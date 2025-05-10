import Foundation
import FirebaseFirestore

/// Extension to add check-in related functionality to the User model
extension User {

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

    /// Check if the user's check-in has expired
    /// - Returns: True if the check-in has expired, false otherwise
    func isCheckInExpired() -> Bool {
        return timeRemaining <= 0
    }

    /// Update the user's last check-in time to now
    mutating func checkIn() {
        lastCheckedIn = Date()
        lastUpdated = Date()
    }

    /// Update the user's check-in interval
    /// - Parameter interval: The new interval in seconds
    mutating func updateCheckInInterval(_ interval: TimeInterval) {
        checkInInterval = interval
        lastUpdated = Date()
    }
}
