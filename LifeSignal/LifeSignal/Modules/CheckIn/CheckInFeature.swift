import SwiftUI
import ComposableArchitecture
import Dependencies

/// A feature for the check-in functionality
/// This feature is a child of UserFeature and focuses on check-in specific UI and operations
@Reducer
struct CheckInFeature {
    /// The state for the check-in feature
    @ObservableState
    struct State: Equatable, Sendable {
        /// Whether to show the check-in confirmation alert
        var showCheckInConfirmation: Bool = false

        /// Whether to show the interval selection sheet
        var showIntervalSelectionSheet: Bool = false

        /// The current time (for UI updates)
        var currentTime: Date = Date()

        /// Last checked in time
        var lastCheckedIn: Date = Date()

        /// Check-in interval in seconds
        var checkInInterval: TimeInterval = TimeConstants.defaultCheckInInterval

        /// Temporary interval for selection
        var selectedInterval: TimeInterval = TimeConstants.defaultCheckInInterval

        /// Whether the user is currently checking in
        var isCheckingIn: Bool = false

        /// Whether the user is currently updating the interval
        var isUpdatingInterval: Bool = false

        /// Error state - using UserFacingError for consistency
        var error: UserFacingError? = nil

        /// Computed property for check-in expiration date
        var checkInExpiration: Date {
            return lastCheckedIn.addingTimeInterval(checkInInterval)
        }

        /// Computed property for time remaining until check-in
        var timeRemaining: TimeInterval {
            return max(0, checkInExpiration.timeIntervalSince(Date()))
        }

        /// Initialize with default values
        init() {}

        /// Initialize with specific values
        init(lastCheckedIn: Date, checkInInterval: TimeInterval) {
            self.lastCheckedIn = lastCheckedIn
            self.checkInInterval = checkInInterval
            self.selectedInterval = checkInInterval
        }
    }

    /// The actions for the check-in feature
    @CasePathable
    enum Action: Equatable, Sendable {
        /// Set whether to show the check-in confirmation alert
        case setShowCheckInConfirmation(Bool)

        /// Set whether to show the interval selection sheet
        case setShowIntervalSelectionSheet(Bool)

        /// Update the current time
        case updateCurrentTime

        /// Update the selected interval
        case updateSelectedInterval(TimeInterval)

        /// Perform check-in (delegated to parent)
        case checkIn

        /// Update check-in interval (delegated to parent)
        case updateCheckInInterval

        /// Update check-in data from user data
        case updateCheckInData(lastCheckedIn: Date, checkInInterval: TimeInterval)

        /// Set error state
        case setError(UserFacingError?)

        /// Delegate actions to parent feature
        case delegate(DelegateAction)

        @CasePathable
        enum DelegateAction: Equatable, Sendable {
            /// Check-in was performed
            case checkInPerformed

            /// Check-in interval was updated
            case checkInIntervalUpdated

            /// Error occurred
            case errorOccurred(UserFacingError)
        }
    }

    // MARK: - Dependencies
    @Dependency(\.timeFormatter) var timeFormatter
    @Dependency(\.date.now) var now

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .setShowCheckInConfirmation(show):
                state.showCheckInConfirmation = show
                return .none

            case let .setShowIntervalSelectionSheet(show):
                state.showIntervalSelectionSheet = show
                if show {
                    // Initialize selected interval with current interval
                    state.selectedInterval = state.checkInInterval
                }
                return .none

            case .updateCurrentTime:
                state.currentTime = now
                return .none

            case let .updateSelectedInterval(interval):
                state.selectedInterval = interval
                return .none

            case .checkIn:
                state.isCheckingIn = true
                state.showCheckInConfirmation = false

                // The actual check-in operation is delegated to the parent UserFeature
                return .send(.delegate(.checkInPerformed))

            case .updateCheckInInterval:
                state.isUpdatingInterval = true
                state.showIntervalSelectionSheet = false

                // The actual interval update is delegated to the parent UserFeature
                return .send(.delegate(.checkInIntervalUpdated))

            case let .updateCheckInData(lastCheckedIn, checkInInterval):
                state.lastCheckedIn = lastCheckedIn
                state.checkInInterval = checkInInterval
                return .none

            case let .setError(error):
                state.error = error
                if let error = error {
                    // If there's an error, notify the parent
                    return .send(.delegate(.errorOccurred(error)))
                }
                return .none

            case .delegate:
                // Delegate actions are handled by the parent feature
                return .none
            }
        }
    }

    // MARK: - Helper Methods

    /// Calculate the check-in progress for the progress circle
    /// - Returns: The progress value (0.0 to 1.0)
    func calculateCheckInProgress(_ state: State) -> Double {
        let elapsed = now.timeIntervalSince(state.lastCheckedIn)
        let progress = elapsed / state.checkInInterval
        return min(max(progress, 0.0), 1.0)
    }

    /// Format the time remaining until check-in expiration
    /// - Returns: A formatted string representation of the time remaining
    func formatTimeRemaining(_ state: State) -> String {
        let timeRemaining = timeFormatter.timeRemaining(state.lastCheckedIn, state.checkInInterval)

        if timeRemaining <= 0 {
            return "Expired"
        }

        return timeFormatter.formatTimeInterval(timeRemaining)
    }

    /// Format the check-in interval for display
    /// - Returns: A formatted string representation of the interval
    func formatCheckInInterval(_ state: State) -> String {
        return timeFormatter.formatTimeIntervalWithFullUnits(state.checkInInterval)
    }
}