import SwiftUI
import ComposableArchitecture
import Foundation
import FirebaseAuth

/// The main content view using TCA
/// Responsible for routing to the appropriate view based on authentication state
struct ContentView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            Group {
                if !viewStore.isAuthenticated {
                    // Authentication flow
                    SignInView(store: store.scope(
                        state: \.authentication ?? AuthenticationFeature.State(),
                        action: AppFeature.Action.authentication
                    ))
                } else if viewStore.needsOnboarding {
                    // Onboarding flow
                    OnboardingView(store: store)
                } else {
                    // Main app tabs
                    MainTabView(store: store)
                }
            }
            .onAppear {
                // Listen for session invalidation through the app feature
                viewStore.send(.setupSessionListener(userId: Auth.auth().currentUser?.uid ?? ""))
            }
        }
    }
}

/// Main tab view for the authenticated user
/// Displays the main navigation tabs of the application
struct MainTabView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            TabView {
                // Home tab
                NavigationStack {
                    HomeView(store: store)
                    .navigationTitle("Home")
                    .navigationBarTitleDisplayMode(.large)
                }
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

                // Responders tab
                NavigationStack {
                    if let contactsState = viewStore.contacts {
                        RespondersView(store: store.scope(
                            state: { _ in contactsState },
                            action: AppFeature.Action.contacts
                        ))
                        .navigationTitle("Responders")
                        .navigationBarTitleDisplayMode(.large)
                    } else {
                        ProgressView("Loading responders...")
                    }
                }
                .tabItem {
                    Label("Responders", systemImage: "person.2.fill")
                }
                .badge(viewStore.contacts?.pendingPingsCount ?? 0)

                // Check-in tab (center)
                NavigationStack {
                    CheckInView(store: store)
                    .navigationTitle("Check-In")
                    .navigationBarTitleDisplayMode(.large)
                }
                .tabItem {
                    Label("Check-In", systemImage: "iphone.circle.fill")
                }

                // Dependents tab
                NavigationStack {
                    if let contactsState = viewStore.contacts {
                        DependentsView(store: store.scope(
                            state: { _ in contactsState },
                            action: AppFeature.Action.contacts
                        ))
                        .navigationTitle("Dependents")
                        .navigationBarTitleDisplayMode(.large)
                    } else {
                        ProgressView("Loading dependents...")
                    }
                }
                .tabItem {
                    Label("Dependents", systemImage: "person.3.fill")
                }
                .badge(viewStore.contacts?.nonResponsiveDependentsCount ?? 0)

                // Profile tab
                NavigationStack {
                    if let userState = viewStore.user {
                        ProfileView(store: store.scope(
                            state: { _ in userState },
                            action: AppFeature.Action.user
                        ))
                        .navigationTitle("Profile")
                        .navigationBarTitleDisplayMode(.large)
                    } else {
                        ProgressView("Loading profile...")
                    }
                }
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
            }
            .accentColor(.blue)
            .background(.ultraThinMaterial)
        }
    }
}