import Foundation
import FirebaseFirestore
import FirebaseFunctions

/// Extension for ContactsViewModel that handles ping-related functionality
///
/// This extension contains methods for sending, responding to, and clearing pings
/// between users. Pings are a way for users to request a response from their contacts.
extension ContactsViewModel {

    // MARK: - Respond to Pings

    /// Responds to a ping from a contact
    ///
    /// This method acknowledges a ping from a responder contact by clearing the incoming ping
    /// timestamp. It uses a Firebase Cloud Function to update both users' contact records.
    ///
    /// - Parameters:
    ///   - contact: The contact who sent the ping
    ///   - completion: Optional callback that is called when the operation completes.
    ///     The boolean parameter indicates success (true) or failure (false).
    ///     If an error occurs, it will be passed as the second parameter.
    ///
    /// - Note: This method requires an authenticated user and will fail if no user is signed in.
    /// - Note: After responding to a ping, the contact's hasIncomingPing property will be false.
    func respondToPing(from contact: ContactReference, completion: ((Bool, Error?) -> Void)? = nil) {
        // Validate authentication and get user ID
        guard let userId = validateAuthentication() else {
            completion?(false, NSError(domain: "ContactsViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }

        // Get the contact's user ID
        guard let contactId = contact.userId else {
            completion?(false, NSError(domain: "ContactsViewModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid contact reference"]))
            return
        }

        // Call the Cloud Function to respond to the ping
        let parameters: [String: Any] = [
            "userRefPath": "users/\(userId)",
            "contactRefPath": "users/\(contactId)"
        ]

        print("Responding to ping from contact: \(contact.name)")

        callFirebaseFunctionWithSuccessCheck(functionName: "respondToPing", parameters: parameters) { [weak self] success, error in
            guard let self = self else { return }

            if let error = error {
                print("Error responding to ping: \(error.localizedDescription)")
                completion?(false, error)
                return
            }

            if !success {
                let serverError = NSError(domain: "ContactsViewModel", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server reported failure"])
                completion?(false, serverError)
                return
            }

            print("Successfully responded to ping from: \(contact.name)")

            // Update the contact locally to reflect the change
            self.updateLocalContact(contact) { updatedContact in
                updatedContact.incomingPingTimestamp = nil
            }

            // Update the pending pings count
            DispatchQueue.main.async {
                self.pendingPingsCount = self.contacts.filter { $0.isResponder && $0.hasIncomingPing }.count
            }

            // Post notifications to refresh the UI
            self.postUIRefreshNotifications()

            completion?(true, nil)
        }
    }

    /// Responds to all pending pings
    ///
    /// This method acknowledges all pending pings from responder contacts by clearing
    /// their incoming ping timestamps. It uses a Firebase Cloud Function to update
    /// all relevant contact records.
    ///
    /// - Parameter completion: Optional callback that is called when the operation completes.
    ///   The boolean parameter indicates success (true) or failure (false).
    ///   If an error occurs, it will be passed as the second parameter.
    ///
    /// - Note: This method requires an authenticated user and will fail if no user is signed in.
    /// - Note: After responding to all pings, the pendingPingsCount property will be zero.
    func respondToAllPings(completion: ((Bool, Error?) -> Void)? = nil) {
        // Validate authentication and get user ID
        guard let userId = validateAuthentication() else {
            completion?(false, NSError(domain: "ContactsViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }

        // Get all contacts with pending pings
        let contactsWithPings = contacts.filter { $0.isResponder && $0.hasIncomingPing }

        if contactsWithPings.isEmpty {
            // No pings to respond to
            completion?(true, nil)
            return
        }

        // Call the Cloud Function to respond to all pings
        let parameters: [String: Any] = [
            "userRefPath": "users/\(userId)"
        ]

        print("Responding to all pings (\(contactsWithPings.count) total)")

        callFirebaseFunctionWithSuccessCheck(functionName: "respondToAllPings", parameters: parameters) { [weak self] success, error in
            guard let self = self else { return }

            if let error = error {
                print("Error responding to all pings: \(error.localizedDescription)")
                completion?(false, error)
                return
            }

            if !success {
                let serverError = NSError(domain: "ContactsViewModel", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server reported failure"])
                completion?(false, serverError)
                return
            }

            print("Successfully responded to all pings")

            // Update all contacts with pings locally
            for contact in contactsWithPings {
                self.updateLocalContact(contact) { updatedContact in
                    updatedContact.incomingPingTimestamp = nil
                }
            }

            // Update the pending pings count
            DispatchQueue.main.async {
                self.pendingPingsCount = 0
            }

            // Post notifications to refresh the UI
            self.postUIRefreshNotifications()

            // Force reload contacts to ensure we have the latest data
            self.forceReloadContacts { _ in
                completion?(true, nil)
            }
        }
    }

    // MARK: - Send Pings

    /// Sends a ping to a dependent contact
    ///
    /// This method sends a ping to a dependent contact by setting the outgoing ping
    /// timestamp. It uses a Firebase Cloud Function to update both users' contact records.
    ///
    /// - Parameters:
    ///   - contact: The dependent contact to ping
    ///   - completion: Optional callback that is called when the operation completes.
    ///     The boolean parameter indicates success (true) or failure (false).
    ///     If an error occurs, it will be passed as the second parameter.
    ///
    /// - Note: This method requires an authenticated user and will fail if no user is signed in.
    /// - Note: After sending a ping, the contact's hasOutgoingPing property will be true.
    func pingDependent(_ contact: ContactReference, completion: ((Bool, Error?) -> Void)? = nil) {
        // Validate authentication and get user ID
        guard let userId = validateAuthentication() else {
            completion?(false, NSError(domain: "ContactsViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }

        // Ensure the contact is a dependent
        guard contact.isDependent else {
            completion?(false, NSError(domain: "ContactsViewModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "Contact is not a dependent"]))
            return
        }

        // Get the contact's user ID
        guard let contactId = contact.userId else {
            completion?(false, NSError(domain: "ContactsViewModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid contact reference"]))
            return
        }

        // Call the Cloud Function to send the ping
        let parameters: [String: Any] = [
            "userRefPath": "users/\(userId)",
            "contactRefPath": "users/\(contactId)"
        ]

        print("Sending ping to dependent: \(contact.name)")

        callFirebaseFunctionWithSuccessCheck(functionName: "pingDependent", parameters: parameters) { [weak self] success, error in
            guard let self = self else { return }

            if let error = error {
                print("Error sending ping: \(error.localizedDescription)")
                completion?(false, error)
                return
            }

            if !success {
                let serverError = NSError(domain: "ContactsViewModel", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server reported failure"])
                completion?(false, serverError)
                return
            }

            print("Successfully sent ping to: \(contact.name)")

            // Update the contact locally to reflect the change
            self.updateLocalContact(contact) { updatedContact in
                updatedContact.outgoingPingTimestamp = Date()
            }

            // Post notifications to refresh the UI
            self.postUIRefreshNotifications()

            completion?(true, nil)
        }
    }

    /// Clears a ping sent to a dependent contact
    ///
    /// This method clears a ping that was previously sent to a dependent contact
    /// by removing the outgoing ping timestamp. It uses a Firebase Cloud Function
    /// to update both users' contact records.
    ///
    /// - Parameters:
    ///   - contact: The dependent contact whose ping should be cleared
    ///   - completion: Optional callback that is called when the operation completes.
    ///     The boolean parameter indicates success (true) or failure (false).
    ///     If an error occurs, it will be passed as the second parameter.
    ///
    /// - Note: This method requires an authenticated user and will fail if no user is signed in.
    /// - Note: After clearing a ping, the contact's hasOutgoingPing property will be false.
    func clearPing(for contact: ContactReference, completion: ((Bool, Error?) -> Void)? = nil) {
        // Validate authentication and get user ID
        guard let userId = validateAuthentication() else {
            completion?(false, NSError(domain: "ContactsViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }

        // Ensure the contact is a dependent
        guard contact.isDependent else {
            completion?(false, NSError(domain: "ContactsViewModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "Contact is not a dependent"]))
            return
        }

        // Get the contact's user ID
        guard let contactId = contact.userId else {
            completion?(false, NSError(domain: "ContactsViewModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid contact reference"]))
            return
        }

        // Call the Cloud Function to clear the ping
        let parameters: [String: Any] = [
            "userRefPath": "users/\(userId)",
            "contactRefPath": "users/\(contactId)"
        ]

        print("Clearing ping for dependent: \(contact.name)")

        callFirebaseFunctionWithSuccessCheck(functionName: "clearPing", parameters: parameters) { [weak self] success, error in
            guard let self = self else { return }

            if let error = error {
                print("Error clearing ping: \(error.localizedDescription)")
                completion?(false, error)
                return
            }

            if !success {
                let serverError = NSError(domain: "ContactsViewModel", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server reported failure"])
                completion?(false, serverError)
                return
            }

            print("Successfully cleared ping for: \(contact.name)")

            // Update the contact locally to reflect the change
            self.updateLocalContact(contact) { updatedContact in
                updatedContact.outgoingPingTimestamp = nil
            }

            // Post notifications to refresh the UI
            self.postUIRefreshNotifications()

            completion?(true, nil)
        }
    }
}
