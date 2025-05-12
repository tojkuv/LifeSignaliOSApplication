import Foundation
import ComposableArchitecture
import FirebaseAuth
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import UIKit

/// The main app feature that composes all other features
@Reducer
struct AppFeature {
    /// Cancellation IDs for long-running effects
    enum CancelID: Hashable, Sendable {
        case appLifecycle
    }

    /// The state of the app feature
    @ObservableState
    struct State: Equatable, Sendable {
        /// User state (parent feature)
        var user = UserFeature.State()

        /// Sign-in state
        var signIn = SignInFeature.State()

        /// Contacts state
        var contacts = ContactsFeature.State()

        /// Shared feature states
        var qrScanner = QRScannerFeature.State()

        /// Presentation states using @Presents
        @Presents var contactDetails: ContactDetailsSheetFeature.State?

        /// Tab feature states
        var home = HomeFeature.State()
        var responders = RespondersFeature.State()
        var dependents = DependentsFeature.State()

        /// New feature states
        var alert = AlertFeature.State()
        var notification = NotificationFeature.State()

        /// Onboarding feature state
        var onboarding = OnboardingFeature.State()

        /// Error alert
        @Presents var errorAlert: AlertState<Action.Alert>?

        /// App lifecycle state - using @Shared for app-wide state
        @Shared(.inMemory("authState")) var isAuthenticated = false
        @Shared(.inMemory("onboardingState")) var needsOnboarding = false

        /// Initialize with default values
        init() {
            // Note: CheckInFeature and ProfileFeature are now child features of UserFeature
            // and will be initialized within UserFeature
        }
    }

    /// Actions that can be performed on the app feature
    enum Action: Equatable, Sendable {
        // MARK: - Child Feature Actions

        /// User feature actions (parent feature)
        case user(UserFeature.Action)

        /// Sign-in feature actions
        case signIn(SignInFeature.Action)

        /// Contacts feature actions
        case contacts(ContactsFeature.Action)

        /// Shared feature actions
        case qrScanner(QRScannerFeature.Action)
        case contactDetails(PresentationAction<ContactDetailsSheetFeature.Action>)

        /// Tab feature actions
        case home(HomeFeature.Action)
        case responders(RespondersFeature.Action)
        case dependents(DependentsFeature.Action)

        /// New feature actions
        case alert(AlertFeature.Action)
        case notification(NotificationFeature.Action)

        /// Onboarding feature actions
        case onboarding(OnboardingFeature.Action)

        /// Error alert actions
        case errorAlert(PresentationAction<Alert>)

        /// Alert actions enum
        enum Alert: Equatable, Sendable {
            case dismiss
            case retry
        }

        // MARK: - App Lifecycle Actions

        /// App appeared
        case appAppeared

        /// App state changed
        case appStateChanged(oldState: UIApplication.State, newState: UIApplication.State)

        /// Authentication state changed
        case authStateChanged

        /// Update FCM token
        case updateFCMToken(String)

        /// Handle URL
        case handleURL(URL)

        /// Check authentication state
        case checkAuthenticationState
        case checkAuthenticationStateResponse(Bool)

        /// Check onboarding state
        case checkOnboardingState
        case checkOnboardingStateResponse(Bool)
    }

    /// Dependencies
    @Dependency(\.firebaseAuth) var firebaseAuth
    @Dependency(\.firebaseApp) var firebaseApp
    @Dependency(\.firebaseNotification) var firebaseNotification
    @Dependency(\.firebaseSessionClient) var firebaseSessionClient

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            // MARK: - App Lifecycle

            case .appAppeared:
                return .merge(
                    .send(.checkAuthenticationState),
                    .run { [firebaseNotification] _ in
                        _ = await firebaseNotification.getAuthorizationStatus()
                    }
                )

            case let .appStateChanged(oldState, newState):
                if newState == .active && oldState != .active && state.isAuthenticated {
                    return .merge(
                        .send(.user(.loadUserData)),
                        .send(.contacts(.loadContacts))
                    )
                }
                return .none

            case .authStateChanged:
                return .send(.checkAuthenticationState)

            case .checkAuthenticationState:
                return .run { [firebaseAuth] send in
                    let isAuthenticated = await firebaseAuth.isAuthenticated()
                    await send(.checkAuthenticationStateResponse(isAuthenticated))
                }

            case let .checkAuthenticationStateResponse(isAuthenticated):
                let wasAuthenticated = state.$isAuthenticated.withLock { $0 }

                // Update the shared authentication state
                state.$isAuthenticated.withLock { $0 = isAuthenticated }

                if !wasAuthenticated && isAuthenticated {
                    return .merge(
                        .send(.user(.startUserDataStream)),
                        .send(.contacts(.startContactsStream)),
                        .send(.checkOnboardingState)
                    )
                } else if wasAuthenticated && !isAuthenticated {
                    return .merge(
                        .send(.user(.stopUserDataStream)),
                        .send(.contacts(.stopContactsStream))
                    )
                }

                return .none

            case .checkOnboardingState:
                return .send(.checkOnboardingStateResponse(!state.user.userData.profileComplete))

            case let .checkOnboardingStateResponse(needsOnboarding):
                // Update the shared onboarding state
                state.$needsOnboarding.withLock { $0 = needsOnboarding }
                return .none

            case let .updateFCMToken(token):
                return .send(.notification(.updateFCMToken(token)))

            case let .handleURL(url):
                // Handle deep links
                return .none

            // MARK: - Child Feature Actions

            case .user, .signIn, .contacts:
                return .none

            case let .qrScanner(.contacts(.lookupContactByQRCode(code))):
                return .send(.contacts(.lookupContactByQRCode(code)))

            case .qrScanner(.contacts(.addContact)):
                return .send(.contacts(.addContact))

            case .qrScanner:
                return .none

            case .contactDetails(.presented(.contacts(.pingDependent(let id)))):
                return .send(.contacts(.pingDependent(id)))

            case .contactDetails(.presented(.contacts(.sendManualAlert(let id)))):
                return .send(.contacts(.sendManualAlert(id)))

            case .contactDetails(.presented(.contacts(.cancelManualAlert(let id)))):
                return .send(.contacts(.cancelManualAlert(id)))

            case .contactDetails(.presented(.contacts(.removeContact(let id)))):
                return .send(.contacts(.removeContact(id)))

            case .contactDetails(.presented(.contacts(.toggleContactRole(let id, let isResponder, let isDependent)))):
                return .send(.contacts(.toggleContactRole(id: id, isResponder: isResponder, isDependent: isDependent)))

            case .contactDetails:
                return .none

            // Home feature actions are now handled directly by UserFeature

            // QR scanner actions from home
            case let .home(.qrScanner(qrScannerAction)):
                return .send(.qrScanner(qrScannerAction))

            // Add contact actions from home
            case let .home(.addContact(.updateQRCode(qrCode))):
                return .send(.qrScanner(.qrCodeScanned(qrCode)))

            case .home(.addContact):
                return .none

            case let .home(.delegate(.updateCheckInInterval(interval))):
                return .send(.user(.updateCheckInInterval(interval)))

            case .home:
                return .none

            case .responders(.contacts(.loadContacts)):
                return .send(.contacts(.loadContacts))

            case .responders(.contacts(.respondToAllPings)):
                return .send(.contacts(.respondToAllPings))

            case let .responders(.qrScanner(.setActive(active))):
                return .send(.qrScanner(.setActive(active)))

            case .responders(.qrScanner(.scanQRCode)):
                return .send(.qrScanner(.scanQRCode))

            case let .responders(.contactDetails(.setActive(active))):
                if active {
                    // Create contact details state when activating
                    state.contactDetails = ContactDetailsSheetFeature.State()
                } else {
                    // Clear contact details state when deactivating
                    state.contactDetails = nil
                }
                return .none

            case let .responders(.contactDetails(.setContact(contact))):
                if state.contactDetails == nil {
                    state.contactDetails = ContactDetailsSheetFeature.State()
                }
                return .send(.contactDetails(.presented(.setContact(contact))))

            case .responders:
                return .none

            case let .user(.userDataStreamResponse(userData)):
                // Sync user data to other features
                return .merge(
                    .send(.notification(.updateNotificationState(
                        enabled: userData.notificationEnabled,
                        notify30Min: userData.notify30MinBefore,
                        notify2Hours: userData.notify2HoursBefore
                    ))),
                    .send(.alert(.updateAlertState(
                        isActive: userData.manualAlertActive,
                        timestamp: userData.manualAlertTimestamp
                    )))
                )

            case let .qrScanner(.setShowScanner(show)):
                state.qrScanner.showScanner = show
                return .none

            case .dependents:
                return .none

            // User sign out is now handled by UserFeature
            case .user(.delegate(.userSignedOut)):
                return .run { [firebaseAuth, firebaseSessionClient] send in
                    do {
                        // Clear session ID
                        firebaseSessionClient.clearSessionId()

                        // Sign out using Firebase Auth
                        try await firebaseAuth.signOut()

                        // Notify the app that auth state changed
                        await send(.authStateChanged)
                    } catch {
                        // Handle sign out error with alert
                        await send(.errorAlert(.presented(.init(title: TextState("Sign Out Error"),
                                                               message: TextState(error.localizedDescription)))))
                    }
                }

            // Alert feature actions
            case .alert(.triggerManualAlert):
                return .none

            case .alert(.clearManualAlert):
                return .none

            case .alert:
                return .none

            // Notification feature actions
            case .notification(.updateNotificationSettings):
                return .none

            case .notification(.updateNotificationPreferences):
                return .none

            case .notification:
                return .none

            case .onboarding(.delegate(.onboardingCompleted)):
                // Update the shared onboarding state
                state.$needsOnboarding.withLock { $0 = false }
                return .none

            case .onboarding:
                return .none

            // Error alert actions
            case .errorAlert(.dismiss), .errorAlert(.presented(.dismiss)):
                state.errorAlert = nil
                return .none

            case .errorAlert(.presented(.retry)):
                state.errorAlert = nil
                // Add retry logic if needed
                return .none

            case .errorAlert:
                return .none
            }
        }

        // Scope child features
        Scope(state: \.user, action: \.user) {
            UserFeature()
        }

        Scope(state: \.signIn, action: \.signIn) {
            SignInFeature()
        }

        Scope(state: \.contacts, action: \.contacts) {
            ContactsFeature()
        }

        // Shared feature reducers
        Scope(state: \.qrScanner, action: \.qrScanner) {
            QRScannerFeature()
        }

        // Use the new presentation reducers
        .presents(state: \.contactDetails, action: \.contactDetails) {
            ContactDetailsSheetFeature()
        }

        // Tab feature reducers
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }

        Scope(state: \.responders, action: \.responders) {
            RespondersFeature()
        }

        Scope(state: \.dependents, action: \.dependents) {
            DependentsFeature()
        }

        // New feature reducers
        Scope(state: \.alert, action: \.alert) {
            AlertFeature()
        }

        Scope(state: \.notification, action: \.notification) {
            NotificationFeature()
        }

        Scope(state: \.onboarding, action: \.onboarding) {
            OnboardingFeature()
        }

        // Add error alert presentation
        .presents(state: \.errorAlert, action: \.errorAlert)
    }

    // MARK: - App Delegate Methods

    /// These methods have been moved to the AppDelegate class and are now using dependency clients
}
