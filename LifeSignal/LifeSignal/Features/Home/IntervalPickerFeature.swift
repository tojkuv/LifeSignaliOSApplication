import Foundation
import ComposableArchitecture

/// Feature for picking a check-in interval
@Reducer
struct IntervalPickerFeature {
    /// The state of the interval picker feature
    struct State: Equatable {
        /// The current interval in seconds
        var interval: TimeInterval
        
        /// Loading state
        var isLoading: Bool = false
        
        /// Error state
        var error: Error? = nil
    }
    
    /// Actions that can be performed on the interval picker feature
    enum Action: Equatable {
        /// Update the interval
        case updateInterval(TimeInterval)
        case updateIntervalResponse(TaskResult<Bool>)
        
        /// Cancel picking an interval
        case cancel
    }
    
    /// Dependencies
    @Dependency(\.checkInClient) var checkInClient
    
    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .updateInterval(interval):
                state.isLoading = true
                return .run { send in
                    let result = await TaskResult {
                        try await checkInClient.updateCheckInInterval(interval)
                    }
                    await send(.updateIntervalResponse(result))
                }
                
            case let .updateIntervalResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }
                
            case .cancel:
                return .none
            }
        }
    }
}
