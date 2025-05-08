import Foundation
import FirebaseCore
import FirebaseFirestore

/// Service class for Firebase functionality
class FirebaseService {
    // Singleton instance
    static let shared = FirebaseService()

    // Private initializer for singleton
    private init() {}

    /// Flag indicating if Firebase has been initialized
    private(set) var isInitialized = false

    /// Firebase app information
    private(set) var appInfo: [String: String] = [:]

    /// Initialize Firebase
    func configure() {
        guard !isInitialized else {
            print("Firebase is already initialized")
            return
        }

        print("Configuring Firebase...")
        FirebaseApp.configure()

        // Check if Firebase was initialized successfully
        if let app = FirebaseApp.app() {
            isInitialized = true

            // Store app information
            let options = app.options
            appInfo = [
                "appName": app.name,
                "googleAppID": options.googleAppID,
                "gcmSenderID": options.gcmSenderID,
                "projectID": options.projectID ?? "Not available"
            ]

            print("Firebase initialized successfully!")
            print("Firebase app name: \(app.name)")
            print("Firebase Google App ID: \(options.googleAppID)")
            print("Firebase GCM Sender ID: \(options.gcmSenderID)")
            print("Firebase Project ID: \(options.projectID ?? "Not available")")
        } else {
            print("Firebase initialization failed!")
        }
    }

    /// Get Firebase initialization status
    /// - Returns: A string describing the current Firebase initialization status
    func getInitializationStatus() -> String {
        if isInitialized, let app = FirebaseApp.app() {
            let options = app.options
            return """
            Firebase is initialized!
            App name: \(app.name)
            Google App ID: \(options.googleAppID)
            GCM Sender ID: \(options.gcmSenderID)
            Project ID: \(options.projectID ?? "Not available")
            """
        } else {
            return "Firebase is NOT initialized!"
        }
    }

    /// Test Firestore connection by fetching a test document
    /// - Parameter completion: Callback with result string and success flag
    func testFirestoreConnection(completion: @escaping (String, Bool) -> Void) {
        guard isInitialized else {
            completion("Firebase is not initialized. Cannot test Firestore.", false)
            return
        }

        let db = Firestore.firestore()

        // Create a test collection and document if it doesn't exist
        let testCollection = db.collection("test")
        let testDocRef = testCollection.document("test_document")

        // First, try to get the document
        testDocRef.getDocument { (document, error) in
            if let error = error {
                completion("Error accessing Firestore: \(error.localizedDescription)", false)
                return
            }

            if let document = document, document.exists {
                // Document exists, read its data
                if let data = document.data() {
                    let dataString = data.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
                    completion("Successfully accessed Firestore!\nTest document data:\n\(dataString)", true)
                } else {
                    completion("Document exists but has no data", true)
                }
            } else {
                // Document doesn't exist, create it
                let testData: [String: Any] = [
                    "timestamp": FieldValue.serverTimestamp(),
                    "message": "This is a test document",
                    "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
                ]

                testDocRef.setData(testData) { error in
                    if let error = error {
                        completion("Error creating test document: \(error.localizedDescription)", false)
                    } else {
                        completion("Successfully created test document in Firestore!\nData:\n\(testData.map { "\($0.key): \($0.value)" }.joined(separator: "\n"))", true)
                    }
                }
            }
        }
    }
}
