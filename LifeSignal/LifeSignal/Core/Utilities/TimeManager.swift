import Foundation

/// A centralized manager for all time-related operations in the app
@available(iOS 16.0, *)
final class TimeManager: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = TimeManager()

    private init() {}

    // MARK: - Constants

    /// Minimum allowed interval in seconds (1 minute)
    static let minimumInterval: TimeInterval = 60

    /// Default check-in interval (24 hours)
    static let defaultInterval: TimeInterval = 24 * 60 * 60

    /// Standard time units in seconds
    struct TimeUnits {
        static let minute: TimeInterval = 60
        static let hour: TimeInterval = 60 * 60
        static let day: TimeInterval = 24 * 60 * 60
    }

    // MARK: - Time Calculations

    /// Safely calculates the expiration date from a check-in time and interval
    /// - Parameters:
    ///   - checkInTime: The time of the last check-in
    ///   - interval: The interval duration in seconds
    /// - Returns: The expiration date
    func calculateExpirationDate(from checkInTime: Date, interval: TimeInterval) -> Date {
        // Ensure interval is at least the minimum
        let safeInterval = max(TimeManager.minimumInterval, interval)
        return checkInTime.addingTimeInterval(safeInterval)
    }

    /// Checks if a contact is non-responsive based on their last check-in and interval
    /// - Parameters:
    ///   - lastCheckIn: Optional last check-in date
    ///   - interval: The interval duration in seconds
    /// - Returns: True if the contact is non-responsive
    func isNonResponsive(lastCheckIn: Date?, interval: TimeInterval) -> Bool {
        guard let lastCheckIn = lastCheckIn else {
            // If no check-in recorded, consider non-responsive
            return true
        }

        let safeInterval = max(TimeManager.minimumInterval, interval)
        let expirationDate = lastCheckIn.addingTimeInterval(safeInterval)
        return expirationDate < Date()
    }

    /// Calculates the time remaining until expiration
    /// - Parameters:
    ///   - lastCheckIn: The time of the last check-in
    ///   - interval: The interval duration in seconds
    /// - Returns: The time remaining in seconds (0 if expired)
    func timeRemaining(lastCheckIn: Date, interval: TimeInterval) -> TimeInterval {
        let safeInterval = max(TimeManager.minimumInterval, interval)
        let expirationDate = lastCheckIn.addingTimeInterval(safeInterval)
        return max(0, expirationDate.timeIntervalSince(Date()))
    }

    // MARK: - Time Formatting

    /// Formats a time interval into a human-readable string (e.g., "2d 5h 30m")
    /// - Parameter interval: The time interval in seconds
    /// - Returns: A formatted string
    func formatTimeInterval(_ interval: TimeInterval) -> String {
        // Handle negative or zero intervals
        if interval <= 0 {
            return "0m"
        }

        let days = Int(interval / TimeUnits.day)
        let hours = Int((interval.truncatingRemainder(dividingBy: TimeUnits.day)) / TimeUnits.hour)
        let minutes = Int((interval.truncatingRemainder(dividingBy: TimeUnits.hour)) / TimeUnits.minute)

        var result = ""
        if days > 0 {
            result += "\(days)d "
        }
        if hours > 0 || days > 0 {
            result += "\(hours)h"
        }
        if days == 0 {
            if hours > 0 || minutes > 0 {
                result += " "
            }
            result += "\(minutes)m"
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Formats a time interval into a human-readable string with full units (e.g., "2 days 5 hours")
    /// - Parameter interval: The time interval in seconds
    /// - Returns: A formatted string
    func formatTimeIntervalWithFullUnits(_ interval: TimeInterval) -> String {
        let days = Int(interval / TimeUnits.day)
        let hours = Int((interval.truncatingRemainder(dividingBy: TimeUnits.day)) / TimeUnits.hour)

        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s")"
        } else {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }
    }

    /// Formats a date into a "time ago" string (e.g., "5m ago")
    /// - Parameter date: The date to format
    /// - Returns: A formatted string
    func formatTimeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        // Handle negative intervals (future dates)
        if interval < 0 {
            return "just now"
        }

        let minutes = Int(interval / TimeUnits.minute)
        let hours = Int(interval / TimeUnits.hour)
        let days = Int(interval / TimeUnits.day)

        if days > 0 {
            return "\(days)d ago"
        } else if hours > 0 {
            return "\(hours)h ago"
        } else if minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "just now"
        }
    }

    // MARK: - Mock Data Helpers

    /// Creates a date in the past with a safe offset
    /// - Parameter hoursAgo: Number of hours in the past
    /// - Returns: A date safely in the past
    func createPastDate(hoursAgo: Double) -> Date {
        return Date().addingTimeInterval(-max(1, hoursAgo) * TimeUnits.hour)
    }
}
