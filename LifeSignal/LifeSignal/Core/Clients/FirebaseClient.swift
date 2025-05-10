import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging
import FirebaseFunctions
import ComposableArchitecture

/// Protocol defining Firebase operations
protocol FirebaseClientProtocol {
    /// Initialize Firebase
    func configure() async
    
    /// Get Firebase initialization status
    func getInitializationStatus() -> String
    
    /// Update FCM token in Firestore
    func updateFCMToken(_ token: String, for userId: String) async throws
    
    /// Test Firestore connection
    func testFirestoreConnection() async throws -> String
}

/// Live implementation of FirebaseClient
struct FirebaseLiveClient: FirebaseClientProtocol {
    private let appInfo: @Sendable () -> [String: String]
    private let isInitialized: @Sendable () -> Bool
    private let fcmToken: @Sendable () -> String?
    
    init() {
        var appInfoStorage: [String: String] = [:]
        var isInitializedStorage = false
        var fcmTokenStorage: String? = nil
        
        self.appInfo = { appInfoStorage }
        self.isInitialized = { isInitializedStorage }
        self.fcmToken = { fcmTokenStorage }
        
        // Capture references for mutation
        let setAppInfo: ([String: String]) -> Void = { appInfoStorage = $0 }
        let setIsInitialized: (Bool) -> Void = { isInitializedStorage = $0 }
        let setFcmToken: (String?) -> Void = { fcmTokenStorage = $0 }
        
        // Set up Firebase Messaging delegate
        Messaging.messaging().delegate = MessagingDelegateAdapter(
            didReceiveRegistrationToken: { token in
                if let token = token {
                    setFcmToken(token)
                }
            }
        )
        
        // Initialize Firebase if not already initialized
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            
            if let app = FirebaseApp.app() {
                setIsInitialized(true)
                
                // Store app information
                let options = app.options
                let info = [
                    "appName": app.name,
                    "googleAppID": options.googleAppID,
                    "gcmSenderID": options.gcmSenderID,
                    "projectID": options.projectID ?? "Not available"
                ]
                setAppInfo(info)
            }
        } else {
            setIsInitialized(true)
        }
    }
    
    func configure() async {
        // Firebase is already configured in init
        // Set up Firebase Functions
        let _ = Functions.functions(region: "us-central1")
        
        // Set up Firebase Messaging
        await setupFirebaseMessaging()
    }
    
    private func setupFirebaseMessaging() async {
        // Request notification permissions
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: authOptions)
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        } catch {
            print("Error requesting notification authorization: \(error.localizedDescription)")
        }
    }
    
    func getInitializationStatus() -> String {
        if isInitialized(), let app = FirebaseApp.app() {
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
    
    func updateFCMToken(_ token: String, for userId: String) async throws {
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreConstants.Collections.users).document(userId)
        
        try await userRef.updateData([
            FirestoreConstants.UserFields.fcmToken: token,
            FirestoreConstants.UserFields.lastUpdated: FieldValue.serverTimestamp()
        ])
    }
    
    func testFirestoreConnection() async throws -> String {
        guard isInitialized() else {
            throw FirebaseError.notInitialized
        }
        
        let db = Firestore.firestore()
        let testCollection = db.collection("test")
        let testDocRef = testCollection.document("test_document")
        
        do {
            let document = try await testDocRef.getDocument()
            
            if document.exists, let data = document.data() {
                let dataString = data.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
                return "Successfully accessed Firestore!\nTest document data:\n\(dataString)"
            } else {
                // Document doesn't exist, create it
                let testData: [String: Any] = [
                    "timestamp": FieldValue.serverTimestamp(),
                    "message": "This is a test document",
                    "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
                ]
                
                try await testDocRef.setData(testData)
                return "Successfully created test document in Firestore!\nData:\n\(testData.map { "\($0.key): \($0.value)" }.joined(separator: "\n"))"
            }
        } catch {
            throw FirebaseError.firestoreError(error.localizedDescription)
        }
    }
}

/// Mock implementation for testing
struct FirebaseMockClient: FirebaseClientProtocol {
    func configure() async {
        // No-op for testing
    }
    
    func getInitializationStatus() -> String {
        return "Firebase is initialized (MOCK)"
    }
    
    func updateFCMToken(_ token: String, for userId: String) async throws {
        // No-op for testing
    }
    
    func testFirestoreConnection() async throws -> String {
        return "Successfully connected to Firestore (MOCK)"
    }
}

/// Firebase-related errors
enum FirebaseError: Error, LocalizedError {
    case notInitialized
    case firestoreError(String)
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Firebase is not initialized"
        case .firestoreError(let message):
            return "Firestore error: \(message)"
        }
    }
}

/// Adapter for Firebase Messaging delegate
private class MessagingDelegateAdapter: NSObject, MessagingDelegate {
    private let didReceiveRegistrationTokenHandler: (String?) -> Void
    
    init(didReceiveRegistrationToken: @escaping (String?) -> Void) {
        self.didReceiveRegistrationTokenHandler = didReceiveRegistrationToken
        super.init()
    }
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        didReceiveRegistrationTokenHandler(fcmToken)
    }
}

// TCA dependency registration
extension DependencyValues {
    var firebaseClient: FirebaseClientProtocol {
        get { self[FirebaseClientKey.self] }
        set { self[FirebaseClientKey.self] = newValue }
    }
    
    private enum FirebaseClientKey: DependencyKey {
        static let liveValue: FirebaseClientProtocol = FirebaseLiveClient()
        static let testValue: FirebaseClientProtocol = FirebaseMockClient()
    }
}
