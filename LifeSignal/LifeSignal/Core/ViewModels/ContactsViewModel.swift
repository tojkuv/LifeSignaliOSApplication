import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

/// ViewModel for managing user contacts and their relationships
///
/// This view model is responsible for handling all contact-related operations including:
/// - Loading and managing the user's contacts (both responders and dependents)
/// - Adding and removing contacts
/// - Looking up users by QR code
/// - Managing contact relationships through Firebase Cloud Functions
/// - Tracking non-responsive dependents and pending pings
///
/// It is part of the app's MVVM architecture and works alongside other view models
/// like UserProfileViewModel and CheckInViewModel to provide a complete user data management solution.
class ContactsViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Combined list of all contacts (both responders and dependents)
    ///
    /// This array contains all of the user's contacts, regardless of their role.
    /// Use the computed properties `responders` and `dependents` to get filtered lists.
    /// This property is updated when contacts are loaded from Firestore or modified locally.
    @Published var contacts: [ContactReference] = []

    /// Dictionary for faster contact lookup by ID
    ///
    /// This dictionary maps contact IDs to ContactReference objects for efficient lookup.
    /// It is kept in sync with the contacts array and provides O(1) access by ID.
    private var contactsById: [String: ContactReference] = [:]

    /// Loading state for contacts
    ///
    /// This property is true when contacts are being loaded from Firestore,
    /// and false when loading is complete or has failed. It can be used by views
    /// to display loading indicators.
    @Published var isLoadingContacts: Bool = false

    /// Error state for contact operations
    ///
    /// This property contains the most recent error that occurred during a contact operation.
    /// It is set to nil at the start of each operation and updated if an error occurs.
    /// Views can observe this property to display error messages.
    @Published var contactError: Error? = nil

    /// Count of non-responsive dependents
    ///
    /// This property tracks the number of dependent contacts who have not checked in
    /// before their expiration time or who have manually triggered an alert.
    /// It is used to display a badge count on the Dependents tab.
    @Published var nonResponsiveDependentsCount: Int = 0

    /// Count of pending pings
    ///
    /// This property tracks the number of responder contacts who have sent a ping
    /// that has not yet been acknowledged. It is used to display a badge count
    /// on the Responders tab.
    @Published var pendingPingsCount: Int = 0

    // MARK: - Computed Properties

    /// Filtered list of contacts who are responders
    ///
    /// This computed property returns a filtered list of contacts who have the responder role.
    /// Responders are users who can respond to the current user's alerts or check-in failures.
    /// This property is used by the RespondersView to display only responder contacts.
    var responders: [ContactReference] {
        contacts.filter { $0.isResponder }
    }

    /// Filtered list of contacts who are dependents
    ///
    /// This computed property returns a filtered list of contacts who have the dependent role.
    /// Dependents are users who the current user is responsible for monitoring.
    /// This property is used by the DependentsView to display only dependent contacts.
    var dependents: [ContactReference] {
        contacts.filter { $0.isDependent }
    }

    /// Get a contact by ID
    ///
    /// This method provides efficient lookup of a contact by its ID using the contactsById dictionary.
    ///
    /// - Parameter id: The contact ID (Firestore document ID)
    /// - Returns: The ContactReference object if found, nil if no contact exists with the given ID
    /// - Note: This method has O(1) time complexity due to dictionary lookup
    func getContact(by id: String) -> ContactReference? {
        return contactsById[id]
    }

    // MARK: - Initialization

    init() {
        // Initialize with empty contacts array
        contacts = []

        // Initialize counts
        DispatchQueue.main.async {
            self.nonResponsiveDependentsCount = 0
            self.pendingPingsCount = 0
        }

        // Load contacts if user is authenticated
        if AuthenticationService.shared.isAuthenticated {
            loadContactsFromFirestore()
        }

        // Set up notification observers for alerts
        setupAlertNotificationObservers()
    }

    /// Set up notification observers for alerts from dependents
    private func setupAlertNotificationObservers() {
        // Observer for when a dependent sends an alert
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DependentAlertReceived"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let dependentId = userInfo["dependentId"] as? String else {
                return
            }

            // Refresh contacts from Firestore to get the latest alert status
            self.loadContactsFromFirestore { success in
                if success {
                    print("Contacts refreshed after receiving alert from dependent: \(dependentId)")

                    // Update the UI
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshDependentsView"), object: nil)
                }
            }
        }

        // Observer for when a dependent cancels an alert
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DependentAlertCanceled"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let dependentId = userInfo["dependentId"] as? String else {
                return
            }

            // Refresh contacts from Firestore to get the latest alert status
            self.loadContactsFromFirestore { success in
                if success {
                    print("Contacts refreshed after dependent canceled alert: \(dependentId)")

                    // Update the UI
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshDependentsView"), object: nil)
                }
            }
        }
    }

    // MARK: - Helper Methods

    /// Validates that the user is authenticated and returns the user ID
    /// - Parameter completion: Callback with user ID or error
    /// - Returns: The user ID if authenticated, nil otherwise
    private func validateAuthentication(completion: ((String?, Error?) -> Void)? = nil) -> String? {
        guard AuthenticationService.shared.isAuthenticated else {
            let error = NSError(domain: "ContactsViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            completion?(nil, error)
            return nil
        }

        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            let error = NSError(domain: "ContactsViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User ID not available"])
            completion?(nil, error)
            return nil
        }

        completion?(userId, nil)
        return userId
    }

    /// Posts notifications to refresh UI views
    private func postUIRefreshNotifications() {
        NotificationCenter.default.post(name: NSNotification.Name("RefreshDependentsView"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("RefreshRespondersView"), object: nil)
    }

    /// Calls a Firebase function with the given name and parameters
    /// - Parameters:
    ///   - functionName: The name of the function to call
    ///   - parameters: The parameters to pass to the function
    ///   - completion: Callback with result data and error
    private func callFirebaseFunction(
        functionName: String,
        parameters: [String: Any],
        completion: @escaping ([String: Any]?, Error?) -> Void
    ) {
        let functions = Functions.functions(region: "us-central1")
        functions.httpsCallable(functionName).call(parameters) { result, error in
            if let error = error {
                print("Error calling \(functionName): \(error.localizedDescription)")
                completion(nil, error)
                return
            }

            guard let data = result?.data as? [String: Any] else {
                let error = NSError(domain: "ContactsViewModel", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
                completion(nil, error)
                return
            }

            completion(data, nil)
        }
    }

    /// Calls a Firebase function with the given name and parameters and handles common success/failure patterns
    /// - Parameters:
    ///   - functionName: The name of the function to call
    ///   - parameters: The parameters to pass to the function
    ///   - completion: Callback with success flag and error
    private func callFirebaseFunctionWithSuccessCheck(
        functionName: String,
        parameters: [String: Any],
        completion: @escaping (Bool, Error?) -> Void
    ) {
        callFirebaseFunction(functionName: functionName, parameters: parameters) { data, error in
            if let error = error {
                completion(false, error)
                return
            }

            guard let data = data,
                  let success = data["success"] as? Bool else {
                let serverError = NSError(domain: "ContactsViewModel", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
                completion(false, serverError)
                return
            }

            if !success {
                let serverError = NSError(domain: "ContactsViewModel", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server reported failure"])
                completion(false, serverError)
                return
            }

            completion(true, nil)
        }
    }

    /// Updates a contact in the local contacts array and dictionary
    /// - Parameters:
    ///   - contact: The contact to update
    ///   - updateAction: Optional closure to modify the contact before updating
    ///   - notifyChanges: Whether to post notifications about the change
    /// - Returns: True if the contact was found and updated, false otherwise
    @discardableResult
    func updateLocalContact(_ contact: ContactReference, updateAction: ((inout ContactReference) -> Void)? = nil, notifyChanges: Bool = true) -> Bool {
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            var updatedContact = contacts[index]

            // Apply the update action if provided
            updateAction?(&updatedContact)

            // Update the contact in the array
            contacts[index] = updatedContact

            // Update the contact in the dictionary
            contactsById[updatedContact.id] = updatedContact

            // Post notifications to refresh the UI if requested
            if notifyChanges {
                postUIRefreshNotifications()
            }

            return true
        }

        return false
    }

    // MARK: - Contact Management

    /// Looks up a user by QR code ID in Firestore
    ///
    /// This method searches the qr_lookup collection to find a user associated with the given QR code ID.
    /// Once found, it retrieves basic user information from the users collection to display to the user
    /// before adding them as a contact.
    ///
    /// - Parameters:
    ///   - qrCodeId: The QR code ID to look up (typically scanned from another user's QR code)
    ///   - completion: Callback that is called when the lookup completes.
    ///     The first parameter contains basic user data if found, or nil if not found.
    ///     The second parameter contains an error if one occurred, or nil on success.
    ///
    /// - Note: This method only retrieves minimal user information needed for contact creation
    ///   (name, phone, note) to protect user privacy.
    /// - Important: The QR code ID must be valid and non-empty or the lookup will fail.
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
                    UserFields.uid: userId,
                    UserFields.name: document.data()?[UserFields.name] as? String ?? "Unknown Name",
                    UserFields.phoneNumber: document.data()?[UserFields.phoneNumber] as? String ?? "",
                    UserFields.note: document.data()?[UserFields.note] as? String ?? ""
                ]

                // Return the minimal user data
                completion(minimalUserData, nil)
            }
        }
    }

    /// Adds a new contact with the given QR code ID and role
    ///
    /// This method creates a bidirectional relationship between the current user and another user
    /// identified by their QR code. It uses a Firebase Cloud Function to ensure that both users'
    /// contact lists are updated consistently.
    ///
    /// - Parameters:
    ///   - qrCodeId: The QR code ID of the user to add as a contact
    ///   - isResponder: True if the contact should be added as a responder
    ///   - isDependent: True if the contact should be added as a dependent
    ///   - completion: Optional callback that is called when the operation completes.
    ///     The boolean parameter indicates success (true) or failure (false).
    ///     If an error occurs, it will be passed as the second parameter.
    ///
    /// - Note: A contact can be both a responder and a dependent at the same time.
    /// - Note: If the contact already exists, this method will return success with a special error
    ///   that UI can handle to show an appropriate message.
    /// - Important: This method requires an authenticated user and will fail if no user is signed in.
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
    ///
    /// This method removes a bidirectional relationship between the current user and a contact.
    /// It uses a Firebase Cloud Function to ensure that both users' contact lists are updated consistently.
    /// The contact is removed locally immediately, and then the cloud function is called to update Firestore.
    ///
    /// - Parameters:
    ///   - contact: The ContactReference object to remove from the user's contacts
    ///   - completion: Optional callback that is called when the operation completes.
    ///     The boolean parameter indicates success (true) or failure (false).
    ///     If an error occurs, it will be passed as the second parameter.
    ///
    /// - Note: This method removes the contact locally before calling the cloud function,
    ///   so the UI will update immediately even if the cloud function takes time to complete.
    /// - Important: This method requires an authenticated user and will fail if no user is signed in.
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

    /// Finds the user ID for a contact by looking in the user's contacts array
    /// - Parameter contact: The contact to find the user ID for
    /// - Returns: The user ID if found, nil otherwise
    private func findContactUserId(for contact: ContactReference) -> String? {
        // Simply return the userId from the ContactReference
        return contact.userId
    }
}
