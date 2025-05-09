import Foundation
import FirebaseFirestore

/// Model for displaying contact information in the UI
///
/// This model combines a ContactReference with user details for display purposes.
/// It is used in the UI layer to show contact information and is not stored in Firestore.
struct ContactDisplayModel: Identifiable, Equatable {
    /// Unique identifier for the contact (user ID)
    var id: String
    
    /// Contact reference containing relationship information
    var reference: ContactReference
    
    /// User's full name
    var name: String
    
    /// User's phone number (E.164 format)
    var phoneNumber: String
    
    /// User's emergency profile description/note
    var note: String
    
    /// User's last check-in time
    var lastCheckedIn: Date?
    
    /// User's check-in interval in seconds
    var checkInInterval: TimeInterval?
    
    /// Whether the user has a manual alert active
    var manualAlertActive: Bool = false
    
    /// Timestamp when the manual alert was activated
    var manualAlertTimestamp: Date?
    
    /// Whether the user has an incoming ping
    var hasIncomingPing: Bool = false
    
    /// Timestamp when the incoming ping was sent
    var incomingPingTimestamp: Date?
    
    /// Whether the user has an outgoing ping
    var hasOutgoingPing: Bool = false
    
    /// Timestamp when the outgoing ping was sent
    var outgoingPingTimestamp: Date?
    
    /// Initialize a new ContactDisplayModel
    /// - Parameters:
    ///   - id: User ID
    ///   - reference: ContactReference containing relationship information
    ///   - name: User's full name
    ///   - phoneNumber: User's phone number
    ///   - note: User's emergency profile description
    init(id: String, reference: ContactReference, name: String, phoneNumber: String = "", note: String = "") {
        self.id = id
        self.reference = reference
        self.name = name
        self.phoneNumber = phoneNumber
        self.note = note
    }
    
    /// Whether this contact is a responder for the user
    var isResponder: Bool {
        reference.isResponder
    }
    
    /// Whether this contact is a dependent of the user
    var isDependent: Bool {
        reference.isDependent
    }
    
    /// Whether to send pings to this contact
    var sendPings: Bool {
        reference.sendPings
    }
    
    /// Whether to receive pings from this contact
    var receivePings: Bool {
        reference.receivePings
    }
    
    /// Whether to notify this contact on check-in
    var notifyOnCheckIn: Bool {
        reference.notifyOnCheckIn
    }
    
    /// Whether to notify this contact on check-in expiry
    var notifyOnExpiry: Bool {
        reference.notifyOnExpiry
    }
    
    /// Optional nickname for this contact
    var nickname: String? {
        reference.nickname
    }
    
    /// Optional notes about this contact
    var notes: String? {
        reference.notes
    }
    
    /// When this contact was last updated
    var lastUpdated: Date {
        reference.lastUpdated
    }
    
    /// Whether this contact is non-responsive (for dependents)
    var isNonResponsive: Bool {
        guard isDependent, let lastCheckedIn = lastCheckedIn, let checkInInterval = checkInInterval else {
            return false
        }
        
        let expirationTime = lastCheckedIn.addingTimeInterval(checkInInterval)
        return Date() > expirationTime || manualAlertActive
    }
    
    /// Formatted time remaining until check-in expiration
    var formattedTimeRemaining: String {
        guard isDependent, let lastCheckedIn = lastCheckedIn, let checkInInterval = checkInInterval else {
            return ""
        }
        
        let expirationTime = lastCheckedIn.addingTimeInterval(checkInInterval)
        
        if manualAlertActive {
            return "Alert Active"
        } else if Date() > expirationTime {
            return "Check-in Expired"
        } else {
            let timeInterval = expirationTime.timeIntervalSince(Date())
            return TimeManager.shared.formatTimeInterval(timeInterval)
        }
    }
    
    /// Create a display-friendly phone number format
    var formattedPhone: String {
        // Simple formatting for now - could be enhanced with proper phone formatting
        return phoneNumber
    }
    
    /// Create a ContactDisplayModel from a ContactReference and user data
    /// - Parameters:
    ///   - reference: ContactReference containing relationship information
    ///   - userData: Dictionary containing user data from Firestore
    /// - Returns: A new ContactDisplayModel instance, or nil if required data is missing
    static func from(reference: ContactReference, userData: [String: Any]) -> ContactDisplayModel? {
        guard let userId = reference.userId else {
            return nil
        }
        
        let name = userData[UserFields.name] as? String ?? "Unknown Name"
        let phoneNumber = userData[UserFields.phoneNumber] as? String ?? ""
        let note = userData[UserFields.note] as? String ?? ""
        
        var model = ContactDisplayModel(
            id: userId,
            reference: reference,
            name: name,
            phoneNumber: phoneNumber,
            note: note
        )
        
        // Add optional fields if available
        if let lastCheckedIn = userData[UserFields.lastCheckedIn] as? Timestamp {
            model.lastCheckedIn = lastCheckedIn.dateValue()
        }
        
        if let checkInInterval = userData[UserFields.checkInInterval] as? TimeInterval {
            model.checkInInterval = checkInInterval
        }
        
        if let manualAlertActive = userData[UserFields.manualAlertActive] as? Bool {
            model.manualAlertActive = manualAlertActive
        }
        
        if let manualAlertTimestamp = userData[UserFields.manualAlertTimestamp] as? Timestamp {
            model.manualAlertTimestamp = manualAlertTimestamp.dateValue()
        }
        
        return model
    }
}
