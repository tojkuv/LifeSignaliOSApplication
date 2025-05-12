import Foundation
import ComposableArchitecture

/// Feature for contact details sheet functionality
@Reducer
struct ContactDetailsSheetFeature {
    /// The state of the contact details sheet feature
    @ObservableState
    struct State: Equatable, Sendable {
        /// Whether the sheet is active
        var isActive: Bool = false

        /// The contact being displayed
        var contact: ContactData?

        /// UI alert states
        struct AlertState: Equatable, Sendable {
            var showPingConfirmation: Bool = false
            var showManualAlertConfirmation: Bool = false
            var showCancelManualAlertConfirmation: Bool = false
            var showRemoveContactConfirmation: Bool = false
        }

        /// Alert states
        var alerts = AlertState()

        /// Operation state
        var isLoading: Bool = false
        var error: Error?

        /// Initialize with default values
        init() {}

        /// Initialize with a contact
        init(contact: ContactData) {
            self.contact = contact
        }
    }

    /// Actions that can be performed on the contact details sheet feature
    enum Action: Equatable, Sendable {
        // MARK: - Sheet Lifecycle
        /// Set whether the sheet is active
        case setActive(Bool)
        /// Set the contact
        case setContact(ContactData?)

        // MARK: - Alert Actions
        /// Set whether to show the ping confirmation alert
        case setShowPingConfirmation(Bool)
        /// Set whether to show the manual alert confirmation alert
        case setShowManualAlertConfirmation(Bool)
        /// Set whether to show the cancel manual alert confirmation alert
        case setShowCancelManualAlertConfirmation(Bool)
        /// Set whether to show the remove contact confirmation alert
        case setShowRemoveContactConfirmation(Bool)

        // MARK: - Operation State
        /// Set whether an operation is in progress
        case setLoading(Bool)
        /// Set the error
        case setError(Error?)

        // MARK: - Delegate Actions
        /// Delegate actions to parent feature
        case delegate(DelegateAction)

        /// Actions that will be delegated to parent feature
        enum DelegateAction: Equatable, Sendable {
            /// Ping a dependent
            case pingDependent(id: String)
            /// Send a manual alert to a dependent
            case sendManualAlert(id: String)
            /// Cancel a manual alert for a dependent
            case cancelManualAlert(id: String)
            /// Remove a contact
            case removeContact(id: String)
            /// Toggle contact role
            case toggleContactRole(id: String, isResponder: Bool, isDependent: Bool)
        }
    }

    @Dependency(\.dismiss) var dismiss

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .setActive(active):
                state.isActive = active
                if !active {
                    state.contact = nil
                    state.alerts = State.AlertState()
                    state.isLoading = false
                    state.error = nil

                    // Use the dismiss dependency if needed
                    return .run { _ in await self.dismiss() }
                }
                return .none

            case let .setContact(contact):
                state.contact = contact
                return .none

            case let .setShowPingConfirmation(show):
                state.alerts.showPingConfirmation = show
                return .none

            case let .setShowManualAlertConfirmation(show):
                state.alerts.showManualAlertConfirmation = show
                return .none

            case let .setShowCancelManualAlertConfirmation(show):
                state.alerts.showCancelManualAlertConfirmation = show
                return .none

            case let .setShowRemoveContactConfirmation(show):
                state.alerts.showRemoveContactConfirmation = show
                return .none

            case let .setLoading(loading):
                state.isLoading = loading
                return .none

            case let .setError(error):
                state.isLoading = false
                state.error = error
                return .none

            case .delegate:
                // These actions will be handled by the parent
                return .none
            }
        }
    }
}
