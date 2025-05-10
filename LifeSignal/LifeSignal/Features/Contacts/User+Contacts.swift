import Foundation
import FirebaseFirestore

/// Extension to add contacts-related functionality to the User model
extension User {

    /// Filtered list of contacts who are responders
    var responders: [ContactReference] {
        contacts.filter { $0.isResponder }
    }

    /// Filtered list of contacts who are dependents
    var dependents: [ContactReference] {
        contacts.filter { $0.isDependent }
    }

    /// Get a contact by ID
    /// - Parameter id: The contact ID
    /// - Returns: The contact if found, nil otherwise
    func getContact(by id: String) -> ContactReference? {
        return contacts.first { $0.id == id }
    }

    /// Add a new contact
    /// - Parameter contact: The contact to add
    /// - Returns: True if the contact was added, false if it already exists
    mutating func addContact(_ contact: ContactReference) -> Bool {
        // Check if contact already exists
        if getContact(by: contact.id) != nil {
            return false
        }

        // Add the contact
        contacts.append(contact)
        lastUpdated = Date()
        return true
    }

    /// Remove a contact
    /// - Parameter id: The ID of the contact to remove
    /// - Returns: True if the contact was removed, false if it wasn't found
    mutating func removeContact(id: String) -> Bool {
        let initialCount = contacts.count
        contacts.removeAll { $0.id == id }

        if contacts.count < initialCount {
            lastUpdated = Date()
            return true
        }

        return false
    }

    /// Update a contact
    /// - Parameters:
    ///   - id: The ID of the contact to update
    ///   - updateAction: Closure that modifies the contact
    /// - Returns: True if the contact was updated, false if it wasn't found
    mutating func updateContact(id: String, updateAction: (inout ContactReference) -> Void) -> Bool {
        if let index = contacts.firstIndex(where: { $0.id == id }) {
            updateAction(&contacts[index])
            lastUpdated = Date()
            return true
        }

        return false
    }

    /// Trigger a manual alert
    mutating func triggerManualAlert() {
        manualAlertActive = true
        manualAlertTimestamp = Date()
        lastUpdated = Date()
    }

    /// Clear a manual alert
    mutating func clearManualAlert() {
        manualAlertActive = false
        lastUpdated = Date()
    }


}
