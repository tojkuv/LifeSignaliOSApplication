import SwiftUI
import ComposableArchitecture
import UIKit

/// Feature for sharing content
@Reducer
struct ShareFeature {
    /// The state of the share feature
    struct State: Equatable {
        /// The items to share
        var items: [Any] = []
        
        /// Flag indicating if the share sheet is showing
        var isShowing: Bool = false
    }
    
    /// Actions that can be performed on the share feature
    enum Action: Equatable {
        /// Show the share sheet
        case show
        
        /// Dismiss the share sheet
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

/// A SwiftUI view for sharing content using TCA
struct TCAShareSheet: View {
    /// The store for the share feature
    let store: StoreOf<ShareFeature>
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            ShareSheet(items: viewStore.items)
                .onDisappear {
                    viewStore.send(.dismiss)
                }
        }
    }
}

/// A UIViewControllerRepresentable for sharing content
struct ShareSheet: UIViewControllerRepresentable {
    /// The items to share
    let items: [Any]
    
    /// Create the UIActivityViewController
    /// - Parameter context: The context
    /// - Returns: A UIActivityViewController
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    /// Update the UIActivityViewController
    /// - Parameters:
    ///   - uiViewController: The UIActivityViewController
    ///   - context: The context
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// A SwiftUI view for sharing content using TCA (convenience initializer)
extension TCAShareSheet {
    /// Initialize with items
    /// - Parameter items: The items to share
    init(items: [Any]) {
        self.store = Store(initialState: ShareFeature.State(items: items)) {
            ShareFeature()
        }
    }
}

#Preview {
    TCAShareSheet(items: ["Test"])
}
