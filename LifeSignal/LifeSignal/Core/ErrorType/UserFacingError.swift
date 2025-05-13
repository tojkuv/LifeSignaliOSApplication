import Foundation

/// User-facing error types that are Equatable and Sendable for use in TCA
enum UserFacingError: Error, Equatable, Sendable {
    /// Authentication errors
    case notAuthenticated
    case authenticationFailed(String)
    
    /// Network errors
    case networkError
    case serverError
    case requestTimeout
    
    /// Data errors
    case dataNotFound
    case dataInvalid
    case operationFailed(String)
    
    /// Permission errors
    case permissionDenied
    
    /// Session errors
    case sessionInvalid
    case sessionExpired
    
    /// Notification errors
    case notificationPermissionDenied
    
    /// Unknown error
    case unknown(String)
    
    /// Maps a raw Error to a UserFacingError
    static func from(_ error: Error) -> UserFacingError {
        // If it's already a UserFacingError, return it
        if let userFacingError = error as? UserFacingError {
            return userFacingError
        }
        
        // If it's a FirebaseError, map it
        if let firebaseError = error as? FirebaseError {
            return mapFromFirebaseError(firebaseError)
        }
        
        // Handle NSError
        let nsError = error as NSError
        
        // Check for Firebase Auth errors
        if nsError.domain == AuthErrorDomain {
            switch nsError.code {
            case AuthErrorCode.networkError.rawValue:
                return .networkError
            case AuthErrorCode.userNotFound.rawValue, AuthErrorCode.userTokenExpired.rawValue:
                return .notAuthenticated
            default:
                return .authenticationFailed(nsError.localizedDescription)
            }
        }
        
        // Check for Firestore errors
        if nsError.domain == FirestoreErrorDomain {
            switch nsError.code {
            case FirestoreErrorCode.notFound.rawValue:
                return .dataNotFound
            case FirestoreErrorCode.permissionDenied.rawValue:
                return .permissionDenied
            case FirestoreErrorCode.unavailable.rawValue:
                return .networkError
            case FirestoreErrorCode.dataLoss.rawValue:
                return .dataInvalid
            default:
                return .unknown(nsError.localizedDescription)
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
        
        return .unknown(error.localizedDescription)
    }
    
    /// Maps a FirebaseError to a UserFacingError
    private static func mapFromFirebaseError(_ error: FirebaseError) -> UserFacingError {
        switch error {
        case .documentNotFound:
            return .dataNotFound
        case .emptyDocument:
            return .dataNotFound
        case .invalidData:
            return .dataInvalid
        case .operationFailed:
            return .operationFailed("Operation failed")
        case .notAuthenticated:
            return .notAuthenticated
        case .authenticationFailed(let message):
            return .authenticationFailed(message)
        case .verificationIdMissing, .invalidVerificationCode, .invalidPhoneNumber:
            return .authenticationFailed("Invalid verification information")
        case .permissionDenied:
            return .permissionDenied
        case .networkError:
            return .networkError
        case .serverError:
            return .serverError
        case .requestTimeout:
            return .requestTimeout
        case .sessionInvalid:
            return .sessionInvalid
        case .sessionExpired:
            return .sessionExpired
        case .fcmTokenUnavailable:
            return .operationFailed("FCM token unavailable")
        case .notificationPermissionDenied:
            return .notificationPermissionDenied
        case .cloudFunctionError(let message):
            return .operationFailed(message)
        case .invalidResponseFormat:
            return .dataInvalid
        case .unknown(let error):
            return .unknown(error.localizedDescription)
        }
    }
}
