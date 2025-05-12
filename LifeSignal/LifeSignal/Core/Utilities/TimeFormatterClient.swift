import Foundation
import ComposableArchitecture

/// A client for formatting time-related values
@DependencyClient
struct TimeFormatterClient: Sendable {
    /// Formats a date into a "time ago" string (e.g., "5m ago")
    var formatTimeAgo: @Sendable (Date) -> String
    
    /// Formats a time interval into a human-readable string (e.g., "2d 5h 30m")
    var formatTimeInterval: @Sendable (TimeInterval) -> String
    
    /// Formats a time interval into a human-readable string with full units (e.g., "2 days 5 hours")
    var formatTimeIntervalWithFullUnits: @Sendable (TimeInterval) -> String
    
    /// Safely calculates the expiration date from a check-in time and interval
    var calculateExpirationDate: @Sendable (Date, TimeInterval) -> Date
    
    /// Checks if a contact is non-responsive based on their last check-in and interval
    var isNonResponsive: @Sendable (Date?, TimeInterval) -> Bool
    
    /// Calculates the time remaining until expiration
    var timeRemaining: @Sendable (Date, TimeInterval) -> TimeInterval
}

// MARK: - Live Implementation

extension TimeFormatterClient {
    /// The live implementation of the time formatter client
    static let live = TimeFormatterClient(
        formatTimeAgo: { date in
            let interval = Date().timeIntervalSince(date)
            
            // Handle negative intervals (future dates)
            if interval < 0 {
                return "just now"
            }
            
            let minutes = Int(interval / 60)
            let hours = Int(interval / 3600)
            let days = Int(interval / 86400)
            
            if days > 0 {
                return "\(days)d ago"
            } else if hours > 0 {
                return "\(hours)h ago"
            } else if minutes > 0 {
                return "\(minutes)m ago"
            } else {
                return "just now"
            }
        },
        
        formatTimeInterval: { interval in
            // Handle negative or zero intervals
            if interval <= 0 {
                return "0m"
            }
            
            let days = Int(interval / 86400)
            let hours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
            let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
            
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
        },
        
        formatTimeIntervalWithFullUnits: { interval in
            let days = Int(interval / 86400)
            let hours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
            
            if days > 0 {
                return "\(days) day\(days == 1 ? "" : "s")"
            } else {
                return "\(hours) hour\(hours == 1 ? "" : "s")"
            }
        },
        
        calculateExpirationDate: { checkInTime, interval in
            // Ensure interval is at least the minimum (1 minute)
            let safeInterval = max(60, interval)
            return checkInTime.addingTimeInterval(safeInterval)
        },
        
        isNonResponsive: { lastCheckIn, interval in
            guard let lastCheckIn = lastCheckIn else {
                // If no check-in recorded, consider non-responsive
                return true
            }
            
            let safeInterval = max(60, interval)
            let expirationDate = lastCheckIn.addingTimeInterval(safeInterval)
            return expirationDate < Date()
        },
        
        timeRemaining: { lastCheckIn, interval in
            let safeInterval = max(60, interval)
            let expirationDate = lastCheckIn.addingTimeInterval(safeInterval)
            return max(0, expirationDate.timeIntervalSince(Date()))
        }
    )
}

// MARK: - Mock Implementation

extension TimeFormatterClient {
    /// A mock implementation that returns predefined values for testing
    static func mock(
        formatTimeAgo: @escaping (Date) -> String = { _ in "5m ago" },
        formatTimeInterval: @escaping (TimeInterval) -> String = { _ in "2h 30m" },
        formatTimeIntervalWithFullUnits: @escaping (TimeInterval) -> String = { _ in "2 hours" },
        calculateExpirationDate: @escaping (Date, TimeInterval) -> Date = { date, _ in date.addingTimeInterval(3600) },
        isNonResponsive: @escaping (Date?, TimeInterval) -> Bool = { _, _ in false },
        timeRemaining: @escaping (Date, TimeInterval) -> TimeInterval = { _, _ in 3600 }
    ) -> Self {
        Self(
            formatTimeAgo: formatTimeAgo,
            formatTimeInterval: formatTimeInterval,
            formatTimeIntervalWithFullUnits: formatTimeIntervalWithFullUnits,
            calculateExpirationDate: calculateExpirationDate,
            isNonResponsive: isNonResponsive,
            timeRemaining: timeRemaining
        )
    }
}

// MARK: - Dependency Registration

extension DependencyValues {
    /// The time formatter client dependency
    var timeFormatter: TimeFormatterClient {
        get { self[TimeFormatterClient.self] }
        set { self[TimeFormatterClient.self] = newValue }
    }
}

extension TimeFormatterClient: DependencyKey {
    /// The live value of the time formatter client
    static var liveValue: TimeFormatterClient {
        return .live
    }
    
    /// The test value of the time formatter client
    static var testValue: TimeFormatterClient {
        return .mock()
    }
}
