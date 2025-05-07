import Foundation

/// Formats a date into a "time ago" string (e.g., "5m ago")
/// This is a convenience wrapper around TimeManager.formatTimeAgo
func formatTimeAgo(_ date: Date) -> String {
    return TimeManager.shared.formatTimeAgo(date)
}

/// Formats a time interval into a human-readable string (e.g., "2d 5h 30m")
/// This is a convenience wrapper around TimeManager.formatTimeInterval
func formatTimeInterval(_ interval: TimeInterval) -> String {
    return TimeManager.shared.formatTimeInterval(interval)
}

/// Formats a time interval into a human-readable string with full units (e.g., "2 days 5 hours")
/// This is a convenience wrapper around TimeManager.formatTimeIntervalWithFullUnits
func formatTimeIntervalWithFullUnits(_ interval: TimeInterval) -> String {
    return TimeManager.shared.formatTimeIntervalWithFullUnits(interval)
}