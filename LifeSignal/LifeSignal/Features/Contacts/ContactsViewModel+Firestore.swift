import Foundation
import FirebaseFirestore

/// Extension to add Firestore operations to the ContactsViewModel
extension ContactsViewModel {
    /// Load contacts from Firestore
    /// - Parameter completion: Optional callback with success flag
    func loadContactsFromFirestore(completion: ((Bool) -> Void)? = nil) {
        guard let userId = validateAuthentication() else {
            completion?(false)
            return
        }

        // Set loading state
        DispatchQueue.main.async {
            self.isLoadingContacts = true
            self.contactError = nil
        }

        // Get the user document from Firestore
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreCollections.users).document(userId)

        userRef.getDocument { [weak self] document, error in
            guard let self = self else { return }

            if let error = error {
                print("Error loading contacts: \(error.localizedDescription)")

                DispatchQueue.main.async {
                    self.contactError = error
                    self.isLoadingContacts = false
                }

                completion?(false)
                return
            }

            guard let document = document, document.exists else {
                print("User document not found")

                DispatchQueue.main.async {
                    self.contactError = NSError(domain: "ContactsViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "User document not found"])
                    self.isLoadingContacts = false
                }

                completion?(false)
                return
            }

            // Extract contacts array from the document
            if let contactsArray = document.data()?[User.Fields.contacts] as? [[String: Any]] {
                // Convert to ContactReference objects
                let contacts = contactsArray.compactMap { ContactReference.fromFirestore($0) }

                // Update the contacts array and dictionary
                DispatchQueue.main.async {
                    self.contacts = contacts
                    self.contactsById = Dictionary(uniqueKeysWithValues: contacts.map { ($0.id, $0) })

                    // Update counts
                    self.updateCounts()

                    // Clear loading state
                    self.isLoadingContacts = false
                }

                print("Loaded \(contacts.count) contacts from Firestore")
                completion?(true)
            } else {
                // No contacts found, set empty array
                DispatchQueue.main.async {
                    self.contacts = []
                    self.contactsById = [:]

                    // Update counts
                    self.updateCounts()

                    // Clear loading state
                    self.isLoadingContacts = false
                }

                print("No contacts found in user document")
                completion?(true)
            }
        }
    }

    /// Force reload contacts from Firestore
    /// - Parameter completion: Optional callback with success flag
    func forceReloadContacts(completion: ((Bool) -> Void)? = nil) {
        loadContactsFromFirestore(completion: completion)
    }

    /// Update counts for non-responsive dependents and pending pings
    private func updateCounts() {
        // Count non-responsive dependents
        nonResponsiveDependentsCount = dependents.filter { $0.isNonResponsive || $0.manualAlertActive }.count

        // Count pending pings
        pendingPingsCount = responders.filter { $0.hasIncomingPing }.count
    }

    /// Looks up a user by QR code ID in Firestore
    /// - Parameters:
    ///   - qrCodeId: The QR code ID to look up
    ///   - completion: Callback with user data or error
    func lookupUserByQRCode(_ qrCodeId: String, completion: @escaping ([String: Any]?, Error?) -> Void) {
        guard !qrCodeId.isEmpty else {
            completion(nil, NSError(domain: "ContactsViewModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "QR code ID is empty"]))
            return
        }

        // Look up the user ID from the QR lookup database
        let db = Firestore.firestore()
        let qrLookupRef = db.collection(FirestoreCollections.qrLookup)

        // Query for documents where qrCodeId matches
        qrLookupRef.whereField("qrCodeId", isEqualTo: qrCodeId).getDocuments { snapshot, error in
            if let error = error {
                print("Error looking up QR code in lookup database: \(error.localizedDescription)")
                completion(nil, error)
                return
            }

            guard let snapshot = snapshot, !snapshot.documents.isEmpty else {
                print("No user found with QR code ID: \(qrCodeId)")
                completion(nil, NSError(domain: "ContactsViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "No user found with this QR code"]))
                return
            }

            // Get the user ID from the document ID
            let userId = snapshot.documents[0].documentID

            // Now get only the basic user information needed for display
            let db = Firestore.firestore()
            let userRef = db.collection(FirestoreCollections.users).document(userId)

            userRef.getDocument { document, error in
                if let error = error {
                    print("Error getting user document: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }

                guard let document = document, document.exists else {
                    print("User document not found for ID: \(userId)")
                    completion(nil, NSError(domain: "ContactsViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "User document not found"]))
                    return
                }

                // Only retrieve the minimal fields needed for contact creation
                // This avoids accessing sensitive user data
                let minimalUserData: [String: Any] = [
                    User.Fields.uid: userId,
                    User.Fields.name: document.data()?[User.Fields.name] as? String ?? "Unknown Name",
                    User.Fields.phoneNumber: document.data()?[User.Fields.phoneNumber] as? String ?? "",
                    User.Fields.note: document.data()?[User.Fields.note] as? String ?? "",
                    User.Fields.qrCodeId: qrCodeId // Include the QR code ID for the contact reference
                ]

                // Return the minimal user data
                completion(minimalUserData, nil)
            }
        }
    }
}
