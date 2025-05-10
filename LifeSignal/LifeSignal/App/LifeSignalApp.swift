import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import ComposableArchitecture

@main
struct LifeSignalApp: App {
    // Register the AppDelegate for orientation lock
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Create the store for the app
    let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .onAppear {
                    // Configure Firebase if needed
                    if FirebaseApp.app() == nil {
                        FirebaseApp.configure()
                    }

                    // Check authentication state
                    checkAuthenticationState()
                }
        }
    }

    /// Check the current authentication state
    private func checkAuthenticationState() {
        // Check if user is already authenticated
        if let user = Auth.auth().currentUser {
            // User is authenticated, validate session
            validateSession(userId: user.uid)
        }
    }

    /// Validate the user's session
    /// - Parameter userId: The user's ID
    private func validateSession(userId: String) {
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreConstants.Collections.users).document(userId)

        userRef.getDocument { document, error in
            if let error = error {
                print("Error validating session: \(error.localizedDescription)")
                return
            }

            guard let document = document, document.exists else {
                print("User document does not exist")
                return
            }

            guard let data = document.data() else {
                print("User document data is empty")
                return
            }

            // Check if the user has completed onboarding
            let profileComplete = data["profileComplete"] as? Bool ?? false

            // Update the store
            ViewStore(store, observe: { $0 }).send(.authenticate)

            if !profileComplete {
                // User needs to complete onboarding
                ViewStore(store, observe: { $0 }).send(.setNeedsOnboarding(true))
            }
        }
    }
}
