import Foundation
import ComposableArchitecture
import FirebaseFirestore

/// Feature for managing user check-in functionality
@Reducer
struct CheckInFeature {
    /// The state of the check-in feature
    struct State: Equatable {
        /// User's check-in interval in seconds (default: 24 hours)
        var checkInInterval: TimeInterval = TimeManager.defaultInterval
        
        /// Timestamp of user's last check-in
        var lastCheckedIn: Date = Date()
        
        /// Flag indicating if user should be notified 30 minutes before check-in expiration
        var notify30MinBefore: Bool = true
        
        /// Flag indicating if user should be notified 2 hours before check-in expiration
        var notify2HoursBefore: Bool = false
        
        /// Flag indicating if user has manually triggered an alert
        var sendAlertActive: Bool = false
        
        /// Timestamp when user manually triggered an alert
        var manualAlertTimestamp: Date? = nil
        
        /// User's notification lead time in minutes (30 or 120)
        var notificationLeadTime: Int = 30
        
        /// Loading state
        var isLoading: Bool = false
        
        /// Error state
        var error: Error? = nil
        
        /// Computed property for check-in expiration time
        var checkInExpiration: Date {
            return lastCheckedIn.addingTimeInterval(checkInInterval)
        }
        
        /// Computed property for time remaining until check-in expiration
        var timeRemaining: TimeInterval {
            return checkInExpiration.timeIntervalSince(Date())
        }
        
        /// Computed property for formatted time remaining until check-in expiration
        var formattedTimeRemaining: String {
            let timeRemaining = checkInExpiration.timeIntervalSince(Date())
            
            if timeRemaining <= 0 {
                return "Expired"
            }
            
            return TimeManager.shared.formatTimeInterval(timeRemaining)
        }
        
        /// Computed property for progress towards check-in expiration (0.0 to 1.0)
        var checkInProgress: Double {
            let elapsed = Date().timeIntervalSince(lastCheckedIn)
            let progress = elapsed / checkInInterval
            return min(max(progress, 0.0), 1.0)
        }
    }
    
    /// Actions that can be performed on the check-in feature
    enum Action: Equatable {
        /// Update the user's last check-in time to now
        case checkIn
        case checkInResponse(TaskResult<Bool>)
        
        /// Update the user's check-in interval
        case updateInterval(TimeInterval)
        case updateIntervalResponse(TaskResult<Bool>)
        
        /// Update the user's notification preferences
        case updateNotificationPreferences(notify30Min: Bool, notify2Hours: Bool)
        case updateNotificationPreferencesResponse(TaskResult<Bool>)
        
        /// Update the user's notification lead time
        case updateNotificationLeadTime(Int)
        case updateNotificationLeadTimeResponse(TaskResult<Bool>)
        
        /// Load the user's check-in data
        case loadCheckInData
        case loadCheckInDataResponse(TaskResult<CheckInData>)
        
        /// Timer tick for UI updates
        case timerTick
    }
    
    /// Dependencies for the check-in feature
    @Dependency(\.checkInClient) var checkInClient
    @Dependency(\.continuousClock) var clock
    
    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .checkIn:
                state.isLoading = true
                return .run { send in
                    let result = await TaskResult {
                        try await checkInClient.updateLastCheckedIn()
                    }
                    await send(.checkInResponse(result))
                }
                
            case let .checkInResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    state.lastCheckedIn = Date()
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }
                
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
                    // Interval was already updated in state when action was dispatched
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }
                
            case let .updateNotificationPreferences(notify30Min, notify2Hours):
                state.isLoading = true
                // Update state immediately for better UX
                state.notify30MinBefore = notify30Min
                state.notify2HoursBefore = notify2Hours
                state.notificationLeadTime = notify2Hours ? 120 : 30
                
                return .run { send in
                    let result = await TaskResult {
                        try await checkInClient.updateNotificationPreferences(
                            notify30Min: notify30Min,
                            notify2Hours: notify2Hours
                        )
                    }
                    await send(.updateNotificationPreferencesResponse(result))
                }
                
            case let .updateNotificationPreferencesResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Preferences were already updated in state when action was dispatched
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }
                
            case let .updateNotificationLeadTime(minutes):
                state.isLoading = true
                // Update state immediately for better UX
                state.notificationLeadTime = minutes
                let notify30Min = minutes == 30
                let notify2Hours = minutes == 120
                state.notify30MinBefore = notify30Min
                state.notify2HoursBefore = notify2Hours
                
                return .run { send in
                    let result = await TaskResult {
                        try await checkInClient.updateNotificationPreferences(
                            notify30Min: notify30Min,
                            notify2Hours: notify2Hours
                        )
                    }
                    await send(.updateNotificationLeadTimeResponse(result))
                }
                
            case let .updateNotificationLeadTimeResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Lead time was already updated in state when action was dispatched
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }
                
            case .loadCheckInData:
                state.isLoading = true
                return .run { send in
                    let result = await TaskResult {
                        try await checkInClient.loadCheckInData()
                    }
                    await send(.loadCheckInDataResponse(result))
                }
                
            case let .loadCheckInDataResponse(result):
                state.isLoading = false
                switch result {
                case let .success(data):
                    state.lastCheckedIn = data.lastCheckedIn
                    state.checkInInterval = data.checkInInterval
                    state.notify30MinBefore = data.notify30MinBefore
                    state.notify2HoursBefore = data.notify2HoursBefore
                    state.notificationLeadTime = data.notify2HoursBefore ? 120 : 30
                    state.sendAlertActive = data.sendAlertActive
                    state.manualAlertTimestamp = data.manualAlertTimestamp
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }
                
            case .timerTick:
                // No state changes needed, just triggers UI updates
                return .none
            }
        }
    }
}

/// Data model for check-in information
struct CheckInData: Equatable {
    var lastCheckedIn: Date
    var checkInInterval: TimeInterval
    var notify30MinBefore: Bool
    var notify2HoursBefore: Bool
    var sendAlertActive: Bool
    var manualAlertTimestamp: Date?
}
