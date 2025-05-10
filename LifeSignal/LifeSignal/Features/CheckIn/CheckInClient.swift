import Foundation
import ComposableArchitecture
import FirebaseFirestore
import FirebaseFunctions

/// Client for interacting with check-in functionality
struct CheckInClient {
    /// Update the user's last check-in time to now
    var updateLastCheckedIn: () async throws -> Bool
    
    /// Update the user's check-in interval
    var updateCheckInInterval: (TimeInterval) async throws -> Bool
    
    /// Update the user's notification preferences
    var updateNotificationPreferences: (notify30Min: Bool, notify2Hours: Bool) async throws -> Bool
    
    /// Load the user's check-in data
    var loadCheckInData: () async throws -> CheckInData
}

extension CheckInClient: DependencyKey {
    /// Live implementation of the check-in client
    static var liveValue: Self {
        return Self(
            updateLastCheckedIn: {
                guard let userId = AuthenticationService.shared.getCurrentUserID() else {
                    throw NSError(domain: "CheckInClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }
                
                let db = Firestore.firestore()
                let userRef = db.collection(FirestoreCollections.users).document(userId)
                
                let updateData: [String: Any] = [
                    User.Fields.lastCheckedIn: Timestamp(date: Date()),
                    User.Fields.lastUpdated: Timestamp(date: Date())
                ]
                
                try await userRef.updateData(updateData)
                return true
            },
            
            updateCheckInInterval: { interval in
                guard let userId = AuthenticationService.shared.getCurrentUserID() else {
                    throw NSError(domain: "CheckInClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }
                
                let db = Firestore.firestore()
                let userRef = db.collection(FirestoreCollections.users).document(userId)
                
                let updateData: [String: Any] = [
                    User.Fields.checkInInterval: interval,
                    User.Fields.lastUpdated: Timestamp(date: Date())
                ]
                
                try await userRef.updateData(updateData)
                return true
            },
            
            updateNotificationPreferences: { notify30Min, notify2Hours in
                guard let userId = AuthenticationService.shared.getCurrentUserID() else {
                    throw NSError(domain: "CheckInClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }
                
                let db = Firestore.firestore()
                let userRef = db.collection(FirestoreCollections.users).document(userId)
                
                let updateData: [String: Any] = [
                    User.Fields.notify30MinBefore: notify30Min,
                    User.Fields.notify2HoursBefore: notify2Hours,
                    User.Fields.lastUpdated: Timestamp(date: Date())
                ]
                
                try await userRef.updateData(updateData)
                return true
            },
            
            loadCheckInData: {
                guard let userId = AuthenticationService.shared.getCurrentUserID() else {
                    throw NSError(domain: "CheckInClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }
                
                let db = Firestore.firestore()
                let userRef = db.collection(FirestoreCollections.users).document(userId)
                
                let document = try await userRef.getDocument()
                
                guard let data = document.data() else {
                    throw NSError(domain: "CheckInClient", code: 404, userInfo: [NSLocalizedDescriptionKey: "User data not found"])
                }
                
                let lastCheckedIn = (data[User.Fields.lastCheckedIn] as? Timestamp)?.dateValue() ?? Date()
                let checkInInterval = data[User.Fields.checkInInterval] as? TimeInterval ?? TimeManager.defaultInterval
                let notify30MinBefore = data[User.Fields.notify30MinBefore] as? Bool ?? true
                let notify2HoursBefore = data[User.Fields.notify2HoursBefore] as? Bool ?? false
                let alertActive = data[User.Fields.manualAlertActive] as? Bool ?? false
                let alertTimestamp = (data[User.Fields.manualAlertTimestamp] as? Timestamp)?.dateValue()
                
                return CheckInData(
                    lastCheckedIn: lastCheckedIn,
                    checkInInterval: checkInInterval,
                    notify30MinBefore: notify30MinBefore,
                    notify2HoursBefore: notify2HoursBefore,
                    sendAlertActive: alertActive,
                    manualAlertTimestamp: alertTimestamp
                )
            }
        )
    }
    
    /// Test implementation of the check-in client
    static var testValue: Self {
        return Self(
            updateLastCheckedIn: {
                return true
            },
            
            updateCheckInInterval: { _ in
                return true
            },
            
            updateNotificationPreferences: { _, _ in
                return true
            },
            
            loadCheckInData: {
                return CheckInData(
                    lastCheckedIn: Date(),
                    checkInInterval: TimeManager.defaultInterval,
                    notify30MinBefore: true,
                    notify2HoursBefore: false,
                    sendAlertActive: false,
                    manualAlertTimestamp: nil
                )
            }
        )
    }
}

extension DependencyValues {
    var checkInClient: CheckInClient {
        get { self[CheckInClient.self] }
        set { self[CheckInClient.self] = newValue }
    }
}
