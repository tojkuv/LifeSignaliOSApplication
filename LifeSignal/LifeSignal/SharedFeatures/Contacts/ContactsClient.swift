import Foundation
import ComposableArchitecture
import FirebaseFirestore

/// Client for interacting with contacts functionality
struct ContactsClient: Sendable {
    // MARK: - Data Operations

    /// Load contacts from Firestore
    var loadContacts: @Sendable () async throws -> [Contact]

    /// Stream contacts for real-time updates
    var streamContacts: @Sendable () -> AsyncStream<[Contact]>

    // MARK: - Contact Management

    /// Add a contact
    var addContact: @Sendable (_ contact: Contact) async throws -> Bool

    /// Update a contact's roles
    var updateContactRoles: @Sendable (_ id: String, _ isResponder: Bool, _ isDependent: Bool) async throws -> Bool

    /// Delete a contact
    var deleteContact: @Sendable (_ id: String) async throws -> Bool

    // MARK: - Ping Operations

    /// Ping a dependent
    var pingDependent: @Sendable (_ id: String) async throws -> Bool

    /// Clear a ping for a dependent
    var clearPing: @Sendable (_ id: String) async throws -> Bool

    /// Respond to a ping
    var respondToPing: @Sendable (_ id: String) async throws -> Bool

    /// Respond to all pings
    var respondToAllPings: @Sendable () async throws -> Bool

    // MARK: - User Lookup

    /// Look up a user by QR code
    var lookupUserByQRCode: @Sendable (_ code: String) async throws -> Contact?
}

extension ContactsClient: DependencyKey {
    /// Live implementation of the contacts client
    static var liveValue: Self {
        @Dependency(\.authClient) var authClient
        @Dependency(\.firebaseClient) var firebaseClient

        return Self(
            loadContacts: {
                guard let userId = await authClient.getCurrentUserId() else {
                    throw NSError(domain: "ContactsClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

                // Get the user document to access contacts
                let userData = try await firebaseClient.getDocument(
                    collection: FirestoreConstants.Collections.users,
                    documentId: userId
                )

                // Extract contacts array (array of maps containing relationship data)
                guard let contactsData = userData[FirestoreConstants.UserFields.contacts] as? [[String: Any]] else {
                    return []
                }

                return try await processContactsData(contactsData, firebaseClient: firebaseClient)
            },

            streamContacts: {
                // Create an AsyncStream that monitors the user's contacts
                return AsyncStream { continuation in
                    Task {
                        do {
                            guard let userId = await authClient.getCurrentUserId() else {
                                throw NSError(domain: "ContactsClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                            }

                            // Get the initial contacts data
                            let initialContacts = try await ContactsClient.liveValue.loadContacts()

                            // Yield the initial data
                            continuation.yield(initialContacts)

                            // Start monitoring for changes
                            let stream = firebaseClient.monitorUserContacts(userId: userId, includeMetadata: false)

                            for await contactSnapshots in stream {
                                // Process the contact snapshots
                                var contacts: [Contact] = []

                                // Get the user document to access contacts relationship data
                                let userData = try await firebaseClient.getDocument(
                                    collection: FirestoreConstants.Collections.users,
                                    documentId: userId
                                )

                                // Extract contacts array (array of maps containing relationship data)
                                guard let contactsData = userData[FirestoreConstants.UserFields.contacts] as? [[String: Any]] else {
                                    continuation.yield([])
                                    continue
                                }

                                // Create a dictionary of contact data by ID for quick lookup
                                var contactDataById: [String: [String: Any]] = [:]
                                for contactData in contactsData {
                                    guard let referencePath = contactData[FirestoreConstants.ContactFields.referencePath] as? String else { continue }
                                    let components = referencePath.components(separatedBy: "/")
                                    guard components.count == 2 && components[0] == "users" else { continue }
                                    let contactId = components[1]
                                    contactDataById[contactId] = contactData
                                }

                                // Process each contact snapshot
                                for snapshot in contactSnapshots {
                                    let contactId = snapshot.documentID

                                    // Skip if we don't have relationship data for this contact
                                    guard let contactData = contactDataById[contactId] else { continue }

                                    // Extract basic user info from the snapshot
                                    guard let contactUserData = snapshot.data() else { continue }

                                    // Create contact from the data
                                    if let contact = createContact(from: contactData, userData: contactUserData, contactId: contactId) {
                                        contacts.append(contact)
                                    }
                                }

                                // Yield the updated contacts
                                continuation.yield(contacts)
                            }
                        } catch {
                            print("Error in streamContacts: \(error.localizedDescription)")
                            // We don't finish the stream on error, just log it
                        }
                    }
                }
            },

            addContact: { contact in
                guard await authClient.getCurrentUserId() != nil else {
                    throw NSError(domain: "ContactsClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

                // Call the Firebase function to add the contact
                let data: [String: Any] = [
                    "contactId": contact.id,
                    "isResponder": contact.isResponder,
                    "isDependent": contact.isDependent
                ]

                let _ = try await firebaseClient.callFunction(name: "addContactRelation", data: data)
                return true
            },

            updateContactRoles: { id, isResponder, isDependent in
                guard await authClient.getCurrentUserId() != nil else {
                    throw NSError(domain: "ContactsClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

                // Call the Firebase function to update the contact roles
                let data: [String: Any] = [
                    "contactId": id,
                    "isResponder": isResponder,
                    "isDependent": isDependent
                ]

                let _ = try await firebaseClient.callFunction(name: "updateContactRoles", data: data)
                return true
            },

            deleteContact: { id in
                guard await authClient.getCurrentUserId() != nil else {
                    throw NSError(domain: "ContactsClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

                // Call the Firebase function to delete the contact
                let data: [String: Any] = [
                    "contactId": id
                ]

                let _ = try await firebaseClient.callFunction(name: "deleteContactRelation", data: data)
                return true
            },

            pingDependent: { id in
                guard await authClient.getCurrentUserId() != nil else {
                    throw NSError(domain: "ContactsClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

                // Call the Firebase function to ping the dependent
                let data: [String: Any] = [
                    "dependentId": id
                ]

                let _ = try await firebaseClient.callFunction(name: "pingDependent", data: data)
                return true
            },

            clearPing: { id in
                guard await authClient.getCurrentUserId() != nil else {
                    throw NSError(domain: "ContactsClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

                // Call the Firebase function to clear the ping
                let data: [String: Any] = [
                    "dependentId": id
                ]

                let _ = try await firebaseClient.callFunction(name: "clearPing", data: data)
                return true
            },

            respondToPing: { id in
                guard await authClient.getCurrentUserId() != nil else {
                    throw NSError(domain: "ContactsClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

                // Call the Firebase function to respond to the ping
                let data: [String: Any] = [
                    "responderId": id
                ]

                let _ = try await firebaseClient.callFunction(name: "respondToPing", data: data)
                return true
            },

            respondToAllPings: {
                guard await authClient.getCurrentUserId() != nil else {
                    throw NSError(domain: "ContactsClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

                // Call the Firebase function to respond to all pings
                let _ = try await firebaseClient.callFunction(name: "respondToAllPings", data: nil)
                return true
            },

            lookupUserByQRCode: { code in
                guard await authClient.getCurrentUserId() != nil else {
                    throw NSError(domain: "ContactsClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

                // Check if the code is a valid Firestore document ID
                do {
                    let data = try await firebaseClient.getDocument(
                        collection: FirestoreConstants.Collections.users,
                        documentId: code
                    )

                    // Extract user info
                    let name = data[FirestoreConstants.UserFields.name] as? String ?? "Unknown"

                    // Create a contact
                    return Contact(
                        id: code,
                        name: name,
                        isResponder: false,
                        isDependent: false,
                        phoneNumber: data[FirestoreConstants.UserFields.phoneNumber] as? String ?? "",
                        phoneRegion: data[FirestoreConstants.UserFields.phoneRegion] as? String ?? "US",
                        note: data[FirestoreConstants.UserFields.note] as? String ?? "",
                        lastCheckedIn: (data[FirestoreConstants.UserFields.lastCheckedIn] as? Timestamp)?.dateValue() ?? Date(),
                        checkInInterval: data[FirestoreConstants.UserFields.checkInInterval] as? TimeInterval ?? TimeManager.defaultInterval,
                        hasIncomingPing: false,
                        hasOutgoingPing: false,
                        incomingPingTimestamp: nil,
                        outgoingPingTimestamp: nil,
                        manualAlertActive: false,
                        manualAlertTimestamp: nil,
                        qrCodeId: data[FirestoreConstants.UserFields.qrCodeId] as? String
                    )
                } catch {
                    return nil
                }
            }
        )
    }

    /// Test implementation of the contacts client
    static var testValue: Self {
        let testContacts = [
            Contact.createDefault(name: "Test Responder", isResponder: true),
            Contact.createDefault(name: "Test Dependent", isDependent: true)
        ]

        return Self(
            loadContacts: {
                return testContacts
            },

            streamContacts: {
                return AsyncStream { continuation in
                    // Yield the initial data
                    continuation.yield(testContacts)

                    // Simulate periodic updates if needed
                    let timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                        // Create updated contacts with current timestamp
                        var updatedContacts = testContacts
                        for i in 0..<updatedContacts.count {
                            updatedContacts[i].lastCheckedIn = Date()
                        }
                        continuation.yield(updatedContacts)
                    }

                    continuation.onTermination = { _ in
                        timer.invalidate()
                    }
                }
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

/// Helper function to process contacts data from Firestore
private func processContactsData(_ contactsData: [[String: Any]], firebaseClient: FirebaseClient) async throws -> [Contact] {
    // Process each contact
    var contacts: [Contact] = []

    for contactData in contactsData {
        // Extract the contact ID from the reference path
        guard let referencePath = contactData[FirestoreConstants.ContactFields.referencePath] as? String else { continue }
        let components = referencePath.components(separatedBy: "/")
        guard components.count == 2 && components[0] == "users" else { continue }
        let contactId = components[1]

        // Get the contact's user document
        let contactUserData = try await firebaseClient.getDocument(
            collection: FirestoreConstants.Collections.users,
            documentId: contactId
        )

        // Create contact from the data
        if let contact = createContact(from: contactData, userData: contactUserData, contactId: contactId) {
            contacts.append(contact)
        }
    }

    return contacts
}

/// Helper function to create a Contact from Firestore data
private func createContact(from contactData: [String: Any], userData: [String: Any], contactId: String) -> Contact? {
    // Extract basic user info
    let name = userData[FirestoreConstants.UserFields.name] as? String ?? "Unknown"
    let lastCheckedIn = (userData[FirestoreConstants.UserFields.lastCheckedIn] as? Timestamp)?.dateValue() ?? Date()
    let checkInInterval = userData[FirestoreConstants.UserFields.checkInInterval] as? TimeInterval ?? TimeManager.defaultInterval
    let manualAlertActive = userData[FirestoreConstants.UserFields.manualAlertActive] as? Bool ?? false
    let manualAlertTimestamp = (userData[FirestoreConstants.UserFields.manualAlertTimestamp] as? Timestamp)?.dateValue()

    // Extract relationship data
    let isResponder = contactData[FirestoreConstants.ContactFields.isResponder] as? Bool ?? false
    let isDependent = contactData[FirestoreConstants.ContactFields.isDependent] as? Bool ?? false
    let hasIncomingPing = contactData[FirestoreConstants.ContactFields.hasIncomingPing] as? Bool ?? false
    let hasOutgoingPing = contactData[FirestoreConstants.ContactFields.hasOutgoingPing] as? Bool ?? false
    let incomingPingTimestamp = (contactData[FirestoreConstants.ContactFields.incomingPingTimestamp] as? Timestamp)?.dateValue()
    let outgoingPingTimestamp = (contactData[FirestoreConstants.ContactFields.outgoingPingTimestamp] as? Timestamp)?.dateValue()

    // Create contact
    return Contact(
        id: contactId,
        name: name,
        isResponder: isResponder,
        isDependent: isDependent,
        phoneNumber: userData[FirestoreConstants.UserFields.phoneNumber] as? String ?? "",
        phoneRegion: userData[FirestoreConstants.UserFields.phoneRegion] as? String ?? "US",
        note: userData[FirestoreConstants.UserFields.note] as? String ?? "",
        lastCheckedIn: lastCheckedIn,
        checkInInterval: checkInInterval,
        hasIncomingPing: hasIncomingPing,
        hasOutgoingPing: hasOutgoingPing,
        incomingPingTimestamp: incomingPingTimestamp,
        outgoingPingTimestamp: outgoingPingTimestamp,
        manualAlertActive: manualAlertActive,
        manualAlertTimestamp: manualAlertTimestamp,
        sendPings: contactData[FirestoreConstants.ContactFields.sendPings] as? Bool ?? true,
        receivePings: contactData[FirestoreConstants.ContactFields.receivePings] as? Bool ?? true,
        nickname: contactData[FirestoreConstants.ContactFields.nickname] as? String,
        notes: contactData[FirestoreConstants.ContactFields.notes] as? String,
        qrCodeId: userData[FirestoreConstants.UserFields.qrCodeId] as? String
    )
}

/// Helper function to compare two values for equality
private func areEqual(_ a: Any?, _ b: Any?) -> Bool {
    // Handle nil cases
    if a == nil && b == nil { return true }
    if a == nil || b == nil { return false }

    // Handle different types
    switch (a, b) {
    case let (a as String, b as String):
        return a == b
    case let (a as Int, b as Int):
        return a == b
    case let (a as Double, b as Double):
        return a == b
    case let (a as Bool, b as Bool):
        return a == b
    case let (a as TimeInterval, b as TimeInterval):
        return a == b
    case let (a as Timestamp, b as Timestamp):
        return a.seconds == b.seconds && a.nanoseconds == b.nanoseconds
    case let (a as Date, b as Date):
        return a.timeIntervalSince1970 == b.timeIntervalSince1970
    case let (a as [String: Any], b as [String: Any]):
        return NSDictionary(dictionary: a).isEqual(to: b)
    case let (a as [Any], b as [Any]):
        return NSArray(array: a).isEqual(to: b)
    default:
        // For other types, use string representation
        return "\(a)" == "\(b)"
    }
}

extension DependencyValues {
    var contactsClient: ContactsClient {
        get { self[ContactsClient.self] }
        set { self[ContactsClient.self] = newValue }
    }
}
