import Foundation
import SwiftUI

/// Class to manage global app state
class AppState: ObservableObject {
    /// Authentication state
    @Published var isAuthenticated: Bool = false

    /// Onboarding state
    @Published var needsOnboarding: Bool = false

    /// Sign out the current user
    func signOut() {
        SessionManager.shared.signOutAndResetAppState(
            isAuthenticated: Binding(
                get: { self.isAuthenticated },
                set: { self.isAuthenticated = $0 }
            ),
            needsOnboarding: Binding(
                get: { self.needsOnboarding },
                set: { self.needsOnboarding = $0 }
            )
        )
    }
}
