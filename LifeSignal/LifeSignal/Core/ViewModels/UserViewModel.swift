import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

// MARK: - Error Types
extension UserViewModel {
    /// Error domain for UserViewModel
    static let errorDomain = "UserViewModel"

    /// Error codes for UserViewModel
    enum ErrorCode: Int {
        case unauthenticated = 401
        case notFound = 404
        case invalidArgument = 400
        case serverError = 500
    }

    /// Create a standard error
    /// - Parameters:
    ///   - code: The error code
    ///   - message: The error message
    /// - Returns: An NSError with the given code and message
    static func createError(code: ErrorCode, message: String) -> NSError {
        return NSError(
            domain: errorDomain,
            code: code.rawValue,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}

/// ViewModel for managing user data and contacts
class UserViewModel: ObservableObject {
    // MARK: - Published Properties

    /// User's full name
    @Published var name = "First Last"

    /// User's phone number
    @Published var phone: String = ""

    /// User's unique QR code identifier
    @Published var qrCodeId = UUID().uuidString

    /// User's check-in interval in seconds (default: 24 hours)
    @Published var checkInInterval: TimeInterval = TimeManager.defaultInterval

    /// Timestamp of the user's last check-in
    @Published var lastCheckedIn = Date()

    /// Time in minutes before expiration to send notification (30 or 120)
    @Published var notificationLeadTime: Int = 30

    /// Combined list of all contacts
    @Published var contacts: [Contact] = []

    /// Dictionary for faster contact lookup by ID
    private var contactsById: [UUID: Contact] = [:]

    /// Loading state for contacts
    @Published var isLoadingContacts: Bool = false

    /// Error state for contact operations
    @Published var contactError: Error? = nil

    /// Computed property to get responders
    var responders: [Contact] {
        contacts.filter { $0.isResponder }
    }

    /// Computed property to get dependents
    var dependents: [Contact] {
        contacts.filter { $0.isDependent }
    }

    /// Get a contact by ID
    /// - Parameter id: The contact ID
    /// - Returns: The contact if found, nil otherwise
    func getContact(by id: UUID) -> Contact? {
        return contactsById[id]
    }

    /// Count of non-responsive dependents
    @Published var nonResponsiveDependentsCount: Int = 0

    /// Count of pending pings
    @Published var pendingPingsCount: Int = 0

    /// User's emergency profile description
    @Published var profileDescription: String = "I have a severe peanut allergy - EpiPen is always in my backpack's front pocket."

    /// Alert toggle state for HomeView
    @Published var sendAlertActive: Bool = false

    /// Flag indicating if user data has been loaded from Firestore
    @Published var isDataLoaded: Bool = false

    // MARK: - Computed Properties

    /// Date when the user's check-in expires
    var checkInExpiration: Date {
        return TimeManager.shared.calculateExpirationDate(from: lastCheckedIn, interval: checkInInterval)
    }

    /// Formatted string showing time until next check-in
    var timeUntilNextCheckIn: String {
        let timeInterval = max(0, checkInExpiration.timeIntervalSince(Date()))
        return TimeManager.shared.formatTimeInterval(timeInterval)
    }

    // MARK: - Helper Methods

    /// Validates that the user is authenticated and returns the user ID
    /// - Parameter completion: Callback with user ID or error
    /// - Returns: The user ID if authenticated, nil otherwise
    private func validateAuthentication(completion: ((String?, Error?) -> Void)? = nil) -> String? {
        guard AuthenticationService.shared.isAuthenticated else {
            let error = Self.createError(code: .unauthenticated, message: "User not authenticated")
            completion?(nil, error)
            return nil
        }

        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            let error = Self.createError(code: .unauthenticated, message: "User ID not available")
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
                let error = Self.createError(code: .serverError, message: "Invalid response from server")
                completion(nil, error)
                return
            }

            completion(data, nil)
        }
    }

    /// Updates a contact in the local contacts array and dictionary
    /// - Parameters:
    ///   - contact: The contact to update
    ///   - updateAction: Optional closure to modify the contact before updating
    ///   - notifyChanges: Whether to post notifications about the change
    /// - Returns: True if the contact was found and updated, false otherwise
    @discardableResult
    private func updateLocalContact(_ contact: Contact, updateAction: ((inout Contact) -> Void)? = nil, notifyChanges: Bool = true) -> Bool {
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

    // MARK: - Initialization

    /// Process contacts from an array in the user document
    /// - Parameters:
    ///   - contactsArray: Array of contact data from Firestore
    ///   - completion: Callback with success flag
    func processContactsFromArray(_ contactsArray: [[String: Any]], completion: @escaping (Bool) -> Void) {
        print("DEBUG: Processing \(contactsArray.count) contacts from array")

        let db = Firestore.firestore()
        var loadedContacts: [Contact] = []
        let group = DispatchGroup()

        for contactData in contactsArray {
            // Extract data from the contact entry
            guard let referencePath = contactData["referencePath"] as? String,
                  let isResponder = contactData["isResponder"] as? Bool,
                  let isDependent = contactData["isDependent"] as? Bool else {
                print("DEBUG: Missing required fields in contact data")
                continue
            }

            print("DEBUG: Processing contact with referencePath: \(referencePath)")

            // Extract the user ID from the path (format: "users/userId")
            let components = referencePath.components(separatedBy: "/")
            guard components.count == 2 && components[0] == "users" else {
                print("DEBUG: Invalid referencePath format: \(referencePath)")
                continue
            }

            let contactUserId = components[1]
            let lastUpdated = (contactData["lastUpdated"] as? Timestamp) ?? Timestamp(date: Date())

            // Fetch the user document to get the name, phone, etc.
            group.enter()
            db.collection(FirestoreSchema.Collections.users).document(contactUserId).getDocument { document, error in
                defer { group.leave() }

                if let error = error {
                    print("DEBUG: Error fetching user document: \(error.localizedDescription)")
                    return
                }

                guard let document = document, document.exists, let userData = document.data() else {
                    print("DEBUG: User document not found for ID: \(contactUserId)")
                    return
                }

                // Extract user data
                let name = userData[FirestoreSchema.User.name] as? String ?? "Unknown User"
                let phone = userData[FirestoreSchema.User.phoneNumber] as? String ?? ""
                let note = userData[FirestoreSchema.User.note] as? String ?? ""
                let qrCodeId = userData[FirestoreSchema.User.qrCodeId] as? String

                print("DEBUG: Fetched user data - name: \(name), isResponder: \(isResponder), isDependent: \(isDependent)")

                // Create a Contact object
                let contact = Contact(
                    id: UUID(), // Generate a new UUID for the contact
                    name: name,
                    phone: phone,
                    note: note,
                    qrCodeId: qrCodeId,
                    isResponder: isResponder,
                    isDependent: isDependent,
                    addedAt: lastUpdated.dateValue()
                )

                // Add to our local array
                loadedContacts.append(contact)
            }
        }

        // Wait for all fetches to complete
        group.notify(queue: .main) { [weak self] in
            guard let self = self else {
                completion(false)
                return
            }

            print("DEBUG: Finished processing contacts array, loaded \(loadedContacts.count) contacts")

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

            print("DEBUG: After processing array - Responders count: \(self.responders.count), Dependents count: \(self.dependents.count)")

            completion(true)
        }
    }

    init() {
        // Generate a random QR code ID for the user
        qrCodeId = UUID().uuidString

        // Initialize with empty contacts array
        contacts = []

        // Initialize counts
        DispatchQueue.main.async {
            self.nonResponsiveDependentsCount = 0
            self.pendingPingsCount = 0
        }

        print("DEBUG: UserViewModel init - isAuthenticated: \(AuthenticationService.shared.isAuthenticated)")

        // Try to load user data from Firestore if authenticated
        if AuthenticationService.shared.isAuthenticated {
            print("DEBUG: UserViewModel init - Loading user data")
            loadUserData { [weak self] success in
                guard let self = self else { return }

                print("DEBUG: UserViewModel init - User data loaded with success: \(success)")

                // Always try to load contacts, even if user data loading failed
                // This ensures we get contacts in all cases
                self.loadContactsFromFirestore { success in
                    print("DEBUG: UserViewModel init - Contacts loaded with success: \(success)")
                    print("DEBUG: UserViewModel init - Contacts count: \(self.contacts.count)")
                    print("DEBUG: UserViewModel init - Responders count: \(self.responders.count)")
                    print("DEBUG: UserViewModel init - Dependents count: \(self.dependents.count)")

                    // Force refresh the UI
                    self.postUIRefreshNotifications()
                }
            }
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

    // MARK: - Firestore Integration

    /// Load user data from Firestore
    /// - Parameter completion: Optional callback when data is loaded
    func loadUserData(completion: ((Bool) -> Void)? = nil) {
        guard AuthenticationService.shared.isAuthenticated else {
            print("Cannot load user data: No authenticated user")
            completion?(false)
            return
        }

        // Get the current user ID
        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            print("Cannot load user data: User ID not available")
            completion?(false)
            return
        }

        // Get reference to the user document
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreSchema.Collections.users).document(userId)

        // Get the document
        userRef.getDocument { [weak self] document, error in
            guard let self = self else { return }

            if let error = error {
                print("Error loading user data: \(error.localizedDescription)")
                completion?(false)
                return
            }

            guard let document = document, document.exists, let userData = document.data() else {
                print("No user data found")
                completion?(false)
                return
            }

            self.updateFromFirestore(userData: userData)
            completion?(true)
        }
    }

    /// Update the view model with data from Firestore
    /// - Parameter userData: The user data from Firestore
    func updateFromFirestore(userData: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Update basic user information
            if let name = userData[FirestoreSchema.User.name] as? String {
                self.name = name
            }

            if let phone = userData[FirestoreSchema.User.phoneNumber] as? String {
                self.phone = phone
            }

            if let qrCodeId = userData[FirestoreSchema.User.qrCodeId] as? String {
                self.qrCodeId = qrCodeId
            }

            if let note = userData[FirestoreSchema.User.note] as? String {
                self.profileDescription = note
            }

            // Update check-in related data
            if let checkInInterval = userData[FirestoreSchema.User.checkInInterval] as? TimeInterval {
                self.checkInInterval = checkInInterval
            }

            if let lastCheckedInTimestamp = userData[FirestoreSchema.User.lastCheckedIn] as? Timestamp {
                self.lastCheckedIn = lastCheckedInTimestamp.dateValue()
            }

            // Update notification preferences
            if let notify30Min = userData[FirestoreSchema.User.notify30MinBefore] as? Bool, notify30Min {
                self.notificationLeadTime = 30
            } else if let notify2Hours = userData[FirestoreSchema.User.notify2HoursBefore] as? Bool, notify2Hours {
                self.notificationLeadTime = 120
            }

            // Mark data as loaded
            self.isDataLoaded = true

            print("User data updated from Firestore")
        }
    }

    /// Save user data to Firestore
    /// - Parameters:
    ///   - additionalData: Additional data to save
    ///   - completion: Optional callback with success flag and error
    func saveUserData(additionalData: [String: Any]? = nil, completion: ((Bool, Error?) -> Void)? = nil) {
        guard AuthenticationService.shared.isAuthenticated else {
            completion?(false, NSError(domain: "UserViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }

        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            completion?(false, NSError(domain: "UserViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User ID not available"]))
            return
        }

        // Create base user data
        var userData: [String: Any] = [
            FirestoreSchema.User.name: name,
            FirestoreSchema.User.note: profileDescription,
            FirestoreSchema.User.qrCodeId: qrCodeId,
            FirestoreSchema.User.checkInInterval: checkInInterval,
            FirestoreSchema.User.lastCheckedIn: lastCheckedIn,
            FirestoreSchema.User.notify30MinBefore: notificationLeadTime == 30,
            FirestoreSchema.User.notify2HoursBefore: notificationLeadTime == 120,
            FirestoreSchema.User.lastUpdated: FieldValue.serverTimestamp()
        ]

        // Add phone number if available from Auth
        if let phoneNumber = Auth.auth().currentUser?.phoneNumber, !phoneNumber.isEmpty {
            userData[FirestoreSchema.User.phoneNumber] = phoneNumber
        }

        // Ensure UID is set
        userData[FirestoreSchema.User.uid] = userId

        // Add profile complete flag
        userData[FirestoreSchema.User.profileComplete] = true

        // Add any additional data
        if let additionalData = additionalData {
            for (key, value) in additionalData {
                userData[key] = value
            }
        }

        // Save to Firestore
        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            let error = NSError(domain: "UserViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User ID not available"])
            print("Error saving user data: \(error.localizedDescription)")
            completion?(false, error)
            return
        }

        // Get reference to the user document
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreSchema.Collections.users).document(userId)

        // Update the document
        userRef.setData(userData, merge: true) { error in
            if let error = error {
                print("Error saving user data: \(error.localizedDescription)")
                completion?(false, error)
                return
            }

            print("User data saved to Firestore")
            completion?(true, nil)
        }
    }

    /// Create an empty contacts collection for a user
    /// - Parameters:
    ///   - userId: The user ID
    ///   - completion: Callback with success flag and error
    private func createEmptyContactsCollection(userId: String, completion: @escaping (Bool, Error?) -> Void) {
        // Create a placeholder document in the contacts subcollection
        let db = Firestore.firestore()
        let placeholderDoc = db.collection(FirestoreSchema.Collections.users)
            .document(userId)
            .collection(FirestoreSchema.Collections.contacts)
            .document("placeholder")

        // Set placeholder data
        placeholderDoc.setData([
            "createdAt": FieldValue.serverTimestamp(),
            "placeholder": true
        ]) { error in
            if let error = error {
                print("Error creating contacts collection: \(error.localizedDescription)")
                completion(false, error)
                return
            }

            // Delete the placeholder document after creating the collection
            placeholderDoc.delete { error in
                if let error = error {
                    print("Error deleting placeholder document: \(error.localizedDescription)")
                    // Not critical, so still return success
                }

                print("Empty contacts collection created for user \(userId)")
                completion(true, nil)
            }
        }
    }

    /// Create a new user document in Firestore
    /// - Parameters:
    ///   - completion: Optional callback with success flag and error
    func createUserDocument(completion: ((Bool, Error?) -> Void)? = nil) {
        guard AuthenticationService.shared.isAuthenticated else {
            completion?(false, NSError(domain: "UserViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }

        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            completion?(false, NSError(domain: "UserViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User ID not available"]))
            return
        }

        // Create a UserDocument object
        var userDoc = UserDocument(
            uid: userId,
            name: name,
            phoneNumber: Auth.auth().currentUser?.phoneNumber ?? "",
            note: profileDescription,
            qrCodeId: qrCodeId,
            createdAt: Date(),
            lastSignInTime: Date()
        )

        // Set profileComplete to true
        userDoc.profileComplete = true

        // Convert to Firestore data
        let userData = userDoc.toFirestoreData()

        // Create the user document
        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            let error = NSError(domain: "UserViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User ID not available"])
            print("Error creating user document: \(error.localizedDescription)")
            completion?(false, error)
            return
        }

        // Get reference to the user document
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreSchema.Collections.users).document(userId)

        // Check if the document exists
        userRef.getDocument { [weak self] document, error in
            guard let self = self else { return }

            if let error = error {
                print("Error checking user document: \(error.localizedDescription)")
                completion?(false, error)
                return
            }

            // If document exists, update it
            if let document = document, document.exists {
                userRef.setData(userData, merge: true) { error in
                    if let error = error {
                        print("Error updating user document: \(error.localizedDescription)")
                        completion?(false, error)
                        return
                    }

                    print("User document updated successfully")

                    // Create the QR lookup document
                    self.updateQRLookup(userId: userId, qrCodeId: self.qrCodeId) { success, error in
                        if let error = error {
                            print("Error creating QR lookup document: \(error.localizedDescription)")
                            // Not critical, so continue
                        }

                        // Create an empty contacts collection
                        self.createEmptyContactsCollection(userId: userId) { success, error in
                            if let error = error {
                                print("Error creating contacts collection: \(error.localizedDescription)")
                                // Not critical, so still return success for the main operation
                            }

                            print("User document created successfully")
                            completion?(true, nil)
                        }
                    }
                }
            } else {
                // Document doesn't exist, create it
                userRef.setData(userData) { error in
                    if let error = error {
                        print("Error creating user document: \(error.localizedDescription)")
                        completion?(false, error)
                        return
                    }

                    print("User document created successfully")

                    // Create the QR lookup document
                    self.updateQRLookup(userId: userId, qrCodeId: self.qrCodeId) { success, error in
                        if let error = error {
                            print("Error creating QR lookup document: \(error.localizedDescription)")
                            // Not critical, so continue
                        }

                        // Create an empty contacts collection
                        self.createEmptyContactsCollection(userId: userId) { success, error in
                            if let error = error {
                                print("Error creating contacts collection: \(error.localizedDescription)")
                                // Not critical, so still return success for the main operation
                            }

                            print("User document created successfully")
                            completion?(true, nil)
                        }
                    }
                }
            }
        }
    }



    // MARK: - User Actions

    /// Update or create a QR lookup document for a user
    /// - Parameters:
    ///   - userId: The user ID
    ///   - qrCodeId: The QR code ID
    ///   - completion: Callback with success flag and error
    private func updateQRLookup(userId: String, qrCodeId: String, completion: @escaping (Bool, Error?) -> Void) {
        // Create QR lookup document
        let qrLookupDoc = QRLookupDocument(
            qrCodeId: qrCodeId,
            updatedAt: Date()
        )

        // Convert to Firestore data
        let qrLookupData = qrLookupDoc.toFirestoreData()

        // Save to Firestore using userId as document ID
        let db = Firestore.firestore()
        db.collection(FirestoreSchema.Collections.qrLookup).document(userId).setData(qrLookupData) { error in
            if let error = error {
                print("Error updating QR lookup: \(error.localizedDescription)")
                completion(false, error)
                return
            }

            print("QR lookup updated for user \(userId) with QR code \(qrCodeId)")
            completion(true, nil)
        }
    }

    /// Generates a new QR code ID for the user
    /// - Parameter completion: Optional callback with success flag and error
    func generateNewQRCode(completion: ((Bool, Error?) -> Void)? = nil) {
        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            completion?(false, NSError(domain: "UserViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }

        // Generate a new QR code ID
        qrCodeId = UUID().uuidString

        // Save to Firestore
        let updateData: [String: Any] = [
            FirestoreSchema.User.qrCodeId: qrCodeId,
            FirestoreSchema.User.lastUpdated: FieldValue.serverTimestamp()
        ]

        // Get reference to the user document
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreSchema.Collections.users).document(userId)

        // Update the document
        userRef.updateData(updateData) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                print("Error updating QR code ID in Firestore: \(error.localizedDescription)")
                completion?(false, error)
                return
            }

            // Update the QR lookup database
            self.updateQRLookup(userId: userId, qrCodeId: self.qrCodeId) { success, error in
                if let error = error {
                    print("Error updating QR lookup database: \(error.localizedDescription)")
                    // Not critical, so still return success for the main operation
                }

                print("QR code ID updated in Firestore and QR lookup database")
                completion?(true, nil)
            }
        }
    }

    /// Updates the user's last check-in time to now
    /// - Parameter completion: Optional callback with success flag and error
    func updateLastCheckedIn(completion: ((Bool, Error?) -> Void)? = nil) {
        lastCheckedIn = Date()

        // Save to Firestore
        let updateData: [String: Any] = [
            FirestoreSchema.User.lastCheckedIn: lastCheckedIn,
            FirestoreSchema.User.lastUpdated: FieldValue.serverTimestamp()
        ]

        // Get the current user ID
        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            let error = NSError(domain: "UserViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User ID not available"])
            print("Error updating last check-in time: \(error.localizedDescription)")
            completion?(false, error)
            return
        }

        // Get reference to the user document
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreSchema.Collections.users).document(userId)

        // Update the document
        userRef.updateData(updateData) { error in
            if let error = error {
                print("Error updating last check-in time in Firestore: \(error.localizedDescription)")
                completion?(false, error)
                return
            }

            print("Last check-in time updated in Firestore")
            completion?(true, nil)
        }
    }

    /// Sets the notification lead time in minutes
    /// - Parameters:
    ///   - minutes: The lead time in minutes (30 or 120)
    ///   - completion: Optional callback with success flag and error
    func setNotificationLeadTime(_ minutes: Int, completion: ((Bool, Error?) -> Void)? = nil) {
        notificationLeadTime = minutes

        // Save to Firestore
        let updateData: [String: Any] = [
            FirestoreSchema.User.notify30MinBefore: minutes == 30,
            FirestoreSchema.User.notify2HoursBefore: minutes == 120,
            FirestoreSchema.User.lastUpdated: FieldValue.serverTimestamp()
        ]

        // Get the current user ID
        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            let error = NSError(domain: "UserViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User ID not available"])
            print("Error updating notification lead time: \(error.localizedDescription)")
            completion?(false, error)
            return
        }

        // Get reference to the user document
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreSchema.Collections.users).document(userId)

        // Update the document
        userRef.updateData(updateData) { error in
            if let error = error {
                print("Error updating notification lead time in Firestore: \(error.localizedDescription)")
                completion?(false, error)
                return
            }

            print("Notification lead time updated in Firestore")
            completion?(true, nil)
        }
    }

    /// Updates the user's name in Firestore
    /// - Parameters:
    ///   - newName: The new name to set
    ///   - completion: Optional callback with success flag and error
    func updateName(_ newName: String, completion: ((Bool, Error?) -> Void)? = nil) {
        // Update local property
        name = newName

        // Save to Firestore
        let updateData: [String: Any] = [
            FirestoreSchema.User.name: newName,
            FirestoreSchema.User.lastUpdated: FieldValue.serverTimestamp()
        ]

        // Get the current user ID
        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            let error = NSError(domain: "UserViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User ID not available"])
            print("Error updating name: \(error.localizedDescription)")
            completion?(false, error)
            return
        }

        // Get reference to the user document
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreSchema.Collections.users).document(userId)

        // Update the document
        userRef.updateData(updateData) { error in
            if let error = error {
                print("Error updating name in Firestore: \(error.localizedDescription)")
                completion?(false, error)
                return
            }

            print("Name updated in Firestore")
            completion?(true, nil)
        }
    }

    /// Updates the user's emergency note in Firestore
    /// - Parameters:
    ///   - newNote: The new emergency note to set
    ///   - completion: Optional callback with success flag and error
    func updateEmergencyNote(_ newNote: String, completion: ((Bool, Error?) -> Void)? = nil) {
        // Update local property
        profileDescription = newNote

        // Save to Firestore
        let updateData: [String: Any] = [
            FirestoreSchema.User.note: newNote,
            FirestoreSchema.User.lastUpdated: FieldValue.serverTimestamp()
        ]

        // Get the current user ID
        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            let error = NSError(domain: "UserViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User ID not available"])
            print("Error updating emergency note: \(error.localizedDescription)")
            completion?(false, error)
            return
        }

        // Get reference to the user document
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreSchema.Collections.users).document(userId)

        // Update the document
        userRef.updateData(updateData) { error in
            if let error = error {
                print("Error updating emergency note in Firestore: \(error.localizedDescription)")
                completion?(false, error)
                return
            }

            print("Emergency note updated in Firestore")
            completion?(true, nil)
        }
    }

    // MARK: - Contact Management

    /// Looks up a user by QR code ID in Firestore
    /// - Parameters:
    ///   - qrCodeId: The QR code ID to look up
    ///   - completion: Callback with user data and error
    func lookupUserByQRCode(_ qrCodeId: String, completion: @escaping ([String: Any]?, Error?) -> Void) {
        guard !qrCodeId.isEmpty else {
            completion(nil, NSError(domain: "UserViewModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "QR code ID is empty"]))
            return
        }

        // Look up the user ID from the QR lookup database
        let db = Firestore.firestore()
        let qrLookupRef = db.collection(FirestoreSchema.Collections.qrLookup)

        // Query for documents where qrCodeId matches
        qrLookupRef.whereField("qrCodeId", isEqualTo: qrCodeId).getDocuments { snapshot, error in
            if let error = error {
                print("Error looking up QR code in lookup database: \(error.localizedDescription)")
                completion(nil, error)
                return
            }

            guard let snapshot = snapshot, !snapshot.documents.isEmpty else {
                print("No user found with QR code ID: \(qrCodeId)")
                completion(nil, NSError(domain: "UserViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "No user found with this QR code"]))
                return
            }

            // Get the user ID from the document ID
            let userId = snapshot.documents[0].documentID

            // Now get only the basic user information needed for display
            let db = Firestore.firestore()
            let userRef = db.collection(FirestoreSchema.Collections.users).document(userId)

            userRef.getDocument { document, error in
                if let error = error {
                    print("Error getting user document: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }

                guard let document = document, document.exists else {
                    print("User document not found for ID: \(userId)")
                    completion(nil, NSError(domain: "UserViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "User document not found"]))
                    return
                }

                // Only retrieve the minimal fields needed for contact creation
                // This avoids accessing sensitive user data
                let minimalUserData: [String: Any] = [
                    FirestoreSchema.User.uid: userId,
                    FirestoreSchema.User.name: document.data()?[FirestoreSchema.User.name] as? String ?? "Unknown Name",
                    FirestoreSchema.User.phoneNumber: document.data()?[FirestoreSchema.User.phoneNumber] as? String ?? "",
                    FirestoreSchema.User.note: document.data()?[FirestoreSchema.User.note] as? String ?? ""
                ]

                // Return the minimal user data
                completion(minimalUserData, nil)
            }
        }
    }

    /// Adds a new contact with the given QR code ID and role
    /// - Parameters:
    ///   - qrCodeId: The QR code ID of the contact
    ///   - isResponder: True if the contact is a responder
    ///   - isDependent: True if the contact is a dependent
    ///   - completion: Optional callback with success flag and error
    func addContact(qrCodeId: String, isResponder: Bool, isDependent: Bool, completion: ((Bool, Error?) -> Void)? = nil) {
        // Validate authentication and get user ID
        guard let userId = validateAuthentication() else {
            completion?(false, Self.createError(code: .unauthenticated, message: "User not authenticated"))
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
                completion?(false, Self.createError(code: .notFound, message: "No user found with this QR code"))
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
                                    completion?(true, Self.createError(code: .invalidArgument, message: "Contact already exists"))
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
                    completion?(false, Self.createError(code: .serverError, message: "Invalid response from server"))
                    return
                }

                if !success {
                    completion?(false, Self.createError(code: .serverError, message: "Server reported failure"))
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
    ///   - contact: The contact to remove
    ///   - completion: Optional callback with success flag and error
    func removeContact(_ contact: Contact, completion: ((Bool, Error?) -> Void)? = nil) {
        // Set error state to nil at the start of the operation
        DispatchQueue.main.async {
            self.contactError = nil
        }

        print("Before removal - Responders count: \(responders.count), Dependents count: \(dependents.count)")

        // Remove the contact from the combined list
        contacts.removeAll { $0.id == contact.id }

        // Remove from the dictionary
        contactsById.removeValue(forKey: contact.id)

        print("Removed contact: \(contact.name)")

        print("After removal - Responders count: \(responders.count), Dependents count: \(dependents.count)")

        // Post notification to refresh the lists views
        postUIRefreshNotifications()

        // Find the contact's user ID
        guard let contactId = findContactUserId(for: contact) else {
            print("Cannot find user ID for contact: \(contact.name)")
            // Still consider it a success since we've removed it locally
            completion?(true, nil)
            return
        }

        // Validate authentication and get user ID
        guard let userId = validateAuthentication() else {
            completion?(false, Self.createError(code: .unauthenticated, message: "User not authenticated"))
            return
        }

        // Call the Cloud Function to delete the bidirectional relationship
        let parameters: [String: Any] = [
            "userARefPath": "users/\(userId)",
            "userBRefPath": "users/\(contactId)"
        ]

        callFirebaseFunction(functionName: "deleteContactRelation", parameters: parameters) { data, error in
            if let error = error {
                completion?(false, error)
                return
            }

            guard let data = data,
                  let success = data["success"] as? Bool else {
                completion?(false, Self.createError(code: .serverError, message: "Invalid response from server"))
                return
            }

            if !success {
                completion?(false, Self.createError(code: .serverError, message: "Server reported failure"))
                return
            }

            print("Contact relationship deleted successfully")
            completion?(true, nil)
        }
    }

    /// Updates a contact's role in the contacts list
    /// - Parameters:
    ///   - contact: The contact to update
    ///   - wasResponder: Whether the contact was previously a responder
    ///   - wasDependent: Whether the contact was previously a dependent
    ///   - completion: Optional callback with success flag and error
    func updateContactRole(contact: Contact, wasResponder: Bool, wasDependent: Bool, completion: ((Bool, Error?) -> Void)? = nil) {
        // Set error state to nil at the start of the operation
        DispatchQueue.main.async {
            self.contactError = nil
        }

        print("\n==== UPDATE CONTACT ROLE ====\nBefore update - Responders count: \(responders.count), Dependents count: \(dependents.count)")
        print("Updating contact role: \(contact.name) (ID: \(contact.id))")
        print("  Was responder: \(wasResponder), is now: \(contact.isResponder)")
        print("  Was dependent: \(wasDependent), is now: \(contact.isDependent)")

        // Use updateLocalContact to update both the array and dictionary
        let updated = updateLocalContact(contact) { _ in
            // No additional changes needed, just use the contact as is
        }

        if !updated {
            print("Contact not found in local contacts array, adding it")
            // If not found (shouldn't happen), add it
            contacts.append(contact)
            contactsById[contact.id] = contact
        }

        // Print the current state of the lists
        print("After update - Responders count: \(responders.count), Dependents count: \(dependents.count)")
        print("==== END UPDATE CONTACT ROLE ====\n")

        // Update the contact relationship using the cloud function
        updateContactRelationship(contact, updateRoles: true) { success, error in
            if let error = error {
                print("Error updating contact relationship: \(error.localizedDescription)")

                // Set the error state
                DispatchQueue.main.async {
                    self.contactError = error
                }

                completion?(false, error)
                return
            }

            print("Contact relationship updated successfully")
            completion?(true, nil)
        }
    }

    /// Updates a contact relationship using the cloud function
    /// - Parameters:
    ///   - contact: The contact to update
    ///   - updateRoles: Whether to update the roles (isResponder, isDependent)
    ///   - updatePings: Whether to update ping status
    ///   - updateNotifications: Whether to update notification settings
    ///   - completion: Optional callback with success flag and error
    func updateContactRelationship(_ contact: Contact,
                                  updateRoles: Bool = false,
                                  updatePings: Bool = false,
                                  updateNotifications: Bool = false,
                                  completion: ((Bool, Error?) -> Void)? = nil) {
        // Validate authentication and get user ID
        guard let userId = validateAuthentication() else {
            completion?(false, Self.createError(code: .unauthenticated, message: "User not authenticated"))
            return
        }

        // Find the contact's user ID
        guard let contactId = findContactUserId(for: contact) else {
            print("Cannot find user ID for contact: \(contact.name)")
            completion?(false, Self.createError(code: .notFound, message: "Contact user ID not found"))
            return
        }

        // Prepare parameters for the cloud function
        let userRefPath = "users/\(userId)"
        let contactRefPath = "users/\(contactId)"

        var params: [String: Any] = [
            "userRefPath": userRefPath,
            "contactRefPath": contactRefPath
        ]

        // Add role parameters if needed
        if updateRoles {
            params["isResponder"] = contact.isResponder
            params["isDependent"] = contact.isDependent
        }

        // Add ping parameters if needed
        if updatePings {
            params["sendPings"] = true // Default to true
            params["receivePings"] = true // Default to true
        }

        // Add notification parameters if needed
        if updateNotifications {
            params["notifyOnCheckIn"] = contact.isResponder
            params["notifyOnExpiry"] = contact.isResponder
        }

        // Call the cloud function
        callFirebaseFunction(functionName: "updateContactRelation", parameters: params) { data, error in
            if let error = error {
                completion?(false, error)
                return
            }

            guard let data = data,
                  let success = data["success"] as? Bool else {
                completion?(false, Self.createError(code: .serverError, message: "Invalid response from server"))
                return
            }

            if !success {
                completion?(false, Self.createError(code: .serverError, message: "Server reported failure"))
                return
            }

            print("Contact relationship updated successfully")
            completion?(true, nil)
        }
    }

    /// Finds the user ID for a contact
    /// - Parameter contact: The contact to find the user ID for
    /// - Returns: The user ID if found, nil otherwise
    private func findContactUserId(for contact: Contact) -> String? {
        // If we have a QR code ID, look it up
        if let qrCodeId = contact.qrCodeId, !qrCodeId.isEmpty {
            // This is a synchronous method, so we need to use a semaphore
            let semaphore = DispatchSemaphore(value: 0)
            var userId: String? = nil

            let db = Firestore.firestore()
            db.collection(FirestoreSchema.Collections.qrLookup)
                .whereField("qrCodeId", isEqualTo: qrCodeId)
                .limit(to: 1)
                .getDocuments { snapshot, error in
                    defer { semaphore.signal() }

                    if let error = error {
                        print("Error looking up QR code: \(error.localizedDescription)")
                        return
                    }

                    userId = snapshot?.documents.first?.documentID
                }

            // Wait for the lookup to complete (with timeout)
            _ = semaphore.wait(timeout: .now() + 5.0)

            if let userId = userId {
                return userId
            }
        }

        // If we don't have a QR code ID or lookup failed, try to find the contact in Firestore
        guard let currentUserId = AuthenticationService.shared.getCurrentUserID() else {
            return nil
        }

        // Look for a contact with matching ID in the user's contacts collection
        let db = Firestore.firestore()
        let contactsRef = db.collection(FirestoreSchema.Collections.users)
            .document(currentUserId)
            .collection(FirestoreSchema.Collections.contacts)

        // This is a synchronous method, so we need to use a semaphore
        let semaphore = DispatchSemaphore(value: 0)
        var contactUserId: String? = nil

        contactsRef.document(contact.id.uuidString).getDocument { document, error in
            defer { semaphore.signal() }

            if let error = error {
                print("Error getting contact document: \(error.localizedDescription)")
                return
            }

            if let document = document, document.exists,
               let data = document.data() {
                // Check for both old reference format and new referencePath format
                if let reference = data["reference"] as? DocumentReference {
                    contactUserId = reference.documentID
                } else if let referencePath = data["referencePath"] as? String {
                    // Extract the document ID from the path (format: "users/userId")
                    let components = referencePath.components(separatedBy: "/")
                    if components.count == 2 && components[0] == "users" {
                        contactUserId = components[1]
                    }
                }
            }
        }

        // Wait for the lookup to complete (with timeout)
        _ = semaphore.wait(timeout: .now() + 5.0)

        return contactUserId
    }

    // MARK: - Firestore Contact Operations

    /// Save a contact to Firestore - now a wrapper around our new approach
    /// - Parameters:
    ///   - contact: The contact to save
    ///   - completion: Optional callback with success flag and error
    private func saveContactToFirestore(_ contact: Contact, completion: @escaping (Bool, Error?) -> Void) {
        // For new contacts, we need to use the addContact method with QR code
        if let qrCodeId = contact.qrCodeId, !qrCodeId.isEmpty {
            addContact(qrCodeId: qrCodeId,
                      isResponder: contact.isResponder,
                      isDependent: contact.isDependent) { success, error in
                if let error = error {
                    print("Error saving contact to Firestore: \(error.localizedDescription)")
                    completion(false, error)
                    return
                }

                print("Contact saved to Firestore: \(contact.name)")
                completion(true, nil)
            }
        } else {
            // If we don't have a QR code, we can't create the contact using our new approach
            // This should not happen in normal operation, but we'll handle it gracefully
            print("Cannot save contact without QR code: \(contact.name)")
            completion(false, NSError(domain: "UserViewModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot save contact without QR code"]))
        }
    }

    /// Update a contact in Firestore - now a wrapper around our new approach
    /// - Parameters:
    ///   - contact: The contact to update
    ///   - completion: Optional callback with success flag and error
    private func updateContactInFirestore(_ contact: Contact, completion: @escaping (Bool, Error?) -> Void) {
        // Use the updateContactRelationship method to update the contact
        updateContactRelationship(contact,
                                 updateRoles: true,
                                 updatePings: true,
                                 updateNotifications: true) { success, error in
            if let error = error {
                print("Error updating contact in Firestore: \(error.localizedDescription)")
                completion(false, error)
                return
            }

            print("Contact updated in Firestore: \(contact.name)")
            completion(true, nil)
        }
    }

    /// Delete a contact from Firestore - now a wrapper around our new approach
    /// - Parameters:
    ///   - contact: The contact to delete
    ///   - completion: Optional callback with success flag and error
    private func deleteContactFromFirestore(_ contact: Contact, completion: @escaping (Bool, Error?) -> Void) {
        // Find the contact's user ID
        guard let contactId = findContactUserId(for: contact) else {
            print("Cannot find user ID for contact: \(contact.name)")
            // Still consider it a success since we've removed it locally
            completion(true, nil)
            return
        }

        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            completion(false, NSError(domain: "UserViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }

        // Call the Cloud Function to delete the bidirectional relationship
        let functions = Functions.functions(region: "us-central1")
        functions.httpsCallable("deleteContactRelation").call([
            "userARefPath": "users/\(userId)",
            "userBRefPath": "users/\(contactId)"
        ]) { result, error in
            if let error = error {
                print("Error calling deleteContactRelation: \(error.localizedDescription)")
                completion(false, error)
                return
            }

            guard let data = result?.data as? [String: Any],
                  let success = data["success"] as? Bool else {
                print("Invalid response from deleteContactRelation function")
                completion(false, NSError(domain: "UserViewModel", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"]))
                return
            }

            if !success {
                print("Function reported failure")
                completion(false, NSError(domain: "UserViewModel", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server reported failure"]))
                return
            }

            print("Contact relationship deleted successfully")
            completion(true, nil)
        }
    }

    /// Load contacts from Firestore
    /// - Parameter completion: Optional callback with success flag
    func loadContactsFromFirestore(completion: ((Bool) -> Void)? = nil) {
        print("DEBUG: Starting to load contacts from Firestore")

        // Set loading state
        DispatchQueue.main.async {
            self.isLoadingContacts = true
            self.contactError = nil
        }

        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            let error = Self.createError(code: .unauthenticated, message: "No authenticated user")
            DispatchQueue.main.async {
                self.contactError = error
                self.isLoadingContacts = false
            }
            print("DEBUG: Cannot load contacts: No authenticated user")
            completion?(false)
            return
        }

        print("DEBUG: Loading contacts for user ID: \(userId)")

        // Get reference to the user document
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreSchema.Collections.users).document(userId)

        // First, check if contacts are stored directly in the user document as an array
        userRef.getDocument { [weak self] document, error in
            guard let self = self else {
                print("DEBUG: Self is nil in loadContactsFromFirestore completion")
                return
            }

            if let error = error {
                print("DEBUG: Error loading user document: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.contactError = error
                    self.isLoadingContacts = false
                }
                completion?(false)
                return
            }

            guard let document = document, document.exists, let userData = document.data() else {
                let error = Self.createError(code: .notFound, message: "User document not found")
                print("DEBUG: User document not found")
                DispatchQueue.main.async {
                    self.contactError = error
                    self.isLoadingContacts = false
                }
                completion?(false)
                return
            }

            // Check if the user document has a contacts array field
            if let contactsArray = userData["contacts"] as? [[String: Any]], !contactsArray.isEmpty {
                print("DEBUG: Found \(contactsArray.count) contacts in user document array")

                // Process contacts from the array
                self.processContactsFromArray(contactsArray) { success in
                    completion?(success)
                }
                return
            }

            print("DEBUG: No contacts array found in user document, checking subcollection")

            // If no contacts array, try the subcollection approach
            let contactsRef = userRef.collection(FirestoreSchema.Collections.contacts)

            // Get all contacts from subcollection
            contactsRef.getDocuments { [weak self] snapshot, error in
                guard let self = self else {
                    print("DEBUG: Self is nil in subcollection completion")
                    return
                }

                if let error = error {
                    print("DEBUG: Error loading contacts from subcollection: \(error.localizedDescription)")
                    completion?(false)
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("DEBUG: No contacts found in subcollection")

                    // If we get here, we didn't find contacts in either place
                    // Return an empty array but consider it a success
                    DispatchQueue.main.async {
                        self.contacts = []
                        print("DEBUG: No contacts found in either location, using empty array")
                        completion?(true)
                    }
                    return
                }

                print("DEBUG: Found \(documents.count) contact documents in subcollection")

                // Convert Firestore documents to Contact objects
                var loadedContacts: [Contact] = []

                for document in documents {
                    let data = document.data()
                    print("DEBUG: Processing contact document: \(document.documentID)")
                    print("DEBUG: Document data: \(data)")

                    // Check if this is a placeholder document
                    if data["placeholder"] as? Bool == true {
                        print("DEBUG: Skipping placeholder document")
                        continue
                    }

                    // Check if this is using the new format with referencePath
                    if let referencePath = data["referencePath"] as? String {
                        print("DEBUG: Found contact with referencePath: \(referencePath)")

                        // This is a contact using the new format with cloud functions
                        // We need to fetch the actual user data from the referenced user document

                        // Extract the user ID from the path (format: "users/userId")
                        let components = referencePath.components(separatedBy: "/")
                        if components.count == 2 && components[0] == "users" {
                            let contactUserId = components[1]

                            // Get the isResponder and isDependent flags from the contact document
                            let isResponder = data["isResponder"] as? Bool ?? false
                            let isDependent = data["isDependent"] as? Bool ?? false
                            let addedAt = data["lastUpdated"] as? Timestamp ?? Timestamp(date: Date())

                            // Fetch the user document to get the name, phone, etc.
                            let userRef = db.collection(FirestoreSchema.Collections.users).document(contactUserId)

                            // Use a dispatch group to make this synchronous
                            let group = DispatchGroup()
                            group.enter()

                            var contactName = "Unknown User"
                            var contactPhone = ""
                            var contactNote = ""
                            var contactQRCodeId: String? = nil

                            userRef.getDocument { userDoc, error in
                                defer { group.leave() }

                                if let error = error {
                                    print("DEBUG: Error fetching user document: \(error.localizedDescription)")
                                    return
                                }

                                if let userData = userDoc?.data() {
                                    contactName = userData[FirestoreSchema.User.name] as? String ?? "Unknown User"
                                    contactPhone = userData[FirestoreSchema.User.phoneNumber] as? String ?? ""
                                    contactNote = userData[FirestoreSchema.User.note] as? String ?? ""
                                    contactQRCodeId = userData[FirestoreSchema.User.qrCodeId] as? String

                                    print("DEBUG: Fetched user data - name: \(contactName), phone: \(contactPhone)")
                                }
                            }

                            // Wait for the user document fetch to complete
                            group.wait()

                            // Create a Contact object with the fetched data
                            let contact = Contact(
                                id: UUID(uuidString: document.documentID) ?? UUID(),
                                name: contactName,
                                phone: contactPhone,
                                note: contactNote,
                                qrCodeId: contactQRCodeId,
                                isResponder: isResponder,
                                isDependent: isDependent,
                                addedAt: addedAt.dateValue()
                            )

                            loadedContacts.append(contact)
                            print("DEBUG: Added contact from referencePath: \(contact.name), isResponder: \(contact.isResponder), isDependent: \(contact.isDependent)")
                            continue
                        }
                    }

                    // If we get here, try the old format
                    // Extract required fields
                    let id = data[FirestoreSchema.Contact.id] as? String
                    let name = data[FirestoreSchema.Contact.name] as? String
                    let phone = data[FirestoreSchema.Contact.phoneNumber] as? String
                    let note = data[FirestoreSchema.Contact.note] as? String
                    let isResponder = data[FirestoreSchema.Contact.isResponder] as? Bool
                    let isDependent = data[FirestoreSchema.Contact.isDependent] as? Bool
                    let addedAtTimestamp = data[FirestoreSchema.Contact.addedAt] as? Timestamp

                    print("DEBUG: Parsed fields - id: \(id ?? "nil"), name: \(name ?? "nil"), isResponder: \(isResponder.map(String.init) ?? "nil"), isDependent: \(isDependent.map(String.init) ?? "nil")")

                    guard let id = id,
                          let name = name,
                          let phone = phone,
                          let note = note,
                          let isResponder = isResponder,
                          let isDependent = isDependent,
                          let addedAtTimestamp = addedAtTimestamp else {
                        print("DEBUG: Invalid contact data in Firestore document: \(document.documentID)")
                        print("DEBUG: Missing fields - id: \(id == nil), name: \(name == nil), phone: \(phone == nil), note: \(note == nil), isResponder: \(isResponder == nil), isDependent: \(isDependent == nil), addedAt: \(addedAtTimestamp == nil)")
                        continue
                    }

                    // Extract optional fields
                    let qrCodeId = data[FirestoreSchema.Contact.qrCodeId] as? String
                    let lastCheckInTimestamp = data[FirestoreSchema.Contact.lastCheckedIn] as? Timestamp
                    let interval = data[FirestoreSchema.Contact.checkInInterval] as? TimeInterval
                    let manualAlertActive = data[FirestoreSchema.Contact.manualAlertActive] as? Bool ?? false
                    let manualAlertTimestamp = data[FirestoreSchema.Contact.manualAlertTimestamp] as? Timestamp
                    let hasIncomingPing = data[FirestoreSchema.Contact.hasIncomingPing] as? Bool ?? false
                    let hasOutgoingPing = data[FirestoreSchema.Contact.hasOutgoingPing] as? Bool ?? false
                    let incomingPingTimestamp = data[FirestoreSchema.Contact.incomingPingTimestamp] as? Timestamp
                    let outgoingPingTimestamp = data[FirestoreSchema.Contact.outgoingPingTimestamp] as? Timestamp

                    // Create Contact object
                    let contact = Contact(
                        id: UUID(uuidString: id) ?? UUID(),
                        name: name,
                        phone: phone,
                        note: note,
                        qrCodeId: qrCodeId,
                        isResponder: isResponder,
                        isDependent: isDependent,
                        lastCheckIn: lastCheckInTimestamp?.dateValue(),
                        interval: interval,
                        addedAt: addedAtTimestamp.dateValue(),
                        manualAlertActive: manualAlertActive,
                        manualAlertTimestamp: manualAlertTimestamp?.dateValue(),
                        hasIncomingPing: hasIncomingPing,
                        hasOutgoingPing: hasOutgoingPing,
                        incomingPingTimestamp: incomingPingTimestamp?.dateValue(),
                        outgoingPingTimestamp: outgoingPingTimestamp?.dateValue()
                    )

                    loadedContacts.append(contact)
                }

                // Update contacts list
                DispatchQueue.main.async {
                    self.contacts = loadedContacts
                    print("DEBUG: Loaded \(loadedContacts.count) contacts from Firestore")
                    print("DEBUG: Responders count: \(self.responders.count), Dependents count: \(self.dependents.count)")

                    // Force refresh the UI
                    self.postUIRefreshNotifications()

                    completion?(true)
                }
            }
        }
    }

    // MARK: - Status Updates

    /// Force reload contacts from Firestore and refresh the UI
    func forceReloadContacts(completion: ((Bool) -> Void)? = nil) {
        print("DEBUG: Force reloading contacts from Firestore")

        loadContactsFromFirestore { [weak self] success in
            guard let self = self else {
                completion?(false)
                return
            }

            print("DEBUG: Force reload completed with success: \(success)")
            print("DEBUG: After force reload - Contacts count: \(self.contacts.count)")
            print("DEBUG: After force reload - Responders count: \(self.responders.count)")
            print("DEBUG: After force reload - Dependents count: \(self.dependents.count)")

            // Force refresh the UI
            self.postUIRefreshNotifications()

            completion?(success)
        }
    }

    /// Calculate the count of non-responsive dependents
    func calculateNonResponsiveDependentsCount() -> Int {
        // Count dependents who are either non-responsive or have a manual alert active
        return contacts.filter { contact in
            // Only count dependents
            guard contact.isDependent else { return false }

            // If manual alert is active, always count as non-responsive
            if contact.manualAlertActive { return true }

            // Use the contact's isNonResponsive computed property
            return contact.isNonResponsive
        }.count
    }

    /// Update the count of non-responsive dependents
    func updateNonResponsiveDependentsCount() {
        nonResponsiveDependentsCount = calculateNonResponsiveDependentsCount()
    }

    // MARK: - Ping Methods

    /// Enum representing the type of ping operation
    enum PingOperation {
        case send
        case respond
        case clear
    }

    /// Handle a ping operation for a contact
    /// - Parameters:
    ///   - operation: The type of ping operation
    ///   - contact: The contact to perform the operation on
    ///   - completion: Optional callback with success flag and error
    func handlePingOperation(operation: PingOperation, for contact: Contact, completion: ((Bool, Error?) -> Void)? = nil) {
        let now = Date()
        let updated = updateLocalContact(contact) { updatedContact in
            switch operation {
            case .send:
                updatedContact.hasOutgoingPing = true
                updatedContact.outgoingPingTimestamp = now
                print("Sent ping to contact: \(updatedContact.name)")
            case .respond:
                updatedContact.hasIncomingPing = false
                updatedContact.incomingPingTimestamp = nil
                print("Responded to ping from contact: \(updatedContact.name)")
            case .clear:
                updatedContact.hasOutgoingPing = false
                updatedContact.outgoingPingTimestamp = nil
                print("Cleared outgoing ping for contact: \(updatedContact.name)")
            }
        }

        if !updated {
            let error = Self.createError(code: .notFound, message: "Contact not found")
            completion?(false, error)
            return
        }

        // Update the contact relationship using the cloud function
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            updateContactRelationship(contacts[index], updatePings: true) { success, error in
                if let error = error {
                    print("Error updating ping status: \(error.localizedDescription)")
                    completion?(false, error)
                    return
                }

                print("Ping status updated successfully")
                completion?(true, nil)
            }
        }

        updatePendingPingsCount()
    }

    /// Send a ping to a responder
    /// - Parameters:
    ///   - responder: The responder to ping
    ///   - completion: Optional callback with success flag and error
    func sendPing(to responder: Contact, completion: ((Bool, Error?) -> Void)? = nil) {
        handlePingOperation(operation: .send, for: responder, completion: completion)
    }

    /// Send a ping to a dependent
    /// - Parameters:
    ///   - dependent: The dependent to ping
    ///   - completion: Optional callback with success flag and error
    func pingDependent(_ dependent: Contact, completion: ((Bool, Error?) -> Void)? = nil) {
        // This is now just an alias for sendPing for consistency
        sendPing(to: dependent, completion: completion)
    }

    /// Respond to a ping from a responder
    /// - Parameters:
    ///   - responder: The responder whose ping to respond to
    ///   - completion: Optional callback with success flag and error
    func respondToPing(from responder: Contact, completion: ((Bool, Error?) -> Void)? = nil) {
        handlePingOperation(operation: .respond, for: responder, completion: completion)
    }

    /// Clear an outgoing ping for a dependent
    /// - Parameters:
    ///   - dependent: The dependent whose ping to clear
    ///   - completion: Optional callback with success flag and error
    func clearPing(for dependent: Contact, completion: ((Bool, Error?) -> Void)? = nil) {
        // This is now just an alias for clearOutgoingPing for consistency
        clearOutgoingPing(for: dependent, completion: completion)
    }

    /// Clear an outgoing ping for a contact
    /// - Parameters:
    ///   - contact: The contact whose ping to clear
    ///   - completion: Optional callback with success flag and error
    func clearOutgoingPing(for contact: Contact, completion: ((Bool, Error?) -> Void)? = nil) {
        handlePingOperation(operation: .clear, for: contact, completion: completion)
    }

    /// Respond to all pending pings
    /// - Parameter completion: Optional callback with success flag and error
    func respondToAllPings(completion: ((Bool, Error?) -> Void)? = nil) {
        // Get all responders with incoming pings
        let respondersWithPings = contacts.filter { $0.isResponder && $0.hasIncomingPing }

        // If no contacts to update, return success
        if respondersWithPings.isEmpty {
            completion?(true, nil)
            return
        }

        // Update all contacts locally first
        var updatedContacts = contacts
        for i in 0..<updatedContacts.count {
            if updatedContacts[i].isResponder && updatedContacts[i].hasIncomingPing {
                updatedContacts[i].hasIncomingPing = false
                updatedContacts[i].incomingPingTimestamp = nil
            }
        }

        // Update the contacts array
        contacts = updatedContacts
        updatePendingPingsCount()

        // Post notifications to refresh the UI
        postUIRefreshNotifications()

        // Update all contacts in Firestore using the cloud function
        let group = DispatchGroup()
        var errors: [Error] = []

        for contact in respondersWithPings {
            group.enter()
            updateContactRelationship(contact, updatePings: true) { success, error in
                if let error = error {
                    print("Error updating ping status: \(error.localizedDescription)")
                    errors.append(error)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if errors.isEmpty {
                completion?(true, nil)
            } else {
                completion?(false, errors.first)
            }
        }
    }

    /// Calculate the count of pending pings
    func calculatePendingPingsCount() -> Int {
        return contacts.filter { $0.isResponder && $0.hasIncomingPing }.count
    }

    /// Update the count of pending pings
    func updatePendingPingsCount() {
        pendingPingsCount = calculatePendingPingsCount()
    }

    // MARK: - Alert Methods

    /// Update the alert status in Firestore and notify responders
    /// - Parameters:
    ///   - isActive: Whether the alert is active
    ///   - completion: Optional callback with success flag and error
    func updateAlertStatus(isActive: Bool, completion: ((Bool, Error?) -> Void)? = nil) {
        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            print("Cannot update alert status: No authenticated user")
            completion?(false, NSError(domain: "UserViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }

        // Update alert status in Firestore
        let updateData: [String: Any] = [
            "manualAlertActive": isActive,
            "manualAlertTimestamp": isActive ? FieldValue.serverTimestamp() : FieldValue.delete(),
            FirestoreSchema.User.lastUpdated: FieldValue.serverTimestamp()
        ]

        // Get reference to the user document
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreSchema.Collections.users).document(userId)

        // Update the document
        userRef.updateData(updateData) { [weak self] error in
            if let error = error {
                print("Error updating alert status in Firestore: \(error.localizedDescription)")

                // Revert the local state if the update failed
                DispatchQueue.main.async {
                    self?.sendAlertActive = !isActive
                }

                completion?(false, error)
                return
            }

            print("Alert status updated in Firestore")

            // Send or cancel the alert notification to responders
            if isActive {
                NotificationService.shared.sendManualAlert(userId: userId) { success, error in
                    if let error = error {
                        print("Error sending manual alert: \(error.localizedDescription)")
                        completion?(false, error)
                        return
                    }

                    print("Manual alert sent to responders")
                    completion?(true, nil)
                }
            } else {
                NotificationService.shared.cancelManualAlert(userId: userId) { success, error in
                    if let error = error {
                        print("Error canceling manual alert: \(error.localizedDescription)")
                        completion?(false, error)
                        return
                    }

                    print("Manual alert canceled")
                    completion?(true, nil)
                }
            }
        }
    }
}