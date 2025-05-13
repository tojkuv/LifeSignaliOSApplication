import Foundation
import ComposableArchitecture
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions
import XCTestDynamicOverlay
import OSLog
import Dependencies
import DependenciesMacros

/// A client for interacting with Firebase contacts data
@DependencyClient
struct FirebaseContactsClient: Sendable {
    /// Stream contacts collection updates
    var streamContacts: @Sendable (String) -> AsyncStream<[ContactData]> = { _ in
        AsyncStream { continuation in
            continuation.yield([])
            continuation.finish()
        }
    }

    /// Get contacts collection once
    var getContacts: @Sendable (String) async throws -> [ContactData] = { _ in
        []
    }

    /// Add a new contact
    var addContact: @Sendable (String, String, [String: Any]) async throws -> Void = { _, _, _ in
        throw FirebaseError.operationFailed
    }

    /// Update a contact
    var updateContact: @Sendable (String, String, [String: Any]) async throws -> Void = { _, _, _ in
        throw FirebaseError.operationFailed
    }

    /// Delete a contact
    var deleteContact: @Sendable (String, String) async throws -> Void = { _, _ in
        throw FirebaseError.operationFailed
    }

    /// Look up a user by QR code
    var lookupUserByQRCode: @Sendable (String) async throws -> (id: String, name: String, phone: String, emergencyNote: String) = { _ in
        throw FirebaseError.operationFailed
    }

    /// Add a contact relation using Firebase Functions
    var addContactRelation: @Sendable (String, String, Bool, Bool) async throws -> Void = { _, _, _, _ in
        throw FirebaseError.operationFailed
    }
}

// MARK: - Live Implementation

extension FirebaseContactsClient: DependencyKey {
    static let liveValue = Self(
        streamContacts: { userId in
            FirebaseLogger.contacts.debug("Starting contacts stream for user: \(userId)")
            let path = "\(FirestoreConstants.Collections.users)/\(userId)/\(FirestoreConstants.Collections.contacts)"

            @Dependency(\.firestoreStorage) var firestoreStorage
            return firestoreStorage.collectionStream(
                path: path,
                transform: { snapshot in
                    FirebaseLogger.contacts.debug("Processing contacts snapshot with \(snapshot.documents.count) documents")
                    var contacts: [ContactData] = []
                    let db = Firestore.firestore()

                    // Process each contact document
                    for contactDoc in snapshot.documents {
                        let contactId = contactDoc.documentID
                        let contactData = contactDoc.data()

                        // Get the contact's user document
                        do {
                            let documentSnapshot = try await db.collection(FirestoreConstants.Collections.users).document(contactId).getDocument()

                            guard documentSnapshot.exists, let contactUserData = documentSnapshot.data() else {
                                FirebaseLogger.contacts.warning("Contact user document not found or empty for ID: \(contactId)")
                                continue
                            }

                            // Create contact from the data
                            if let contact = ContactData.fromFirestore(contactData, id: contactId) {
                                // Update with user data
                                var updatedContact = contact
                                updatedContact.name = contactUserData[FirestoreConstants.UserFields.name] as? String ?? "Unknown User"

                                if let lastCheckedIn = contactUserData[FirestoreConstants.UserFields.lastCheckedIn] as? Timestamp {
                                    updatedContact.lastCheckedIn = lastCheckedIn.dateValue()
                                }

                                if let checkInInterval = contactUserData[FirestoreConstants.UserFields.checkInInterval] as? TimeInterval {
                                    updatedContact.checkInInterval = checkInInterval
                                }

                                contacts.append(updatedContact)
                            }
                        } catch {
                            FirebaseLogger.contacts.error("Error getting contact user document for ID \(contactId): \(error.localizedDescription)")
                            // Continue processing other contacts even if one fails
                        }
                    }

                    FirebaseLogger.contacts.info("Processed \(contacts.count) contacts for user: \(userId)")
                    return contacts
                }
            )
        },

        getContacts: { userId in
            FirebaseLogger.contacts.debug("Getting contacts for user: \(userId)")

            let contactsPath = "\(FirestoreConstants.Collections.users)/\(userId)/\(FirestoreConstants.Collections.contacts)"

            @Dependency(\.firestoreStorage) var firestoreStorage
            do {
                // Get all contacts using FirestoreStorageClient
                let contactDocuments = try await firestoreStorage.getCollection(
                    path: contactsPath,
                    transform: { document in
                        return (id: document.documentID, data: document.data())
                    }
                )

                FirebaseLogger.contacts.debug("Retrieved \(contactDocuments.count) contact documents")

                var contacts: [ContactData] = []

                // Process each contact document
                for (contactId, contactData) in contactDocuments {
                    // Get the contact's user document using FirestoreStorageClient
                    let userPath = "\(FirestoreConstants.Collections.users)/\(contactId)"
                    do {
                        let contactUserData = try await firestoreStorage.getDocument(
                            path: userPath,
                            transform: { snapshot in
                                guard let data = snapshot.data() else {
                                    throw FirebaseError.emptyDocument
                                }
                                return data
                            }
                        )

                        // Create contact from the data
                        if let contact = ContactData.fromFirestore(contactData, id: contactId) {
                            // Update with user data
                            var updatedContact = contact
                            updatedContact.name = contactUserData[FirestoreConstants.UserFields.name] as? String ?? "Unknown User"

                            if let lastCheckedIn = contactUserData[FirestoreConstants.UserFields.lastCheckedIn] as? Timestamp {
                                updatedContact.lastCheckedIn = lastCheckedIn.dateValue()
                            }

                            if let checkInInterval = contactUserData[FirestoreConstants.UserFields.checkInInterval] as? TimeInterval {
                                updatedContact.checkInInterval = checkInInterval
                            }

                            contacts.append(updatedContact)
                        }
                    } catch {
                        FirebaseLogger.contacts.warning("Could not get user data for contact \(contactId): \(error.localizedDescription)")
                        // Continue with next contact
                    }
                }

                FirebaseLogger.contacts.info("Retrieved \(contacts.count) contacts for user: \(userId)")
                return contacts
            } catch {
                FirebaseLogger.contacts.error("Failed to get contacts: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        addContact: { userId, contactId, contactData in
            FirebaseLogger.contacts.debug("Adding contact \(contactId) for user: \(userId)")

            let contactPath = "\(FirestoreConstants.Collections.users)/\(userId)/\(FirestoreConstants.Collections.contacts)/\(contactId)"
            @Dependency(\.firestoreStorage) var firestoreStorage

            try await firestoreStorage.setDocument(
                path: contactPath,
                data: contactData,
                merge: false
            )

            FirebaseLogger.contacts.info("Added contact \(contactId) for user: \(userId)")
        },

        updateContact: { userId, contactId, fields in
            FirebaseLogger.contacts.debug("Updating contact \(contactId) for user: \(userId)")

            // Add last updated timestamp
            var fieldsToUpdate = fields
            fieldsToUpdate[FirestoreConstants.ContactFields.lastUpdated] = Timestamp(date: Date())

            let contactPath = "\(FirestoreConstants.Collections.users)/\(userId)/\(FirestoreConstants.Collections.contacts)/\(contactId)"
            @Dependency(\.firestoreStorage) var firestoreStorage

            try await firestoreStorage.updateDocument(
                path: contactPath,
                data: fieldsToUpdate
            )

            FirebaseLogger.contacts.info("Updated contact \(contactId) for user: \(userId)")
        },

        deleteContact: { userId, contactId in
            FirebaseLogger.contacts.debug("Deleting contact \(contactId) for user: \(userId)")

            let contactPath = "\(FirestoreConstants.Collections.users)/\(userId)/\(FirestoreConstants.Collections.contacts)/\(contactId)"
            @Dependency(\.firestoreStorage) var firestoreStorage

            try await firestoreStorage.deleteDocument(
                path: contactPath
            )

            FirebaseLogger.contacts.info("Deleted contact \(contactId) for user: \(userId)")
        },

        lookupUserByQRCode: { qrCode in
            FirebaseLogger.contacts.debug("Looking up user by QR code")

            let functions = Functions.functions()
            let result = try await functions.httpsCallable("lookupUserByQRCode").call(["qrCodeId": qrCode])

            guard let data = result.data as? [String: Any],
                  let userId = data["userId"] as? String,
                  let name = data["name"] as? String,
                  let phone = data["phoneNumber"] as? String,
                  let emergencyNote = data["emergencyNote"] as? String else {
                FirebaseLogger.contacts.error("Invalid response format from lookupUserByQRCode function")
                throw FirebaseError.invalidResponseFormat
            }

            FirebaseLogger.contacts.info("Found user \(userId) by QR code")
            return (id: userId, name: name, phone: phone, emergencyNote: emergencyNote)
        },

        addContactRelation: { userId, contactId, isResponder, isDependent in
            FirebaseLogger.contacts.debug("Adding contact relation between \(userId) and \(contactId)")

            let functions = Functions.functions()

            // Prepare the data for the Firebase function
            let data: [String: Any] = [
                "userId": userId,
                "contactId": contactId,
                "isResponder": isResponder,
                "isDependent": isDependent
            ]

            // Call the Firebase function
            let result = try await functions.httpsCallable("addContactRelation").call(data)

            // Validate the response
            guard let _ = result.data as? [String: Any] else {
                FirebaseLogger.contacts.error("Invalid response format from addContactRelation function")
                throw FirebaseError.invalidResponseFormat
            }

            FirebaseLogger.contacts.info("Added contact relation between \(userId) and \(contactId)")
        }
    )
}

// MARK: - Test Implementation

extension FirebaseContactsClient: TestDependencyKey {
    /// A test implementation that fails with an unimplemented error
    static let testValue = Self(
        streamContacts: unimplemented("\(Self.self).streamContacts", placeholder: { _ in
            AsyncStream { continuation in
                continuation.yield([])
                continuation.finish()
            }
        }),
        getContacts: unimplemented("\(Self.self).getContacts", placeholder: { _ in [] }),
        addContact: unimplemented("\(Self.self).addContact"),
        updateContact: unimplemented("\(Self.self).updateContact"),
        deleteContact: unimplemented("\(Self.self).deleteContact"),
        lookupUserByQRCode: unimplemented("\(Self.self).lookupUserByQRCode"),
        addContactRelation: unimplemented("\(Self.self).addContactRelation")
    )

    /// A mock implementation that returns predefined values for testing
    static func mock(
        streamContacts: @Sendable @escaping (String) -> AsyncStream<[ContactData]> = { _ in
            AsyncStream { continuation in
                continuation.yield([])
                continuation.finish()
            }
        },
        getContacts: @Sendable @escaping (String) async throws -> [ContactData] = { _ in [] },
        addContact: @Sendable @escaping (String, String, [String: Any]) async throws -> Void = { _, _, _ in },
        updateContact: @Sendable @escaping (String, String, [String: Any]) async throws -> Void = { _, _, _ in },
        deleteContact: @Sendable @escaping (String, String) async throws -> Void = { _, _ in },
        lookupUserByQRCode: @Sendable @escaping (String) async throws -> (id: String, name: String, phone: String, emergencyNote: String) = { _ in
            ("", "", "", "")
        },
        addContactRelation: @Sendable @escaping (String, String, Bool, Bool) async throws -> Void = { _, _, _, _ in }
    ) -> Self {
        Self(
            streamContacts: streamContacts,
            getContacts: getContacts,
            addContact: addContact,
            updateContact: updateContact,
            deleteContact: deleteContact,
            lookupUserByQRCode: lookupUserByQRCode,
            addContactRelation: addContactRelation
        )
    }
}

extension DependencyValues {
    var firebaseContactsClient: FirebaseContactsClient {
        get { self[FirebaseContactsClient.self] }
        set { self[FirebaseContactsClient.self] = newValue }
    }
}
