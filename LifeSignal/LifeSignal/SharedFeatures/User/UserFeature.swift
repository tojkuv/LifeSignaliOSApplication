import Foundation
import ComposableArchitecture
import FirebaseFirestore

/// Feature for managing user data and operations
@Reducer
struct UserFeature {
    /// Cancellation IDs for long-running effects
    enum CancelID: Hashable {
        case userDataStream
    }

    /// The state of the user feature
    struct State: Equatable {
        // MARK: - Profile Data

        /// User's full name
        var name: String = ""

        /// User's phone number (E.164 format)
        var phoneNumber: String = ""

        /// User's phone region (ISO country code)
        var phoneRegion: String = "US"

        /// User's emergency profile description/note
        var note: String = ""

        /// User's unique QR code identifier
        var qrCodeId: String = ""

        /// Flag indicating if user has enabled notifications
        var notificationEnabled: Bool = true

        /// Flag indicating if user has completed profile setup
        var profileComplete: Bool = false

        // MARK: - Check-in Data

        /// Timestamp of user's last check-in
        var lastCheckedIn: Date = Date()

        /// User's check-in interval in seconds (default: 24 hours)
        var checkInInterval: TimeInterval = TimeManager.defaultInterval

        /// Flag indicating if user should be notified 30 minutes before check-in expiration
        var notify30MinBefore: Bool = true

        /// Flag indicating if user should be notified 2 hours before check-in expiration
        var notify2HoursBefore: Bool = false

        /// Flag indicating if user has manually triggered an alert
        var sendAlertActive: Bool = false

        /// Timestamp when user manually triggered an alert
        var manualAlertTimestamp: Date? = nil

        // MARK: - UI State

        /// Loading state
        var isLoading: Bool = false

        /// Error state
        var error: Error? = nil

        // MARK: - Computed Properties

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

        /// Custom Equatable implementation to handle Error? property
        static func == (lhs: State, rhs: State) -> Bool {
            lhs.name == rhs.name &&
            lhs.phoneNumber == rhs.phoneNumber &&
            lhs.phoneRegion == rhs.phoneRegion &&
            lhs.note == rhs.note &&
            lhs.qrCodeId == rhs.qrCodeId &&
            lhs.notificationEnabled == rhs.notificationEnabled &&
            lhs.profileComplete == rhs.profileComplete &&
            lhs.lastCheckedIn == rhs.lastCheckedIn &&
            lhs.checkInInterval == rhs.checkInInterval &&
            lhs.notify30MinBefore == rhs.notify30MinBefore &&
            lhs.notify2HoursBefore == rhs.notify2HoursBefore &&
            lhs.sendAlertActive == rhs.sendAlertActive &&
            lhs.manualAlertTimestamp == rhs.manualAlertTimestamp &&
            lhs.isLoading == rhs.isLoading &&
            (lhs.error != nil) == (rhs.error != nil)
        }
    }

    /// Actions that can be performed on the user feature
    enum Action: Equatable {
        /// Load user data
        case loadUserData
        case loadUserDataResponse(TaskResult<UserData>)

        /// Stream user data
        case startUserDataStream
        case userDataStreamResponse(UserData)
        case stopUserDataStream

        /// Update profile data
        case updateProfile(name: String, note: String)
        case updateProfileResponse(TaskResult<Bool>)

        /// Update notification settings
        case updateNotificationSettings(enabled: Bool)
        case updateNotificationSettingsResponse(TaskResult<Bool>)

        /// Check-in actions
        case checkIn
        case checkInResponse(TaskResult<Bool>)

        /// Update check-in interval
        case updateCheckInInterval(TimeInterval)
        case updateCheckInIntervalResponse(TaskResult<Bool>)

        /// Update notification preferences
        case updateNotificationPreferences(notify30Min: Bool, notify2Hours: Bool)
        case updateNotificationPreferencesResponse(TaskResult<Bool>)

        /// Sign out
        case signOut
        case signOutResponse(TaskResult<Bool>)
    }

    /// Dependencies
    @Dependency(\.userClient) var userClient

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadUserData:
                state.isLoading = true
                return .run { send in
                    do {
                        // Load all user data at once
                        let userData = try await userClient.loadUserData()
                        await send(.loadUserDataResponse(.success(userData)))
                    } catch {
                        await send(.loadUserDataResponse(.failure(error)))
                    }
                }

            case let .loadUserDataResponse(result):
                state.isLoading = false
                switch result {
                case let .success(userData):
                    // Update all user properties directly
                    state.name = userData.name
                    state.phoneNumber = userData.phoneNumber
                    state.phoneRegion = userData.phoneRegion
                    state.note = userData.note
                    state.qrCodeId = userData.qrCodeId
                    state.notificationEnabled = userData.notificationEnabled
                    state.profileComplete = userData.profileComplete
                    state.lastCheckedIn = userData.lastCheckedIn
                    state.checkInInterval = userData.checkInInterval
                    state.notify30MinBefore = userData.notify30MinBefore
                    state.notify2HoursBefore = userData.notify2HoursBefore
                    state.sendAlertActive = userData.sendAlertActive
                    state.manualAlertTimestamp = userData.manualAlertTimestamp
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }

            case .startUserDataStream:
                // Start streaming user data
                return .run { send in
                    // Get the user data stream
                    let stream = userClient.streamUserData()

                    // Process each update from the stream
                    for await userData in stream {
                        await send(.userDataStreamResponse(userData))
                    }
                }
                .cancellable(id: CancelID.userDataStream)

            case let .userDataStreamResponse(userData):
                // Update all user properties with the latest data from the stream
                state.name = userData.name
                state.phoneNumber = userData.phoneNumber
                state.phoneRegion = userData.phoneRegion
                state.note = userData.note
                state.qrCodeId = userData.qrCodeId
                state.notificationEnabled = userData.notificationEnabled
                state.profileComplete = userData.profileComplete
                state.lastCheckedIn = userData.lastCheckedIn
                state.checkInInterval = userData.checkInInterval
                state.notify30MinBefore = userData.notify30MinBefore
                state.notify2HoursBefore = userData.notify2HoursBefore
                state.sendAlertActive = userData.sendAlertActive
                state.manualAlertTimestamp = userData.manualAlertTimestamp
                return .none

            case .stopUserDataStream:
                // Cancel the user data stream
                return .cancel(id: CancelID.userDataStream)

            case let .updateProfile(name, note):
                state.isLoading = true
                // Update local state immediately for better UX
                state.name = name
                state.note = note
                state.profileComplete = true

                return .run { send in
                    let result = await TaskResult {
                        try await userClient.updateUserFields([
                            FirestoreConstants.UserFields.name: name,
                            FirestoreConstants.UserFields.note: note,
                            FirestoreConstants.UserFields.profileComplete: true
                        ])
                    }
                    await send(.updateProfileResponse(result))
                }

            case let .updateProfileResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Profile data was already updated in state when action was dispatched
                    return .none
                case let .failure(error):
                    state.error = error
                    // Reload user data to revert changes if there was an error
                    return .send(.loadUserData)
                }

            case let .updateNotificationSettings(enabled):
                state.isLoading = true
                // Update local state immediately for better UX
                state.notificationEnabled = enabled

                return .run { send in
                    let result = await TaskResult {
                        try await userClient.updateUserFields([
                            FirestoreConstants.UserFields.notificationEnabled: enabled
                        ])
                    }
                    await send(.updateNotificationSettingsResponse(result))
                }

            case let .updateNotificationSettingsResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Notification settings were already updated in state when action was dispatched
                    return .none
                case let .failure(error):
                    state.error = error
                    // Reload user data to revert changes if there was an error
                    return .send(.loadUserData)
                }

            case .checkIn:
                state.isLoading = true
                // Update local state immediately for better UX
                state.lastCheckedIn = Date()

                return .run { send in
                    let result = await TaskResult {
                        try await userClient.updateUserFields([
                            FirestoreConstants.UserFields.lastCheckedIn: Timestamp(date: Date())
                        ])
                    }
                    await send(.checkInResponse(result))
                }

            case let .checkInResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Check-in was already updated in state when action was dispatched
                    return .none
                case let .failure(error):
                    state.error = error
                    // Reload user data to revert changes if there was an error
                    return .send(.loadUserData)
                }

            case let .updateCheckInInterval(interval):
                state.isLoading = true
                // Update local state immediately for better UX
                state.checkInInterval = interval

                return .run { send in
                    let result = await TaskResult {
                        try await userClient.updateUserFields([
                            FirestoreConstants.UserFields.checkInInterval: interval
                        ])
                    }
                    await send(.updateCheckInIntervalResponse(result))
                }

            case let .updateCheckInIntervalResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Interval was already updated in state when action was dispatched
                    return .none
                case let .failure(error):
                    state.error = error
                    // Reload user data to revert changes if there was an error
                    return .send(.loadUserData)
                }

            case let .updateNotificationPreferences(notify30Min, notify2Hours):
                state.isLoading = true
                // Update local state immediately for better UX
                state.notify30MinBefore = notify30Min
                state.notify2HoursBefore = notify2Hours

                return .run { send in
                    let result = await TaskResult {
                        try await userClient.updateUserFields([
                            FirestoreConstants.UserFields.notify30MinBefore: notify30Min,
                            FirestoreConstants.UserFields.notify2HoursBefore: notify2Hours
                        ])
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
                    // Reload user data to revert changes if there was an error
                    return .send(.loadUserData)
                }

            case .signOut:
                state.isLoading = true
                return .run { send in
                    let result = await TaskResult {
                        try await userClient.signOut()
                    }
                    await send(.signOutResponse(result))
                }

            case let .signOutResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Handle sign out in parent feature
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }
            }
        }
    }
}

/// Profile data type for loading user profile information
typealias ProfileData = (name: String, phoneNumber: String, phoneRegion: String, note: String, qrCodeId: String, notificationEnabled: Bool, profileComplete: Bool)

/// Check-in data type for loading user check-in information
typealias CheckInData = CheckInFeature.CheckInData
