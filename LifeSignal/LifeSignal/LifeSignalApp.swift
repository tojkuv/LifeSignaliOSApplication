import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

@main
struct LifeSignalApp: App {
    // Register the AppDelegate for orientation lock
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var userViewModel = UserViewModel()
    @StateObject private var appState = AppState()
    @State private var showFirebaseTest = false // Set to true to show Firebase test view
    @State private var showUserModelTest = true // Set to true to show User Model test view

    var body: some Scene {
        WindowGroup {
            Group {
                if showFirebaseTest {
                    FirebaseTestView()
                        .environmentObject(userViewModel)
                        .environmentObject(appState)
                } else if showUserModelTest {
                    UserModelTestView()
                        .environmentObject(userViewModel)
                        .environmentObject(appState)
                } else if !appState.isAuthenticated {
                    AuthenticationView(
                        isAuthenticated: $appState.isAuthenticated,
                        needsOnboarding: $appState.needsOnboarding
                    )
                    .environmentObject(userViewModel)
                    .environmentObject(appState)
                } else if appState.needsOnboarding {
                    OnboardingView(
                        needsOnboarding: $appState.needsOnboarding
                    )
                    .environmentObject(userViewModel)
                    .environmentObject(appState)
                } else {
                    ContentView()
                        .environmentObject(userViewModel)
                        .environmentObject(appState)
                        .onAppear {
                            setupSessionListener()
                            loadUserData()
                        }
                }
            }
            .onAppear {
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
        } else {
            // User is not authenticated
            appState.isAuthenticated = false
            appState.needsOnboarding = false
        }
    }

    /// Validate the user's session
    private func validateSession(userId: String) {
        SessionManager.shared.validateSession(userId: userId) { isValid, error in
            if let error = error {
                print("Error validating session: \(error.localizedDescription)")
                signOut()
                return
            }

            if isValid {
                // Session is valid, check if user needs onboarding
                checkUserOnboardingStatus(userId: userId)
            } else {
                // Session is invalid, sign out
                signOut()
            }
        }
    }

    /// Check if the user needs onboarding
    private func checkUserOnboardingStatus(userId: String) {
        UserService.shared.getCurrentUserData { userData, error in
            if let error = error {
                print("Error checking user data: \(error.localizedDescription)")

                // If error is "User document not found", user needs onboarding
                if (error as NSError).domain == "UserService" && (error as NSError).code == 404 {
                    appState.isAuthenticated = true
                    appState.needsOnboarding = true
                } else {
                    signOut()
                }
                return
            }

            if let userData = userData {
                // User exists, check if profile is complete
                let profileComplete = userData["profileComplete"] as? Bool ?? false

                if profileComplete {
                    // User is authenticated and has a complete profile
                    appState.isAuthenticated = true
                    appState.needsOnboarding = false

                    // Update UserViewModel with user data
                    userViewModel.updateFromFirestore(userData: userData)
                } else {
                    // User exists but profile is incomplete
                    appState.isAuthenticated = true
                    appState.needsOnboarding = true
                }
            } else {
                // No user data, needs onboarding
                appState.isAuthenticated = true
                appState.needsOnboarding = true
            }
        }
    }

    /// Set up a listener for session changes
    private func setupSessionListener() {
        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            return
        }

        // Remove any existing listener
        appDelegate.removeSessionListener()

        // Set up a new listener
        appDelegate.sessionListener = SessionManager.shared.watchSession(userId: userId) {
            // Session is invalid, sign out
            signOut()
        }
    }

    /// Load user data from Firestore
    private func loadUserData() {
        userViewModel.loadUserData { success in
            if !success {
                print("Failed to load user data")
            }
        }
    }

    /// Sign out the current user
    private func signOut() {
        SessionManager.shared.signOutAndResetAppState(
            isAuthenticated: $appState.isAuthenticated,
            needsOnboarding: $appState.needsOnboarding
        )
    }
}
