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
        // No longer need userDataStream as it's handled at the AppFeature level
    }

    /// The state of the user feature
    @ObservableState
    struct State: Equatable, Sendable {
        /// User data - primary model containing all user information
        var userData: UserData = .empty

        /// Loading state
        var isLoading: Bool = false

        /// Child feature states
        @Presents var profile: ProfileFeature.State?
        @Presents var checkIn: CheckInFeature.State?

        /// Initialize with default values
        init() {}
    }

    /// Actions that can be performed on the user feature
    @CasePathable
    enum Action: Equatable, Sendable {
        // MARK: - Data Operations

        /// Load user data
        case loadUserData
        case loadUserDataResponse(UserData)
        case loadUserDataFailed(UserFacingError)

        // Stream management is now handled at the AppFeature level

        // MARK: - Profile Operations

        /// Update profile
        case updateProfile(name: String, emergencyNote: String)
        case updateProfileSucceeded
        case updateProfileFailed(UserFacingError)

        /// Update notification preferences
        case updateNotificationPreferences(enabled: Bool, notify30MinBefore: Bool, notify2HoursBefore: Bool)
        case updateNotificationPreferencesSucceeded
        case updateNotificationPreferencesFailed(UserFacingError)

        // MARK: - Check-in Operations

        /// Perform check-in
        case checkIn
        case checkInSucceeded
        case checkInFailed(UserFacingError)

        /// Update check-in interval
        case updateCheckInInterval(TimeInterval)
        case updateCheckInIntervalSucceeded
        case updateCheckInIntervalFailed(UserFacingError)

        /// Trigger manual alert
        case triggerManualAlert
        case triggerManualAlertSucceeded
        case triggerManualAlertFailed(UserFacingError)

        /// Clear manual alert
        case clearManualAlert
        case clearManualAlertSucceeded
        case clearManualAlertFailed(UserFacingError)

        // MARK: - Child Feature Actions

        /// Profile feature actions
        case profile(PresentationAction<ProfileFeature.Action>)

        /// Check-in feature actions
        case checkInAction(PresentationAction<CheckInFeature.Action>)

        // MARK: - Delegate Actions

        /// Delegate actions to notify parent features
        case delegate(DelegateAction)

        enum DelegateAction: Equatable, Sendable {
            /// User data was updated
            case userDataUpdated(UserData)

            /// User data loading failed
            case userDataLoadFailed(UserFacingError)

            /// Profile was updated
            case profileUpdated

            /// Profile update failed
            case profileUpdateFailed(UserFacingError)

            /// Notification preferences update failed
            case notificationPreferencesUpdateFailed(UserFacingError)

            /// Check-in was performed
            case checkInPerformed(Date)

            /// Check-in failed
            case checkInFailed(UserFacingError)

            /// Check-in interval was updated
            case checkInIntervalUpdated(TimeInterval)

            /// Check-in interval update failed
            case checkInIntervalUpdateFailed(UserFacingError)

            /// Manual alert trigger failed
            case manualAlertTriggerFailed(UserFacingError)

            /// Manual alert clear failed
            case manualAlertClearFailed(UserFacingError)

            /// Phone number update failed
            case phoneNumberUpdateFailed(UserFacingError)

            /// User signed out
            case userSignedOut
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
                return .run { [firebaseUserClient, firebaseAuth] send in
                    do {
                        // Get the authenticated user ID or throw if not available
                        let userId = try await firebaseAuth.currentUserId()

                        // Get the user document using the client
                        let userData = try await firebaseUserClient.getUserDocument(userId)
                        await send(.loadUserDataResponse(userData))
                    } catch {
                        // Map the error to a user-facing error
                        let userFacingError = UserFacingError.from(error)

                        // Handle error directly in the effect
                        await send(.loadUserDataFailed(userFacingError))

                        // Notify delegate about the failure with the user-facing error
                        await send(.delegate(.userDataLoadFailed(userFacingError)))
                    }
                }

            case let .loadUserDataResponse(userData):
                state.isLoading = false

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

            case let .loadUserDataFailed(error):
                state.isLoading = false
                // Log the error but don't take any additional action
                // The parent feature will handle displaying the error to the user
                FirebaseLogger.user.error("User data loading failed: \(error)")
                return .none

            // Stream management is now handled at the AppFeature level

            // MARK: - Profile Operations

            case let .updateProfile(name, emergencyNote):
                state.isLoading = true

                // Update local state immediately for better UX
                state.userData.name = name
                state.userData.emergencyNote = emergencyNote
                state.userData.profileComplete = true

                return .run { [firebaseUserClient, firebaseAuth] send in
                    do {
                        // Get the authenticated user ID or throw if not available
                        let userId = try await firebaseAuth.currentUserId()

                        // Create profile update
                        let update = ProfileUpdate(name: name, emergencyNote: emergencyNote)

                        // Update the profile using the client
                        try await firebaseUserClient.updateProfile(userId, update)

                        // Send success response
                        await send(.updateProfileSucceeded)

                        // Notify delegate that profile was updated
                        await send(.delegate(.profileUpdated))
                    } catch {
                        // Map the error to a user-facing error
                        let userFacingError = UserFacingError.from(error)

                        // Handle error directly in the effect
                        await send(.updateProfileFailed(userFacingError))

                        // Notify delegate about the failure with the user-facing error
                        await send(.delegate(.profileUpdateFailed(userFacingError)))

                        // Reload user data to revert changes if there was an error
                        await send(.loadUserData)
                    }
                }

            case .updateProfileSucceeded:
                state.isLoading = false
                return .none

            case let .updateProfileFailed(error):
                state.isLoading = false
                FirebaseLogger.user.error("Profile update failed: \(error)")
                return .none

            case let .updateNotificationPreferences(enabled, notify30MinBefore, notify2HoursBefore):
                state.isLoading = true

                // Update local state immediately for better UX
                state.userData.notificationEnabled = enabled
                state.userData.notify30MinBefore = notify30MinBefore
                state.userData.notify2HoursBefore = notify2HoursBefore

                return .run { [firebaseUserClient, firebaseAuth] send in
                    do {
                        // Get the authenticated user ID or throw if not available
                        let userId = try await firebaseAuth.currentUserId()

                        // Create notification preferences
                        let preferences = NotificationPreferences(
                            enabled: enabled,
                            notify30MinBefore: notify30MinBefore,
                            notify2HoursBefore: notify2HoursBefore
                        )

                        // Update notification preferences using the client
                        try await firebaseUserClient.updateNotificationPreferences(userId, preferences)

                        // Send success response
                        await send(.updateNotificationPreferencesSucceeded)
                    } catch {
                        // Map the error to a user-facing error
                        let userFacingError = UserFacingError.from(error)

                        // Handle error directly in the effect
                        await send(.updateNotificationPreferencesFailed(userFacingError))

                        // Notify delegate about the failure with the user-facing error
                        await send(.delegate(.notificationPreferencesUpdateFailed(userFacingError)))

                        // Reload user data to revert changes if there was an error
                        await send(.loadUserData)
                    }
                }

            case .updateNotificationPreferencesSucceeded:
                state.isLoading = false
                return .none

            case let .updateNotificationPreferencesFailed(error):
                state.isLoading = false
                FirebaseLogger.user.error("Notification preferences update failed: \(error)")
                return .none

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
                    do {
                        // Get the authenticated user ID or throw if not available
                        let userId = try await firebaseAuth.currentUserId()

                        // Get user data for notification preferences
                        let userData = try await firebaseUserClient.getUserDocument(userId)

                        // Perform check-in using the client
                        try await firebaseUserClient.checkIn(userId)

                        // Show a confirmation notification
                        let _ = try await firebaseNotification.showLocalNotification(
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

                        // Send success response
                        await send(.checkInSucceeded)

                        // Notify delegate that check-in was performed
                        await send(.delegate(.checkInPerformed(now)))
                    } catch {
                        // Map the error to a user-facing error
                        let userFacingError = UserFacingError.from(error)

                        // Handle error directly in the effect
                        await send(.checkInFailed(userFacingError))

                        // Notify delegate about the failure with the user-facing error
                        await send(.delegate(.checkInFailed(userFacingError)))

                        // Reload user data to revert changes if there was an error
                        await send(.loadUserData)
                    }
                }

            case .checkInSucceeded:
                state.isLoading = false
                return .none

            case let .checkInFailed(error):
                state.isLoading = false
                FirebaseLogger.user.error("Check-in failed: \(error)")
                return .none

            case let .updateCheckInInterval(interval):
                state.isLoading = true

                // Update local state immediately for better UX
                state.userData.checkInInterval = interval

                // Update check-in interval in child feature if it exists
                if state.checkIn != nil {
                    state.checkIn?.checkInInterval = interval
                }

                return .run { [firebaseUserClient, firebaseNotification, firebaseAuth, timeFormatter] send in
                    do {
                        // Get the authenticated user ID or throw if not available
                        let userId = try await firebaseAuth.currentUserId()

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
                        let _ = try await firebaseNotification.showLocalNotification(
                            title: "Check-in Interval Updated",
                            body: "Your check-in interval has been updated to \(timeFormatter.formatTimeIntervalWithFullUnits(interval)).",
                            userInfo: ["type": "intervalUpdate"]
                        )

                        // Send success response
                        await send(.updateCheckInIntervalSucceeded)

                        // Notify delegate that check-in interval was updated
                        await send(.delegate(.checkInIntervalUpdated(interval)))
                    } catch {
                        // Map the error to a user-facing error
                        let userFacingError = UserFacingError.from(error)

                        // Handle error directly in the effect
                        await send(.updateCheckInIntervalFailed(userFacingError))

                        // Notify delegate about the failure with the user-facing error
                        await send(.delegate(.checkInIntervalUpdateFailed(userFacingError)))

                        // Reload user data to revert changes if there was an error
                        await send(.loadUserData)
                    }
                }

            case .updateCheckInIntervalSucceeded:
                state.isLoading = false
                return .none

            case let .updateCheckInIntervalFailed(error):
                state.isLoading = false
                FirebaseLogger.user.error("Check-in interval update failed: \(error)")
                return .none

            case .triggerManualAlert:
                state.isLoading = true

                // Update local state immediately for better UX
                state.userData.manualAlertActive = true
                state.userData.manualAlertTimestamp = Date()

                return .run { [firebaseUserClient, firebaseAuth] send in
                    do {
                        // Get the authenticated user ID or throw if not available
                        let userId = try await firebaseAuth.currentUserId()

                        // Trigger manual alert using the client
                        try await firebaseUserClient.triggerManualAlert(userId)

                        // Send success response
                        await send(.triggerManualAlertSucceeded)
                    } catch {
                        // Map the error to a user-facing error
                        let userFacingError = UserFacingError.from(error)

                        // Handle error directly in the effect
                        await send(.triggerManualAlertFailed(userFacingError))

                        // Notify delegate about the failure with the user-facing error
                        await send(.delegate(.manualAlertTriggerFailed(userFacingError)))

                        // Reload user data to revert changes if there was an error
                        await send(.loadUserData)
                    }
                }

            case .triggerManualAlertSucceeded:
                state.isLoading = false
                return .none

            case let .triggerManualAlertFailed(error):
                state.isLoading = false
                FirebaseLogger.user.error("Manual alert trigger failed: \(error)")
                return .none

            case .clearManualAlert:
                state.isLoading = true

                // Update local state immediately for better UX
                state.userData.manualAlertActive = false
                state.userData.manualAlertTimestamp = nil

                return .run { [firebaseUserClient, firebaseAuth] send in
                    do {
                        // Get the authenticated user ID or throw if not available
                        let userId = try await firebaseAuth.currentUserId()

                        // Clear manual alert using the client
                        try await firebaseUserClient.clearManualAlert(userId)

                        // Send success response
                        await send(.clearManualAlertSucceeded)
                    } catch {
                        // Map the error to a user-facing error
                        let userFacingError = UserFacingError.from(error)

                        // Handle error directly in the effect
                        await send(.clearManualAlertFailed(userFacingError))

                        // Notify delegate about the failure with the user-facing error
                        await send(.delegate(.manualAlertClearFailed(userFacingError)))

                        // Reload user data to revert changes if there was an error
                        await send(.loadUserData)
                    }
                }

            case .clearManualAlertSucceeded:
                state.isLoading = false
                return .none

            case let .clearManualAlertFailed(error):
                state.isLoading = false
                FirebaseLogger.user.error("Manual alert clear failed: \(error)")
                return .none

            // MARK: - Child Feature Actions

            case .profile(.presented(.delegate(.updateProfile(let name, let emergencyNote)))):
                // Handle profile update from child feature
                return .send(.updateProfile(name: name, emergencyNote: emergencyNote))

            case .profile(.presented(.delegate(.updatePhoneNumber(let phone, let region)))):
                // Handle phone number update from child feature
                // Update user document with new phone number
                state.isLoading = true

                return .run { [firebaseUserClient, firebaseAuth] send in
                    do {
                        // Get the authenticated user ID or throw if not available
                        let userId = try await firebaseAuth.currentUserId()

                        // Update phone number in Firestore
                        let fields: [String: Any] = [
                            FirestoreConstants.UserFields.phoneNumber: phone,
                            FirestoreConstants.UserFields.phoneRegion: region
                        ]

                        try await firebaseUserClient.updateUserDocument(userId, fields)

                        // Load updated user data
                        let userData = try await firebaseUserClient.getUserDocument(userId)
                        await send(.loadUserDataResponse(userData))
                    } catch {
                        // Map the error to a user-facing error
                        let userFacingError = UserFacingError.from(error)

                        // Notify delegate about the failure with the user-facing error
                        await send(.delegate(.phoneNumberUpdateFailed(userFacingError)))

                        // Load user data to refresh the state
                        await send(.loadUserData)
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

            // Error handling is now delegated to AppFeature

            // MARK: - Delegate Actions

            case .delegate(.userSignedOut):
                // This will be handled by the parent AppFeature
                return .none

            case .delegate:
                // Other delegate actions are handled by the parent feature
                return .none
            }
        }

        // Include child features using ifLet
        .ifLet(\.$profile, action: \.profile) {
            ProfileFeature()
        }
        .ifLet(\.$checkIn, action: \.checkInAction) {
            CheckInFeature()
        }

        ._printChanges()
    }
}
