import SwiftUI
import ComposableArchitecture
import Combine
import FirebaseAuth

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
        var checkInInterval: TimeInterval = TimeManager.defaultInterval

        /// Temporary interval for selection
        var selectedInterval: TimeInterval = TimeManager.defaultInterval

        /// Whether the user is currently checking in
        var isCheckingIn: Bool = false

        /// Whether the user is currently updating the interval
        var isUpdatingInterval: Bool = false

        /// Error state
        var error: Error?

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

        /// Custom Equatable implementation to handle Error? property
        static func == (lhs: State, rhs: State) -> Bool {
            lhs.showCheckInConfirmation == rhs.showCheckInConfirmation &&
            lhs.showIntervalSelectionSheet == rhs.showIntervalSelectionSheet &&
            lhs.currentTime == rhs.currentTime &&
            lhs.lastCheckedIn == rhs.lastCheckedIn &&
            lhs.checkInInterval == rhs.checkInInterval &&
            lhs.selectedInterval == rhs.selectedInterval &&
            lhs.isCheckingIn == rhs.isCheckingIn &&
            lhs.isUpdatingInterval == rhs.isUpdatingInterval &&
            (lhs.error != nil) == (rhs.error != nil)
        }
    }

    /// The actions for the check-in feature
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

        /// Clear any error state
        case clearError

        /// Delegate actions to parent feature
        case delegate(DelegateAction)

        enum DelegateAction: Equatable, Sendable {
            /// Check-in was performed
            case checkInPerformed

            /// Check-in interval was updated
            case checkInIntervalUpdated
        }
    }

    // MARK: - Dependencies
    @Dependency(\.timeFormatter) var timeFormatter

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
                state.currentTime = Date()
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

            case .clearError:
                state.error = nil
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
        let elapsed = Date().timeIntervalSince(state.lastCheckedIn)
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