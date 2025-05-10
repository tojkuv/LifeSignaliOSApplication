import Foundation
import ComposableArchitecture

/// Feature for displaying instructions
@Reducer
struct InstructionsFeature {
    /// The state of the instructions feature
    struct State: Equatable {}
    
    /// Actions that can be performed on the instructions feature
    enum Action: Equatable {
        /// Dismiss the instructions
        case dismiss
    }
    
    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .dismiss:
                return .none
            }
        }
    }
}
