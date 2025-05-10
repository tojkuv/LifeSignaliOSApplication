import SwiftUI
import ComposableArchitecture

/// Feature for displaying basic instructions
@Reducer
struct InstructionsFeature {
    /// The state of the basic instructions feature
    struct State: Equatable {
        /// Flag indicating if the instructions are showing
        var isShowing: Bool = false
    }
    
    /// Actions that can be performed on the basic instructions feature
    enum Action: Equatable {
        /// Show or hide the instructions
        case setShowing(Bool)
    }
    
    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .setShowing(isShowing):
                state.isShowing = isShowing
                return .none
            }
        }
    }
}
