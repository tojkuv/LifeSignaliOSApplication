import Foundation
import OSLog

/// A utility for logging Firebase-related operations
enum FirebaseLogger {
    /// Logger for Firebase Authentication operations
    static let auth = Logger(subsystem: "com.lifesignal", category: "FirebaseAuth")
    
    /// Logger for Firebase App operations
    static let app = Logger(subsystem: "com.lifesignal", category: "FirebaseApp")
    
    /// Logger for Firebase Messaging operations
    static let messaging = Logger(subsystem: "com.lifesignal", category: "FirebaseMessaging")
    
    /// Logger for Firebase Notification operations
    static let notification = Logger(subsystem: "com.lifesignal", category: "FirebaseNotification")
    
    /// Logger for Firebase Session operations
    static let session = Logger(subsystem: "com.lifesignal", category: "FirebaseSession")
    
    /// Logger for Firebase User operations
    static let user = Logger(subsystem: "com.lifesignal", category: "FirebaseUser")
    
    /// Logger for Firebase Contacts operations
    static let contacts = Logger(subsystem: "com.lifesignal", category: "FirebaseContacts")
}
