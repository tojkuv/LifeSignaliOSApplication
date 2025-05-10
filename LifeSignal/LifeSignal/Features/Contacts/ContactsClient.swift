import Foundation
import ComposableArchitecture
import FirebaseFirestore
import FirebaseFunctions

/// Client for interacting with contacts functionality
struct ContactsClient {
    /// Load contacts from Firestore
    var loadContacts: () async throws -> [Contact]

    /// Add a contact
    var addContact: (Contact) async throws -> Bool

    /// Update a contact's roles
    var updateContactRoles: (id: String, isResponder: Bool, isDependent: Bool) async throws -> Bool

    /// Delete a contact
    var deleteContact: (id: String) async throws -> Bool

    /// Ping a dependent
    var pingDependent: (id: String) async throws -> Bool

    /// Clear a ping for a dependent
    var clearPing: (id: String) async throws -> Bool

    /// Respond to a ping
    var respondToPing: (id: String) async throws -> Bool

    /// Respond to all pings
    var respondToAllPings: () async throws -> Bool

    /// Look up a user by QR code
    var lookupUserByQRCode: (String) async throws -> Contact?
}

extension ContactsClient: DependencyKey {
    /// Live implementation of the contacts client
    static var liveValue: Self {
        return Self(
            loadContacts: {
                guard let userId = AuthenticationService.shared.getCurrentUserID() else {
                    throw NSError(domain: "ContactsClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

                let db = Firestore.firestore()
                let userRef = db.collection(FirestoreConstants.Collections.users).document(userId)

                // Get the user document to access contacts
                let userDoc = try await userRef.getDocument()
                guard let userData = userDoc.data() else {
                    throw NSError(domain: "ContactsClient", code: 404, userInfo: [NSLocalizedDescriptionKey: "User data not found"])
                }

                // Extract contacts array
                guard let contactsData = userData[FirestoreConstants.UserFields.contacts] as? [[String: Any]] else {
                    return []
                }

                // Process each contact
                var contacts: [Contact] = []

                for contactData in contactsData {
                    // Extract the contact ID from the reference path
                    guard let referencePath = contactData[FirestoreConstants.ContactFields.referencePath] as? String else { continue }
                    let components = referencePath.components(separatedBy: "/")
                    guard components.count == 2 && components[0] == "users" else { continue }
                    let contactId = components[1]

                    // Get the contact's user document
                    let contactRef = db.collection(FirestoreConstants.Collections.users).document(contactId)
                    let contactDoc = try await contactRef.getDocument()

                    guard let contactUserData = contactDoc.data() else { continue }

                    // Extract basic user info
                    let name = contactUserData[FirestoreConstants.UserFields.name] as? String ?? "Unknown"
                    let lastCheckedIn = (contactUserData[FirestoreConstants.UserFields.lastCheckedIn] as? Timestamp)?.dateValue() ?? Date()
                    let checkInInterval = contactUserData[FirestoreConstants.UserFields.checkInInterval] as? TimeInterval ?? TimeManager.defaultInterval
                    let manualAlertActive = contactUserData[FirestoreConstants.UserFields.manualAlertActive] as? Bool ?? false
                    let manualAlertTimestamp = (contactUserData[FirestoreConstants.UserFields.manualAlertTimestamp] as? Timestamp)?.dateValue()

                    // Extract relationship data
                    let isResponder = contactData[FirestoreConstants.ContactFields.isResponder] as? Bool ?? false
                    let isDependent = contactData[FirestoreConstants.ContactFields.isDependent] as? Bool ?? false
                    let hasIncomingPing = contactData[FirestoreConstants.ContactFields.hasIncomingPing] as? Bool ?? false
                    let hasOutgoingPing = contactData[FirestoreConstants.ContactFields.hasOutgoingPing] as? Bool ?? false
                    let incomingPingTimestamp = (contactData[FirestoreConstants.ContactFields.incomingPingTimestamp] as? Timestamp)?.dateValue()
                    let outgoingPingTimestamp = (contactData[FirestoreConstants.ContactFields.outgoingPingTimestamp] as? Timestamp)?.dateValue()

                    // Create contact
                    let contact = Contact(
                        id: contactId,
                        name: name,
                        isResponder: isResponder,
                        isDependent: isDependent,
                        lastCheckedIn: lastCheckedIn,
                        checkInInterval: checkInInterval,
                        hasIncomingPing: hasIncomingPing,
                        hasOutgoingPing: hasOutgoingPing,
                        incomingPingTimestamp: incomingPingTimestamp,
                        outgoingPingTimestamp: outgoingPingTimestamp,
                        manualAlertActive: manualAlertActive,
                        manualAlertTimestamp: manualAlertTimestamp
                    )

                    contacts.append(contact)
                }

                return contacts
            },

            addContact: { contact in
                guard let userId = AuthenticationService.shared.getCurrentUserID() else {
                    throw NSError(domain: "ContactsClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

                // Call the Firebase function to add the contact
                let functions = Functions.functions()
                let data: [String: Any] = [
                    "contactId": contact.id,
                    "isResponder": contact.isResponder,
                    "isDependent": contact.isDependent
                ]

                let _ = try await functions.httpsCallable("addContactRelation").call(data)
                return true
            },

            updateContactRoles: { id, isResponder, isDependent in
                guard let userId = AuthenticationService.shared.getCurrentUserID() else {
                    throw NSError(domain: "ContactsClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

                // Call the Firebase function to update the contact roles
                let functions = Functions.functions()
                let data: [String: Any] = [
                    "contactId": id,
                    "isResponder": isResponder,
                    "isDependent": isDependent
                ]

                let _ = try await functions.httpsCallable("updateContactRoles").call(data)
                return true
            },

            deleteContact: { id in
                guard let userId = AuthenticationService.shared.getCurrentUserID() else {
                    throw NSError(domain: "ContactsClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

                // Call the Firebase function to delete the contact
                let functions = Functions.functions()
                let data: [String: Any] = [
                    "contactId": id
                ]

                let _ = try await functions.httpsCallable("deleteContactRelation").call(data)
                return true
            },

            pingDependent: { id in
                guard let userId = AuthenticationService.shared.getCurrentUserID() else {
                    throw NSError(domain: "ContactsClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

                // Call the Firebase function to ping the dependent
                let functions = Functions.functions()
                let data: [String: Any] = [
                    "dependentId": id
                ]

                let _ = try await functions.httpsCallable("pingDependent").call(data)
                return true
            },

            clearPing: { id in
                guard let userId = AuthenticationService.shared.getCurrentUserID() else {
                    throw NSError(domain: "ContactsClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

                // Call the Firebase function to clear the ping
                let functions = Functions.functions()
                let data: [String: Any] = [
                    "dependentId": id
                ]

                let _ = try await functions.httpsCallable("clearPing").call(data)
                return true
            },

            respondToPing: { id in
                guard let userId = AuthenticationService.shared.getCurrentUserID() else {
                    throw NSError(domain: "ContactsClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

                // Call the Firebase function to respond to the ping
                let functions = Functions.functions()
                let data: [String: Any] = [
                    "responderId": id
                ]

                let _ = try await functions.httpsCallable("respondToPing").call(data)
                return true
            },

            respondToAllPings: {
                guard let userId = AuthenticationService.shared.getCurrentUserID() else {
                    throw NSError(domain: "ContactsClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

                // Call the Firebase function to respond to all pings
                let functions = Functions.functions()
                let _ = try await functions.httpsCallable("respondToAllPings").call()
                return true
            },

            lookupUserByQRCode: { code in
                guard let userId = AuthenticationService.shared.getCurrentUserID() else {
                    throw NSError(domain: "ContactsClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

                // Check if the code is a valid Firestore document ID
                let db = Firestore.firestore()
                let userRef = db.collection(FirestoreConstants.Collections.users).document(code)

                let document = try await userRef.getDocument()

                guard let data = document.data(), document.exists else {
                    return nil
                }

                // Extract user info
                let name = data[FirestoreConstants.UserFields.name] as? String ?? "Unknown"

                // Create a contact
                return Contact(
                    id: code,
                    name: name,
                    isResponder: false,
                    isDependent: false,
                    lastCheckedIn: Date(),
                    checkInInterval: TimeManager.defaultInterval,
                    hasIncomingPing: false,
                    hasOutgoingPing: false,
                    incomingPingTimestamp: nil,
                    outgoingPingTimestamp: nil,
                    manualAlertActive: false,
                    manualAlertTimestamp: nil
                )
            }
        )
    }

    /// Test implementation of the contacts client
    static var testValue: Self {
        return Self(
            loadContacts: {
                return [
                    Contact.createDefault(name: "Test Responder", isResponder: true),
                    Contact.createDefault(name: "Test Dependent", isDependent: true)
                ]
            },

            addContact: { _ in
                return true
            },

            updateContactRoles: { _, _, _ in
                return true
            },

            deleteContact: { _ in
                return true
            },

            pingDependent: { _ in
                return true
            },

            clearPing: { _ in
                return true
            },

            respondToPing: { _ in
                return true
            },

            respondToAllPings: {
                return true
            },

            lookupUserByQRCode: { code in
                return Contact.createDefault(name: "User \(code)")
            }
        )
    }
}

extension DependencyValues {
    var contactsClient: ContactsClient {
        get { self[ContactsClient.self] }
        set { self[ContactsClient.self] = newValue }
    }
}
