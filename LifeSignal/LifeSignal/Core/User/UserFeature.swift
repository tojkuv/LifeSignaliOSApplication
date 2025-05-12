import Foundation
import ComposableArchitecture
import FirebaseAuth
import Dependencies
import FirebaseFirestore

/// Parent feature for managing user data and related operations
@Reducer
struct UserFeature {
    /// Cancellation IDs for long-running effects
    enum CancelID: Hashable, Sendable {
        case userDataStream
    }

    /// The state of the user feature
    @ObservableState
    struct State: Equatable, Sendable {
        /// User data - primary model containing all user information
        var userData: UserData = .empty

        /// Loading state
        var isLoading: Bool = false

        /// Error state using AlertState for better error handling
        @Presents var alert: AlertState<Action.Alert>?

        /// Stream state
        var isStreamActive: Bool = false

        /// Child feature states
        @Presents var profile: ProfileFeature.State?
        @Presents var checkIn: CheckInFeature.State?

        /// Custom Equatable implementation
        static func == (lhs: State, rhs: State) -> Bool {
            lhs.userData == rhs.userData &&
            lhs.isLoading == rhs.isLoading &&
            lhs.isStreamActive == rhs.isStreamActive
            // Alert state is handled by @Presents
        }

        /// Initialize with default values
        init() {}
    }

    /// Actions that can be performed on the user feature
    @CasePathable
    enum Action: Equatable, Sendable {
        // MARK: - Data Operations

        /// Load user data
        case loadUserData
        case loadUserDataResponse(TaskResult<UserData>)

        // MARK: - Stream Management

        /// Stream user data
        case startUserDataStream
        case userDataStreamResponse(UserData)
        case stopUserDataStream

        // MARK: - Profile Operations

        /// Update profile
        case updateProfile(name: String, emergencyNote: String)
        case updateProfileResponse(TaskResult<Void>)

        /// Update notification preferences
        case updateNotificationPreferences(enabled: Bool, notify30MinBefore: Bool, notify2HoursBefore: Bool)
        case updateNotificationPreferencesResponse(TaskResult<Void>)

        // MARK: - Check-in Operations

        /// Perform check-in
        case checkIn
        case checkInResponse(TaskResult<Void>)

        /// Update check-in interval
        case updateCheckInInterval(TimeInterval)
        case updateCheckInIntervalResponse(TaskResult<Void>)

        /// Trigger manual alert
        case triggerManualAlert
        case triggerManualAlertResponse(TaskResult<Void>)

        /// Clear manual alert
        case clearManualAlert
        case clearManualAlertResponse(TaskResult<Void>)

        // MARK: - Child Feature Actions

        /// Profile feature actions
        case profile(PresentationAction<ProfileFeature.Action>)

        /// Check-in feature actions
        case checkInAction(PresentationAction<CheckInFeature.Action>)

        // MARK: - Error Handling

        /// Alert actions for error handling
        case alert(PresentationAction<Alert>)

        /// Alert actions enum
        enum Alert: Equatable, Sendable {
            case dismiss
            case retry
        }

        // MARK: - Delegate Actions

        /// Delegate actions to notify parent features
        case delegate(DelegateAction)

        enum DelegateAction: Sendable {
            /// User data was updated
            case userDataUpdated(UserData)

            /// User data loading failed
            case userDataLoadFailed(Error)

            /// Profile was updated
            case profileUpdated

            /// Check-in was performed
            case checkInPerformed(Date)

            /// Check-in interval was updated
            case checkInIntervalUpdated(TimeInterval)

            /// User signed out
            case userSignedOut

            /// Custom Equatable implementation to handle Error
            static func == (lhs: DelegateAction, rhs: DelegateAction) -> Bool {
                switch (lhs, rhs) {
                case let (.userDataUpdated(lhsData), .userDataUpdated(rhsData)):
                    return lhsData == rhsData
                case (.userDataLoadFailed, .userDataLoadFailed):
                    // Just compare the case, not the associated Error value
                    return true
                case (.profileUpdated, .profileUpdated):
                    return true
                case let (.checkInPerformed(lhsDate), .checkInPerformed(rhsDate)):
                    return lhsDate == rhsDate
                case let (.checkInIntervalUpdated(lhsInterval), .checkInIntervalUpdated(rhsInterval)):
                    return lhsInterval == rhsInterval
                case (.userSignedOut, .userSignedOut):
                    return true
                default:
                    return false
                }
            }
        }
    }

    /// Dependencies
    @Dependency(\.firebaseUserClient) var firebaseUserClient
    @Dependency(\.firebaseAuth) var firebaseAuth
    @Dependency(\.firebaseNotification) var firebaseNotification
    @Dependency(\.timeFormatter) var timeFormatter

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            // MARK: - Data Operations

            case .loadUserData:
                state.isLoading = true
                return .run { [firebaseUserClient] send in
                    let result = await TaskResult {
                        // Load all user data at once
                        guard let userId = firebaseAuth.currentUserId() else {
                            throw NSError(domain: "UserFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }

                        // Get the user document using the client
                        return try await firebaseUserClient.getUserDocument(userId)
                    }
                    await send(.loadUserDataResponse(result))
                }

            case let .loadUserDataResponse(result):
                state.isLoading = false
                switch result {
                case let .success(userData):
                    // Update user data directly
                    state.userData = userData

                    // Initialize child feature states if needed
                    if state.checkIn == nil {
                        state.checkIn = CheckInFeature.State(
                            lastCheckedIn: userData.lastCheckedIn,
                            checkInInterval: userData.checkInInterval
                        )
                    } else {
                        // Update check-in data in child feature
                        state.checkIn?.lastCheckedIn = userData.lastCheckedIn
                        state.checkIn?.checkInInterval = userData.checkInInterval
                    }

                    // Initialize profile feature state if needed
                    if state.profile == nil {
                        state.profile = ProfileFeature.State(userData: userData)
                    } else {
                        // Update user data in profile feature
                        state.profile?.userData = userData
                    }

                    // Notify delegate that user data was updated
                    return .send(.delegate(.userDataUpdated(userData)))

                case let .failure(error):
                    // Use AlertState for error handling
                    state.alert = AlertState {
                        TextState("Error Loading User Data")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("Dismiss")
                        }
                        ButtonState(action: .retry) {
                            TextState("Retry")
                        }
                    } message: {
                        TextState(error.localizedDescription)
                    }
                    return .send(.delegate(.userDataLoadFailed(error)))
                }

            // MARK: - Stream Management

            case .startUserDataStream:
                // Only start the stream if it's not already active
                guard !state.isStreamActive else { return .none }

                state.isStreamActive = true

                // Start streaming user data using the Firebase client with TCA's recommended pattern
                return .run { [firebaseUserClient, firebaseAuth] send in
                    guard let userId = firebaseAuth.currentUserId() else {
                        await send(.loadUserDataResponse(.failure(
                            NSError(domain: "UserFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        )))
                        return
                    }

                    // Use a while loop for better control and error handling
                    do {
                        // Create a stream of user document updates
                        for await result in firebaseUserClient.streamUserDocument(userId) {
                            switch result {
                            case let .success(userData):
                                await send(.userDataStreamResponse(userData))
                            case let .failure(error):
                                // Only update error state for persistent errors
                                if let nsError = error as NSError?,
                                   nsError.domain != FirestoreErrorDomain ||
                                   nsError.code != FirestoreErrorCode.unavailable.rawValue {
                                    await send(.loadUserDataResponse(.failure(error)))
                                }

                                // For temporary errors, wait a bit and continue
                                try await Task.sleep(for: .seconds(1))
                            }

                            // Cooperate with the task system
                            await Task.yield()
                        }
                    } catch {
                        // If we get here with an error, the stream has ended unexpectedly
                        await send(.loadUserDataResponse(.failure(error)))
                    }

                    // If we get here, the stream has ended
                    await send(.stopUserDataStream)
                }
                .cancellable(id: CancelID.userDataStream)

            case let .userDataStreamResponse(userData):
                // Update user data with the latest data from the stream
                state.userData = userData

                // Update check-in data in child feature if it exists
                if state.checkIn != nil {
                    state.checkIn?.lastCheckedIn = userData.lastCheckedIn
                    state.checkIn?.checkInInterval = userData.checkInInterval
                }

                // Update profile data in child feature if it exists
                if state.profile != nil {
                    state.profile?.userData = userData
                }

                // Clear any previous error since we received valid data
                if state.alert != nil {
                    state.alert = nil
                }

                // Notify delegate that user data was updated
                return .send(.delegate(.userDataUpdated(userData)))

            case .stopUserDataStream:
                // Stop the user data stream
                state.isStreamActive = false
                return .cancel(id: CancelID.userDataStream)

            // MARK: - Profile Operations

            case let .updateProfile(name, emergencyNote):
                state.isLoading = true

                // Update local state immediately for better UX
                state.userData.name = name
                state.userData.emergencyNote = emergencyNote
                state.userData.profileComplete = true

                return .run { [firebaseUserClient, firebaseAuth] send in
                    let result = await TaskResult {
                        guard let userId = firebaseAuth.currentUserId() else {
                            throw NSError(domain: "UserFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }

                        // Create profile update
                        let update = ProfileUpdate(name: name, emergencyNote: emergencyNote)

                        // Update the profile using the client
                        try await firebaseUserClient.updateProfile(userId, update)
                    }
                    await send(.updateProfileResponse(result))
                }

            case let .updateProfileResponse(result):
                state.isLoading = false

                switch result {
                case .success:
                    return .send(.delegate(.profileUpdated))

                case let .failure(error):
                    // Use AlertState for error handling
                    state.alert = AlertState {
                        TextState("Profile Update Failed")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("Dismiss")
                        }
                        ButtonState(action: .retry) {
                            TextState("Retry")
                        }
                    } message: {
                        TextState(error.localizedDescription)
                    }
                    // Reload user data to revert changes if there was an error
                    return .send(.loadUserData)
                }

            case let .updateNotificationPreferences(enabled, notify30MinBefore, notify2HoursBefore):
                state.isLoading = true

                // Update local state immediately for better UX
                state.userData.notificationEnabled = enabled
                state.userData.notify30MinBefore = notify30MinBefore
                state.userData.notify2HoursBefore = notify2HoursBefore

                return .run { [firebaseUserClient, firebaseAuth] send in
                    let result = await TaskResult {
                        guard let userId = firebaseAuth.currentUserId() else {
                            throw NSError(domain: "UserFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }

                        // Create notification preferences
                        let preferences = NotificationPreferences(
                            enabled: enabled,
                            notify30MinBefore: notify30MinBefore,
                            notify2HoursBefore: notify2HoursBefore
                        )

                        // Update notification preferences using the client
                        try await firebaseUserClient.updateNotificationPreferences(userId, preferences)
                    }
                    await send(.updateNotificationPreferencesResponse(result))
                }

            case let .updateNotificationPreferencesResponse(result):
                state.isLoading = false

                switch result {
                case .success:
                    return .none

                case let .failure(error):
                    // Use AlertState for error handling
                    state.alert = AlertState {
                        TextState("Notification Preferences Update Failed")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("Dismiss")
                        }
                        ButtonState(action: .retry) {
                            TextState("Retry")
                        }
                    } message: {
                        TextState(error.localizedDescription)
                    }
                    // Reload user data to revert changes if there was an error
                    return .send(.loadUserData)
                }

            // MARK: - Check-in Operations

            case .checkIn:
                state.isLoading = true

                // Update local state immediately for better UX
                let now = Date()
                state.userData.lastCheckedIn = now

                // Update check-in state in child feature if it exists
                if state.checkIn != nil {
                    state.checkIn?.lastCheckedIn = now
                }

                return .run { [firebaseUserClient, firebaseNotification, firebaseAuth, timeFormatter, checkInInterval = state.userData.checkInInterval] send in
                    let result = await TaskResult {
                        guard let userId = firebaseAuth.currentUserId() else {
                            throw NSError(domain: "UserFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }

                        // Get user data for notification preferences
                        let userData = try await firebaseUserClient.getUserDocument(userId)

                        // Perform check-in using the client
                        try await firebaseUserClient.checkIn(userId)

                        // Show a confirmation notification
                        try await firebaseNotification.showLocalNotification(
                            title: "Check-in Successful",
                            body: "Your check-in has been recorded. Next check-in due in \(timeFormatter.formatTimeIntervalWithFullUnits(checkInInterval)).",
                            userInfo: ["type": "checkInConfirmation"]
                        )

                        // Schedule reminder notifications if enabled
                        if userData.notificationEnabled {
                            // Cancel any existing scheduled notifications
                            let identifiers = [
                                "checkInReminder-\(userData.checkInExpiration.timeIntervalSince1970)-30",
                                "checkInReminder-\(userData.checkInExpiration.timeIntervalSince1970)-120"
                            ]
                            await firebaseNotification.cancelScheduledNotifications(identifiers: identifiers)

                            // Schedule new reminders
                            let expirationDate = Date().addingTimeInterval(checkInInterval)
                            var reminderIds: [String] = []

                            // Schedule 30-minute reminder if enabled
                            if userData.notify30MinBefore {
                                let reminderId = try await firebaseNotification.scheduleCheckInReminder(
                                    expirationDate: expirationDate,
                                    minutesBefore: 30
                                )
                                reminderIds.append(reminderId)
                            }

                            // Schedule 2-hour reminder if enabled
                            if userData.notify2HoursBefore {
                                let reminderId = try await firebaseNotification.scheduleCheckInReminder(
                                    expirationDate: expirationDate,
                                    minutesBefore: 120
                                )
                                reminderIds.append(reminderId)
                            }
                        }
                    }
                    await send(.checkInResponse(result))
                }

            case let .checkInResponse(result):
                state.isLoading = false

                switch result {
                case .success:
                    // Notify delegate that check-in was performed
                    return .send(.delegate(.checkInPerformed(state.userData.lastCheckedIn)))

                case let .failure(error):
                    // Use AlertState for error handling
                    state.alert = AlertState {
                        TextState("Check-in Failed")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("Dismiss")
                        }
                        ButtonState(action: .retry) {
                            TextState("Retry")
                        }
                    } message: {
                        TextState(error.localizedDescription)
                    }
                    // Reload user data to revert changes if there was an error
                    return .send(.loadUserData)
                }

            case let .updateCheckInInterval(interval):
                state.isLoading = true

                // Update local state immediately for better UX
                state.userData.checkInInterval = interval

                // Update check-in interval in child feature if it exists
                if state.checkIn != nil {
                    state.checkIn?.checkInInterval = interval
                }

                return .run { [firebaseUserClient, firebaseNotification, firebaseAuth, timeFormatter] send in
                    let result = await TaskResult {
                        guard let userId = firebaseAuth.currentUserId() else {
                            throw NSError(domain: "UserFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }

                        // Get user data for notification preferences
                        let userData = try await firebaseUserClient.getUserDocument(userId)

                        // Update check-in interval using the client
                        try await firebaseUserClient.updateCheckInInterval(userId, interval)

                        // Cancel any existing scheduled notifications
                        let identifiers = [
                            "checkInReminder-\(userData.checkInExpiration.timeIntervalSince1970)-30",
                            "checkInReminder-\(userData.checkInExpiration.timeIntervalSince1970)-120"
                        ]
                        await firebaseNotification.cancelScheduledNotifications(identifiers: identifiers)

                        // Schedule new reminders if notifications are enabled
                        if userData.notificationEnabled {
                            let expirationDate = Date().addingTimeInterval(interval)
                            var reminderIds: [String] = []

                            // Schedule 30-minute reminder if enabled
                            if userData.notify30MinBefore {
                                let reminderId = try await firebaseNotification.scheduleCheckInReminder(
                                    expirationDate: expirationDate,
                                    minutesBefore: 30
                                )
                                reminderIds.append(reminderId)
                            }

                            // Schedule 2-hour reminder if enabled
                            if userData.notify2HoursBefore {
                                let reminderId = try await firebaseNotification.scheduleCheckInReminder(
                                    expirationDate: expirationDate,
                                    minutesBefore: 120
                                )
                                reminderIds.append(reminderId)
                            }
                        }

                        // Show a notification about the updated interval
                        try await firebaseNotification.showLocalNotification(
                            title: "Check-in Interval Updated",
                            body: "Your check-in interval has been updated to \(timeFormatter.formatTimeIntervalWithFullUnits(interval)).",
                            userInfo: ["type": "intervalUpdate"]
                        )
                    }
                    await send(.updateCheckInIntervalResponse(result))
                }

            case let .updateCheckInIntervalResponse(result):
                state.isLoading = false

                switch result {
                case .success:
                    // Notify delegate that check-in interval was updated
                    return .send(.delegate(.checkInIntervalUpdated(state.userData.checkInInterval)))

                case let .failure(error):
                    // Use AlertState for error handling
                    state.alert = AlertState {
                        TextState("Failed to Update Check-in Interval")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("Dismiss")
                        }
                        ButtonState(action: .retry) {
                            TextState("Retry")
                        }
                    } message: {
                        TextState(error.localizedDescription)
                    }
                    // Reload user data to revert changes if there was an error
                    return .send(.loadUserData)
                }

            case .triggerManualAlert:
                state.isLoading = true

                // Update local state immediately for better UX
                state.userData.manualAlertActive = true
                state.userData.manualAlertTimestamp = Date()

                return .run { [firebaseUserClient, firebaseAuth] send in
                    let result = await TaskResult {
                        guard let userId = firebaseAuth.currentUserId() else {
                            throw NSError(domain: "UserFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }

                        // Trigger manual alert using the client
                        try await firebaseUserClient.triggerManualAlert(userId)
                    }
                    await send(.triggerManualAlertResponse(result))
                }

            case let .triggerManualAlertResponse(result):
                state.isLoading = false

                switch result {
                case .success:
                    return .none

                case let .failure(error):
                    // Use AlertState for error handling
                    state.alert = AlertState {
                        TextState("Failed to Trigger Alert")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("Dismiss")
                        }
                        ButtonState(action: .retry) {
                            TextState("Retry")
                        }
                    } message: {
                        TextState(error.localizedDescription)
                    }
                    // Reload user data to revert changes if there was an error
                    return .send(.loadUserData)
                }

            case .clearManualAlert:
                state.isLoading = true

                // Update local state immediately for better UX
                state.userData.manualAlertActive = false
                state.userData.manualAlertTimestamp = nil

                return .run { [firebaseUserClient, firebaseAuth] send in
                    let result = await TaskResult {
                        guard let userId = firebaseAuth.currentUserId() else {
                            throw NSError(domain: "UserFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }

                        // Clear manual alert using the client
                        try await firebaseUserClient.clearManualAlert(userId)
                    }
                    await send(.clearManualAlertResponse(result))
                }

            case let .clearManualAlertResponse(result):
                state.isLoading = false

                switch result {
                case .success:
                    return .none

                case let .failure(error):
                    // Use AlertState for error handling
                    state.alert = AlertState {
                        TextState("Failed to Clear Alert")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("Dismiss")
                        }
                        ButtonState(action: .retry) {
                            TextState("Retry")
                        }
                    } message: {
                        TextState(error.localizedDescription)
                    }
                    // Reload user data to revert changes if there was an error
                    return .send(.loadUserData)
                }

            // MARK: - Child Feature Actions

            case .profile(.presented(.delegate(.updateProfile(let name, let emergencyNote)))):
                // Handle profile update from child feature
                return .send(.updateProfile(name: name, emergencyNote: emergencyNote))

            case .profile(.presented(.delegate(.updatePhoneNumber(let phone, let region)))):
                // Handle phone number update from child feature
                // Update user document with new phone number
                state.isLoading = true

                return .run { [firebaseUserClient, firebaseAuth] send in
                    let result = await TaskResult {
                        guard let userId = firebaseAuth.currentUserId() else {
                            throw NSError(domain: "UserFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }

                        // Update phone number in Firestore
                        let fields: [String: Any] = [
                            FirestoreConstants.UserFields.phoneNumber: phone,
                            FirestoreConstants.UserFields.phoneRegion: region
                        ]

                        try await firebaseUserClient.updateUserDocument(userId, fields)
                    }

                    // We don't need to send a response back to the profile feature
                    // as it will get updated through the user data stream
                    if case .failure(let error) = result {
                        await send(.loadUserDataResponse(.failure(error)))
                    }
                }

            case .profile(.presented(.delegate(.userSignedOut))):
                // Handle sign out from child feature
                return .send(.delegate(.userSignedOut))

            case .profile:
                // Other profile actions are handled by the ProfileFeature
                return .none

            case .checkInAction(.presented(.delegate(.checkInPerformed))):
                // Delegate to parent action
                return .send(.checkIn)

            case .checkInAction(.presented(.delegate(.checkInIntervalUpdated))):
                // Delegate to parent action with the selected interval
                if let selectedInterval = state.checkIn?.selectedInterval {
                    return .send(.updateCheckInInterval(selectedInterval))
                }
                return .none

            case .checkInAction:
                // Other check-in actions are handled by the CheckInFeature
                return .none

            // MARK: - Error Handling

            case .alert(.presented(.retry)):
                state.alert = nil
                return .send(.loadUserData)

            case .alert(.dismiss):
                state.alert = nil
                return .none

            // MARK: - Delegate Actions

            case .delegate(.userSignedOut):
                // This will be handled by the parent AppFeature
                return .none

            case .delegate:
                // Other delegate actions are handled by the parent feature
                return .none
            }
        }

        // Include child features using presents
        .presents(\.profile, action: \.profile) {
            ProfileFeature()
        }

        .presents(\.checkIn, action: \.checkInAction) {
            CheckInFeature()
        }

        // Add alert presentation
        .presents(\.alert, action: \.alert)

        ._printChanges()
    }
}
