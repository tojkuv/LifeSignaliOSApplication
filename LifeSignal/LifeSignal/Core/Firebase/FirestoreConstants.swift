import Foundation
import FirebaseFirestore

/// Constants for Firestore collections, fields, and other Firebase-related values
enum FirestoreConstants {
    /// Firestore collection names
    enum Collections {
        /// Users collection
        static let users = "users"
        
        /// Contacts subcollection
        static let contacts = "contacts"
    }
    
    /// User document field names
    enum UserFields {
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
    enum ContactFields {
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
    }
}

/// Firebase-related errors
enum FirebaseError: Error, LocalizedError {
    /// Document not found in Firestore
    case documentNotFound
    
    /// Invalid data format
    case invalidData
    
    /// Operation failed
    case operationFailed
    
    /// User not authenticated
    case notAuthenticated
    
    /// Permission denied
    case permissionDenied
    
    /// Network error
    case networkError
    
    /// Server error
    case serverError
    
    /// Unknown error
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .documentNotFound:
            return "Document not found"
        case .invalidData:
            return "Invalid data format"
        case .operationFailed:
            return "Operation failed"
        case .notAuthenticated:
            return "User not authenticated"
        case .permissionDenied:
            return "Permission denied"
        case .networkError:
            return "Network error"
        case .serverError:
            return "Server error"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}
