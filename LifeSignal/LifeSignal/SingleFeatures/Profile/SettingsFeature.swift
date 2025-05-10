import Foundation
import ComposableArchitecture

/// Feature for settings
@Reducer
struct SettingsFeature {
    /// The state of the settings feature
    struct State: Equatable {
        /// Flag indicating if notifications are enabled
        var notificationsEnabled: Bool = true

        /// Loading state
        var isLoading: Bool = false

        /// Error state
        var error: Error? = nil

        /// Custom Equatable implementation to handle Error? property
        static func == (lhs: State, rhs: State) -> Bool {
            lhs.notificationsEnabled == rhs.notificationsEnabled &&
            lhs.isLoading == rhs.isLoading &&
            (lhs.error != nil) == (rhs.error != nil)
        }
    }

    /// Actions that can be performed on the settings feature
    enum Action: Equatable {
        /// Load settings
        case loadSettings
        case loadSettingsResponse(TaskResult<Bool>)

        /// Update notification settings
        case updateNotifications(Bool)
        case updateNotificationsResponse(TaskResult<Bool>)
    }

    /// Dependencies
    @Dependency(\.userClient) var userClient

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadSettings:
                state.isLoading = true
                return .run { send in
                    let result = await TaskResult {
                        try await userClient.loadSettings()
                    }
                    await send(.loadSettingsResponse(result))
                }

            case let .loadSettingsResponse(result):
                state.isLoading = false
                switch result {
                case let .success(enabled):
                    state.notificationsEnabled = enabled
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }

            case let .updateNotifications(enabled):
                state.isLoading = true
                return .run { send in
                    let result = await TaskResult {
                        try await userClient.updateUserFields([
                            FirestoreConstants.UserFields.notificationEnabled: enabled
                        ])
                    }
                    await send(.updateNotificationsResponse(result))
                }

            case let .updateNotificationsResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }
            }
        }
    }
}
