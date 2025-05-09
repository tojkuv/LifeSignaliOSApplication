import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Extension containing Firestore-specific functionality for ContactsViewModel
///
/// This extension separates the Firestore integration code from the main ContactsViewModel
/// to improve code organization and maintainability. It contains methods for:
/// - Loading contacts from Firestore
/// - Processing contact data from Firestore documents
/// - Refreshing contacts from Firestore
///
/// These methods handle the data synchronization between the local view model
/// and the remote Firestore database.
// MARK: - Firestore Integration
extension ContactsViewModel {

    /// Process contacts from an array in the user document
    ///
    /// This method processes an array of contact data from a Firestore document and
    /// converts it into ContactReference objects. For each contact in the array, it:
    /// 1. Extracts the reference path to the contact's user document
    /// 2. Fetches the contact's user document to get their name, phone, etc.
    /// 3. Creates a ContactReference object with the combined data
    /// 4. Adds the ContactReference to the contacts array and contactsById dictionary
    ///
    /// - Parameters:
    ///   - contactsArray: Array of contact data from Firestore, typically from the
    ///     "contacts" field in the user document
    ///   - completion: Callback that is called when processing completes.
    ///     The boolean parameter indicates success (true) or failure (false).
    ///
    /// - Note: This method uses a DispatchGroup to handle the asynchronous fetching
    ///   of multiple contact documents in parallel.
    /// - Note: After processing, this method updates the nonResponsiveDependentsCount
    ///   and pendingPingsCount properties based on the loaded contacts.
    func processContactsFromArray(_ contactsArray: [[String: Any]], completion: @escaping (Bool) -> Void) {
        print("ContactsViewModel: Processing \(contactsArray.count) contacts from array")

        let db = Firestore.firestore()
        var loadedContacts: [ContactReference] = []
        let group = DispatchGroup()

        for contactData in contactsArray {
            // Create a ContactReference from the Firestore data
            guard let contactRef = ContactReference.fromFirestore(contactData) else {
                print("ContactsViewModel: ERROR - Could not create ContactReference from data")
                continue
            }

            // Extract the user ID from the reference path
            guard let contactUserId = contactRef.userId else {
                print("ContactsViewModel: ERROR - Invalid referencePath format: \(contactRef.referencePath)")
                continue
            }

            // Fetch the user document to get the name, phone, etc.
            group.enter()
            db.collection(FirestoreCollections.users).document(contactUserId).getDocument { document, error in
                defer { group.leave() }

                if let error = error {
                    print("ContactsViewModel: ERROR - Failed to fetch user document: \(error.localizedDescription)")
                    return
                }

                guard let document = document, document.exists, let userData = document.data() else {
                    print("ContactsViewModel: ERROR - User document not found for ID: \(contactUserId)")
                    return
                }

                // Extract user data
                let name = userData[UserFields.name] as? String ?? "Unknown User"
                let phone = userData[UserFields.phoneNumber] as? String ?? ""
                let note = userData[UserFields.note] as? String ?? ""
                let qrCodeId = userData[UserFields.qrCodeId] as? String

                // Add user data to the contact reference
                var updatedContactRef = contactRef
                updatedContactRef.name = name
                updatedContactRef.phone = phone
                updatedContactRef.note = note
                updatedContactRef.qrCodeId = qrCodeId

                // Add check-in data if available
                if let lastCheckIn = userData[UserFields.lastCheckedIn] as? Timestamp {
                    updatedContactRef.lastCheckIn = lastCheckIn.dateValue()
                }

                if let interval = userData[UserFields.checkInInterval] as? TimeInterval {
                    updatedContactRef.interval = interval
                }

                // Add alert status if available
                if let manualAlertActive = userData[UserFields.manualAlertActive] as? Bool {
                    updatedContactRef.manualAlertActive = manualAlertActive
                }

                if let manualAlertTimestamp = userData[UserFields.manualAlertTimestamp] as? Timestamp {
                    updatedContactRef.manualAlertTimestamp = manualAlertTimestamp.dateValue()
                }

                // Add ping status if available
                // Note: These fields would need to be added to UserFields if they don't exist
                if let hasIncomingPing = userData["hasIncomingPing"] as? Bool {
                    updatedContactRef.hasIncomingPing = hasIncomingPing
                }

                if let hasOutgoingPing = userData["hasOutgoingPing"] as? Bool {
                    updatedContactRef.hasOutgoingPing = hasOutgoingPing
                }

                if let incomingPingTimestamp = userData["incomingPingTimestamp"] as? Timestamp {
                    updatedContactRef.incomingPingTimestamp = incomingPingTimestamp.dateValue()
                }

                if let outgoingPingTimestamp = userData["outgoingPingTimestamp"] as? Timestamp {
                    updatedContactRef.outgoingPingTimestamp = outgoingPingTimestamp.dateValue()
                }

                // Add to our local array
                loadedContacts.append(updatedContactRef)
            }
        }

        // Wait for all fetches to complete
        group.notify(queue: .main) { [weak self] in
            guard let self = self else {
                completion(false)
                return
            }

            print("ContactsViewModel: Finished processing contacts array, loaded \(loadedContacts.count) contacts")

            // Update the contacts array
            self.contacts = loadedContacts

            // Update the contacts dictionary
            self.contactsById = Dictionary(uniqueKeysWithValues: loadedContacts.map { ($0.id, $0) })

            // Update counts
            let nonResponsiveCount = self.contacts.filter { contact in
                guard contact.isDependent else { return false }
                if contact.manualAlertActive { return true }
                return contact.isNonResponsive
            }.count

            let pendingCount = self.contacts.filter { $0.isResponder && $0.hasIncomingPing }.count

            self.nonResponsiveDependentsCount = nonResponsiveCount
            self.pendingPingsCount = pendingCount

            // Clear any previous errors
            self.contactError = nil
            self.isLoadingContacts = false

            // Post notifications to refresh the UI
            self.postUIRefreshNotifications()

            print("ContactsViewModel: Contacts loaded - Responders: \(self.responders.count), Dependents: \(self.dependents.count)")

            completion(true)
        }
    }

    /// Load contacts from Firestore
    ///
    /// This method retrieves the user's contacts from Firestore and updates the view model.
    /// It first sets the loading state to true, then fetches the user document from Firestore.
    /// If the user document contains a contacts array, it processes that array to create
    /// Contact objects. If no contacts are found, it sets an empty contacts array.
    ///
    /// - Parameter completion: Optional callback that is called when loading completes.
    ///   The boolean parameter indicates success (true) or failure (false).
    ///
    /// - Note: This method is automatically called during initialization if a user is authenticated.
    /// - Note: This method sets isLoadingContacts to true at the start and false when complete.
    /// - Note: If an error occurs, it sets the contactError property with the error details.
    /// - Important: This method requires an authenticated user and will fail if no user is signed in.
    func loadContactsFromFirestore(completion: ((Bool) -> Void)? = nil) {
        print("ContactsViewModel: Starting to load contacts from Firestore")

        // Set loading state
        DispatchQueue.main.async {
            self.isLoadingContacts = true
            self.contactError = nil
        }

        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            let error = NSError(domain: "ContactsViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
            DispatchQueue.main.async {
                self.contactError = error
                self.isLoadingContacts = false
            }
            print("ContactsViewModel: ERROR - Cannot load contacts: No authenticated user")
            completion?(false)
            return
        }

        print("ContactsViewModel: Loading contacts for user ID: \(userId)")

        // Get reference to the user document
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreCollections.users).document(userId)

        // First, check if contacts are stored directly in the user document as an array
        userRef.getDocument { [weak self] document, error in
            guard let self = self else {
                print("ContactsViewModel: ERROR - Self is nil in loadContactsFromFirestore completion")
                return
            }

            if let error = error {
                print("ContactsViewModel: ERROR - Failed to load user document: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.contactError = error
                    self.isLoadingContacts = false
                }
                completion?(false)
                return
            }

            guard let document = document, document.exists, let userData = document.data() else {
                let error = NSError(domain: "ContactsViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "User document not found"])
                print("ContactsViewModel: ERROR - User document not found")
                DispatchQueue.main.async {
                    self.contactError = error
                    self.isLoadingContacts = false
                }
                completion?(false)
                return
            }

            // Check if the user document has a contacts array field
            if let contactsArray = userData["contacts"] as? [[String: Any]], !contactsArray.isEmpty {
                print("ContactsViewModel: Found \(contactsArray.count) contacts in user document")

                // Process contacts from the array
                self.processContactsFromArray(contactsArray) { success in
                    completion?(success)
                }
                return
            }

            print("ContactsViewModel: No contacts found in user document")

            // If we get here, we didn't find contacts
            // Return an empty array but consider it a success
            DispatchQueue.main.async {
                self.contacts = []
                self.contactsById = [:]
                self.nonResponsiveDependentsCount = 0
                self.pendingPingsCount = 0
                self.isLoadingContacts = false
                print("ContactsViewModel: Using empty contacts array")
                completion?(true)
            }
        }
    }

    /// Force reload contacts from Firestore and refresh the UI
    ///
    /// This method provides a way to explicitly refresh the contacts data from Firestore.
    /// It's useful when the app needs to ensure it has the most up-to-date contact information,
    /// such as after adding or removing a contact, or when the user manually refreshes the UI.
    ///
    /// - Parameter completion: Optional callback that is called when reloading completes.
    ///   The boolean parameter indicates success (true) or failure (false).
    ///
    /// - Note: This method calls loadContactsFromFirestore and then posts UI refresh notifications
    ///   to ensure all views displaying contact data are updated.
    /// - Note: This method logs detailed debug information about the contacts that were loaded.
    func forceReloadContacts(completion: ((Bool) -> Void)? = nil) {
        print("ContactsViewModel: Force reloading contacts from Firestore")

        loadContactsFromFirestore { [weak self] success in
            guard let self = self else {
                completion?(false)
                return
            }

            print("ContactsViewModel: Force reload completed with success: \(success)")
            print("ContactsViewModel: Contacts loaded - Total: \(self.contacts.count), Responders: \(self.responders.count), Dependents: \(self.dependents.count)")

            // Force refresh the UI
            self.postUIRefreshNotifications()

            completion?(success)
        }
    }
}
