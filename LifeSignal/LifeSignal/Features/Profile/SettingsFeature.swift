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
    @Dependency(\.profileClient) var profileClient

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadSettings:
                state.isLoading = true
                return .run { send in
                    let result = await TaskResult {
                        try await profileClient.loadSettings()
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
                        try await profileClient.updateNotificationSettings(enabled: enabled)
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
