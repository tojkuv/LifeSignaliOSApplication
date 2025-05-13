
import Foundation
import ComposableArchitecture
import FirebaseFirestore
import FirebaseFunctions
import FirebaseAuth
import Dependencies

/// Parent feature for managing user contacts
/// This feature serves as the central repository for contacts data and operations
@Reducer
struct ContactsFeature {
    /// Cancellation IDs for long-running effects
    enum CancelID: Hashable, Sendable {
        // No longer need contactsStream as it's handled at the AppFeature level
    }

    /// The state of the contacts feature
    @ObservableState
    struct State: Equatable, Sendable {
        // MARK: - Contact Data
        var contacts: IdentifiedArrayOf<ContactData> = []

        // MARK: - Status
        var isLoading: Bool = false

        // MARK: - Computed Properties
        var responders: IdentifiedArrayOf<ContactData> {
            IdentifiedArray(uniqueElements: contacts.filter { $0.isResponder })
        }

        var dependents: IdentifiedArrayOf<ContactData> {
            IdentifiedArray(uniqueElements: contacts.filter { $0.isDependent })
        }

        var nonResponsiveDependentsCount: Int {
            dependents.filter { $0.isNonResponsive || $0.manualAlertActive }.count
        }

        var pendingPingsCount: Int {
            contacts.filter { $0.hasIncomingPing }.count
        }

        // MARK: - Initialization
        init(
            contacts: IdentifiedArrayOf<ContactData> = [],
            isLoading: Bool = false
        ) {
            self.contacts = contacts
            self.isLoading = isLoading
        }
    }

    /// Actions that can be performed on the contacts feature
    @CasePathable
    enum Action: Equatable, Sendable {
        // MARK: - Data Loading
        case loadContacts
        case contactsLoaded([ContactData])
        case contactsLoadFailed(UserFacingError)
        case contactsUpdated([ContactData])

        // MARK: - Contact Management
        case updateContactRoles(id: String, isResponder: Bool, isDependent: Bool)
        case contactRolesUpdated
        case contactRolesUpdateFailed(UserFacingError)
        case deleteContact(id: String)
        case contactDeleted
        case contactDeleteFailed(UserFacingError)

        // MARK: - Ping Operations (Delegated to PingFeature)
        case updateContactPingStatus(id: String, hasOutgoingPing: Bool, outgoingPingTimestamp: Date?)
        case updateContactPingResponseStatus(id: String, hasIncomingPing: Bool, incomingPingTimestamp: Date?)
        case updateAllContactsResponseStatus

        // MARK: - Delegate Actions
        case delegate(DelegateAction)

        /// Actions that will be delegated to parent features
        enum DelegateAction: Equatable, Sendable {
            case contactsUpdated
            case contactsLoadFailed(UserFacingError)
        }
    }

    /// Dependencies for the contacts feature
    @Dependency(\.firebaseContactsClient) var firebaseContactsClient
    @Dependency(\.firebaseAuth) var firebaseAuth
    @Dependency(\.timeFormatter) var timeFormatter

    /// Helper method to format contact time strings
    private func formatContactTimeStrings(_ contacts: [ContactData]) -> [ContactData] {
        var formattedContacts = contacts
        for i in 0..<formattedContacts.count {
            // Format incoming ping time
            if let incomingPingTimestamp = formattedContacts[i].incomingPingTimestamp {
                formattedContacts[i].formattedIncomingPingTime = timeFormatter.formatTimeAgo(incomingPingTimestamp)
            }

            // Format outgoing ping time
            if let outgoingPingTimestamp = formattedContacts[i].outgoingPingTimestamp {
                formattedContacts[i].formattedOutgoingPingTime = timeFormatter.formatTimeAgo(outgoingPingTimestamp)
            }

            // Format time remaining for check-in
            if let lastCheckedIn = formattedContacts[i].lastCheckedIn, let checkInInterval = formattedContacts[i].checkInInterval {
                let timeRemaining = timeFormatter.timeRemaining(lastCheckedIn, checkInInterval)
                formattedContacts[i].formattedTimeRemaining = timeFormatter.formatTimeInterval(timeRemaining)
            }
        }
        return formattedContacts
    }

    /// Helper method to sort responders with pending pings first, then alphabetically
    func sortedResponders(_ responders: IdentifiedArrayOf<ContactData>) -> [ContactData] {
        // Partition into pending pings and others
        let (pendingPings, others) = responders.elements.partitioned { $0.hasIncomingPing }

        // Sort pending pings by most recent ping timestamp
        let sortedPendingPings = pendingPings.sorted {
            ($0.incomingPingTimestamp ?? .distantPast) > ($1.incomingPingTimestamp ?? .distantPast)
        }

        // Sort others alphabetically
        let sortedOthers = others.sorted { $0.name < $1.name }

        // Combine with pending pings at the top
        return sortedPendingPings + sortedOthers
    }

    /// Helper method to sort dependents based on status (manual alert, non-responsive, pinged, responsive)
    func sortedDependents(_ dependents: IdentifiedArrayOf<ContactData>) -> [ContactData] {
        // Partition into manual alert, non-responsive, pinged, and responsive
        let (manualAlert, rest1) = dependents.elements.partitioned { $0.manualAlertActive }
        let (nonResponsive, rest2) = rest1.partitioned { $0.isNonResponsive }
        let (pinged, responsive) = rest2.partitioned { $0.hasOutgoingPing }

        // Sort manual alerts by most recent alert timestamp
        let sortedManualAlert = manualAlert.sorted {
            ($0.manualAlertTimestamp ?? .distantPast) > ($1.manualAlertTimestamp ?? .distantPast)
        }

        // Sort non-responsive by most expired first
        let sortedNonResponsive = nonResponsive.sorted {
            guard let lastCheckIn0 = $0.lastCheckedIn, let interval0 = $0.checkInInterval,
                  let lastCheckIn1 = $1.lastCheckedIn, let interval1 = $1.checkInInterval else {
                return false
            }
            let expiration0 = lastCheckIn0.addingTimeInterval(interval0)
            let expiration1 = lastCheckIn1.addingTimeInterval(interval1)
            return expiration0 < expiration1
        }

        // Sort pinged by most recent ping timestamp
        let sortedPinged = pinged.sorted {
            ($0.outgoingPingTimestamp ?? .distantPast) > ($1.outgoingPingTimestamp ?? .distantPast)
        }

        // Sort responsive alphabetically
        let sortedResponsive = responsive.sorted { $0.name < $1.name }

        // Combine all categories with priority order
        return sortedManualAlert + sortedNonResponsive + sortedPinged + sortedResponsive
    }

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            // MARK: - Data Loading

            case .loadContacts:
                state.isLoading = true

                return .run { [firebaseContactsClient, firebaseAuth] send in
                    do {
                        // Get the authenticated user ID or throw if not available
                        let userId = try await firebaseAuth.currentUserId()

                        // Get contacts using the client
                        let contacts = try await firebaseContactsClient.getContacts(userId)

                        // Format time strings for each contact
                        let formattedContacts = formatContactTimeStrings(contacts)
                        await send(.contactsLoaded(formattedContacts))
                    } catch {
                        // Map the error to a user-facing error
                        let userFacingError = UserFacingError.from(error)

                        // Handle error directly in the effect
                        await send(.contactsLoadFailed(userFacingError))

                        // Notify delegate about the failure with the user-facing error
                        await send(.delegate(.contactsLoadFailed(userFacingError)))
                    }
                }

            case let .contactsLoaded(contacts):
                state.isLoading = false
                state.contacts = IdentifiedArray(uniqueElements: contacts)

                // Notify delegate that contacts were updated
                return .send(.delegate(.contactsUpdated))

            case let .contactsLoadFailed(error):
                state.isLoading = false

                // Log the error but don't take any additional action
                // The parent feature will handle displaying the error to the user
                FirebaseLogger.contacts.error("Contacts loading failed: \(error)")
                return .none

            case let .contactsUpdated(contacts):
                // Format time strings for each contact
                let formattedContacts = formatContactTimeStrings(contacts)
                state.contacts = IdentifiedArray(uniqueElements: formattedContacts)

                // Notify delegate that contacts were updated
                return .send(.delegate(.contactsUpdated))

            // MARK: - Contact Management

            case let .updateContactRoles(id, isResponder, isDependent):
                // Update local state immediately for better UX
                if let index = state.contacts.index(id: id) {
                    state.contacts[index].isResponder = isResponder
                    state.contacts[index].isDependent = isDependent
                }

                state.isLoading = true

                return .run { [firebaseContactsClient, firebaseAuth] send in
                    do {
                        // Get the authenticated user ID or throw if not available
                        let userId = try await firebaseAuth.currentUserId()

                        // Update the contact roles using the client
                        try await firebaseContactsClient.updateContact(
                            userId,
                            id,
                            [
                                FirestoreConstants.ContactFields.isResponder: isResponder,
                                FirestoreConstants.ContactFields.isDependent: isDependent
                            ]
                        )

                        // Send success response
                        await send(.contactRolesUpdated)
                    } catch {
                        // Map the error to a user-facing error
                        let userFacingError = UserFacingError.from(error)

                        // Handle error directly in the effect
                        await send(.contactRolesUpdateFailed(userFacingError))

                        // Reload contacts to revert changes if there was an error
                        await send(.loadContacts)
                    }
                }

            case .contactRolesUpdated:
                state.isLoading = false
                // Notify delegate that contacts were updated
                return .send(.delegate(.contactsUpdated))

            case let .contactRolesUpdateFailed(error):
                state.isLoading = false

                // Log the error
                FirebaseLogger.contacts.error("Contact roles update failed: \(error)")
                return .none

            case let .deleteContact(id):
                // Remove from local state immediately for better UX
                state.contacts.remove(id: id)
                state.isLoading = true

                return .run { [firebaseContactsClient, firebaseAuth] send in
                    do {
                        // Get the authenticated user ID or throw if not available
                        let userId = try await firebaseAuth.currentUserId()

                        // Delete the contact using the client
                        try await firebaseContactsClient.deleteContact(userId, id)

                        // Send success response
                        await send(.contactDeleted)
                    } catch {
                        // Map the error to a user-facing error
                        let userFacingError = UserFacingError.from(error)

                        // Handle error directly in the effect
                        await send(.contactDeleteFailed(userFacingError))

                        // Reload contacts to revert changes if there was an error
                        await send(.loadContacts)
                    }
                }

            case .contactDeleted:
                state.isLoading = false
                // Notify delegate that contacts were updated
                return .send(.delegate(.contactsUpdated))

            case let .contactDeleteFailed(error):
                state.isLoading = false

                // Log the error
                FirebaseLogger.contacts.error("Contact delete failed: \(error)")
                return .none

            // MARK: - Ping Operations (Delegated to PingFeature)

            case let .updateContactPingStatus(id, hasOutgoingPing, outgoingPingTimestamp):
                // Update the contact's ping status
                if let index = state.contacts.index(id: id) {
                    state.contacts[index].hasOutgoingPing = hasOutgoingPing
                    state.contacts[index].outgoingPingTimestamp = outgoingPingTimestamp

                    // Format the outgoing ping time if it exists
                    if let timestamp = outgoingPingTimestamp {
                        state.contacts[index].formattedOutgoingPingTime = timeFormatter.formatTimeAgo(timestamp)
                    } else {
                        state.contacts[index].formattedOutgoingPingTime = nil
                    }
                }

                // Notify delegate that contacts were updated
                return .send(.delegate(.contactsUpdated))

            case let .updateContactPingResponseStatus(id, hasIncomingPing, incomingPingTimestamp):
                // Update the contact's ping response status
                if let index = state.contacts.index(id: id) {
                    state.contacts[index].hasIncomingPing = hasIncomingPing
                    state.contacts[index].incomingPingTimestamp = incomingPingTimestamp

                    // Format the incoming ping time if it exists
                    if let timestamp = incomingPingTimestamp {
                        state.contacts[index].formattedIncomingPingTime = timeFormatter.formatTimeAgo(timestamp)
                    } else {
                        state.contacts[index].formattedIncomingPingTime = nil
                    }
                }

                // Notify delegate that contacts were updated
                return .send(.delegate(.contactsUpdated))

            case .updateAllContactsResponseStatus:
                // Update all contacts to clear incoming pings
                for i in state.contacts.indices where state.contacts[i].hasIncomingPing {
                    state.contacts[i].hasIncomingPing = false
                    state.contacts[i].incomingPingTimestamp = nil
                    state.contacts[i].formattedIncomingPingTime = nil
                }

                // Notify delegate that contacts were updated
                return .send(.delegate(.contactsUpdated))

            case .delegate:
                // These actions are handled by the parent feature
                return .none
            }
        }

        ._printChanges()
    }
}
