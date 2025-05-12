import Foundation
import ComposableArchitecture

/// A client for formatting phone numbers
@DependencyClient
struct PhoneFormatterClient: Sendable {
    /// Format a phone number for display
    /// - Parameters:
    ///   - phoneNumber: The phone number to format
    ///   - region: The phone region code (e.g., "US")
    /// - Returns: A formatted phone number string with international prefix
    var formatPhoneNumber: @Sendable (_ phoneNumber: String, _ region: String) -> String = { phoneNumber, _ in
        return "+\(phoneNumber.filter { $0.isNumber })"
    }
}

// MARK: - Live Implementation

extension PhoneFormatterClient {
    /// The live implementation of the phone formatter client
    static let live = PhoneFormatterClient(
        formatPhoneNumber: { phoneNumber, region in
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
    )
}

// MARK: - Mock Implementation

extension PhoneFormatterClient {
    /// A mock implementation that returns predefined values for testing
    static func mock(
        formatPhoneNumber: @escaping @Sendable (_ phoneNumber: String, _ region: String) -> String = { phoneNumber, _ in "+1\(phoneNumber)" }
    ) -> Self {
        Self(formatPhoneNumber: formatPhoneNumber)
    }
}

// MARK: - Dependency Registration

extension DependencyValues {
    /// The phone formatter client dependency
    var phoneFormatter: PhoneFormatterClient {
        get { self[PhoneFormatterClient.self] }
        set { self[PhoneFormatterClient.self] = newValue }
    }
}

extension PhoneFormatterClient: DependencyKey {
    /// The live value of the phone formatter client
    static var liveValue: PhoneFormatterClient {
        return .live
    }

    /// The test value of the phone formatter client
    static var testValue: PhoneFormatterClient {
        return .mock()
    }
}
