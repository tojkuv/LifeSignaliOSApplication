import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

/// ViewModel for managing user profile data and interactions with Firestore
///
/// This view model is responsible for handling all user profile-related operations including:
/// - Loading and saving basic user information (name, phone, profile description)
/// - Managing the user's QR code for contact discovery
/// - Synchronizing user data with Firestore
///
/// It is part of the app's MVVM architecture and works alongside other view models
/// like ContactsViewModel and CheckInViewModel to provide a complete user data management solution.
class UserProfileViewModel: ObservableObject {
    // MARK: - Published Properties

    /// User's full name
    ///
    /// This property is displayed in the UI and shared with contacts.
    /// It is synchronized with Firestore and used to identify the user to their contacts.
    /// Default value is a placeholder that should be replaced during onboarding.
    @Published var name = "First Last"

    /// User's phone number in E.164 format
    ///
    /// This property is typically populated from Firebase Authentication
    /// and is used for SMS notifications and contact information.
    /// It is stored in Firestore and shared with the user's contacts.
    @Published var phone: String = ""

    /// User's unique QR code identifier
    ///
    /// This UUID is used to generate the QR code that other users can scan
    /// to add this user as a contact. It is stored in both the user document
    /// and in the qr_lookup collection for discovery.
    /// A new random UUID is generated on initialization.
    @Published var qrCodeId = UUID().uuidString

    /// User's emergency profile description
    ///
    /// This text contains important emergency information that should be
    /// accessible to responders in case of an emergency.
    /// For example, medical conditions, allergies, or emergency contact instructions.
    /// Default value is a placeholder that should be replaced during onboarding.
    @Published var profileDescription: String = "I have a severe peanut allergy - EpiPen is always in my backpack's front pocket."

    /// Flag indicating if user data has been loaded from Firestore
    ///
    /// This property is used to track whether the view model has successfully
    /// loaded user data from Firestore. It can be used by views to determine
    /// if they should display placeholder content or actual user data.
    @Published var isDataLoaded: Bool = false

    // MARK: - Initialization

    init() {
        // Generate a random QR code ID for the user
        qrCodeId = UUID().uuidString

        print("UserProfileViewModel: Initializing with authentication state: \(AuthenticationService.shared.isAuthenticated)")

        // Try to load user data from Firestore if authenticated
        if AuthenticationService.shared.isAuthenticated {
            print("UserProfileViewModel: Loading user data from Firestore")
            loadUserData { [weak self] success in
                guard let self = self else { return }

                print("UserProfileViewModel: User data loaded successfully: \(success)")
            }
        }
    }

    // MARK: - Firestore Integration

    /// Load user data from Firestore
    ///
    /// This method retrieves the user's profile data from Firestore and updates the view model properties.
    /// It requires an authenticated user and will fail if no user is signed in or if the user document
    /// doesn't exist in Firestore.
    ///
    /// - Parameter completion: Optional callback that is called when data loading completes.
    ///   The boolean parameter indicates success (true) or failure (false).
    /// - Note: This method is automatically called during initialization if a user is authenticated.
    func loadUserData(completion: ((Bool) -> Void)? = nil) {
        guard AuthenticationService.shared.isAuthenticated else {
            print("UserProfileViewModel: ERROR - Cannot load user data: No authenticated user")
            completion?(false)
            return
        }

        // Get the current user ID
        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            print("UserProfileViewModel: ERROR - Cannot load user data: User ID not available")
            completion?(false)
            return
        }

        // Get reference to the user document
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreCollections.users).document(userId)

        // Get the document
        userRef.getDocument { [weak self] document, error in
            guard let self = self else { return }

            if let error = error {
                print("UserProfileViewModel: ERROR - Failed to load user data: \(error.localizedDescription)")
                completion?(false)
                return
            }

            guard let document = document, document.exists, let userData = document.data() else {
                print("UserProfileViewModel: ERROR - User document not found in Firestore")
                completion?(false)
                return
            }

            self.updateFromFirestore(userData: userData)
            completion?(true)
        }
    }

    /// Update the view model with data from Firestore
    ///
    /// This method updates the view model's properties with values from a Firestore document.
    /// It handles type conversion and safely updates only the properties that exist in the document.
    /// All updates are performed on the main thread to ensure UI updates are thread-safe.
    ///
    /// - Parameter userData: Dictionary containing user data retrieved from Firestore.
    ///   Expected keys are defined in FirestoreSchema.User.
    /// - Note: This method is typically called internally after retrieving data from Firestore,
    ///   but can also be used to update the view model from externally retrieved data.
    func updateFromFirestore(userData: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Update basic user information
            if let name = userData[UserFields.name] as? String {
                self.name = name
            }

            if let phone = userData[UserFields.phoneNumber] as? String {
                self.phone = phone
            }

            if let qrCodeId = userData[UserFields.qrCodeId] as? String {
                self.qrCodeId = qrCodeId
            }

            if let note = userData[UserFields.note] as? String {
                self.profileDescription = note
            }

            // Mark data as loaded
            self.isDataLoaded = true

            print("UserProfileViewModel: User profile data updated from Firestore")
        }
    }

    /// Save user data to Firestore
    ///
    /// This method saves the current state of the view model to the user's Firestore document.
    /// It automatically includes basic user information (name, profile description, QR code ID)
    /// and can accept additional data to be saved in the same operation.
    ///
    /// - Parameters:
    ///   - additionalData: Optional dictionary of additional fields to save to Firestore.
    ///     These values will be merged with the basic user data.
    ///   - completion: Optional callback that is called when the save operation completes.
    ///     The boolean parameter indicates success (true) or failure (false).
    ///     If an error occurs, it will be passed as the second parameter.
    ///
    /// - Note: This method uses Firestore's merge functionality, so it will only update
    ///   the specified fields without overwriting the entire document.
    /// - Important: This method requires an authenticated user and will fail if no user is signed in.
    func saveUserData(additionalData: [String: Any]? = nil, completion: ((Bool, Error?) -> Void)? = nil) {
        guard AuthenticationService.shared.isAuthenticated else {
            completion?(false, NSError(domain: "UserProfileViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }

        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            completion?(false, NSError(domain: "UserProfileViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User ID not available"]))
            return
        }

        // Create base user data
        var userData: [String: Any] = [
            UserFields.name: name,
            UserFields.note: profileDescription,
            UserFields.qrCodeId: qrCodeId,
            UserFields.lastUpdated: FieldValue.serverTimestamp()
        ]

        // Add phone number if available from Auth
        if let phoneNumber = Auth.auth().currentUser?.phoneNumber, !phoneNumber.isEmpty {
            userData[UserFields.phoneNumber] = phoneNumber
        }

        // Ensure UID is set
        userData[UserFields.uid] = userId

        // Add profile complete flag
        userData[UserFields.profileComplete] = true

        // Add any additional data
        if let additionalData = additionalData {
            for (key, value) in additionalData {
                userData[key] = value
            }
        }

        // Save to Firestore
        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            let error = NSError(domain: "UserProfileViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User ID not available"])
            print("UserProfileViewModel: ERROR - Failed to save user data: \(error.localizedDescription)")
            completion?(false, error)
            return
        }

        // Get reference to the user document
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreCollections.users).document(userId)

        // Update the document
        userRef.setData(userData, merge: true) { error in
            if let error = error {
                print("UserProfileViewModel: ERROR - Failed to save user data to Firestore: \(error.localizedDescription)")
                completion?(false, error)
                return
            }

            print("UserProfileViewModel: User data successfully saved to Firestore")
            completion?(true, nil)
        }
    }

    /// Create a new user document in Firestore
    /// - Parameters:
    ///   - completion: Optional callback with success flag and error
    func createUserDocument(completion: ((Bool, Error?) -> Void)? = nil) {
        guard AuthenticationService.shared.isAuthenticated else {
            completion?(false, NSError(domain: "UserProfileViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }

        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            completion?(false, NSError(domain: "UserProfileViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User ID not available"]))
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

        // Get reference to the user document
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreCollections.users).document(userId)

        // Set the document data
        userRef.setData(userData, merge: true) { error in
            if let error = error {
                print("UserProfileViewModel: ERROR - Failed to create user document: \(error.localizedDescription)")
                completion?(false, error)
                return
            }

            print("UserProfileViewModel: User document created successfully")
            completion?(true, nil)
        }
    }

    // MARK: - QR Code Management

    /// Update or create a QR lookup document for a user
    ///
    /// This private method creates or updates a document in the qr_lookup collection
    /// that maps a QR code ID to a user ID. This enables other users to find this user
    /// by scanning their QR code.
    ///
    /// - Parameters:
    ///   - userId: The Firebase user ID (document ID in the users collection)
    ///   - qrCodeId: The QR code identifier to associate with this user
    ///   - completion: Callback that is called when the operation completes.
    ///     The boolean parameter indicates success (true) or failure (false).
    ///     If an error occurs, it will be passed as the second parameter.
    ///
    /// - Note: The QR lookup document uses the user ID as its document ID to ensure
    ///   there is only one lookup document per user.
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
        db.collection(FirestoreCollections.qrLookup).document(userId).setData(qrLookupData) { error in
            if let error = error {
                print("UserProfileViewModel: ERROR - Failed to update QR lookup: \(error.localizedDescription)")
                completion(false, error)
                return
            }

            print("UserProfileViewModel: QR lookup updated for user \(userId)")
            completion(true, nil)
        }
    }

    /// Generates a new QR code ID for the user
    ///
    /// This method creates a new random UUID to use as the user's QR code identifier,
    /// updates it in Firestore, and updates the QR lookup document. This is useful when
    /// a user wants to invalidate their old QR code for security reasons.
    ///
    /// - Parameter completion: Optional callback that is called when the operation completes.
    ///   The boolean parameter indicates success (true) or failure (false).
    ///   If an error occurs, it will be passed as the second parameter.
    ///
    /// - Note: This method updates both the user document and the QR lookup document
    ///   to ensure consistency between the two.
    /// - Important: This method requires an authenticated user and will fail if no user is signed in.
    func generateNewQRCode(completion: ((Bool, Error?) -> Void)? = nil) {
        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            completion?(false, NSError(domain: "UserProfileViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }

        // Generate a new QR code ID
        qrCodeId = UUID().uuidString

        // Save to Firestore
        let updateData: [String: Any] = [
            UserFields.qrCodeId: qrCodeId,
            UserFields.lastUpdated: FieldValue.serverTimestamp()
        ]

        // Get reference to the user document
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreCollections.users).document(userId)

        // Update the document
        userRef.updateData(updateData) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                print("UserProfileViewModel: ERROR - Failed to update QR code ID in Firestore: \(error.localizedDescription)")
                completion?(false, error)
                return
            }

            // Update the QR lookup database
            self.updateQRLookup(userId: userId, qrCodeId: self.qrCodeId) { success, error in
                if let error = error {
                    print("UserProfileViewModel: ERROR - Failed to update QR lookup database: \(error.localizedDescription)")
                    // Not critical, so still return success for the main operation
                }

                print("UserProfileViewModel: QR code ID successfully updated in Firestore and QR lookup database")
                completion?(true, nil)
            }
        }
    }

    // MARK: - User Profile Updates

    /// Updates the user's name in Firestore
    ///
    /// This method updates the user's name both locally and in Firestore.
    /// It uses Firestore's updateData method to only update the name field
    /// without affecting other fields in the document.
    ///
    /// - Parameters:
    ///   - newName: The new name to set for the user
    ///   - completion: Optional callback that is called when the update completes.
    ///     The boolean parameter indicates success (true) or failure (false).
    ///     If an error occurs, it will be passed as the second parameter.
    ///
    /// - Note: This method updates the local property immediately and then
    ///   synchronizes with Firestore. If the Firestore update fails, the local
    ///   property will still have been updated.
    /// - Important: This method requires an authenticated user and will fail if no user is signed in.
    func updateName(_ newName: String, completion: ((Bool, Error?) -> Void)? = nil) {
        // Update local property
        name = newName

        // Save to Firestore
        let updateData: [String: Any] = [
            UserFields.name: newName,
            UserFields.lastUpdated: FieldValue.serverTimestamp()
        ]

        // Get the current user ID
        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            let error = NSError(domain: "UserProfileViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User ID not available"])
            print("UserProfileViewModel: ERROR - Failed to update name: \(error.localizedDescription)")
            completion?(false, error)
            return
        }

        // Get reference to the user document
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreCollections.users).document(userId)

        // Update the document
        userRef.updateData(updateData) { error in
            if let error = error {
                print("UserProfileViewModel: ERROR - Failed to update name in Firestore: \(error.localizedDescription)")
                completion?(false, error)
                return
            }

            print("UserProfileViewModel: Name successfully updated in Firestore")
            completion?(true, nil)
        }
    }

    /// Updates the user's emergency note in Firestore
    ///
    /// This method updates the user's emergency profile description both locally and in Firestore.
    /// The emergency note contains important information that should be accessible to responders
    /// in case of an emergency.
    ///
    /// - Parameters:
    ///   - newNote: The new emergency note/description to set
    ///   - completion: Optional callback that is called when the update completes.
    ///     The boolean parameter indicates success (true) or failure (false).
    ///     If an error occurs, it will be passed as the second parameter.
    ///
    /// - Note: This method updates the local property immediately and then
    ///   synchronizes with Firestore. If the Firestore update fails, the local
    ///   property will still have been updated.
    /// - Important: This method requires an authenticated user and will fail if no user is signed in.
    func updateEmergencyNote(_ newNote: String, completion: ((Bool, Error?) -> Void)? = nil) {
        // Update local property
        profileDescription = newNote

        // Save to Firestore
        let updateData: [String: Any] = [
            UserFields.note: newNote,
            UserFields.lastUpdated: FieldValue.serverTimestamp()
        ]

        // Get the current user ID
        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            let error = NSError(domain: "UserProfileViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User ID not available"])
            print("UserProfileViewModel: ERROR - Failed to update emergency note: \(error.localizedDescription)")
            completion?(false, error)
            return
        }

        // Get reference to the user document
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreCollections.users).document(userId)

        // Update the document
        userRef.updateData(updateData) { error in
            if let error = error {
                print("UserProfileViewModel: ERROR - Failed to update emergency note in Firestore: \(error.localizedDescription)")
                completion?(false, error)
                return
            }

            print("UserProfileViewModel: Emergency note successfully updated in Firestore")
            completion?(true, nil)
        }
    }
}
