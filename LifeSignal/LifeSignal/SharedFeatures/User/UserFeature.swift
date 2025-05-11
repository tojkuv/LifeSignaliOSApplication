import Foundation
import ComposableArchitecture
import FirebaseFirestore
import FirebaseAuth

/// Feature for managing user data and operations
@Reducer
struct UserFeature {
    /// Cancellation IDs for long-running effects
    enum CancelID: Hashable {
        case userDataStream
    }

    /// The state of the user feature
    struct State: Equatable, Sendable, Decodable {
        // MARK: - Profile Data

        /// User's full name
        var name: String = ""

        /// User's phone number (E.164 format)
        var phoneNumber: String = ""

        /// User's phone region (ISO country code)
        var phoneRegion: String = "US"

        /// User's emergency profile description/note
        var emergencyNote: String = ""

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
        var manualAlertActive: Bool = false

        /// Timestamp when user manually triggered an alert
        var manualAlertTimestamp: Date? = nil

        /// Loading state
        var isLoading: Bool = false

        /// Error state
        var error: Error?

        /// User stream state
        var userStream: UserStreamFeature.State?

        // MARK: - Computed Properties

        /// Computed property for check-in expiration time
        var checkInExpiration: Date {
            return lastCheckedIn.addingTimeInterval(checkInInterval)
        }

        /// Computed property for time remaining until check-in expiration
        var timeRemaining: TimeInterval {
            return checkInExpiration.timeIntervalSince(Date())
        }

        /// Custom Equatable implementation to handle Error? property
        static func == (lhs: State, rhs: State) -> Bool {
            lhs.name == rhs.name &&
            lhs.phoneNumber == rhs.phoneNumber &&
            lhs.phoneRegion == rhs.phoneRegion &&
            lhs.emergencyNote == rhs.emergencyNote &&
            lhs.qrCodeId == rhs.qrCodeId &&
            lhs.notificationEnabled == rhs.notificationEnabled &&
            lhs.profileComplete == rhs.profileComplete &&
            lhs.lastCheckedIn == rhs.lastCheckedIn &&
            lhs.checkInInterval == rhs.checkInInterval &&
            lhs.notify30MinBefore == rhs.notify30MinBefore &&
            lhs.notify2HoursBefore == rhs.notify2HoursBefore &&
            lhs.manualAlertActive == rhs.manualAlertActive &&
            lhs.manualAlertTimestamp == rhs.manualAlertTimestamp &&
            lhs.isLoading == rhs.isLoading &&
            (lhs.error != nil) == (rhs.error != nil)
        }

        // MARK: - Decodable Implementation

        enum CodingKeys: String, CodingKey {
            case name
            case phoneNumber
            case phoneRegion
            case emergencyNote
            case qrCodeId
            case notificationEnabled
            case profileComplete
            case lastCheckedIn
            case checkInInterval
            case notify30MinBefore
            case notify2HoursBefore
            case manualAlertActive
            case manualAlertTimestamp
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            // Decode profile data
            name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
            phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber) ?? ""
            phoneRegion = try container.decodeIfPresent(String.self, forKey: .phoneRegion) ?? "US"
            emergencyNote = try container.decodeIfPresent(String.self, forKey: .emergencyNote) ?? ""
            qrCodeId = try container.decodeIfPresent(String.self, forKey: .qrCodeId) ?? ""
            notificationEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationEnabled) ?? true
            profileComplete = try container.decodeIfPresent(Bool.self, forKey: .profileComplete) ?? false

            // Decode check-in data
            if let lastCheckedInTimestamp = try container.decodeIfPresent(FirestoreTimestamp.self, forKey: .lastCheckedIn) {
                lastCheckedIn = lastCheckedInTimestamp.date
            }

            checkInInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .checkInInterval) ?? TimeManager.defaultInterval
            notify30MinBefore = try container.decodeIfPresent(Bool.self, forKey: .notify30MinBefore) ?? true
            notify2HoursBefore = try container.decodeIfPresent(Bool.self, forKey: .notify2HoursBefore) ?? false
            manualAlertActive = try container.decodeIfPresent(Bool.self, forKey: .manualAlertActive) ?? false

            if let manualAlertTimestampValue = try container.decodeIfPresent(FirestoreTimestamp.self, forKey: .manualAlertTimestamp) {
                manualAlertTimestamp = manualAlertTimestampValue.date
            }
        }
    }

    /// Actions that can be performed on the user feature
    enum Action: Equatable, Sendable {
        /// Load user data
        case loadUserData
        case loadUserDataResponse(TaskResult<State>)

        /// Stream user data
        case startUserDataStream
        case userDataStreamResponse(State)
        case stopUserDataStream

        /// Update profile data
        case updateProfile(name: String, emergencyNote: String)
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

        /// User stream feature actions
        case userStream(UserStreamFeature.Action)

        /// Authentication feature actions
        case authenticationFeature(AuthenticationFeature.Action)
    }

    /// Dependencies
    @Dependency(\.userStreamFeature) var userStreamFeature

    /// Helper function to parse user data from Firestore document using manual parsing
    private func parseUserData(from data: [String: Any]) -> State {
        // Create a new state with default values
        var state = State()

        // Parse profile data
        state.name = data[FirestoreConstants.UserFields.name] as? String ?? ""
        state.phoneNumber = data[FirestoreConstants.UserFields.phoneNumber] as? String ?? ""
        state.phoneRegion = data[FirestoreConstants.UserFields.phoneRegion] as? String ?? "US"
        state.emergencyNote = data[FirestoreConstants.UserFields.emergencyNote] as? String ?? ""
        state.qrCodeId = data[FirestoreConstants.UserFields.qrCodeId] as? String ?? ""
        state.notificationEnabled = data[FirestoreConstants.UserFields.notificationEnabled] as? Bool ?? true
        state.profileComplete = data[FirestoreConstants.UserFields.profileComplete] as? Bool ?? false

        // Parse check-in data
        state.lastCheckedIn = (data[FirestoreConstants.UserFields.lastCheckedIn] as? Timestamp)?.dateValue() ?? Date()
        state.checkInInterval = data[FirestoreConstants.UserFields.checkInInterval] as? TimeInterval ?? TimeManager.defaultInterval
        state.notify30MinBefore = data[FirestoreConstants.UserFields.notify30MinBefore] as? Bool ?? true
        state.notify2HoursBefore = data[FirestoreConstants.UserFields.notify2HoursBefore] as? Bool ?? false
        state.manualAlertActive = data[FirestoreConstants.UserFields.manualAlertActive] as? Bool ?? false
        state.manualAlertTimestamp = (data[FirestoreConstants.UserFields.manualAlertTimestamp] as? Timestamp)?.dateValue()

        return state
    }

    /// Helper function to compare two values for equality
    private func areEqual(_ a: Any?, _ b: Any?) -> Bool {
        // Handle nil cases
        if a == nil && b == nil { return true }
        if a == nil || b == nil { return false }

        // Handle different types
        switch (a, b) {
        case let (a as String, b as String):
            return a == b
        case let (a as Int, b as Int):
            return a == b
        case let (a as Double, b as Double):
            return a == b
        case let (a as Bool, b as Bool):
            return a == b
        case let (a as TimeInterval, b as TimeInterval):
            return a == b
        case let (a as Timestamp, b as Timestamp):
            return a.seconds == b.seconds && a.nanoseconds == b.nanoseconds
        case let (a as Date, b as Date):
            return a.timeIntervalSince1970 == b.timeIntervalSince1970
        case let (a as [String: Any], b as [String: Any]):
            return NSDictionary(dictionary: a).isEqual(to: b)
        case let (a as [Any], b as [Any]):
            return NSArray(array: a).isEqual(to: b)
        default:
            // For other types, use string representation
            return "\(a)" == "\(b)"
        }
    }

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            // Handle user stream feature actions
            if case let .userStream(.userDocumentUpdated(data)) = action {
                // Process the updated user data
                let userData: State
                do {
                    // Convert Firestore data to JSON data
                    let jsonData = try JSONSerialization.data(withJSONObject: data)

                    // Create a decoder
                    let decoder = JSONDecoder()

                    // Decode the JSON data to UserFeature.State
                    userData = try decoder.decode(State.self, from: jsonData)
                } catch {
                    print("Error decoding user data: \(error.localizedDescription)")
                    userData = parseUserData(from: data)
                }

                return .send(.userDataStreamResponse(userData))
            } else if case .userStream = action {
                return .none
            }
            switch action {
            case .loadUserData:
                state.isLoading = true
                return .run { send in
                    do {
                        // Load all user data at once
                        guard let userId = Auth.auth().currentUser?.uid else {
                            throw NSError(domain: "UserFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }

                        // Get the user document directly from Firestore
                        let result = await TaskResult {
                            let db = Firestore.firestore()
                            let documentSnapshot = try await db.collection(FirestoreConstants.Collections.users).document(userId).getDocument()

                            guard documentSnapshot.exists, let data = documentSnapshot.data() else {
                                throw FirebaseError.documentNotFound
                            }

                            return data
                        }

                        switch result {
                        case let .success(data):
                            // Try to use the decoder first, fall back to manual parsing if it fails
                            let userData: State
                            do {
                                // Convert Firestore data to JSON data
                                let jsonData = try JSONSerialization.data(withJSONObject: data)

                                // Create a decoder
                                let decoder = JSONDecoder()

                                // Decode the JSON data to UserFeature.State
                                userData = try decoder.decode(State.self, from: jsonData)
                            } catch {
                                print("Error decoding user data: \(error.localizedDescription)")
                                userData = parseUserData(from: data)
                            }

                            await send(.loadUserDataResponse(.success(userData)))

                        case let .failure(error):
                            await send(.loadUserDataResponse(.failure(error)))
                        }
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
                    state.emergencyNote = userData.emergencyNote
                    state.qrCodeId = userData.qrCodeId
                    state.notificationEnabled = userData.notificationEnabled
                    state.profileComplete = userData.profileComplete
                    state.lastCheckedIn = userData.lastCheckedIn
                    state.checkInInterval = userData.checkInInterval
                    state.notify30MinBefore = userData.notify30MinBefore
                    state.notify2HoursBefore = userData.notify2HoursBefore
                    state.manualAlertActive = userData.manualAlertActive
                    state.manualAlertTimestamp = userData.manualAlertTimestamp
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }

            case .startUserDataStream:
                // Start streaming user data using the UserStreamFeature
                return .run { send in
                    do {
                        guard let userId = Auth.auth().currentUser?.uid else {
                            throw NSError(domain: "UserFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }

                        // Start the user document stream
                        await send(.userStream(.startStream(userId: userId)))
                    } catch {
                        print("Error starting user data stream: \(error.localizedDescription)")
                    }
                }

            case let .userDataStreamResponse(userData):
                // Update all user properties with the latest data from the stream
                state.name = userData.name
                state.phoneNumber = userData.phoneNumber
                state.phoneRegion = userData.phoneRegion
                state.emergencyNote = userData.emergencyNote
                state.qrCodeId = userData.qrCodeId
                state.notificationEnabled = userData.notificationEnabled
                state.profileComplete = userData.profileComplete
                state.lastCheckedIn = userData.lastCheckedIn
                state.checkInInterval = userData.checkInInterval
                state.notify30MinBefore = userData.notify30MinBefore
                state.notify2HoursBefore = userData.notify2HoursBefore
                state.manualAlertActive = userData.manualAlertActive
                state.manualAlertTimestamp = userData.manualAlertTimestamp
                return .none

            case .stopUserDataStream:
                // Stop the user data stream
                return .send(.userStream(.stopStream))

            case let .updateProfile(name, emergencyNote):
                state.isLoading = true
                // Update local state immediately for better UX
                state.name = name
                state.emergencyNote = emergencyNote
                state.profileComplete = true

                return .run { send in
                    do {
                        guard let userId = Auth.auth().currentUser?.uid else {
                            throw NSError(domain: "UserFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }

                        let fields = [
                            FirestoreConstants.UserFields.name: name,
                            FirestoreConstants.UserFields.emergencyNote: emergencyNote,
                            FirestoreConstants.UserFields.profileComplete: true
                        ]

                        // Get current user data to compare
                        let getDocResult = await TaskResult {
                            let db = Firestore.firestore()
                            let documentSnapshot = try await db.collection(FirestoreConstants.Collections.users).document(userId).getDocument()

                            guard documentSnapshot.exists, let data = documentSnapshot.data() else {
                                throw FirebaseError.documentNotFound
                            }

                            return data
                        }

                        switch getDocResult {
                        case let .success(userData):
                            // Only include fields that have actually changed
                            var fieldsToUpdate: [String: Any] = [:]

                            for (key, newValue) in fields {
                                let currentValue = userData[key]

                                // Check if the value has changed
                                if currentValue == nil || !areEqual(currentValue, newValue) {
                                    fieldsToUpdate[key] = newValue
                                }
                            }

                            // Only update if there are changes
                            if !fieldsToUpdate.isEmpty {
                                // Add last updated timestamp
                                fieldsToUpdate[FirestoreConstants.UserFields.lastUpdated] = Timestamp(date: Date())

                                let updateResult = await TaskResult {
                                    let db = Firestore.firestore()
                                    try await db.collection(FirestoreConstants.Collections.users).document(userId).updateData(fieldsToUpdate)
                                    return true
                                }

                                await send(.updateProfileResponse(updateResult))
                            } else {
                                // No changes needed
                                await send(.updateProfileResponse(.success(true)))
                            }

                        case let .failure(error):
                            await send(.updateProfileResponse(.failure(error)))
                        }
                    } catch {
                        await send(.updateProfileResponse(.failure(error)))
                    }
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
                    do {
                        guard let userId = Auth.auth().currentUser?.uid else {
                            throw NSError(domain: "UserFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }

                        let fields = [
                            FirestoreConstants.UserFields.notificationEnabled: enabled
                        ]

                        // Get current user data to compare
                        let getDocResult = await TaskResult {
                            let db = Firestore.firestore()
                            let documentSnapshot = try await db.collection(FirestoreConstants.Collections.users).document(userId).getDocument()

                            guard documentSnapshot.exists, let data = documentSnapshot.data() else {
                                throw FirebaseError.documentNotFound
                            }

                            return data
                        }

                        switch getDocResult {
                        case let .success(userData):
                            // Only include fields that have actually changed
                            var fieldsToUpdate: [String: Any] = [:]

                            for (key, newValue) in fields {
                                let currentValue = userData[key]

                                // Check if the value has changed
                                if currentValue == nil || !areEqual(currentValue, newValue) {
                                    fieldsToUpdate[key] = newValue
                                }
                            }

                            // Only update if there are changes
                            if !fieldsToUpdate.isEmpty {
                                // Add last updated timestamp
                                fieldsToUpdate[FirestoreConstants.UserFields.lastUpdated] = Timestamp(date: Date())

                                let updateResult = await TaskResult {
                                    let db = Firestore.firestore()
                                    try await db.collection(FirestoreConstants.Collections.users).document(userId).updateData(fieldsToUpdate)
                                    return true
                                }

                                await send(.updateNotificationSettingsResponse(updateResult))
                            } else {
                                // No changes needed
                                await send(.updateNotificationSettingsResponse(.success(true)))
                            }

                        case let .failure(error):
                            await send(.updateNotificationSettingsResponse(.failure(error)))
                        }
                    } catch {
                        await send(.updateNotificationSettingsResponse(.failure(error)))
                    }
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
                    do {
                        guard let userId = Auth.auth().currentUser?.uid else {
                            throw NSError(domain: "UserFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }

                        let fields = [
                            FirestoreConstants.UserFields.lastCheckedIn: Timestamp(date: Date())
                        ]

                        // Get current user data to compare
                        let getDocResult = await TaskResult {
                            let db = Firestore.firestore()
                            let documentSnapshot = try await db.collection(FirestoreConstants.Collections.users).document(userId).getDocument()

                            guard documentSnapshot.exists, let data = documentSnapshot.data() else {
                                throw FirebaseError.documentNotFound
                            }

                            return data
                        }

                        switch getDocResult {
                        case let .success(userData):
                            // Only include fields that have actually changed
                            var fieldsToUpdate: [String: Any] = [:]

                            for (key, newValue) in fields {
                                let currentValue = userData[key]

                                // Check if the value has changed
                                if currentValue == nil || !areEqual(currentValue, newValue) {
                                    fieldsToUpdate[key] = newValue
                                }
                            }

                            // Only update if there are changes
                            if !fieldsToUpdate.isEmpty {
                                // Add last updated timestamp
                                fieldsToUpdate[FirestoreConstants.UserFields.lastUpdated] = Timestamp(date: Date())

                                let updateResult = await TaskResult {
                                    let db = Firestore.firestore()
                                    try await db.collection(FirestoreConstants.Collections.users).document(userId).updateData(fieldsToUpdate)
                                    return true
                                }

                                await send(.checkInResponse(updateResult))
                            } else {
                                // No changes needed
                                await send(.checkInResponse(.success(true)))
                            }

                        case let .failure(error):
                            await send(.checkInResponse(.failure(error)))
                        }
                    } catch {
                        await send(.checkInResponse(.failure(error)))
                    }
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
                    do {
                        guard let userId = Auth.auth().currentUser?.uid else {
                            throw NSError(domain: "UserFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }

                        let fields = [
                            FirestoreConstants.UserFields.checkInInterval: interval
                        ]

                        // Get current user data to compare
                        let getDocResult = await TaskResult {
                            let db = Firestore.firestore()
                            let documentSnapshot = try await db.collection(FirestoreConstants.Collections.users).document(userId).getDocument()

                            guard documentSnapshot.exists, let data = documentSnapshot.data() else {
                                throw FirebaseError.documentNotFound
                            }

                            return data
                        }

                        switch getDocResult {
                        case let .success(userData):
                            // Only include fields that have actually changed
                            var fieldsToUpdate: [String: Any] = [:]

                            for (key, newValue) in fields {
                                let currentValue = userData[key]

                                // Check if the value has changed
                                if currentValue == nil || !areEqual(currentValue, newValue) {
                                    fieldsToUpdate[key] = newValue
                                }
                            }

                            // Only update if there are changes
                            if !fieldsToUpdate.isEmpty {
                                // Add last updated timestamp
                                fieldsToUpdate[FirestoreConstants.UserFields.lastUpdated] = Timestamp(date: Date())

                                let updateResult = await TaskResult {
                                    let db = Firestore.firestore()
                                    try await db.collection(FirestoreConstants.Collections.users).document(userId).updateData(fieldsToUpdate)
                                    return true
                                }

                                await send(.updateCheckInIntervalResponse(updateResult))
                            } else {
                                // No changes needed
                                await send(.updateCheckInIntervalResponse(.success(true)))
                            }

                        case let .failure(error):
                            await send(.updateCheckInIntervalResponse(.failure(error)))
                        }
                    } catch {
                        await send(.updateCheckInIntervalResponse(.failure(error)))
                    }
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
                    do {
                        guard let userId = Auth.auth().currentUser?.uid else {
                            throw NSError(domain: "UserFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }

                        let fields = [
                            FirestoreConstants.UserFields.notify30MinBefore: notify30Min,
                            FirestoreConstants.UserFields.notify2HoursBefore: notify2Hours
                        ]

                        // Get current user data to compare
                        let getDocResult = await TaskResult {
                            let db = Firestore.firestore()
                            let documentSnapshot = try await db.collection(FirestoreConstants.Collections.users).document(userId).getDocument()

                            guard documentSnapshot.exists, let data = documentSnapshot.data() else {
                                throw FirebaseError.documentNotFound
                            }

                            return data
                        }

                        switch getDocResult {
                        case let .success(userData):
                            // Only include fields that have actually changed
                            var fieldsToUpdate: [String: Any] = [:]

                            for (key, newValue) in fields {
                                let currentValue = userData[key]

                                // Check if the value has changed
                                if currentValue == nil || !areEqual(currentValue, newValue) {
                                    fieldsToUpdate[key] = newValue
                                }
                            }

                            // Only update if there are changes
                            if !fieldsToUpdate.isEmpty {
                                // Add last updated timestamp
                                fieldsToUpdate[FirestoreConstants.UserFields.lastUpdated] = Timestamp(date: Date())

                                let updateResult = await TaskResult {
                                    let db = Firestore.firestore()
                                    try await db.collection(FirestoreConstants.Collections.users).document(userId).updateData(fieldsToUpdate)
                                    return true
                                }

                                await send(.updateNotificationPreferencesResponse(updateResult))
                            } else {
                                // No changes needed
                                await send(.updateNotificationPreferencesResponse(.success(true)))
                            }

                        case let .failure(error):
                            await send(.updateNotificationPreferencesResponse(.failure(error)))
                        }
                    } catch {
                        await send(.updateNotificationPreferencesResponse(.failure(error)))
                    }
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
                        do {
                            // Sign out using Firebase Auth directly
                            try Auth.auth().signOut()

                            // Clear the session ID using AuthenticationFeature
                            await send(.authenticationFeature(.clearSessionId))

                            return true
                        } catch {
                            throw error
                        }
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

        .ifLet(\.userStream, action: /Action.userStream) {
            UserStreamFeature()
        }
        ._printChanges()
        Scope(state: \.self, action: /Action.authenticationFeature) {
            AuthenticationFeature()
        }
    }
}

/// User data type for loading and streaming user data
typealias UserData = UserFeature.State

/// Profile data type for loading user profile information
typealias ProfileData = (name: String, phoneNumber: String, phoneRegion: String, emergencyNote: String, qrCodeId: String, notificationEnabled: Bool, profileComplete: Bool)
