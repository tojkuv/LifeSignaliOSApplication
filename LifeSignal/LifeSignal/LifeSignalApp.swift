import SwiftUI

@main
struct LifeSignalApp: App {
    // Register the AppDelegate for orientation lock
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var userViewModel = UserViewModel()
    @State private var isAuthenticated = true // Set to true for debugging

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userViewModel)
        }
    }
}
