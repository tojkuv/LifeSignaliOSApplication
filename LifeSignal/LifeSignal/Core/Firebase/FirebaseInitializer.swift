import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging
import FirebaseFunctions
import UIKit

/// Helper for initializing Firebase services
struct FirebaseInitializer {
    /// Initialize Firebase and related services
    static func initialize() {
        // Initialize Firebase if not already initialized
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        // Set up Firebase Functions
        let _ = Functions.functions(region: "us-central1")
    }
    
    /// Set up Firebase Messaging for push notifications
    static func setupMessaging() async {
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
        
        // Set up FCM token monitoring
        Messaging.messaging().delegate = MessagingDelegateAdapter.shared
    }
    
    /// Get Firebase initialization status as a string
    static func getInitializationStatus() -> String {
        if let app = FirebaseApp.app() {
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
}
