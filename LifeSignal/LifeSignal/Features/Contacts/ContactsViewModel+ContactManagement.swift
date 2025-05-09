import Foundation
import FirebaseFirestore

/// Extension to add contact management functionality to the ContactsViewModel
extension ContactsViewModel {
    /// Adds a new contact with the given QR code ID and role
    /// - Parameters:
    ///   - qrCodeId: The QR code ID of the user to add as a contact
    ///   - isResponder: True if the contact should be added as a responder
    ///   - isDependent: True if the contact should be added as a dependent
    ///   - completion: Optional callback with success flag and error
    func addContact(qrCodeId: String, isResponder: Bool, isDependent: Bool, completion: ((Bool, Error?) -> Void)? = nil) {
        // Validate authentication and get user ID
        guard let userId = validateAuthentication() else {
            completion?(false, NSError(domain: "ContactsViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }
        
        // First, look up the user by QR code ID to get basic information for display
        lookupUserByQRCode(qrCodeId) { [weak self] userData, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error looking up user by QR code: \(error.localizedDescription)")
                completion?(false, error)
                return
            }
            
            guard let userData = userData, !userData.isEmpty else {
                print("No user data found for QR code ID: \(qrCodeId)")
                completion?(false, NSError(domain: "ContactsViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "No user found with this QR code"]))
                return
            }
            
            // Call the Cloud Function to create the bidirectional relationship
            let parameters: [String: Any] = [
                "userId": userId,
                "qrCode": qrCodeId,  // Keep using qrCode as the parameter name to match the cloud function's expected parameter
                "isResponder": isResponder,
                "isDependent": isDependent
            ]
            
            self.callFirebaseFunction(functionName: "addContactRelation", parameters: parameters) { data, error in
                if let error = error as NSError? {
                    // Check for specific error codes
                    if error.domain == "com.firebase.functions" {
                        // Parse the Firebase error message
                        if let details = error.userInfo["FIRFunctionsErrorDetailsKey"] as? [String: Any],
                           let message = details["message"] as? String {
                            
                            // Check if this is the "already exists" error
                            if message.contains("already in your contacts") {
                                print("Contact already exists: \(message)")
                                
                                // This is not a failure case - the contact already exists
                                // Reload contacts to ensure the UI is up to date
                                self.loadContactsFromFirestore { _ in
                                    // Return a special error that UI can handle appropriately
                                    completion?(true, NSError(domain: "ContactsViewModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "Contact already exists"]))
                                }
                                return
                            }
                        }
                    }
                    
                    // For all other errors
                    print("Error adding contact: \(error.localizedDescription)")
                    completion?(false, error)
                    return
                }
                
                guard let data = data,
                      let success = data["success"] as? Bool,
                      let contactId = data["contactId"] as? String else {
                    completion?(false, NSError(domain: "ContactsViewModel", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"]))
                    return
                }
                
                if !success {
                    completion?(false, NSError(domain: "ContactsViewModel", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server reported failure"]))
                    return
                }
                
                print("Contact relationship created successfully with contact ID: \(contactId)")
                
                // Reload contacts to get the updated list
                self.loadContactsFromFirestore { success in
                    completion?(success, nil)
                }
            }
        }
    }
    
    /// Adds a new contact with the given QR code ID and single role
    /// - Parameters:
    ///   - qrCodeId: The QR code ID of the contact
    ///   - isResponder: True if the contact is a responder, false if dependent
    ///   - completion: Optional callback with success flag and error
    func addContact(qrCodeId: String, isResponder: Bool, completion: ((Bool, Error?) -> Void)? = nil) {
        addContact(qrCodeId: qrCodeId, isResponder: isResponder, isDependent: !isResponder, completion: completion)
    }
    
    /// Removes a contact from the contacts list
    /// - Parameters:
    ///   - contact: The ContactReference object to remove
    ///   - completion: Optional callback with success flag and error
    func removeContact(_ contact: ContactReference, completion: ((Bool, Error?) -> Void)? = nil) {
        // Set error state to nil at the start of the operation
        DispatchQueue.main.async {
            self.contactError = nil
            self.isLoadingContacts = true
        }
        
        print("Starting contact removal for: \(contact.name)")
        
        // Store a local copy of the contact for reference
        let contactToRemove = contact
        
        // Validate authentication and get user ID
        guard let userId = validateAuthentication() else {
            DispatchQueue.main.async {
                self.isLoadingContacts = false
            }
            completion?(false, NSError(domain: "ContactsViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }
        
        // Get the contact's user ID directly from the reference path
        guard let contactId = contactToRemove.userId else {
            print("Cannot extract user ID from reference path: \(contactToRemove.referencePath)")
            
            // Since we can't find the contact ID, just remove it locally
            self.removeContactLocally(contactToRemove)
            DispatchQueue.main.async {
                self.isLoadingContacts = false
            }
            completion?(true, nil)
            return
        }
        
        // Call the Cloud Function to delete the bidirectional relationship
        let parameters: [String: Any] = [
            "userARefPath": "users/\(userId)",
            "userBRefPath": "users/\(contactId)"
        ]
        
        print("Calling deleteContactRelation function for contact: \(contactToRemove.name) with ID: \(contactId)")
        
        callFirebaseFunctionWithSuccessCheck(functionName: "deleteContactRelation", parameters: parameters) { [weak self] success, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error in deleteContactRelation: \(error.localizedDescription)")
                
                // Set the error state
                DispatchQueue.main.async {
                    self.contactError = error
                    self.isLoadingContacts = false
                }
                
                completion?(false, error)
                return
            }
            
            if !success {
                let serverError = NSError(domain: "ContactsViewModel", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server reported failure"])
                
                // Set the error state
                DispatchQueue.main.async {
                    self.contactError = serverError
                    self.isLoadingContacts = false
                }
                
                completion?(false, serverError)
                return
            }
            
            print("Contact relationship deleted successfully on server")
            
            // Now that the server operation succeeded, remove the contact locally
            self.removeContactLocally(contactToRemove)
            
            // Force reload contacts to ensure we have the latest data
            self.forceReloadContacts { success in
                DispatchQueue.main.async {
                    self.isLoadingContacts = false
                }
                print("Contacts reloaded after deletion with success: \(success)")
                completion?(true, nil)
            }
        }
    }
    
    /// Helper method to remove a contact locally
    /// - Parameter contact: The contact to remove
    private func removeContactLocally(_ contact: ContactReference) {
        print("Before removal - Responders count: \(responders.count), Dependents count: \(dependents.count)")
        
        // Remove the contact from the combined list
        contacts.removeAll { $0.id == contact.id }
        
        // Remove from the dictionary
        contactsById.removeValue(forKey: contact.id)
        
        print("Removed contact locally: \(contact.name)")
        print("After removal - Responders count: \(responders.count), Dependents count: \(dependents.count)")
    }
    
    /// Update a contact's roles
    /// - Parameters:
    ///   - contact: The contact to update
    ///   - isResponder: Whether the contact should be a responder
    ///   - isDependent: Whether the contact should be a dependent
    ///   - completion: Optional callback with success flag and error
    func updateContactRoles(_ contact: ContactReference, isResponder: Bool, isDependent: Bool, completion: ((Bool, Error?) -> Void)? = nil) {
        guard let userId = validateAuthentication() else {
            completion?(false, NSError(domain: "ContactsViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }
        
        guard let contactId = contact.userId else {
            completion?(false, NSError(domain: "ContactsViewModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "Contact user ID not available"]))
            return
        }
        
        // Call the Cloud Function to update the contact roles
        let parameters: [String: Any] = [
            "userRefPath": "users/\(userId)",
            "contactRefPath": "users/\(contactId)",
            "isResponder": isResponder,
            "isDependent": isDependent
        ]
        
        callFirebaseFunctionWithSuccessCheck(functionName: "updateContactRelation", parameters: parameters) { [weak self] success, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error updating contact roles: \(error.localizedDescription)")
                completion?(false, error)
                return
            }
            
            if !success {
                let serverError = NSError(domain: "ContactsViewModel", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server reported failure"])
                completion?(false, serverError)
                return
            }
            
            print("Contact roles updated successfully for: \(contact.name)")
            
            // Update the local contact
            self.updateLocalContact(contact) { updatedContact in
                updatedContact.isResponder = isResponder
                updatedContact.isDependent = isDependent
            }
            
            completion?(true, nil)
        }
    }
}
