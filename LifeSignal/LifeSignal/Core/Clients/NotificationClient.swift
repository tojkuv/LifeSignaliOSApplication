import Foundation
import UIKit
import UserNotifications
import FirebaseFirestore
import ComposableArchitecture

/// Protocol defining notification operations
protocol NotificationClientProtocol {
    /// Request notification permissions
    func requestNotificationPermissions() async -> Bool
    
    /// Check if notifications are authorized
    func checkNotificationAuthorization() async -> Bool
    
    /// Send a manual alert to all responders
    func sendManualAlert(userId: String) async throws
    
    /// Cancel a manual alert
    func cancelManualAlert(userId: String) async throws
    
    /// Show a local notification for testing
    func showLocalNotification(title: String, body: String, userInfo: [String: Any])
}

/// Live implementation of NotificationClient
struct NotificationLiveClient: NotificationClientProtocol {
    func requestNotificationPermissions() async -> Bool {
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: authOptions)
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            print("Error requesting notification authorization: \(error.localizedDescription)")
            return false
        }
    }
    
    func checkNotificationAuthorization() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }
    
    func sendManualAlert(userId: String) async throws {
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreConstants.Collections.users).document(userId)
        
        // Update the user document to mark the alert as active
        try await userRef.updateData([
            FirestoreConstants.UserFields.manualAlertActive: true,
            FirestoreConstants.UserFields.manualAlertTimestamp: FieldValue.serverTimestamp()
        ])
        
        // Get the user's contacts
        let snapshot = try await userRef.getDocument()
        
        guard let userData = snapshot.data(),
              let userName = userData[FirestoreConstants.UserFields.name] as? String,
              let contacts = userData[FirestoreConstants.UserFields.contacts] as? [[String: Any]] else {
            return
        }
        
        // Filter responders (people who should be notified when this user sends an alert)
        let responders = contacts.filter { ($0[FirestoreConstants.ContactFields.isResponder] as? Bool) == true }
        
        // For each responder, update their contact list to show this user has an active alert
        for responder in responders {
            if let responderPath = responder[FirestoreConstants.ContactFields.referencePath] as? String {
                let responderRef = db.document(responderPath)
                
                // Get the responder's contacts
                let responderSnapshot = try await responderRef.getDocument()
                
                guard let responderData = responderSnapshot.data(),
                      let responderContacts = responderData[FirestoreConstants.UserFields.contacts] as? [[String: Any]] else {
                    continue
                }
                
                // Find this user in the responder's contacts
                if let contactIndex = responderContacts.firstIndex(where: {
                    if let contactPath = $0[FirestoreConstants.ContactFields.referencePath] as? String {
                        return contactPath.contains(userId)
                    }
                    return false
                }) {
                    // Update the contact to show the alert is active
                    var updatedContacts = responderContacts
                    updatedContacts[contactIndex][FirestoreConstants.ContactFields.manualAlertActive] = true
                    updatedContacts[contactIndex][FirestoreConstants.ContactFields.manualAlertTimestamp] = FieldValue.serverTimestamp()
                    
                    // Update the responder's document
                    try await responderRef.updateData([
                        FirestoreConstants.UserFields.contacts: updatedContacts
                    ])
                }
            }
        }
    }
    
    func cancelManualAlert(userId: String) async throws {
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreConstants.Collections.users).document(userId)
        
        // Update the user document to mark the alert as inactive
        try await userRef.updateData([
            FirestoreConstants.UserFields.manualAlertActive: false,
            FirestoreConstants.UserFields.manualAlertTimestamp: FieldValue.delete()
        ])
        
        // Get the user's contacts
        let snapshot = try await userRef.getDocument()
        
        guard let userData = snapshot.data(),
              let contacts = userData[FirestoreConstants.UserFields.contacts] as? [[String: Any]] else {
            return
        }
        
        // Filter responders (people who should be notified when this user cancels an alert)
        let responders = contacts.filter { ($0[FirestoreConstants.ContactFields.isResponder] as? Bool) == true }
        
        // For each responder, update their contact list to show this user has canceled the alert
        for responder in responders {
            if let responderPath = responder[FirestoreConstants.ContactFields.referencePath] as? String {
                let responderRef = db.document(responderPath)
                
                // Get the responder's contacts
                let responderSnapshot = try await responderRef.getDocument()
                
                guard let responderData = responderSnapshot.data(),
                      let responderContacts = responderData[FirestoreConstants.UserFields.contacts] as? [[String: Any]] else {
                    continue
                }
                
                // Find this user in the responder's contacts
                if let contactIndex = responderContacts.firstIndex(where: {
                    if let contactPath = $0[FirestoreConstants.ContactFields.referencePath] as? String {
                        return contactPath.contains(userId)
                    }
                    return false
                }) {
                    // Update the contact to show the alert is inactive
                    var updatedContacts = responderContacts
                    updatedContacts[contactIndex][FirestoreConstants.ContactFields.manualAlertActive] = false
                    
                    // Update the responder's document
                    try await responderRef.updateData([
                        FirestoreConstants.UserFields.contacts: updatedContacts
                    ])
                }
            }
        }
    }
    
    func showLocalNotification(title: String, body: String, userInfo: [String: Any] = [:]) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Add user info
        for (key, value) in userInfo {
            if let value = value as? String {
                content.userInfo[key] = value
            }
        }
        
        // Create a trigger (immediate)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // Create the request
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        // Add the request to the notification center
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing local notification: \(error.localizedDescription)")
            }
        }
    }
}

/// Mock implementation for testing
struct NotificationMockClient: NotificationClientProtocol {
    func requestNotificationPermissions() async -> Bool {
        return true
    }
    
    func checkNotificationAuthorization() async -> Bool {
        return true
    }
    
    func sendManualAlert(userId: String) async throws {
        // No-op for testing
    }
    
    func cancelManualAlert(userId: String) async throws {
        // No-op for testing
    }
    
    func showLocalNotification(title: String, body: String, userInfo: [String: Any] = [:]) {
        // No-op for testing
    }
}

// TCA dependency registration
extension DependencyValues {
    var notificationClient: NotificationClientProtocol {
        get { self[NotificationClientKey.self] }
        set { self[NotificationClientKey.self] = newValue }
    }
    
    private enum NotificationClientKey: DependencyKey {
        static let liveValue: NotificationClientProtocol = NotificationLiveClient()
        static let testValue: NotificationClientProtocol = NotificationMockClient()
    }
}
