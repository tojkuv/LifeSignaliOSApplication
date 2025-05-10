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