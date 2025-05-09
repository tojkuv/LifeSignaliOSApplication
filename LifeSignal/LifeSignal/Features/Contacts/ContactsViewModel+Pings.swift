import Foundation
import FirebaseFirestore

/// Extension to add ping-related functionality to the ContactsViewModel
extension ContactsViewModel {
    /// Ping a dependent
    /// - Parameters:
    ///   - contact: The dependent to ping
    ///   - completion: Optional callback with success flag and error
    func pingDependent(_ contact: ContactReference, completion: ((Bool, Error?) -> Void)? = nil) {
        guard let userId = validateAuthentication() else {
            completion?(false, NSError(domain: "ContactsViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }
        
        guard let contactId = contact.userId else {
            completion?(false, NSError(domain: "ContactsViewModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "Contact user ID not available"]))
            return
        }
        
        // Call the Cloud Function to ping the dependent
        let parameters: [String: Any] = [
            "responderRefPath": "users/\(userId)",
            "dependentRefPath": "users/\(contactId)"
        ]
        
        callFirebaseFunctionWithSuccessCheck(functionName: "pingDependent", parameters: parameters) { [weak self] success, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error pinging dependent: \(error.localizedDescription)")
                completion?(false, error)
                return
            }
            
            if !success {
                let serverError = NSError(domain: "ContactsViewModel", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server reported failure"])
                completion?(false, serverError)
                return
            }
            
            print("Ping sent successfully to dependent: \(contact.name)")
            
            // Update the local contact to show the outgoing ping
            self.updateLocalContact(contact) { updatedContact in
                updatedContact.outgoingPingTimestamp = Date()
                updatedContact.hasOutgoingPing = true
            }
            
            completion?(true, nil)
        }
    }
    
    /// Respond to a ping from a responder
    /// - Parameters:
    ///   - contact: The responder who sent the ping
    ///   - completion: Optional callback with success flag and error
    func respondToPing(from contact: ContactReference, completion: ((Bool, Error?) -> Void)? = nil) {
        guard let userId = validateAuthentication() else {
            completion?(false, NSError(domain: "ContactsViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }
        
        guard let contactId = contact.userId else {
            completion?(false, NSError(domain: "ContactsViewModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "Contact user ID not available"]))
            return
        }
        
        // Call the Cloud Function to respond to the ping
        let parameters: [String: Any] = [
            "dependentRefPath": "users/\(userId)",
            "responderRefPath": "users/\(contactId)"
        ]
        
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
            
            print("Responded to ping from responder: \(contact.name)")
            
            // Update the local contact to clear the incoming ping
            self.updateLocalContact(contact) { updatedContact in
                updatedContact.incomingPingTimestamp = nil
                updatedContact.hasIncomingPing = false
            }
            
            // Update the pending pings count
            DispatchQueue.main.async {
                self.pendingPingsCount = self.responders.filter { $0.hasIncomingPing }.count
            }
            
            completion?(true, nil)
        }
    }
    
    /// Respond to all pending pings
    /// - Parameter completion: Optional callback with success flag and error
    func respondToAllPings(completion: ((Bool, Error?) -> Void)? = nil) {
        guard let userId = validateAuthentication() else {
            completion?(false, NSError(domain: "ContactsViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }
        
        // Call the Cloud Function to respond to all pings
        let parameters: [String: Any] = [
            "dependentRefPath": "users/\(userId)"
        ]
        
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
            
            print("Responded to all pending pings")
            
            // Update all local contacts to clear incoming pings
            for contact in self.responders where contact.hasIncomingPing {
                self.updateLocalContact(contact) { updatedContact in
                    updatedContact.incomingPingTimestamp = nil
                    updatedContact.hasIncomingPing = false
                }
            }
            
            // Update the pending pings count
            DispatchQueue.main.async {
                self.pendingPingsCount = 0
            }
            
            completion?(true, nil)
        }
    }
    
    /// Clear a ping to a dependent
    /// - Parameters:
    ///   - contact: The dependent to clear the ping for
    ///   - completion: Optional callback with success flag and error
    func clearPing(for contact: ContactReference, completion: ((Bool, Error?) -> Void)? = nil) {
        guard let userId = validateAuthentication() else {
            completion?(false, NSError(domain: "ContactsViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }
        
        guard let contactId = contact.userId else {
            completion?(false, NSError(domain: "ContactsViewModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "Contact user ID not available"]))
            return
        }
        
        // Call the Cloud Function to clear the ping
        let parameters: [String: Any] = [
            "responderRefPath": "users/\(userId)",
            "dependentRefPath": "users/\(contactId)"
        ]
        
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
            
            print("Ping cleared successfully for dependent: \(contact.name)")
            
            // Update the local contact to clear the outgoing ping
            self.updateLocalContact(contact) { updatedContact in
                updatedContact.outgoingPingTimestamp = nil
                updatedContact.hasOutgoingPing = false
            }
            
            completion?(true, nil)
        }
    }
}
