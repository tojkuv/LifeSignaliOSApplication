import Foundation
import ComposableArchitecture
import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging

/// Root feature for the app using TCA
@Reducer
struct AppFeature {
    /// The state of the app feature
    struct State: Equatable, Sendable {
        /// Authentication feature state
        var authentication: AuthenticationFeature.State?

        /// User feature state (shared across features)
        var user: UserFeature.State?

        /// Contacts feature state
        var contacts: ContactsFeature.State?

        /// QR code feature state
        var qrCode: QRCodeFeature.State?

        /// Notification feature state
        var notification: NotificationFeature.State?

        /// Flag indicating if user is authenticated
        var isAuthenticated: Bool = false

        /// Flag indicating if user needs to complete onboarding
        var needsOnboarding: Bool = false

        /// Session listener task (not included in Equatable)
        @EquatableNoop var sessionListenerTask: Task<Void, Never>? = nil

        /// FCM token
        var fcmToken: String? = nil
    }

    /// Actions that can be performed on the app feature
    enum Action: Equatable, Sendable {
        /// App lifecycle actions
        case appLaunched

        /// Authentication actions
        case authentication(AuthenticationFeature.Action)

        /// User actions (shared across features)
        case user(UserFeature.Action)

        /// Contacts actions
        case contacts(ContactsFeature.Action)

        /// QR code actions
        case qrCode(QRCodeFeature.Action)

        /// Notification actions
        case notification(NotificationFeature.Action)

        /// Initialize Firebase
        case initializeFirebase
        case firebaseInitialized

        /// Set authentication state
        case authenticate

        /// Set onboarding state
        case setNeedsOnboarding(Bool)

        /// Complete onboarding
        case completeOnboarding

        /// Sign out
        case signOut

        // MARK: - Session Management

        /// Set up session listener
        case setupSessionListener(userId: String)
        case sessionInvalidated
        case clearSessionId

        // MARK: - Push Notification Handling

        /// Register device token for push notifications
        case registerDeviceToken(Data)

        /// Update FCM token
        case updateFCMToken(String)
        case updateFCMTokenResponse(TaskResult<Bool>)

        /// Handle remote notification
        case handleRemoteNotification([AnyHashable: Any])

        /// Handle URL
        case handleURL(URL)
    }

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .appLaunched:
                // Handle app launch - initialize Firebase and check authentication
                return .send(.initializeFirebase)

            case .initializeFirebase:
                return .run { send in
                    // Initialize Firebase
                    FirebaseInitializer.initialize()

                    // Set up Firebase Messaging
                    await FirebaseInitializer.setupMessaging()

                    await send(.firebaseInitialized)
                }

            case .firebaseInitialized:
                // Check if user is already authenticated
                if let userId = Auth.auth().currentUser?.uid {
                    // Set up session listener
                    return .concatenate(
                        .send(.setupSessionListener(userId: userId)),
                        .send(.authenticate)
                    )
                }
                return .none

            case .authenticate:
                state.isAuthenticated = true

                // Initialize user feature state first
                if state.user == nil {
                    state.user = UserFeature.State()
                }

                // Initialize contacts feature state if it doesn't exist
                if state.contacts == nil {
                    state.contacts = ContactsFeature.State()
                }

                // Initialize QR code feature state if it doesn't exist
                if state.qrCode == nil {
                    state.qrCode = QRCodeFeature.State()
                }

                // Initialize notification feature state if it doesn't exist
                if state.notification == nil {
                    state.notification = NotificationFeature.State()
                }

                // Start streaming user data and contacts
                return .concatenate(
                    .send(.user(.startUserDataStream)),
                    .send(.contacts(.startContactsStream)),
                    .send(.notification(.checkAuthorizationStatus))
                )

            case .setNeedsOnboarding(let needsOnboarding):
                state.needsOnboarding = needsOnboarding
                return .none

            case .completeOnboarding:
                state.needsOnboarding = false

                // In a real implementation, we would save the profile information
                // to Firebase here

                return .none

            case .authentication(.verifyCodeResponse(.success(true))):
                // User successfully authenticated
                return .send(.authenticate)

            case .authentication:
                // Handle other authentication actions
                if state.authentication == nil {
                    state.authentication = AuthenticationFeature.State()
                }

                return .none

            case .contacts(.startContactsStream), .contacts(.stopContactsStream), .contacts(.contactsStreamResponse):
                // These actions are handled directly in the contacts feature
                return .none

            case .contacts:
                // Handle other contacts actions
                return .none

            case .user(.signOutResponse(.success)):
                // Handle successful sign out
                state.isAuthenticated = false
                state.user = nil
                state.contacts = nil
                state.authentication = nil
                return .none

            case .user(.signOut):
                // Stop all streams before signing out
                return .concatenate(
                    .send(.user(.stopUserDataStream)),
                    .send(.contacts(.stopContactsStream))
                )

            case let .user(.userDataStreamResponse(userData)):
                // Check if the user has completed onboarding when user data is received
                if state.isAuthenticated && !userData.profileComplete {
                    return .send(.setNeedsOnboarding(true))
                }
                return .none

            case .user:
                // Handle other user actions
                return .none

            case let .qrCode(.scanQRCode(code)):
                // When a QR code is scanned, we need to look up the user in Firebase
                guard let userId = state.user?.id else {
                    return .none
                }

                // Forward the scanned QR code to the QR code feature
                if let qrCodeState = state.qrCode {
                    state.qrCode = qrCodeState
                    return .send(.qrCode(.scanQRCode(code)))
                }
                return .none

            case .qrCode(.clearScannedQRCode):
                // Clear the scanned QR code
                if let qrCodeState = state.qrCode {
                    state.qrCode = qrCodeState
                    return .send(.qrCode(.clearScannedQRCode))
                }
                return .none

            case .qrCode:
                // Handle other QR code actions
                return .none

            case .notification(.requestPermissionsResponse), .notification(.checkAuthorizationStatusResponse):
                // These actions are handled directly in the notification feature
                return .none

            case .notification:
                // Handle other notification actions
                return .none

            // MARK: - Session Management

            case let .setupSessionListener(userId):
                // Cancel any existing listener
                state.sessionListenerTask?.cancel()
                state.sessionListenerTask = nil

                // Create a new listener task
                state.sessionListenerTask = Task {
                    // Create a store for the authentication feature
                    let store = Store(initialState: AuthenticationFeature.State()) {
                        AuthenticationFeature()
                    }

                    // Start the session stream
                    await ViewStore(store, observe: { $0 }).send(.startSessionStream(userId: userId))

                    // Create a task to observe session invalidation
                    for await action in await store.actionStream {
                        if case .sessionInvalidated = action {
                            // Session was invalidated, sign out the user
                            print("Session was invalidated, signing out")

                            // Sign out on the main thread
                            await MainActor.run {
                                // Sign out using Auth
                                try? Auth.auth().signOut()

                                // Clear session ID
                                await ViewStore(store, observe: { $0 }).send(.clearSessionId)

                                // Post notification to reset app state
                                NotificationCenter.default.post(name: NSNotification.Name("ResetAppState"), object: nil)
                            }

                            break
                        }
                    }
                }
                return .none

            case .sessionInvalidated:
                // This action is handled by the session listener
                return .none

            case .clearSessionId:
                // This action is handled by the authentication feature
                return .none

            // MARK: - Push Notification Handling

            case let .registerDeviceToken(deviceToken):
                // Pass device token to auth
                Auth.auth().setAPNSToken(deviceToken, type: .unknown)

                // Pass device token to FCM
                Messaging.messaging().apnsToken = deviceToken

                // No further action needed, FCM token updates will come through the MessagingDelegateAdapter
                return .none

            case let .updateFCMToken(token):
                state.fcmToken = token

                // Only update token in Firestore if user is authenticated
                guard let userId = Auth.auth().currentUser?.uid else {
                    return .none
                }

                return .run { send in
                    let result = await TaskResult {
                        let db = Firestore.firestore()
                        let userRef = db.collection(FirestoreConstants.Collections.users).document(userId)

                        try await userRef.updateData([
                            FirestoreConstants.UserFields.fcmToken: token,
                            FirestoreConstants.UserFields.lastUpdated: FieldValue.serverTimestamp()
                        ])

                        return true
                    }

                    await send(.updateFCMTokenResponse(result))
                }

            case .updateFCMTokenResponse:
                // No state changes needed
                return .none

            case let .handleRemoteNotification(notification):
                // Handle FCM notifications
                print("Handling remote notification: \(notification)")

                // Check if this is an alert notification
                if let alertType = notification["alertType"] as? String {
                    print("Received alert notification of type: \(alertType)")

                    switch alertType {
                    case "manualAlert":
                        if let dependentId = notification["dependentId"] as? String,
                           let dependentName = notification["dependentName"] as? String,
                           let timestampString = notification["timestamp"] as? String,
                           let timestampValue = Double(timestampString) {

                            let timestamp = Date(timeIntervalSince1970: timestampValue)
                            print("Manual alert from dependent: \(dependentId) - \(dependentName)")

                            // Forward to notification feature
                            return .send(.notification(.handleDependentAlert(
                                dependentId: dependentId,
                                dependentName: dependentName,
                                timestamp: timestamp
                            )))
                        }

                    case "manualAlertCanceled":
                        if let dependentId = notification["dependentId"] as? String,
                           let dependentName = notification["dependentName"] as? String {
                            print("Manual alert canceled for dependent: \(dependentId) - \(dependentName)")

                            // Forward to notification feature
                            return .send(.notification(.handleDependentAlertCancellation(
                                dependentId: dependentId,
                                dependentName: dependentName
                            )))
                        }

                    case "checkInExpired":
                        if let dependentId = notification["dependentId"] as? String,
                           let dependentName = notification["dependentName"] as? String {
                            print("Check-in expired for dependent: \(dependentId)")

                            // Forward to notification feature
                            return .send(.notification(.showLocalNotification(
                                title: "Check-in Expired",
                                body: "\(dependentName)'s check-in has expired.",
                                userInfo: ["dependentId": dependentId]
                            )))
                        }

                    default:
                        break
                    }
                }

                return .none

            case let .handleURL(url):
                // Currently only handling Firebase Auth URLs
                // Add additional URL handling here if needed
                print("Handling URL: \(url)")
                return .none

            // Profile feature has been removed, using UserFeature directly
            }
        }
        .ifLet(\.authentication, action: /Action.authentication) {
            AuthenticationFeature()
        }
        .ifLet(\.user, action: /Action.user) {
            UserFeature()
        }
        .ifLet(\.contacts, action: /Action.contacts) {
            ContactsFeature()
        }
        .ifLet(\.qrCode, action: /Action.qrCode) {
            QRCodeFeature()
        }
        .ifLet(\.notification, action: /Action.notification) {
            NotificationFeature()
        }
    }
}
