import SwiftUI
import ComposableArchitecture
import FirebaseAuth
import Dependencies
import UserNotifications
import Combine

/// The main content view using AppFeature
/// Responsible for routing to the appropriate view based on authentication state
struct ContentView: View {
    /// The store for the app feature
    @Bindable var store: StoreOf<AppFeature>

    // MARK: - Body
    var body: some View {
        Group {
            // Using shared state for authentication and onboarding
            // This ensures consistent state across the app
            if !store.$isAuthenticated.wrappedValue {
                // Authentication flow
                SignInView(
                    store: store.scope(
                        state: \.signIn,
                        action: \.signIn
                    )
                )
            } else if store.$needsOnboarding.wrappedValue {
                // Onboarding flow
                OnboardingView(store: store.scope(
                    state: \.onboarding,
                    action: \.onboarding
                ))
            } else {
                // Main app with tabs
                MainTabView()
                    .environment(\.store, store)
            }
        }
        .onAppear {
            store.send(.appAppeared)
        }
        .onChange(of: UIApplication.shared.applicationState) { oldState, newState in
            store.send(.appStateChanged(oldState: oldState, newState: newState))
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AuthStateChanged"))) { _ in
            store.send(.authStateChanged)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FCMTokenUpdated"))) { notification in
            if let token = notification.userInfo?["token"] as? String {
                store.send(.updateFCMToken(token))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RemoteNotificationReceived"))) { _ in
            // App-level notification handling if needed
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NotificationResponseReceived"))) { _ in
            // App-level notification response handling if needed
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}