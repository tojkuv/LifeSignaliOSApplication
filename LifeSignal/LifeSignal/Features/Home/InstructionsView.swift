import SwiftUI
import ComposableArchitecture

/// Feature for displaying instructions
@Reducer
struct InstructionsFeature {
    /// The state of the instructions feature
    struct State: Equatable {
        /// Flag indicating if the instructions are being shown
        var isShowing: Bool = false
    }
    
    /// Actions that can be performed on the instructions feature
    enum Action: Equatable {
        /// Show the instructions
        case show
        
        /// Dismiss the instructions
        case dismiss
    }
    
    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .show:
                state.isShowing = true
                return .none
                
            case .dismiss:
                state.isShowing = false
                return .none
            }
        }
    }
}

/// A SwiftUI view for displaying instructions using TCA
struct InstructionsView: View {
    /// The store for the instructions feature
    let store: StoreOf<InstructionsFeature>
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        instructionSection(
                            title: "Welcome to LifeSignal",
                            content: "LifeSignal helps you stay connected with your trusted contacts. It automatically notifies your responders if you don't check in within your specified time interval.",
                            icon: "app.badge.checkmark.fill"
                        )
                        
                        instructionSection(
                            title: "Setting Up",
                            content: "1. Set your check-in interval in the Home tab\n2. Add responders by scanning their QR code\n3. Enable notifications to receive reminders before timeout",
                            icon: "gear"
                        )
                        
                        instructionSection(
                            title: "Check-In Process",
                            content: "1. Check in regularly before your timer expires\n2. Receive notifications before expiration\n3. If you don't check in, your responders will be notified",
                            icon: "clock"
                        )
                        
                        instructionSection(
                            title: "Responders",
                            content: "Responders are trusted contacts who will be notified if you don't check in on time. They can then take appropriate action to ensure your safety.",
                            icon: "person.2"
                        )
                        
                        instructionSection(
                            title: "Dependents",
                            content: "Dependents are people you're responsible for checking on. You'll be notified if they don't check in on time.",
                            icon: "person.3"
                        )
                        
                        instructionSection(
                            title: "QR Codes",
                            content: "Share your QR code with trusted contacts to let them add you. Scan others' QR codes to add them as contacts.",
                            icon: "qrcode"
                        )
                        
                        instructionSection(
                            title: "Privacy",
                            content: "LifeSignal respects your privacy. Your location is never shared, only your check-in status.",
                            icon: "lock.shield"
                        )
                    }
                    .padding()
                }
                .navigationTitle("How LifeSignal Works")
                .navigationBarItems(trailing: Button("Done") {
                    viewStore.send(.dismiss)
                })
            }
        }
    }
    
    /// Create an instruction section
    /// - Parameters:
    ///   - title: The section title
    ///   - content: The section content
    ///   - icon: The section icon
    /// - Returns: A view containing the instruction section
    private func instructionSection(title: String, content: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
            }
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

/// A SwiftUI view for displaying instructions using TCA (convenience initializer)
extension InstructionsView {
    /// Initialize with a dismiss callback
    /// - Parameter onDismiss: Callback for when the instructions are dismissed
    init(onDismiss: @escaping () -> Void) {
        self.store = Store(initialState: InstructionsFeature.State()) {
            InstructionsFeature()
                ._printChanges()
        }
        
        // Set up a listener for the dismiss action
        ViewStore(self.store, observe: { $0.isShowing }).publisher
            .sink { isShowing in
                if !isShowing {
                    onDismiss()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Cancellables for managing subscriptions
    @State private var cancellables = Set<AnyCancellable>()
}

#Preview {
    InstructionsView(onDismiss: { })
}
