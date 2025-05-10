import Foundation
import ComposableArchitecture
import FirebaseFirestore

// UserData structure has been moved directly into UserFeature.State

/// Client for interacting with user data in Firestore
struct UserClient: Sendable {
    // MARK: - Data Operations

    /// Load all user data at once
    var loadUserData: @Sendable () async throws -> UserFeature.State

    /// Stream user data for real-time updates
    var streamUserData: @Sendable () -> AsyncStream<UserFeature.State>

    /// Load profile data from Firestore (legacy method)
    var loadProfile: @Sendable () async throws -> (name: String, phoneNumber: String, phoneRegion: String, note: String, qrCodeId: String, notificationEnabled: Bool, profileComplete: Bool)

    /// Load the user's check-in data (legacy method)
    var loadCheckInData: @Sendable () async throws -> CheckInFeature.CheckInData

    /// Update specific user fields only if they have changed
    /// This is the primary method for updating user data
    var updateUserFields: @Sendable (_ fields: [String: Any]) async throws -> Bool

    // MARK: - Authentication Operations

    /// Sign out the current user
    var signOut: @Sendable () async throws -> Bool
}

/// Helper function to parse user data from Firestore document
private func parseUserData(from data: [String: Any]) -> UserFeature.State {
    // Create a new state with default values
    var state = UserFeature.State()

    // Parse profile data
    state.name = data[FirestoreConstants.UserFields.name] as? String ?? ""
    state.phoneNumber = data[FirestoreConstants.UserFields.phoneNumber] as? String ?? ""
    state.phoneRegion = data[FirestoreConstants.UserFields.phoneRegion] as? String ?? "US"
    state.note = data[FirestoreConstants.UserFields.note] as? String ?? ""
    state.qrCodeId = data[FirestoreConstants.UserFields.qrCodeId] as? String ?? ""
    state.notificationEnabled = data[FirestoreConstants.UserFields.notificationEnabled] as? Bool ?? true
    state.profileComplete = data[FirestoreConstants.UserFields.profileComplete] as? Bool ?? false

    // Parse check-in data
    state.lastCheckedIn = (data[FirestoreConstants.UserFields.lastCheckedIn] as? Timestamp)?.dateValue() ?? Date()
    state.checkInInterval = data[FirestoreConstants.UserFields.checkInInterval] as? TimeInterval ?? TimeManager.defaultInterval
    state.notify30MinBefore = data[FirestoreConstants.UserFields.notify30MinBefore] as? Bool ?? true
    state.notify2HoursBefore = data[FirestoreConstants.UserFields.notify2HoursBefore] as? Bool ?? false
    state.sendAlertActive = data[FirestoreConstants.UserFields.manualAlertActive] as? Bool ?? false
    state.manualAlertTimestamp = (data[FirestoreConstants.UserFields.manualAlertTimestamp] as? Timestamp)?.dateValue()

    return state
}

extension UserClient: DependencyKey {
    /// Live implementation of the user client
    static var liveValue: Self {
        @Dependency(\.authClient) var authClient
        @Dependency(\.firebaseClient) var firebaseClient
        @Dependency(\.sessionClient) var sessionClient

        return Self(
            // MARK: - Data Operations

            loadUserData: {
                guard let userId = await authClient.getCurrentUserId() else {
                    throw NSError(domain: "UserClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

                let data = try await firebaseClient.getDocument(
                    collection: FirestoreConstants.Collections.users,
                    documentId: userId
                )

                return parseUserData(from: data)
            },

            streamUserData: {
                // Create an AsyncStream that monitors the user document
                return AsyncStream { continuation in
                    Task {
                        do {
                            guard let userId = await authClient.getCurrentUserId() else {
                                throw NSError(domain: "UserClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                            }

                            // Get the initial data
                            let initialData = try await firebaseClient.getDocument(
                                collection: FirestoreConstants.Collections.users,
                                documentId: userId
                            )

                            // Yield the initial data
                            let userData = parseUserData(from: initialData)
                            continuation.yield(userData)

                            // Start monitoring for changes
                            let stream = firebaseClient.monitorUserDocument(userId: userId, includeMetadata: false)

                            for await snapshot in stream {
                                if let data = snapshot.data() {
                                    let userData = parseUserData(from: data)
                                    continuation.yield(userData)
                                }
                            }
                        } catch {
                            print("Error in streamUserData: \(error.localizedDescription)")
                            // We don't finish the stream on error, just log it
                        }
                    }
                }
            },

            loadProfile: {
                // Use the new loadUserData method and extract profile data
                let state = try await UserClient.liveValue.loadUserData()

                return (
                    name: state.name,
                    phoneNumber: state.phoneNumber,
                    phoneRegion: state.phoneRegion,
                    note: state.note,
                    qrCodeId: state.qrCodeId,
                    notificationEnabled: state.notificationEnabled,
                    profileComplete: state.profileComplete
                )
            },

            loadCheckInData: {
                // Use the new loadUserData method and extract check-in data
                let state = try await UserClient.liveValue.loadUserData()

                return CheckInFeature.CheckInData(
                    lastCheckedIn: state.lastCheckedIn,
                    checkInInterval: state.checkInInterval,
                    notify30MinBefore: state.notify30MinBefore,
                    notify2HoursBefore: state.notify2HoursBefore,
                    sendAlertActive: state.sendAlertActive,
                    manualAlertTimestamp: state.manualAlertTimestamp
                )
            },

            updateUserFields: { fields in
                guard let userId = await authClient.getCurrentUserId() else {
                    throw NSError(domain: "UserClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

                // Get current user data to compare
                let userData = try await firebaseClient.getDocument(
                    collection: FirestoreConstants.Collections.users,
                    documentId: userId
                )

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

                    try await firebaseClient.updateDocument(
                        collection: FirestoreConstants.Collections.users,
                        documentId: userId,
                        data: fieldsToUpdate
                    )
                }

                return true
            },

            // MARK: - Authentication Operations

            signOut: {
                do {
                    // Sign out using the auth client
                    try await authClient.signOut()

                    // Clear the session ID
                    await sessionClient.clearSessionId()

                    return true
                } catch {
                    throw error
                }
            }
        )
    }

    /// Test implementation of the user client
    static var testValue: Self {
        var testState = UserFeature.State()
        testState.name = "Test User"
        testState.phoneNumber = "+15551234567"
        testState.phoneRegion = "US"
        testState.note = "Test note"
        testState.qrCodeId = "test-qr-code"
        testState.notificationEnabled = true
        testState.profileComplete = true
        testState.lastCheckedIn = Date()
        testState.checkInInterval = TimeManager.defaultInterval
        testState.notify30MinBefore = true
        testState.notify2HoursBefore = false
        testState.sendAlertActive = false
        testState.manualAlertTimestamp = nil

        return Self(
            loadUserData: {
                return testState
            },

            streamUserData: {
                return AsyncStream { continuation in
                    // Yield the initial data
                    continuation.yield(testState)

                    // Simulate periodic updates if needed
                    let timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                        var updatedState = testState
                        updatedState.lastCheckedIn = Date()
                        continuation.yield(updatedState)
                    }

                    continuation.onTermination = { _ in
                        timer.invalidate()
                    }
                }
            },

            loadProfile: {
                return (
                    name: testState.name,
                    phoneNumber: testState.phoneNumber,
                    phoneRegion: testState.phoneRegion,
                    note: testState.note,
                    qrCodeId: testState.qrCodeId,
                    notificationEnabled: testState.notificationEnabled,
                    profileComplete: testState.profileComplete
                )
            },

            loadCheckInData: {
                return CheckInFeature.CheckInData(
                    lastCheckedIn: testState.lastCheckedIn,
                    checkInInterval: testState.checkInInterval,
                    notify30MinBefore: testState.notify30MinBefore,
                    notify2HoursBefore: testState.notify2HoursBefore,
                    sendAlertActive: testState.sendAlertActive,
                    manualAlertTimestamp: testState.manualAlertTimestamp
                )
            },

            updateUserFields: { _ in
                return true
            },

            signOut: {
                return true
            }
        )
    }
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

extension DependencyValues {
    var userClient: UserClient {
        get { self[UserClient.self] }
        set { self[UserClient.self] = newValue }
    }
}
