import SwiftUI
import ComposableArchitecture

/// Environment key for the app store
private struct StoreEnvironmentKey: EnvironmentKey {
    static let defaultValue: StoreOf<AppFeature>? = nil
}

/// Environment extension for the app store
extension EnvironmentValues {
    var store: StoreOf<AppFeature>? {
        get { self[StoreEnvironmentKey.self] }
        set { self[StoreEnvironmentKey.self] = newValue }
    }
}

/// Main tab view for the app
struct MainTabView: View {
    /// The app store from the environment
    @Environment(\.store) private var appStore

    /// The current tab selection
    @State private var selectedTab = 0

    var body: some View {
        if let store = appStore {
            TabView(selection: $selectedTab) {
                // Home tab
                NavigationStack {
                    HomeView(store: store.scope(
                        state: \.home,
                        action: \.home
                    ))
                    .environment(\.store, store)
                }
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)

                // Responders tab
                NavigationStack {
                    RespondersView(
                        store: store.scope(
                            state: \.responders,
                            action: \.responders
                        )
                    )
                }
                .tabItem {
                    Label("Responders", systemImage: "person.2")
                }
                .tag(1)

                // Check-in tab
                NavigationStack {
                    CheckInView(
                        store: store.scope(
                            state: \.user.checkIn,
                            action: \.user.checkIn
                        )
                    )
                }
                .tabItem {
                    Label("Check-in", systemImage: "checkmark.circle")
                }
                .tag(2)

                // Dependents tab
                NavigationStack {
                    DependentsView(
                        store: store.scope(
                            state: \.dependents,
                            action: \.dependents
                        )
                    )
                }
                .tabItem {
                    Label("Dependents", systemImage: "person.3")
                }
                .tag(3)

                // Profile tab
                NavigationStack {
                    ProfileView(
                        store: store.scope(
                            state: \.user.profile,
                            action: \.user.profile
                        )
                    )
                }
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
                .tag(4)
            }
        } else {
            Text("Store not available")
                .foregroundColor(.red)
        }
    }
}

#Preview {
    MainTabView()
        .environment(\.store, Store(initialState: AppFeature.State()) {
            AppFeature()
        })
}
