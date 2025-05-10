import Foundation
import ComposableArchitecture
import FirebaseFirestore

/// Feature for managing user check-in functionality
@Reducer
struct CheckInFeature {
    /// Data model for check-in information
    struct CheckInData: Equatable {
        var lastCheckedIn: Date
        var checkInInterval: TimeInterval
        var notify30MinBefore: Bool
        var notify2HoursBefore: Bool
        var sendAlertActive: Bool
        var manualAlertTimestamp: Date?
    }
    /// The state of the check-in feature
    struct State: Equatable {
        /// User's notification lead time in minutes (30 or 120)
        var notificationLeadTime: Int = 30

        /// Loading state
        var isLoading: Bool = false

        /// Error state
        var error: Error? = nil

        /// Reference to the parent user state
        var _userState: UserFeature.State?

        /// Computed properties that access user state
        var checkInInterval: TimeInterval { _userState?.checkInInterval ?? TimeManager.defaultInterval }
        var lastCheckedIn: Date { _userState?.lastCheckedIn ?? Date() }
        var notify30MinBefore: Bool { _userState?.notify30MinBefore ?? true }
        var notify2HoursBefore: Bool { _userState?.notify2HoursBefore ?? false }
        var sendAlertActive: Bool { _userState?.sendAlertActive ?? false }
        var manualAlertTimestamp: Date? { _userState?.manualAlertTimestamp }

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
        /// Parent user actions
        case userAction(UserFeature.Action)

        /// Update the user's last check-in time to now
        case checkIn

        /// Update the user's check-in interval
        case updateInterval(TimeInterval)

        /// Update the user's notification preferences
        case updateNotificationPreferences(notify30Min: Bool, notify2Hours: Bool)

        /// Update the user's notification lead time
        case updateNotificationLeadTime(Int)

        /// Timer tick for UI updates
        case timerTick
    }

    /// Dependencies for the check-in feature
    @Dependency(\.userClient) var userClient
    @Dependency(\.continuousClock) var clock

    /// Connect to parent user state
    @ObservableState
    struct _UserState {
        var userState: UserFeature.State?
    }

    /// Property wrapper for connecting to parent user state
    func _userState(
        get: @escaping (State) -> UserFeature.State?,
        set: @escaping (inout State, UserFeature.State?) -> Void
    ) -> some ReducerOf<Self> {
        Reduce { state, action in
            if case let .userAction(userAction) = action {
                return .send(.user(userAction))
            }
            return self.reduce(into: &state, action: action)
        }
        .transformDependency(\.self) { dependency in
            var dependency = dependency
            let userState = _UserState(userState: get(dependency.state))

            dependency.state._userState = userState.userState

            return dependency
        }
    }

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .userAction:
                // Forward to parent
                return .none

            case .checkIn:
                state.isLoading = true
                return .send(.userAction(.checkIn))

            case let .updateInterval(interval):
                state.isLoading = true
                return .send(.userAction(.updateCheckInInterval(interval)))

            case let .updateNotificationPreferences(notify30Min, notify2Hours):
                state.isLoading = true
                state.notificationLeadTime = notify2Hours ? 120 : 30
                return .send(.userAction(.updateNotificationPreferences(notify30Min: notify30Min, notify2Hours: notify2Hours)))

            case let .updateNotificationLeadTime(minutes):
                state.isLoading = true
                state.notificationLeadTime = minutes
                let notify30Min = minutes == 30
                let notify2Hours = minutes == 120
                return .send(.userAction(.updateNotificationPreferences(notify30Min: notify30Min, notify2Hours: notify2Hours)))

            case .timerTick:
                // No state changes needed, just triggers UI updates
                return .none
            }
        }
    }
}
