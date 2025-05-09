import Foundation
import UIKit
import UserNotifications
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging
import FirebaseFunctions

/// Service class for Firebase functionality
class FirebaseService: NSObject {
    // Singleton instance
    static let shared = FirebaseService()

    // Private initializer for singleton
    private override init() {
        super.init()
    }

    /// Flag indicating if Firebase has been initialized
    private(set) var isInitialized = false

    /// Firebase app information
    private(set) var appInfo: [String: String] = [:]

    /// FCM token for the current device
    private(set) var fcmToken: String?

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

            // Set up Firebase Messaging
            setupFirebaseMessaging()

            // Set up Firebase Functions
            setupFirebaseFunctions()
        } else {
            print("Firebase initialization failed!")
        }
    }

    /// Set up Firebase Functions
    private func setupFirebaseFunctions() {
        // Configure Firebase Functions to use the us-central1 region by default
        let _ = Functions.functions(region: "us-central1")

        // Log that Functions is configured
        print("Firebase Functions configured with default region: us-central1")
    }

    /// Set up Firebase Messaging
    private func setupFirebaseMessaging() {
        // Set messaging delegate
        Messaging.messaging().delegate = self

        // Register for remote notifications
        UNUserNotificationCenter.current().delegate = self

        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { granted, error in
                if let error = error {
                    print("Error requesting notification authorization: \(error.localizedDescription)")
                    return
                }

                if granted {
                    print("Notification authorization granted")
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                } else {
                    print("Notification authorization denied")
                }
            }
        )
    }

    /// Update FCM token in Firestore
    /// - Parameter token: The FCM token to update
    func updateFCMToken(_ token: String) {
        self.fcmToken = token

        // Only update if user is authenticated
        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            print("Cannot update FCM token: No authenticated user")
            return
        }

        // Update token in Firestore
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreSchema.Collections.users).document(userId)

        userRef.updateData([
            FirestoreSchema.User.fcmToken: token,
            FirestoreSchema.User.lastUpdated: FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Error updating FCM token in Firestore: \(error.localizedDescription)")
                return
            }

            print("FCM token updated in Firestore")
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

// MARK: - MessagingDelegate
extension FirebaseService: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(fcmToken ?? "nil")")

        // Store token
        if let token = fcmToken {
            updateFCMToken(token)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension FirebaseService: UNUserNotificationCenterDelegate {
    // Called when a notification is delivered to a foreground app
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print("Received notification in foreground: \(userInfo)")

        // Show the notification in foreground
        completionHandler([.banner, .sound, .badge])
    }

    // Called when a user taps on a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("User tapped on notification: \(userInfo)")

        // Handle notification tap
        if let alertType = userInfo["alertType"] as? String {
            switch alertType {
            case "manualAlert":
                // Handle manual alert tap
                if let dependentId = userInfo["dependentId"] as? String {
                    print("Manual alert from dependent: \(dependentId)")
                    // Post notification to navigate to the dependent's details
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToDependentDetails"),
                        object: nil,
                        userInfo: ["dependentId": dependentId]
                    )
                }
            case "manualAlertCanceled":
                // Handle manual alert cancellation tap
                if let dependentId = userInfo["dependentId"] as? String {
                    print("Manual alert canceled for dependent: \(dependentId)")
                    // Post notification to navigate to the dependent's details
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToDependentDetails"),
                        object: nil,
                        userInfo: ["dependentId": dependentId]
                    )
                }
            case "checkInExpired":
                // Handle check-in expired tap
                if let dependentId = userInfo["dependentId"] as? String {
                    print("Check-in expired for dependent: \(dependentId)")
                    // Post notification to navigate to the dependent's details
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToDependentDetails"),
                        object: nil,
                        userInfo: ["dependentId": dependentId]
                    )
                }
            default:
                break
            }
        }

        completionHandler()
    }
}
