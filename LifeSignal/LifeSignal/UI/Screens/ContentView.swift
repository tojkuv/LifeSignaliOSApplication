import SwiftUI
import Foundation
import UIKit

/// The main content view of the app
struct ContentView: View {
    @EnvironmentObject private var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home tab
            NavigationStack {
                HomeView()
                    .navigationTitle("Home")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)

            // Responders tab
            NavigationStack {
                RespondersView()
                    .navigationTitle("Responders")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Responders", systemImage: "person.2.fill")
            }
            .if(userProfileViewModel.pendingPingsCount > 0) { view in
                view.badge(userProfileViewModel.pendingPingsCount)
            }
            .tag(1)

            // Check-in tab (center)
            NavigationStack {
                CountdownView()
                    .navigationTitle("Check-In")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Check-In", systemImage: "iphone.circle.fill")
            }
            .tag(2)

            // Dependents tab
            NavigationStack {
                DependentsView()
                    .navigationTitle("Dependents")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Dependents", systemImage: "person.3.fill")
            }
            .if(userProfileViewModel.nonResponsiveDependentsCount > 0) { view in
                view.badge(userProfileViewModel.nonResponsiveDependentsCount)
            }
            .tag(3)

            // Profile tab
            NavigationStack {
                ProfileView()
                    .navigationTitle("Profile")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle.fill")
            }
            .tag(4)
        }
        .accentColor(.blue)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    ContentView()
        .environmentObject(UserProfileViewModel())
        .environmentObject(AppState())
}

