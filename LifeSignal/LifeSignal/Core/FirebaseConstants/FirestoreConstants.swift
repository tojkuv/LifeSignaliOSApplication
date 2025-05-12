import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Firestore error domain constant
let FirestoreErrorDomain = "FIRFirestoreErrorDomain"

/// Constants for Firestore collections, fields, and other Firebase-related values
enum FirestoreConstants: Sendable {
    /// Firestore collection names
    enum Collections: Sendable {
        /// Users collection
        static let users = "users"

        /// Contacts subcollection
        static let contacts = "contacts"
    }

    /// User document field names
    enum UserFields: Sendable {
        /// User's name
        static let name = "name"

        /// User's phone number
        static let phoneNumber = "phoneNumber"

        /// User's phone region
        static let phoneRegion = "phoneRegion"

        /// User's note
        static let emergencyNote = "emergencyNote"

        /// User's QR code ID
        static let qrCodeId = "qrCodeId"

        /// User's check-in interval in seconds
        static let checkInInterval = "checkInInterval"

        /// User's last check-in timestamp
        static let lastCheckedIn = "lastCheckedIn"

        /// Flag indicating if user wants notification 30 minutes before check-in
        static let notify30MinBefore = "notify30MinBefore"

        /// Flag indicating if user wants notification 2 hours before check-in
        static let notify2HoursBefore = "notify2HoursBefore"

        /// User's FCM token for push notifications
        static let fcmToken = "fcmToken"

        /// User's session ID
        static let sessionId = "sessionId"

        /// User's last sign-in time
        static let lastSignInTime = "lastSignInTime"

        /// Flag indicating if user's profile is complete
        static let profileComplete = "profileComplete"

        /// Flag indicating if notifications are enabled
        static let notificationEnabled = "notificationEnabled"

        /// Last updated timestamp
        static let lastUpdated = "lastUpdated"

        /// Creation timestamp
        static let createdAt = "createdAt"

        /// Flag indicating if manual alert is active
        static let manualAlertActive = "manualAlertActive"

        /// Manual alert timestamp
        static let manualAlertTimestamp = "manualAlertTimestamp"
    }

    /// Contact document field names
    enum ContactFields: Sendable {
        /// Reference path to the user document
        static let referencePath = "referencePath"

        /// Flag indicating if contact is a responder
        static let isResponder = "isResponder"

        /// Flag indicating if contact is a dependent
        static let isDependent = "isDependent"

        /// Last updated timestamp
        static let lastUpdated = "lastUpdated"

        /// Added timestamp
        static let addedAt = "addedAt"

        /// Incoming ping
        static let hasIncomingPing = "hasIncomingPing"

        /// Incoming ping timestamp
        static let incomingPingTimestamp = "incomingPingTimestamp"

        /// Outgoing ping
        static let hasOutgoingPing = "hasOutgoingPing"

        /// Outgoing ping timestamp
        static let outgoingPingTimestamp = "outgoingPingTimestamp"

        /// Flag indicating if manual alert is active
        static let manualAlertActive = "manualAlertActive"

        /// Manual alert timestamp
        static let manualAlertTimestamp = "manualAlertTimestamp"
    }
}

/// Firebase-related errors
enum FirebaseError: Error, LocalizedError, Sendable {
    // Firestore errors
    /// Document not found in Firestore
    case documentNotFound

    /// Document exists but has no data
    case emptyDocument

    /// Invalid data format
    case invalidData

    /// Operation failed
    case operationFailed

    // Authentication errors
    /// User not authenticated
    case notAuthenticated

    /// Authentication failed
    case authenticationFailed(String)

    /// Verification ID missing
    case verificationIdMissing

    /// Invalid verification code
    case invalidVerificationCode

    /// Phone number format invalid
    case invalidPhoneNumber

    // Permission errors
    /// Permission denied
    case permissionDenied

    // Network errors
    /// Network error
    case networkError

    /// Server error
    case serverError

    /// Request timeout
    case requestTimeout

    // Session errors
    /// Session invalid
    case sessionInvalid

    /// Session expired
    case sessionExpired

    // Messaging errors
    /// FCM token not available
    case fcmTokenUnavailable

    /// Notification permission denied
    case notificationPermissionDenied

    // Function errors
    /// Cloud function error
    case cloudFunctionError(String)

    /// Invalid response format
    case invalidResponseFormat

    /// Unknown error
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .documentNotFound:
            return "Document not found"
        case .emptyDocument:
            return "Document exists but has no data"
        case .invalidData:
            return "Invalid data format"
        case .operationFailed:
            return "Operation failed"
        case .notAuthenticated:
            return "User not authenticated"
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .verificationIdMissing:
            return "Verification ID is missing"
        case .invalidVerificationCode:
            return "Invalid verification code"
        case .invalidPhoneNumber:
            return "Invalid phone number format"
        case .permissionDenied:
            return "Permission denied"
        case .networkError:
            return "Network error"
        case .serverError:
            return "Server error"
        case .requestTimeout:
            return "Request timed out"
        case .sessionInvalid:
            return "Session is invalid"
        case .sessionExpired:
            return "Session has expired"
        case .fcmTokenUnavailable:
            return "FCM token is not available"
        case .notificationPermissionDenied:
            return "Notification permission denied"
        case .cloudFunctionError(let message):
            return "Cloud function error: \(message)"
        case .invalidResponseFormat:
            return "Invalid response format from server"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }

    /// Convert a standard Error to a FirebaseError
    static func from(_ error: Error) -> FirebaseError {
        if let firebaseError = error as? FirebaseError {
            return firebaseError
        }

        let nsError = error as NSError

        // Check for Firebase Auth errors
        if nsError.domain == AuthErrorDomain {
            switch nsError.code {
            case AuthErrorCode.networkError.rawValue:
                return .networkError
            case AuthErrorCode.userNotFound.rawValue, AuthErrorCode.userTokenExpired.rawValue:
                return .notAuthenticated
            case AuthErrorCode.invalidVerificationCode.rawValue:
                return .invalidVerificationCode
            case AuthErrorCode.invalidVerificationID.rawValue:
                return .verificationIdMissing
            case AuthErrorCode.invalidPhoneNumber.rawValue:
                return .invalidPhoneNumber
            default:
                return .authenticationFailed(nsError.localizedDescription)
            }
        }

        // Check for Firestore errors
        if nsError.domain == FirestoreErrorDomain {
            switch nsError.code {
            case FirestoreErrorCode.notFound.rawValue:
                return .documentNotFound
            case FirestoreErrorCode.permissionDenied.rawValue:
                return .permissionDenied
            case FirestoreErrorCode.unavailable.rawValue:
                return .networkError
            case FirestoreErrorCode.dataLoss.rawValue:
                return .invalidData
            default:
                return .unknown(error)
            }
        }

        // Check for network-related errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return .networkError
            case NSURLErrorTimedOut:
                return .requestTimeout
            default:
                return .networkError
            }
        }

        return .unknown(error)
    }
}
