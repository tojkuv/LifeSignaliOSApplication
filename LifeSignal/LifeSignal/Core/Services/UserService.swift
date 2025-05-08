import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

/// Service class for user data operations
class UserService {
    // Singleton instance
    static let shared = UserService()

    // Firestore reference
    private let db = Firestore.firestore()

    // Users collection reference
    private var usersCollection: CollectionReference {
        return db.collection("users")
    }

    // Private initializer for singleton
    private init() {}

    /// Get the current user's document reference
    /// - Returns: DocumentReference for the current user or nil if not authenticated
    private func getCurrentUserDocument() -> DocumentReference? {
        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            print("Error: No authenticated user")
            return nil
        }

        return usersCollection.document(userId)
    }

    /// Get user data for the current authenticated user
    /// - Parameter completion: Callback with user data and error
    func getCurrentUserData(completion: @escaping ([String: Any]?, Error?) -> Void) {
        guard let userDoc = getCurrentUserDocument() else {
            print("getCurrentUserData: User not authenticated")
            completion(nil, NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }

        print("Getting user data for document: \(userDoc.documentID)")

        userDoc.getDocument { document, error in
            if let error = error {
                print("Error getting user document: \(error.localizedDescription)")
                completion(nil, error)
                return
            }

            guard let document = document, document.exists else {
                print("User document does not exist for ID: \(userDoc.documentID)")

                // For new users, we'll create a basic document
                if let phoneNumber = Auth.auth().currentUser?.phoneNumber {
                    print("Creating basic document for new user with phone: \(phoneNumber)")

                    // Generate a QR code ID for the new user - CRITICAL FIELD
                    let qrCodeId = UUID().uuidString
                    print("Generated QR code ID for new user: \(qrCodeId)")

                    let userData: [String: Any] = [
                        "uid": userDoc.documentID,
                        "phoneNumber": phoneNumber,
                        "createdAt": FieldValue.serverTimestamp(),
                        "lastSignInTime": FieldValue.serverTimestamp(),
                        "profileComplete": false,
                        "qrCodeId": qrCodeId,
                        "name": "New User", // Required field
                        "note": "", // Required field
                        "checkInInterval": 24 * 60 * 60, // 24 hours in seconds
                        "lastCheckedIn": FieldValue.serverTimestamp(),
                        // Initialize other fields with default values
                        "notificationEnabled": true,
                        "notify30MinBefore": false,
                        "notify2HoursBefore": false,
                        "manualAlertActive": false,
                        "contacts": []
                    ]

                    // Log the data we're about to save
                    print("Creating basic user document with fields: \(userData.keys.joined(separator: ", "))")

                    // Use setData with merge option to ensure we don't overwrite existing fields
                    userDoc.setData(userData, merge: true) { error in
                        if let error = error {
                            print("Error creating basic user document: \(error.localizedDescription)")

                            // Check if it's a permission error
                            if let nsError = error as NSError?, nsError.domain == "FIRFirestoreErrorDomain" {
                                print("Firestore error code: \(nsError.code)")
                                print("Firestore error details: \(nsError.userInfo)")
                            }

                            completion(nil, NSError(domain: "UserService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to create user document: \(error.localizedDescription)"]))
                        } else {
                            print("Created basic user document for new user")
                            completion(userData, nil)
                        }
                    }
                    return
                }

                completion(nil, NSError(domain: "UserService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User document not found"]))
                return
            }

            print("Found user document with data")
            completion(document.data(), nil)
        }
    }

    /// Update user data for the current authenticated user
    /// - Parameters:
    ///   - data: The data to update
    ///   - completion: Callback with success flag and error
    func updateCurrentUserData(data: [String: Any], completion: @escaping (Bool, Error?) -> Void) {
        guard let userDoc = getCurrentUserDocument() else {
            completion(false, NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }

        userDoc.updateData(data) { error in
            if let error = error {
                print("Error updating user document: \(error.localizedDescription)")
                completion(false, error)
                return
            }

            completion(true, nil)
        }
    }

    /// Create user data for the current authenticated user if it doesn't exist
    /// - Parameters:
    ///   - data: The initial user data
    ///   - completion: Callback with success flag and error
    func createUserDataIfNeeded(data: [String: Any], completion: @escaping (Bool, Error?) -> Void) {
        guard let userDoc = getCurrentUserDocument() else {
            completion(false, NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }

        userDoc.getDocument { document, error in
            if let error = error {
                print("Error checking user document: \(error.localizedDescription)")
                completion(false, error)
                return
            }

            if let document = document, document.exists {
                // Document already exists
                completion(true, nil)
                return
            }

            // Document doesn't exist, create it with user data
            var userData = data

            // Add additional fields if they don't exist
            if userData["uid"] == nil, let uid = AuthenticationService.shared.getCurrentUserID() {
                userData["uid"] = uid
            }

            if userData["createdAt"] == nil {
                userData["createdAt"] = FieldValue.serverTimestamp()
            }

            if userData["lastSignInTime"] == nil {
                userData["lastSignInTime"] = FieldValue.serverTimestamp()
            }

            if userData["phoneNumber"] == nil, let phoneNumber = Auth.auth().currentUser?.phoneNumber {
                userData["phoneNumber"] = phoneNumber
            }

            // Document doesn't exist, create it
            userDoc.setData(userData) { error in
                if let error = error {
                    print("Error creating user document: \(error.localizedDescription)")
                    completion(false, error)
                    return
                }

                print("Successfully created user document for user: \(userDoc.documentID)")
                completion(true, nil)
            }
        }
    }

    /// Get user data for a specific user ID
    /// - Parameters:
    ///   - userId: The user ID to get data for
    ///   - completion: Callback with user data and error
    func getUserData(userId: String, completion: @escaping ([String: Any]?, Error?) -> Void) {
        // Check if user is authenticated
        guard AuthenticationService.shared.isAuthenticated else {
            completion(nil, NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }

        usersCollection.document(userId).getDocument { document, error in
            if let error = error {
                print("Error getting user document: \(error.localizedDescription)")
                completion(nil, error)
                return
            }

            guard let document = document, document.exists else {
                print("User document does not exist")
                completion(nil, NSError(domain: "UserService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User document not found"]))
                return
            }

            completion(document.data(), nil)
        }
    }

    /// Create the test user document if it doesn't exist
    /// - Parameter completion: Callback with success flag and error
    func createTestUserIfNeeded(completion: @escaping (Bool, Error?) -> Void) {
        // Get current user ID
        guard let currentUserId = AuthenticationService.shared.getCurrentUserID() else {
            print("createTestUserIfNeeded: User not authenticated")
            completion(false, NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }

        // Get current user phone number
        guard let phoneNumber = Auth.auth().currentUser?.phoneNumber else {
            print("createTestUserIfNeeded: Phone number not available")
            completion(false, NSError(domain: "UserService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Phone number not available"]))
            return
        }

        print("Creating test user for phone: \(phoneNumber), user ID: \(currentUserId)")

        // Determine which test user this is
        let isFirstTestUser = phoneNumber == "+11234567890"
        let isSecondTestUser = phoneNumber == "+16505553434"

        // Only proceed for known test users
        guard isFirstTestUser || isSecondTestUser else {
            print("createTestUserIfNeeded: Not a recognized test user: \(phoneNumber)")
            completion(false, NSError(domain: "UserService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Not a recognized test user"]))
            return
        }

        let testUserDoc = usersCollection.document(currentUserId)

        testUserDoc.getDocument { document, error in
            if let error = error {
                print("Error checking test user document: \(error.localizedDescription)")
                completion(false, error)
                return
            }

            if let document = document, document.exists {
                // Document already exists
                print("Test user document already exists for \(phoneNumber)")
                completion(true, nil)
                return
            }

            // Generate a QR code ID - CRITICAL FIELD
            let qrCodeId = UUID().uuidString
            print("Generated QR code ID for test user: \(qrCodeId)")

            // Document doesn't exist, create it with all required fields
            var userData: [String: Any] = [
                "uid": currentUserId,
                "phoneNumber": phoneNumber,
                "createdAt": FieldValue.serverTimestamp(),
                "lastSignInTime": FieldValue.serverTimestamp(),
                "profileComplete": true,
                "notificationEnabled": true,
                "testUser": true,
                "qrCodeId": qrCodeId,
                "checkInInterval": 24 * 60 * 60, // 24 hours in seconds
                "lastCheckedIn": FieldValue.serverTimestamp(),
                "note": "This is a test user account",
                // Initialize other fields with default values
                "notify30MinBefore": false,
                "notify2HoursBefore": false,
                "manualAlertActive": false,
                "manualAlertTimestamp": FieldValue.serverTimestamp(),
                "contacts": []
            ]

            // Set user-specific data
            if isFirstTestUser {
                userData["name"] = "Test User 1" // Required field
                userData["email"] = "test1@example.com"
                userData["note"] = "This is test user 1 with phone +11234567890" // Override the default note
            } else if isSecondTestUser {
                userData["name"] = "Test User 2" // Required field
                userData["email"] = "test2@example.com"
                userData["note"] = "This is test user 2 with phone +16505553434" // Override the default note
            } else {
                userData["name"] = "Unknown Test User" // Ensure name is always set (required field)
            }

            // Log the data we're about to save
            print("Creating test user document with fields: \(userData.keys.joined(separator: ", "))")

            // Use setData with merge option to ensure we don't overwrite existing fields
            testUserDoc.setData(userData, merge: true) { error in
                if let error = error {
                    print("Error creating test user document: \(error.localizedDescription)")

                    // Check if it's a permission error
                    if let nsError = error as NSError?, nsError.domain == "FIRFirestoreErrorDomain" {
                        print("Firestore error code: \(nsError.code)")
                        print("Firestore error details: \(nsError.userInfo)")
                    }

                    completion(false, error)
                    return
                }

                print("Successfully created test user document for \(phoneNumber)")
                completion(true, nil)
            }
        }
    }

    /// Test accessing the specific user with ID Jkp4pSeWl9ZIT9t0tMUdR3dCu2w2
    /// - Parameter completion: Callback with result string, success flag, and user data
    func testAccessSpecificUser(completion: @escaping (String, Bool, [String: Any]?) -> Void) {
        // Check if user is authenticated
        guard AuthenticationService.shared.isAuthenticated else {
            completion("Error: User not authenticated. Please sign in first.", false, nil)
            return
        }

        let specificUserId = "Jkp4pSeWl9ZIT9t0tMUdR3dCu2w2"
        let currentUserId = AuthenticationService.shared.getCurrentUserID() ?? "unknown"

        print("Testing access to user \(specificUserId). Current user ID: \(currentUserId)")

        // Otherwise, proceed with the actual Firestore query
        usersCollection.document(specificUserId).getDocument { document, error in
            if let error = error {
                let errorMessage = error.localizedDescription

                // Check if this is a permissions error
                if errorMessage.contains("Missing or insufficient permissions") {
                    completion("Permission denied: Cannot access user data.\n\nThis is expected if you're not authenticated as this specific user (Jkp4pSeWl9ZIT9t0tMUdR3dCu2w2).\n\nFirestore security rules only allow users to read their own data.", false, nil)
                } else {
                    completion("Error accessing user data: \(errorMessage)", false, nil)
                }
                return
            }

            guard let document = document, document.exists else {
                completion("User document does not exist for ID: \(specificUserId)", false, nil)
                return
            }

            if let data = document.data() {
                // Create a summary of the data for logging purposes
                let _ = data.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
                completion("Successfully accessed user data!\n\nUser ID: \(specificUserId)", true, data)
            } else {
                completion("User document exists but has no data", false, nil)
            }
        }
    }
}
