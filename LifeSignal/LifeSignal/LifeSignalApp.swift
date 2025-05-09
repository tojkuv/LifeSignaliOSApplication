import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

@main
struct LifeSignalApp: App {
    // Register the AppDelegate for orientation lock
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var userProfileViewModel = UserProfileViewModel()
    @StateObject private var appState = AppState()
    @State private var showFirebaseTest = false // Set to true to show Firebase test view
    @State private var showUserModelTest = false // Set to true to show User Model test view

    var body: some Scene {
        WindowGroup {
            Group {
                if showFirebaseTest {
                    FirebaseTestView()
                        .environmentObject(userProfileViewModel)
                        .environmentObject(appState)
                } else if showUserModelTest {
                    UserModelTestView()
                        .environmentObject(userProfileViewModel)
                        .environmentObject(appState)
                } else if !appState.isAuthenticated {
                    AuthenticationView(
                        isAuthenticated: $appState.isAuthenticated,
                        needsOnboarding: $appState.needsOnboarding
                    )
                    .environmentObject(userProfileViewModel)
                    .environmentObject(appState)
                } else if appState.needsOnboarding {
                    OnboardingView(
                        needsOnboarding: $appState.needsOnboarding
                    )
                    .environmentObject(userProfileViewModel)
                    .environmentObject(appState)
                } else {
                    ContentView()
                        .environmentObject(userProfileViewModel)
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
        userProfileViewModel.loadUserData { success in
            if !success {
                print("Error loading user data, assuming user needs onboarding")
                appState.isAuthenticated = true
                appState.needsOnboarding = true
                return
            }

            // Check if profile is complete based on UserViewModel data
            let profileComplete = !userProfileViewModel.name.isEmpty && !userProfileViewModel.profileDescription.isEmpty

            print("User document exists for ID: \(userId)")
            print("Profile complete status: \(profileComplete)")

            if profileComplete {
                // User is authenticated and has a complete profile
                print("Profile is complete, skipping onboarding")
                appState.isAuthenticated = true
                appState.needsOnboarding = false
            } else {
                // User exists but profile is incomplete
                print("Profile is incomplete, showing onboarding")
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
        userProfileViewModel.loadUserData { success in
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
