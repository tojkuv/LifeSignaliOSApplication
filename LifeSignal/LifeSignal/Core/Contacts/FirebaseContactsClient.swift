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
    var streamContacts: @Sendable (String) -> AsyncStream<[ContactData]>

    /// Get contacts collection once
    var getContacts: @Sendable (String) async throws -> [ContactData]

    /// Add a new contact
    var addContact: @Sendable (String, String, [String: Any]) async throws -> Void

    /// Update a contact
    var updateContact: @Sendable (String, String, [String: Any]) async throws -> Void

    /// Delete a contact
    var deleteContact: @Sendable (String, String) async throws -> Void

    /// Look up a user by QR code
    var lookupUserByQRCode: @Sendable (String) async throws -> (id: String, name: String, phone: String, emergencyNote: String)

    /// Add a contact relation using Firebase Functions
    var addContactRelation: @Sendable (String, String, Bool, Bool) async throws -> Void
}

// MARK: - Live Implementation

extension FirebaseContactsClient: DependencyKey {
    static let liveValue = Self(
        streamContacts: { userId in
            FirebaseLogger.contacts.debug("Starting contacts stream for user: \(userId)")

            // Create a new AsyncStream that transforms the TaskResult stream into a ContactData stream
            return AsyncStream<[ContactData]> { continuation in
                // Create a task to handle the stream
                let task = Task {
                    do {
                        // Get the original stream with TaskResult
                        let taskResultStream = FirestoreStreamHelper.collectionStream(
                            path: "\(FirestoreConstants.Collections.users)/\(userId)/\(FirestoreConstants.Collections.contacts)",
                            logger: FirebaseLogger.contacts
                        ) { snapshot in
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

                        // Process the TaskResult stream
                        for await result in taskResultStream {
                            switch result {
                            case .success(let contactsData):
                                continuation.yield(contactsData)
                            case .failure(let error):
                                FirebaseLogger.contacts.error("Error in contacts stream: \(error.localizedDescription)")
                                // Map the error to a UserFacingError for better handling
                                let userFacingError = UserFacingError.from(error)
                                FirebaseLogger.contacts.debug("Mapped to user facing error: \(userFacingError)")
                                // We don't propagate errors in the stream, just log them
                                // This makes the stream more resilient and easier to use
                                continue
                            }
                        }

                        // If we get here, the stream has ended
                        continuation.finish()
                    } catch {
                        FirebaseLogger.contacts.error("Fatal error in contacts stream: \(error.localizedDescription)")
                        continuation.finish()
                    }
                }

                // Set up cancellation
                continuation.onTermination = { _ in
                    task.cancel()
                }
            }
        },

        getContacts: { userId in
            FirebaseLogger.contacts.debug("Getting contacts for user: \(userId)")
            do {
                let db = Firestore.firestore()
                let contactsPath = "\(FirestoreConstants.Collections.users)/\(userId)/\(FirestoreConstants.Collections.contacts)"
                let collectionRef = db.collection(contactsPath)
                let querySnapshot = try await collectionRef.getDocuments()
                let contactsSnapshot = querySnapshot.documents

                FirebaseLogger.contacts.debug("Retrieved \(contactsSnapshot.count) contact documents")

                var contacts: [ContactData] = []

                // Process each contact document
                for contactDoc in contactsSnapshot {
                    let contactId = contactDoc.documentID
                    let contactData = contactDoc.data()

                    // Get the contact's user document
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
            do {
                let db = Firestore.firestore()
                let contactPath = "\(FirestoreConstants.Collections.users)/\(userId)/\(FirestoreConstants.Collections.contacts)/\(contactId)"
                try await db.document(contactPath).setData(contactData)
                FirebaseLogger.contacts.info("Added contact \(contactId) for user: \(userId)")
            } catch {
                FirebaseLogger.contacts.error("Failed to add contact: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        updateContact: { userId, contactId, fields in
            FirebaseLogger.contacts.debug("Updating contact \(contactId) for user: \(userId)")
            do {
                // Add last updated timestamp
                var fieldsToUpdate = fields
                fieldsToUpdate[FirestoreConstants.ContactFields.lastUpdated] = Timestamp(date: Date())

                let db = Firestore.firestore()
                let contactPath = "\(FirestoreConstants.Collections.users)/\(userId)/\(FirestoreConstants.Collections.contacts)/\(contactId)"
                try await db.document(contactPath).updateData(fieldsToUpdate)
                FirebaseLogger.contacts.info("Updated contact \(contactId) for user: \(userId)")
            } catch {
                FirebaseLogger.contacts.error("Failed to update contact: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        deleteContact: { userId, contactId in
            FirebaseLogger.contacts.debug("Deleting contact \(contactId) for user: \(userId)")
            do {
                let db = Firestore.firestore()
                let contactPath = "\(FirestoreConstants.Collections.users)/\(userId)/\(FirestoreConstants.Collections.contacts)/\(contactId)"
                try await db.document(contactPath).delete()
                FirebaseLogger.contacts.info("Deleted contact \(contactId) for user: \(userId)")
            } catch {
                FirebaseLogger.contacts.error("Failed to delete contact: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        lookupUserByQRCode: { qrCode in
            FirebaseLogger.contacts.debug("Looking up user by QR code")
            do {
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
            } catch {
                FirebaseLogger.contacts.error("Failed to lookup user by QR code: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
        },

        addContactRelation: { userId, contactId, isResponder, isDependent in
            FirebaseLogger.contacts.debug("Adding contact relation between \(userId) and \(contactId)")
            do {
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
            } catch {
                FirebaseLogger.contacts.error("Failed to add contact relation: \(error.localizedDescription)")
                throw FirebaseError.from(error)
            }
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
        lookupUserByQRCode: unimplemented("\(Self.self).lookupUserByQRCode", placeholder: { _ in ("", "", "", "") }),
        addContactRelation: unimplemented("\(Self.self).addContactRelation")
    )

    /// A mock implementation that returns predefined values for testing
    static func mock(
        streamContacts: @escaping (String) -> AsyncStream<[ContactData]> = { _ in
            AsyncStream { continuation in
                continuation.yield([])
                continuation.finish()
            }
        },
        getContacts: @escaping (String) async throws -> [ContactData] = { _ in [] },
        addContact: @escaping (String, String, [String: Any]) async throws -> Void = { _, _, _ in },
        updateContact: @escaping (String, String, [String: Any]) async throws -> Void = { _, _, _ in },
        deleteContact: @escaping (String, String) async throws -> Void = { _, _ in },
        lookupUserByQRCode: @escaping (String) async throws -> (id: String, name: String, phone: String, emergencyNote: String) = { _ in
            ("", "", "", "")
        },
        addContactRelation: @escaping (String, String, Bool, Bool) async throws -> Void = { _, _, _, _ in }
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
