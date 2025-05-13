
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
        case contactsStream
    }

    /// The state of the contacts feature
    @ObservableState
    struct State: Equatable, Sendable {
        // MARK: - Contact Data
        var contacts: IdentifiedArrayOf<ContactData> = []

        // MARK: - Status
        var isLoading: Bool = false
        var error: UserFacingError? = nil
        var isStreamActive: Bool = false

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
            isLoading: Bool = false,
            error: UserFacingError? = nil,
            isStreamActive: Bool = false
        ) {
            self.contacts = contacts
            self.isLoading = isLoading
            self.error = error
            self.isStreamActive = isStreamActive
        }
    }

    /// Actions that can be performed on the contacts feature
    enum Action: Equatable, Sendable {
        // MARK: - Data Loading
        case loadContacts
        case loadContactsResponse(TaskResult<[ContactData]>)
        case startContactsStream
        case contactsUpdated([ContactData])
        case contactsStreamFailed(Error)
        case stopContactsStream
        case setError(UserFacingError?)
        case setLoading(Bool)

        // MARK: - Contact Management
        case updateContactRoles(id: String, isResponder: Bool, isDependent: Bool)
        case updateContactRolesResponse(TaskResult<Bool>)
        case deleteContact(id: String)
        case deleteContactResponse(TaskResult<Bool>)

        // MARK: - Ping Operations
        case pingDependent(id: String)
        case pingDependentResponse(TaskResult<Bool>)
        case clearPing(id: String)
        case clearPingResponse(TaskResult<Bool>)
        case respondToPing(id: String)
        case respondToPingResponse(TaskResult<Bool>)
        case respondToAllPings
        case respondToAllPingsResponse(TaskResult<Bool>)

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
                state.error = nil

                return .run { [firebaseContactsClient, firebaseAuth] send in
                    do {
                        let userId = try await firebaseAuth.currentUserId()

                        let contacts = try await firebaseContactsClient.getContacts(userId)
                        await send(.loadContactsResponse(.success(contacts)))
                    } catch {
                        let userFacingError = UserFacingError.from(error)
                        await send(.loadContactsResponse(.failure(userFacingError)))
                    }
                }

            case let .loadContactsResponse(result):
                state.isLoading = false

                switch result {
                case let .success(contacts):
                    // Format time strings for each contact
                    let formattedContacts = formatContactTimeStrings(contacts)
                    state.contacts = IdentifiedArray(uniqueElements: formattedContacts)

                    // Notify delegate that contacts were updated
                    return .send(.delegate(.contactsUpdated))

                case let .failure(error):
                    state.error = error

                    // Notify delegate that contacts loading failed
                    return .send(.delegate(.contactsLoadFailed(error)))
                }

            case .startContactsStream:
                // This action is now handled by the AppFeature
                // Just mark the stream as active
                state.isStreamActive = true
                return .none

            case let .contactsUpdated(contacts):
                // Format time strings for each contact
                let formattedContacts = formatContactTimeStrings(contacts)
                state.contacts = IdentifiedArray(uniqueElements: formattedContacts)

                // Notify delegate that contacts were updated
                return .send(.delegate(.contactsUpdated))

            case let .contactsStreamFailed(error):
                // Only update error state for persistent errors
                if let nsError = error as NSError?,
                   nsError.domain != FirestoreErrorDomain ||
                   nsError.code != FirestoreErrorCode.unavailable.rawValue {
                    let userFacingError = UserFacingError.from(error)
                    state.error = userFacingError

                    // Notify delegate that contacts loading failed
                    return .send(.delegate(.contactsLoadFailed(userFacingError)))
                }
                return .none

            case .stopContactsStream:
                // This action is now handled by the AppFeature
                // Just mark the stream as inactive
                state.isStreamActive = false
                return .none

            case let .setError(error):
                state.error = error
                return .none

            case let .setLoading(isLoading):
                state.isLoading = isLoading
                return .none

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
                        let userId = try await firebaseAuth.currentUserId()

                        // Call the Firebase function to update the contact roles
                        try await firebaseContactsClient.updateContact(
                            userId: userId,
                            contactId: id,
                            fields: [
                                FirestoreConstants.ContactFields.isResponder: isResponder,
                                FirestoreConstants.ContactFields.isDependent: isDependent
                            ]
                        )

                        await send(.updateContactRolesResponse(.success(true)))
                    } catch {
                        let userFacingError = UserFacingError.from(error)
                        await send(.updateContactRolesResponse(.failure(userFacingError)))
                    }
                }

            case let .updateContactRolesResponse(result):
                state.isLoading = false

                switch result {
                case .success:
                    // Notify delegate that contacts were updated
                    return .send(.delegate(.contactsUpdated))

                case let .failure(error):
                    state.error = error

                    // Reload contacts to revert changes if there was an error
                    return .concatenate(
                        .send(.loadContacts),
                        .send(.delegate(.contactsLoadFailed(error)))
                    )
                }

            case let .deleteContact(id):
                // Remove from local state immediately for better UX
                state.contacts.remove(id: id)
                state.isLoading = true

                return .run { [firebaseContactsClient, firebaseAuth] send in
                    do {
                        let userId = try await firebaseAuth.currentUserId()

                        try await firebaseContactsClient.deleteContact(userId: userId, contactId: id)
                        await send(.deleteContactResponse(.success(true)))
                    } catch {
                        let userFacingError = UserFacingError.from(error)
                        await send(.deleteContactResponse(.failure(userFacingError)))
                    }
                }

            case let .deleteContactResponse(result):
                state.isLoading = false

                switch result {
                case .success:
                    // Notify delegate that contacts were updated
                    return .send(.delegate(.contactsUpdated))

                case let .failure(error):
                    state.error = error

                    // Reload contacts to revert changes if there was an error
                    return .concatenate(
                        .send(.loadContacts),
                        .send(.delegate(.contactsLoadFailed(error)))
                    )
                }

            // MARK: - Ping Operations

            case let .pingDependent(id):
                // Update local state immediately for better UX
                if let index = state.contacts.index(id: id) {
                    state.contacts[index].hasOutgoingPing = true
                    state.contacts[index].outgoingPingTimestamp = Date()

                    // Format the outgoing ping time
                    state.contacts[index].formattedOutgoingPingTime = timeFormatter.formatTimeAgo(state.contacts[index].outgoingPingTimestamp!)
                }

                state.isLoading = true

                return .run { [firebaseAuth] send in
                    do {
                        _ = try await firebaseAuth.currentUserId()

                        // Call the Firebase function to ping the dependent
                        let data: [String: Any] = [
                            "dependentId": id
                        ]

                        let functions = Functions.functions()
                        let result = try await functions.httpsCallable("pingDependent").call(data)

                        guard let _ = result.data as? [String: Any] else {
                            throw FirebaseError.invalidData
                        }

                        await send(.pingDependentResponse(.success(true)))
                    } catch {
                        let userFacingError = UserFacingError.from(error)
                        await send(.pingDependentResponse(.failure(userFacingError)))
                    }
                }

            case let .pingDependentResponse(result):
                state.isLoading = false

                switch result {
                case .success:
                    // Notify delegate that contacts were updated
                    return .send(.delegate(.contactsUpdated))

                case let .failure(error):
                    state.error = error

                    // Reload contacts to revert changes if there was an error
                    return .concatenate(
                        .send(.loadContacts),
                        .send(.delegate(.contactsLoadFailed(error)))
                    )
                }

            case let .clearPing(id):
                // Update local state immediately for better UX
                if let index = state.contacts.index(id: id) {
                    state.contacts[index].hasOutgoingPing = false
                    state.contacts[index].outgoingPingTimestamp = nil
                    state.contacts[index].formattedOutgoingPingTime = nil
                }

                state.isLoading = true

                return .run { [firebaseAuth] send in
                    do {
                        let userId = try await firebaseAuth.currentUserId()

                        // Call the Firebase function to clear the ping
                        let data: [String: Any] = [
                            "userId": userId,
                            "contactId": id
                        ]

                        let functions = Functions.functions()
                        let result = try await functions.httpsCallable("clearPing").call(data)

                        guard let _ = result.data as? [String: Any] else {
                            throw FirebaseError.invalidData
                        }

                        await send(.clearPingResponse(.success(true)))
                    } catch {
                        let userFacingError = UserFacingError.from(error)
                        await send(.clearPingResponse(.failure(userFacingError)))
                    }
                }

            case let .clearPingResponse(result):
                state.isLoading = false

                switch result {
                case .success:
                    // Notify delegate that contacts were updated
                    return .send(.delegate(.contactsUpdated))

                case let .failure(error):
                    state.error = error

                    // Reload contacts to revert changes if there was an error
                    return .concatenate(
                        .send(.loadContacts),
                        .send(.delegate(.contactsLoadFailed(error)))
                    )
                }

            case let .respondToPing(id):
                // Update local state immediately for better UX
                if let index = state.contacts.index(id: id) {
                    state.contacts[index].hasIncomingPing = false
                    state.contacts[index].incomingPingTimestamp = nil
                    state.contacts[index].formattedIncomingPingTime = nil
                }

                state.isLoading = true

                return .run { [firebaseAuth] send in
                    do {
                        _ = try await firebaseAuth.currentUserId()

                        // Call the Firebase function to respond to the ping
                        let data: [String: Any] = [
                            "responderId": id
                        ]

                        let functions = Functions.functions()
                        let result = try await functions.httpsCallable("respondToPing").call(data)

                        guard let _ = result.data as? [String: Any] else {
                            throw FirebaseError.invalidData
                        }

                        await send(.respondToPingResponse(.success(true)))
                    } catch {
                        let userFacingError = UserFacingError.from(error)
                        await send(.respondToPingResponse(.failure(userFacingError)))
                    }
                }

            case let .respondToPingResponse(result):
                state.isLoading = false

                switch result {
                case .success:
                    // Notify delegate that contacts were updated
                    return .send(.delegate(.contactsUpdated))

                case let .failure(error):
                    state.error = error

                    // Reload contacts to revert changes if there was an error
                    return .concatenate(
                        .send(.loadContacts),
                        .send(.delegate(.contactsLoadFailed(error)))
                    )
                }

            case .respondToAllPings:
                // Update local state immediately for better UX
                for i in state.contacts.indices where state.contacts[i].hasIncomingPing {
                    state.contacts[i].hasIncomingPing = false
                    state.contacts[i].incomingPingTimestamp = nil
                    state.contacts[i].formattedIncomingPingTime = nil
                }

                state.isLoading = true

                return .run { [firebaseAuth] send in
                    do {
                        _ = try await firebaseAuth.currentUserId()

                        // Call the Firebase function to respond to all pings
                        let functions = Functions.functions()
                        let result = try await functions.httpsCallable("respondToAllPings").call(nil)

                        guard let _ = result.data as? [String: Any] else {
                            throw FirebaseError.invalidData
                        }

                        await send(.respondToAllPingsResponse(.success(true)))
                    } catch {
                        let userFacingError = UserFacingError.from(error)
                        await send(.respondToAllPingsResponse(.failure(userFacingError)))
                    }
                }

            case let .respondToAllPingsResponse(result):
                state.isLoading = false

                switch result {
                case .success:
                    // Notify delegate that contacts were updated
                    return .send(.delegate(.contactsUpdated))

                case let .failure(error):
                    state.error = error

                    // Reload contacts to revert changes if there was an error
                    return .concatenate(
                        .send(.loadContacts),
                        .send(.delegate(.contactsLoadFailed(error)))
                    )
                }

            case .delegate:
                // These actions are handled by the parent feature
                return .none
            }
        }
    }
}
