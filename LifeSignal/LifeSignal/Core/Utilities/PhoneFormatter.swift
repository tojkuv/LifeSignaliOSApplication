import Foundation

/// Utility class for formatting phone numbers
struct PhoneFormatter {
    /// Format a phone number for display
    /// - Parameters:
    ///   - phoneNumber: The phone number to format
    ///   - region: The phone region code (e.g., "US")
    /// - Returns: A formatted phone number string with international prefix
    static func formatPhoneNumber(_ phoneNumber: String, region: String) -> String {
        // Extract digits only
        let digitsOnly = phoneNumber.filter { $0.isNumber }
        
        // Simple formatting for now - in a real app, you would use a proper phone number library
        // like PhoneNumberKit to handle international formatting correctly
        
        // For US numbers
        if region == "US" {
            // Add +1 prefix if not present
            let formattedNumber = digitsOnly.hasPrefix("1") ? "+\(digitsOnly)" : "+1\(digitsOnly)"
            return formattedNumber
        }
        
        // For other regions, just add + prefix
        // In a real implementation, you would use proper region codes and formatting
        return "+\(digitsOnly)"
    }
}
