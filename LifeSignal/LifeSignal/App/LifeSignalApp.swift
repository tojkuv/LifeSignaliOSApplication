import SwiftUI
import ComposableArchitecture

@main
struct LifeSignalApp: App {
    // Register the AppDelegate for orientation lock
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Use the store from the AppDelegate
    var store: StoreOf<AppFeature> {
        appDelegate.store
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .onAppear {
                    // Initialize the app through the app feature
                    Task {
                        await ViewStore(store, observe: { $0 }).send(.appLaunched)
                    }
                }
        }
    }
}
