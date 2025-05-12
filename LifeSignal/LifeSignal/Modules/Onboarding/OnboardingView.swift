import SwiftUI
import ComposableArchitecture

/// A SwiftUI view for onboarding using TCA 1.5+
struct OnboardingView: View {
    /// The store for the onboarding feature
    @Bindable var store: StoreOf<OnboardingFeature>
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Profile Information")) {
                    TextField("Name", text: $store.name)
                        .disabled(store.isLoading)
                    
                    TextField("Emergency Note (Optional)", text: $store.emergencyNote)
                        .foregroundColor(.secondary)
                        .disabled(store.isLoading)
                }
                
                Section {
                    Button {
                        store.send(.completeSetupButtonTapped)
                    } label: {
                        HStack {
                            Spacer()
                            if store.isLoading {
                                ProgressView()
                                    .padding(.trailing, 5)
                            }
                            Text("Complete Setup")
                            Spacer()
                        }
                    }
                    .disabled(store.name.isEmpty || store.isLoading)
                }
                
                if let error = store.error {
                    Section {
                        Text(error.localizedDescription)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Setup Profile")
        }
    }
}

#Preview {
    OnboardingView(
        store: Store(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }
    )
}
