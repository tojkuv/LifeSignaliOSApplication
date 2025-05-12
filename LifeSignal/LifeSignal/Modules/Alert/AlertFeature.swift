import Foundation
import ComposableArchitecture
import FirebaseAuth

/// Feature for managing manual alerts
@Reducer
struct AlertFeature {
    /// The state of the alert feature
    @ObservableState
    struct State: Equatable, Sendable {
        /// Whether a manual alert is active
        var isAlertActive: Bool = false
        
        /// When the alert was triggered
        var alertTimestamp: Date? = nil
        
        /// Loading state
        var isLoading: Bool = false
        
        /// Error state
        var error: Error?
        
        /// UI state
        var showAlertConfirmation: Bool = false
        var showClearAlertConfirmation: Bool = false
        
        /// Custom Equatable implementation to handle Error? property
        static func == (lhs: State, rhs: State) -> Bool {
            lhs.isAlertActive == rhs.isAlertActive &&
            lhs.alertTimestamp == rhs.alertTimestamp &&
            lhs.isLoading == rhs.isLoading &&
            lhs.showAlertConfirmation == rhs.showAlertConfirmation &&
            lhs.showClearAlertConfirmation == rhs.showClearAlertConfirmation &&
            (lhs.error != nil) == (rhs.error != nil)
        }
    }
    
    /// Actions that can be performed on the alert feature
    enum Action: Equatable, Sendable {
        /// Update alert state from user data
        case updateAlertState(isActive: Bool, timestamp: Date?)
        
        /// Set whether to show the alert confirmation dialog
        case setShowAlertConfirmation(Bool)
        
        /// Set whether to show the clear alert confirmation dialog
        case setShowClearAlertConfirmation(Bool)
        
        /// Trigger manual alert
        case triggerManualAlert
        case triggerManualAlertResponse(TaskResult<Void>)
        
        /// Clear manual alert
        case clearManualAlert
        case clearManualAlertResponse(TaskResult<Void>)
        
        /// Clear any error state
        case clearError
    }
    
    /// Dependencies
    @Dependency(\.firebaseUserClient) var firebaseUserClient
    @Dependency(\.firebaseAuth) var firebaseAuth
    @Dependency(\.firebaseNotification) var firebaseNotification
    
    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .updateAlertState(isActive, timestamp):
                state.isAlertActive = isActive
                state.alertTimestamp = timestamp
                return .none
                
            case let .setShowAlertConfirmation(show):
                state.showAlertConfirmation = show
                return .none
                
            case let .setShowClearAlertConfirmation(show):
                state.showClearAlertConfirmation = show
                return .none
                
            case .triggerManualAlert:
                state.isLoading = true
                // Update local state immediately for better UX
                state.isAlertActive = true
                state.alertTimestamp = Date()
                
                return .run { [firebaseUserClient, firebaseNotification] send in
                    let result = await TaskResult {
                        guard let userId = firebaseAuth.currentUserId() else {
                            throw NSError(domain: "AlertFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }
                        
                        // Get user name for notification
                        let userData = try await firebaseUserClient.getUserDocument(userId)
                        
                        // Trigger manual alert using the client
                        try await firebaseUserClient.triggerManualAlert(userId)
                        
                        // Send a notification to confirm the alert was activated
                        try await firebaseNotification.sendManualAlertNotification(userName: userData.name)
                    }
                    await send(.triggerManualAlertResponse(result))
                }
                
            case let .triggerManualAlertResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Alert was already updated in state when action was dispatched
                    return .none
                case let .failure(error):
                    state.error = error
                    // Revert the local state change if there was an error
                    state.isAlertActive = false
                    state.alertTimestamp = nil
                    return .none
                }
                
            case .clearManualAlert:
                state.isLoading = true
                // Update local state immediately for better UX
                state.isAlertActive = false
                state.alertTimestamp = nil
                
                return .run { [firebaseUserClient, firebaseNotification] send in
                    let result = await TaskResult {
                        guard let userId = firebaseAuth.currentUserId() else {
                            throw NSError(domain: "AlertFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }
                        
                        // Get user name for notification
                        let userData = try await firebaseUserClient.getUserDocument(userId)
                        
                        // Clear manual alert using the client
                        try await firebaseUserClient.clearManualAlert(userId)
                        
                        // Send a notification to confirm the alert was cleared
                        try await firebaseNotification.clearManualAlertNotification(userName: userData.name)
                    }
                    await send(.clearManualAlertResponse(result))
                }
                
            case let .clearManualAlertResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Alert was already updated in state when action was dispatched
                    return .none
                case let .failure(error):
                    state.error = error
                    // Revert the local state change if there was an error
                    state.isAlertActive = true
                    state.alertTimestamp = Date()
                    return .none
                }
                
            case .clearError:
                state.error = nil
                return .none
            }
        }
    }
}
