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
            completion(nil, NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }

        userDoc.getDocument { document, error in
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
        let testUserId = "Jkp4pSeWl9ZIT9t0tMUdR3dCu2w2"
        let testUserDoc = usersCollection.document(testUserId)

        // Check if the user is authenticated
        guard AuthenticationService.shared.isAuthenticated else {
            completion(false, NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }

        // Check if the current user is the test user
        guard AuthenticationService.shared.getCurrentUserID() == testUserId else {
            completion(false, NSError(domain: "UserService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only the test user can create their own document"]))
            return
        }

        testUserDoc.getDocument { document, error in
            if let error = error {
                print("Error checking test user document: \(error.localizedDescription)")
                completion(false, error)
                return
            }

            if let document = document, document.exists {
                // Document already exists
                print("Test user document already exists")
                completion(true, nil)
                return
            }

            // Document doesn't exist, create it
            let userData: [String: Any] = [
                "uid": testUserId,
                "name": "Test User",
                "email": "test@example.com",
                "phoneNumber": "+11234567890",
                "createdAt": FieldValue.serverTimestamp(),
                "lastSignInTime": FieldValue.serverTimestamp(),
                "profileComplete": true,
                "notificationEnabled": true,
                "testUser": true
            ]

            testUserDoc.setData(userData) { error in
                if let error = error {
                    print("Error creating test user document: \(error.localizedDescription)")
                    completion(false, error)
                    return
                }

                print("Successfully created test user document")
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
                let dataString = data.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
                completion("Successfully accessed user data!\n\nUser ID: \(specificUserId)", true, data)
            } else {
                completion("User document exists but has no data", false, nil)
            }
        }
    }
}
