import SwiftUI
import FirebaseAuth
import ComposableArchitecture

@main
struct LifeSignalApp: App {
    // Register the AppDelegate for orientation lock
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // TCA dependency container
    private let dependencies = DependencyValues()

    // TCA clients
    private var firebaseClient: FirebaseClient {
        dependencies.firebaseClient
    }

    private var sessionClient: SessionClient {
        dependencies.sessionClient
    }

    private var authClient: AuthenticationClient {
        dependencies.authClient
    }

    // Create the store for the app
    let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .onAppear {
                    // Check authentication state
                    Task {
                        await checkAuthenticationState()
                    }
                }
        }
    }

    /// Check the current authentication state
    private func checkAuthenticationState() async {
        // Check if user is already authenticated using the auth client
        if let userId = await authClient.getCurrentUserId() {
            // User is authenticated, validate session
            await validateSession(userId: userId)
        }
    }

    /// Validate the user's session
    /// - Parameter userId: The user's ID
    private func validateSession(userId: String) async {
        do {
            // Update the session using the session client
            try await sessionClient.updateSession(userId: userId)

            // Get user data to check if onboarding is complete
            let userData = try await firebaseClient.getUserData(userId: userId)

            // Check if the user has completed onboarding
            let profileComplete = userData[FirestoreConstants.UserFields.profileComplete] as? Bool ?? false

            // Update the store on the main thread
            await MainActor.run {
                ViewStore(store, observe: { $0 }).send(.authenticate)

                if !profileComplete {
                    // User needs to complete onboarding
                    ViewStore(store, observe: { $0 }).send(.setNeedsOnboarding(true))
                }
            }
        } catch {
            print("Error validating session: \(error.localizedDescription)")
        }
    }
}
