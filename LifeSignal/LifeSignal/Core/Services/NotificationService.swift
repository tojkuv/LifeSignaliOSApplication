import Foundation
import UIKit
import UserNotifications
import FirebaseFirestore
import FirebaseMessaging

/// Service class for handling push notifications and alerts
class NotificationService {
    // Singleton instance
    static let shared = NotificationService()

    // Private initializer for singleton
    private init() {}

    /// Request notification permissions
    /// - Parameter completion: Optional callback with success flag and error
    func requestNotificationPermissions(completion: ((Bool, Error?) -> Void)? = nil) {
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { granted, error in
                if let error = error {
                    print("Error requesting notification authorization: \(error.localizedDescription)")
                    completion?(false, error)
                    return
                }

                if granted {
                    print("Notification authorization granted")
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                    completion?(true, nil)
                } else {
                    print("Notification authorization denied")
                    completion?(false, nil)
                }
            }
        )
    }

    /// Check if notifications are authorized
    /// - Parameter completion: Callback with authorization status
    func checkNotificationAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let isAuthorized = settings.authorizationStatus == .authorized
            DispatchQueue.main.async {
                completion(isAuthorized)
            }
        }
    }

    /// Send a manual alert to all responders
    /// - Parameters:
    ///   - userId: The user ID of the person sending the alert
    ///   - completion: Optional callback with success flag and error
    func sendManualAlert(userId: String, completion: ((Bool, Error?) -> Void)? = nil) {
        guard AuthenticationService.shared.isAuthenticated else {
            let error = NSError(domain: "NotificationService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            completion?(false, error)
            return
        }

        // Get the user document
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)

        // Update the user document to mark the alert as active
        userRef.updateData([
            "manualAlertActive": true,
            "manualAlertTimestamp": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Error updating alert status in Firestore: \(error.localizedDescription)")
                completion?(false, error)
                return
            }

            print("Alert status updated in Firestore")

            // Get the user's contacts
            userRef.getDocument { snapshot, error in
                if let error = error {
                    print("Error getting user document: \(error.localizedDescription)")
                    completion?(false, error)
                    return
                }

                guard let userData = snapshot?.data(),
                      let userName = userData["name"] as? String,
                      let contacts = userData["contacts"] as? [[String: Any]] else {
                    print("No contacts found in user document")
                    completion?(true, nil)
                    return
                }

                // Filter responders (people who should be notified when this user sends an alert)
                let responders = contacts.filter { ($0["isResponder"] as? Bool) == true }

                if responders.isEmpty {
                    print("No responders found for user")
                    completion?(true, nil)
                    return
                }

                print("Found \(responders.count) responders to notify")

                // For each responder, update their contact list to show this user has an active alert
                for responder in responders {
                    if let responderRef = responder["reference"] as? DocumentReference {
                        // Get the responder's contacts
                        responderRef.getDocument { responderSnapshot, responderError in
                            if let responderError = responderError {
                                print("Error getting responder document: \(responderError.localizedDescription)")
                                return
                            }

                            guard let responderData = responderSnapshot?.data(),
                                  let responderContacts = responderData["contacts"] as? [[String: Any]] else {
                                print("No contacts found in responder document")
                                return
                            }

                            // Find this user in the responder's contacts
                            if let contactIndex = responderContacts.firstIndex(where: {
                                if let contactRef = $0["reference"] as? DocumentReference {
                                    return contactRef.documentID == userId
                                }
                                return false
                            }) {
                                // Update the contact to show the alert is active
                                var updatedContacts = responderContacts
                                updatedContacts[contactIndex]["manualAlertActive"] = true
                                updatedContacts[contactIndex]["manualAlertTimestamp"] = FieldValue.serverTimestamp()

                                // Update the responder's document
                                responderRef.updateData([
                                    "contacts": updatedContacts
                                ]) { updateError in
                                    if let updateError = updateError {
                                        print("Error updating responder's contacts: \(updateError.localizedDescription)")
                                        return
                                    }

                                    print("Updated responder's contacts to show alert")
                                }
                            }
                        }
                    }
                }

                completion?(true, nil)
            }
        }
    }

    /// Cancel a manual alert
    /// - Parameters:
    ///   - userId: The user ID of the person canceling the alert
    ///   - completion: Optional callback with success flag and error
    func cancelManualAlert(userId: String, completion: ((Bool, Error?) -> Void)? = nil) {
        guard AuthenticationService.shared.isAuthenticated else {
            let error = NSError(domain: "NotificationService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            completion?(false, error)
            return
        }

        // Get the user document
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)

        // Update the user document to mark the alert as inactive
        userRef.updateData([
            "manualAlertActive": false,
            "manualAlertTimestamp": FieldValue.delete()
        ]) { error in
            if let error = error {
                print("Error updating alert status in Firestore: \(error.localizedDescription)")
                completion?(false, error)
                return
            }

            print("Alert status updated in Firestore")

            // Get the user's contacts
            userRef.getDocument { snapshot, error in
                if let error = error {
                    print("Error getting user document: \(error.localizedDescription)")
                    completion?(false, error)
                    return
                }

                guard let userData = snapshot?.data(),
                      let contacts = userData["contacts"] as? [[String: Any]] else {
                    print("No contacts found in user document")
                    completion?(true, nil)
                    return
                }

                // Filter responders (people who should be notified when this user cancels an alert)
                let responders = contacts.filter { ($0["isResponder"] as? Bool) == true }

                if responders.isEmpty {
                    print("No responders found for user")
                    completion?(true, nil)
                    return
                }

                print("Found \(responders.count) responders to notify about alert cancellation")

                // For each responder, update their contact list to show this user has canceled the alert
                for responder in responders {
                    if let responderRef = responder["reference"] as? DocumentReference {
                        // Get the responder's contacts
                        responderRef.getDocument { responderSnapshot, responderError in
                            if let responderError = responderError {
                                print("Error getting responder document: \(responderError.localizedDescription)")
                                return
                            }

                            guard let responderData = responderSnapshot?.data(),
                                  let responderContacts = responderData["contacts"] as? [[String: Any]] else {
                                print("No contacts found in responder document")
                                return
                            }

                            // Find this user in the responder's contacts
                            if let contactIndex = responderContacts.firstIndex(where: {
                                if let contactRef = $0["reference"] as? DocumentReference {
                                    return contactRef.documentID == userId
                                }
                                return false
                            }) {
                                // Update the contact to show the alert is inactive
                                var updatedContacts = responderContacts
                                updatedContacts[contactIndex]["manualAlertActive"] = false

                                // Update the responder's document
                                responderRef.updateData([
                                    "contacts": updatedContacts
                                ]) { updateError in
                                    if let updateError = updateError {
                                        print("Error updating responder's contacts: \(updateError.localizedDescription)")
                                        return
                                    }

                                    print("Updated responder's contacts to clear alert")
                                }
                            }
                        }
                    }
                }

                completion?(true, nil)
            }
        }
    }

    /// Show a local notification for testing
    /// - Parameters:
    ///   - title: The notification title
    ///   - body: The notification body
    ///   - userInfo: Additional data to include with the notification
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

    /// Handle an alert notification from a dependent
    /// - Parameters:
    ///   - dependentId: The user ID of the dependent who sent the alert
    ///   - dependentName: The name of the dependent
    ///   - timestamp: The timestamp of the alert
    func handleDependentAlert(dependentId: String, dependentName: String, timestamp: Date) {
        // Show a local notification
        showLocalNotification(
            title: "Alert from \(dependentName)",
            body: "\(dependentName) has sent an emergency alert.",
            userInfo: [
                "alertType": "manualAlert",
                "dependentId": dependentId,
                "timestamp": timestamp.timeIntervalSince1970.description
            ]
        )

        // Post a notification to update the UI
        NotificationCenter.default.post(
            name: NSNotification.Name("DependentAlertReceived"),
            object: nil,
            userInfo: [
                "dependentId": dependentId,
                "timestamp": timestamp
            ]
        )

        // Post notification to refresh the dependents view
        NotificationCenter.default.post(name: NSNotification.Name("RefreshDependentsView"), object: nil)
    }

    /// Handle an alert cancellation from a dependent
    /// - Parameters:
    ///   - dependentId: The user ID of the dependent who canceled the alert
    ///   - dependentName: The name of the dependent
    func handleDependentAlertCancellation(dependentId: String, dependentName: String) {
        // Show a local notification
        showLocalNotification(
            title: "Alert Canceled",
            body: "\(dependentName) has canceled their emergency alert.",
            userInfo: [
                "alertType": "manualAlertCanceled",
                "dependentId": dependentId
            ]
        )

        // Post a notification to update the UI
        NotificationCenter.default.post(
            name: NSNotification.Name("DependentAlertCanceled"),
            object: nil,
            userInfo: [
                "dependentId": dependentId
            ]
        )

        // Post notification to refresh the dependents view
        NotificationCenter.default.post(name: NSNotification.Name("RefreshDependentsView"), object: nil)
    }
}
