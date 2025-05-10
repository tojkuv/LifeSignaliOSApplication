import SwiftUI
import ComposableArchitecture
import Foundation

/// The main content view using TCA
struct ContentView: View {
    let store: StoreOf<AppFeature>

    // Notification center observer
    @State private var resetAppStateObserver: NSObjectProtocol? = nil

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            Group {
                if !viewStore.isAuthenticated {
                    AuthenticationView(store: store.scope(
                        state: \.authentication ?? AuthenticationFeature.State(),
                        action: AppFeature.Action.authentication
                    ))
                } else if viewStore.needsOnboarding {
                    OnboardingView(store: store)
                } else {
                    TabView {
                        // Home tab
                        NavigationStack {
                            HomeView(store: store.scope(
                                state: \.home ?? HomeFeature.State(),
                                action: AppFeature.Action.home
                            ))
                            .navigationTitle("Home")
                            .navigationBarTitleDisplayMode(.large)
                        }
                        .tabItem {
                            Label("Home", systemImage: "house.fill")
                        }

                        // Responders tab
                        NavigationStack {
                            RespondersView(store: store.scope(
                                state: \.contacts ?? ContactsFeature.State(),
                                action: AppFeature.Action.contacts
                            ))
                            .navigationTitle("Responders")
                            .navigationBarTitleDisplayMode(.large)
                        }
                        .tabItem {
                            Label("Responders", systemImage: "person.2.fill")
                        }
                        .badge(viewStore.contacts?.pendingPingsCount ?? 0)

                        // Check-in tab (center)
                        NavigationStack {
                            CountdownView(store: store.scope(
                                state: \.checkIn ?? CheckInFeature.State(),
                                action: AppFeature.Action.checkIn
                            ))
                            .navigationTitle("Check-In")
                            .navigationBarTitleDisplayMode(.large)
                        }
                        .tabItem {
                            Label("Check-In", systemImage: "iphone.circle.fill")
                        }

                        // Dependents tab
                        NavigationStack {
                            DependentsView(store: store.scope(
                                state: \.contacts ?? ContactsFeature.State(),
                                action: AppFeature.Action.contacts
                            ))
                            .navigationTitle("Dependents")
                            .navigationBarTitleDisplayMode(.large)
                        }
                        .tabItem {
                            Label("Dependents", systemImage: "person.3.fill")
                        }
                        .badge(viewStore.contacts?.nonResponsiveDependentsCount ?? 0)

                        // Profile tab
                        NavigationStack {
                            ProfileView(store: store.scope(
                                state: \.profile ?? ProfileFeature.State(),
                                action: AppFeature.Action.profile
                            ))
                            .navigationTitle("Profile")
                            .navigationBarTitleDisplayMode(.large)
                        }
                        .tabItem {
                            Label("Profile", systemImage: "person.crop.circle.fill")
                        }
                    }
                    .accentColor(.blue)
                    .background(.ultraThinMaterial)
                }
            }
            .onAppear {
                // Set up notification observer for app state reset
                resetAppStateObserver = NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("ResetAppState"),
                    object: nil,
                    queue: .main
                ) { _ in
                    // Reset the app state when session is invalidated
                    viewStore.send(.authentication(.signOut))
                }
            }
            .onDisappear {
                // Remove the observer when the view disappears
                if let observer = resetAppStateObserver {
                    NotificationCenter.default.removeObserver(observer)
                    resetAppStateObserver = nil
                }
            }
        }
    }
}

/// A SwiftUI view for onboarding using TCA
struct OnboardingView: View {
    /// The store for the app feature
    let store: StoreOf<AppFeature>

    /// State for the onboarding form
    @State private var name = ""
    @State private var note = ""

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                Form {
                    Section(header: Text("Profile Information")) {
                        TextField("Name", text: $name)
                        TextField("Note (Optional)", text: $note)
                    }

                    Section {
                        Button(action: {
                            // In a real implementation, we would save the profile information
                            // and then complete onboarding
                            viewStore.send(.completeOnboarding)
                        }) {
                            HStack {
                                Spacer()
                                Text("Complete Setup")
                                Spacer()
                            }
                        }
                        .disabled(name.isEmpty)
                    }
                }
                .navigationTitle("Setup Profile")
            }
        }
    }
}

#Preview {
    ContentView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}
