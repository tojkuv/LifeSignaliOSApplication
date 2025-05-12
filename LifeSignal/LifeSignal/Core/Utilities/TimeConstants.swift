import Foundation

/// Constants for time-related values
enum TimeConstants {
    /// Default check-in interval (24 hours in seconds)
    static let defaultCheckInInterval: TimeInterval = 24 * 60 * 60
    
    /// Minimum check-in interval (1 hour in seconds)
    static let minimumCheckInInterval: TimeInterval = 60 * 60
    
    /// Maximum check-in interval (72 hours in seconds)
    static let maximumCheckInInterval: TimeInterval = 72 * 60 * 60
    
    /// Common check-in intervals in hours
    static let commonCheckInIntervals: [Int] = [1, 2, 4, 8, 12, 24, 48, 72]
}
