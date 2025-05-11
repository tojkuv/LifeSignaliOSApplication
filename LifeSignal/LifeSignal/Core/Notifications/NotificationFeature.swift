import Foundation
import ComposableArchitecture
import UserNotifications
import FirebaseFirestore
import UIKit

/// Feature for handling notifications using TCA
@Reducer
struct NotificationFeature {
    /// Cancellation IDs for long-running effects
    enum CancelID: Hashable {
        case notificationPermissionRequest
    }

    /// The state of the notification feature
    struct State: Equatable, Sendable {
        /// Flag indicating if notifications are authorized
        var isAuthorized: Bool = false

        /// Flag indicating if a permission request is in progress
        var isRequestingPermission: Bool = false

        /// Flag indicating if a manual alert is active
        var isManualAlertActive: Bool = false

        /// Timestamp of the manual alert
        var manualAlertTimestamp: Date? = nil

        /// Loading state
        var isLoading: Bool = false

        /// Error state
        var error: Error? = nil

        /// Initialize with default values
        init(
            isAuthorized: Bool = false,
            isRequestingPermission: Bool = false,
            isManualAlertActive: Bool = false,
            manualAlertTimestamp: Date? = nil,
            isLoading: Bool = false,
            error: Error? = nil
        ) {
            self.isAuthorized = isAuthorized
            self.isRequestingPermission = isRequestingPermission
            self.isManualAlertActive = isManualAlertActive
            self.manualAlertTimestamp = manualAlertTimestamp
            self.isLoading = isLoading
            self.error = error
        }
    }

    /// Actions that can be performed on the notification feature
    enum Action: Equatable, Sendable {
        /// Request notification permissions
        case requestPermissions
        case requestPermissionsResponse(Bool)

        /// Check notification authorization status
        case checkAuthorizationStatus
        case checkAuthorizationStatusResponse(Bool)

        /// Send a manual alert to all responders
        case sendManualAlert(userId: String)
        case sendManualAlertResponse(TaskResult<Bool>)

        /// Cancel a manual alert
        case cancelManualAlert(userId: String)
        case cancelManualAlertResponse(TaskResult<Bool>)

        /// Show a local notification
        case showLocalNotification(title: String, body: String, userInfo: [String: Any])
        case showLocalNotificationResponse(TaskResult<Bool>)

        /// Handle an alert notification from a dependent
        case handleDependentAlert(dependentId: String, dependentName: String, timestamp: Date)
        case handleDependentAlertResponse(TaskResult<Bool>)

        /// Handle an alert cancellation from a dependent
        case handleDependentAlertCancellation(dependentId: String, dependentName: String)
        case handleDependentAlertCancellationResponse(TaskResult<Bool>)
    }

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .requestPermissions:
                state.isRequestingPermission = true
                state.error = nil

                return .run { send in
                    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
                    do {
                        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: authOptions)
                        if granted {
                            await MainActor.run {
                                UIApplication.shared.registerForRemoteNotifications()
                            }
                        }
                        await send(.requestPermissionsResponse(granted))
                    } catch {
                        print("Error requesting notification authorization: \(error.localizedDescription)")
                        await send(.requestPermissionsResponse(false))
                    }
                }
                .cancellable(id: CancelID.notificationPermissionRequest)

            case let .requestPermissionsResponse(granted):
                state.isRequestingPermission = false
                state.isAuthorized = granted
                return .none

            case .checkAuthorizationStatus:
                state.isLoading = true

                return .run { send in
                    let settings = await UNUserNotificationCenter.current().notificationSettings()
                    let isAuthorized = settings.authorizationStatus == .authorized
                    await send(.checkAuthorizationStatusResponse(isAuthorized))
                }

            case let .checkAuthorizationStatusResponse(isAuthorized):
                state.isLoading = false
                state.isAuthorized = isAuthorized
                return .none

            case let .sendManualAlert(userId):
                state.isLoading = true
                state.error = nil

                return .run { send in
                    let result = await TaskResult {
                        let db = Firestore.firestore()
                        let userRef = db.collection(FirestoreConstants.Collections.users).document(userId)

                        // Update the user document to mark the alert as active
                        try await userRef.updateData([
                            FirestoreConstants.UserFields.manualAlertActive: true,
                            FirestoreConstants.UserFields.manualAlertTimestamp: FieldValue.serverTimestamp()
                        ])

                        // Get the user's contacts from the contacts subcollection
                        let contactsSnapshot = try await db.collection("\(FirestoreConstants.Collections.users)/\(userId)/\(FirestoreConstants.Collections.contacts)").getDocuments()

                        guard let userData = (try? await userRef.getDocument())?.data(),
                              let userName = userData[FirestoreConstants.UserFields.name] as? String else {
                            return false
                        }

                        // Filter responders (people who should be notified when this user sends an alert)
                        let responders = contactsSnapshot.documents.filter {
                            ($0.data()[FirestoreConstants.ContactFields.isResponder] as? Bool) == true
                        }

                        // For each responder, update their contact document to show this user has an active alert
                        for responderDoc in responders {
                            let responderId = responderDoc.documentID

                            // Update the responder's contact document for this user
                            let responderContactRef = db.document("\(FirestoreConstants.Collections.users)/\(responderId)/\(FirestoreConstants.Collections.contacts)/\(userId)")

                            // Check if the contact document exists
                            if (try? await responderContactRef.getDocument())?.exists == true {
                                // Update the contact to show the alert is active
                                try await responderContactRef.updateData([
                                    FirestoreConstants.ContactFields.manualAlertActive: true,
                                    FirestoreConstants.ContactFields.manualAlertTimestamp: FieldValue.serverTimestamp()
                                ])
                            }
                        }

                        return true
                    }

                    await send(.sendManualAlertResponse(result))
                }

            case let .sendManualAlertResponse(result):
                state.isLoading = false

                switch result {
                case .success(let success):
                    if success {
                        state.isManualAlertActive = true
                        state.manualAlertTimestamp = Date()
                    }
                case .failure(let error):
                    state.error = error
                }

                return .none

            case let .cancelManualAlert(userId):
                state.isLoading = true
                state.error = nil

                return .run { send in
                    let result = await TaskResult {
                        let db = Firestore.firestore()
                        let userRef = db.collection(FirestoreConstants.Collections.users).document(userId)

                        // Update the user document to mark the alert as inactive
                        try await userRef.updateData([
                            FirestoreConstants.UserFields.manualAlertActive: false,
                            FirestoreConstants.UserFields.manualAlertTimestamp: FieldValue.delete()
                        ])

                        // Get the user's contacts from the contacts subcollection
                        let contactsSnapshot = try await db.collection("\(FirestoreConstants.Collections.users)/\(userId)/\(FirestoreConstants.Collections.contacts)").getDocuments()

                        // Filter responders (people who should be notified when this user cancels an alert)
                        let responders = contactsSnapshot.documents.filter {
                            ($0.data()[FirestoreConstants.ContactFields.isResponder] as? Bool) == true
                        }

                        // For each responder, update their contact document to show this user has canceled the alert
                        for responderDoc in responders {
                            let responderId = responderDoc.documentID

                            // Update the responder's contact document for this user
                            let responderContactRef = db.document("\(FirestoreConstants.Collections.users)/\(responderId)/\(FirestoreConstants.Collections.contacts)/\(userId)")

                            // Check if the contact document exists
                            if (try? await responderContactRef.getDocument())?.exists == true {
                                // Update the contact to show the alert is inactive
                                try await responderContactRef.updateData([
                                    FirestoreConstants.ContactFields.manualAlertActive: false
                                ])
                            }
                        }

                        return true
                    }

                    await send(.cancelManualAlertResponse(result))
                }

            case let .cancelManualAlertResponse(result):
                state.isLoading = false

                switch result {
                case .success(let success):
                    if success {
                        state.isManualAlertActive = false
                        state.manualAlertTimestamp = nil
                    }
                case .failure(let error):
                    state.error = error
                }

                return .none

            case let .showLocalNotification(title, body, userInfo):
                return .run { send in
                    let result = await TaskResult {
                        let content = UNMutableNotificationContent()
                        content.title = title
                        content.body = body
                        content.sound = .default

                        // Add user info
                        for (key, value) in userInfo {
                            if let value = value as? String {
                                content.userInfo[key] = value
                            }
                        }

                        // Create a trigger (immediate)
                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

                        // Create the request
                        let request = UNNotificationRequest(
                            identifier: UUID().uuidString,
                            content: content,
                            trigger: trigger
                        )

                        // Add the request to the notification center
                        try await UNUserNotificationCenter.current().add(request)
                        return true
                    }

                    await send(.showLocalNotificationResponse(result))
                }

            case .showLocalNotificationResponse:
                return .none

            case let .handleDependentAlert(dependentId, dependentName, timestamp):
                return .run { send in
                    // First show a local notification
                    await send(.showLocalNotification(
                        title: "Alert from \(dependentName)",
                        body: "\(dependentName) has sent an emergency alert.",
                        userInfo: [
                            "alertType": "manualAlert",
                            "dependentId": dependentId,
                            "timestamp": timestamp.timeIntervalSince1970.description
                        ]
                    ))

                    // Post a notification to update the UI
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("DependentAlertReceived"),
                            object: nil,
                            userInfo: [
                                "dependentId": dependentId,
                                "timestamp": timestamp
                            ]
                        )

                        // Post notification to refresh the dependents view
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshDependentsView"), object: nil)
                    }

                    await send(.handleDependentAlertResponse(.success(true)))
                }

            case .handleDependentAlertResponse:
                return .none

            case let .handleDependentAlertCancellation(dependentId, dependentName):
                return .run { send in
                    // First show a local notification
                    await send(.showLocalNotification(
                        title: "Alert Canceled",
                        body: "\(dependentName) has canceled their emergency alert.",
                        userInfo: [
                            "alertType": "manualAlertCanceled",
                            "dependentId": dependentId
                        ]
                    ))

                    // Post a notification to update the UI
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("DependentAlertCanceled"),
                            object: nil,
                            userInfo: [
                                "dependentId": dependentId
                            ]
                        )

                        // Post notification to refresh the dependents view
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshDependentsView"), object: nil)
                    }

                    await send(.handleDependentAlertCancellationResponse(.success(true)))
                }

            case .handleDependentAlertCancellationResponse:
                return .none
            }
        }
    }
}

// MARK: - Dependency Registration

/// Register NotificationFeature as a dependency
private enum NotificationFeatureKey: DependencyKey {
    static let liveValue = NotificationFeature()
}

extension DependencyValues {
    var notificationFeature: NotificationFeature {
        get { self[NotificationFeatureKey.self] }
        set { self[NotificationFeatureKey.self] = newValue }
    }
}
