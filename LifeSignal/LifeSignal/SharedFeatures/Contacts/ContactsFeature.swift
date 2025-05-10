import Foundation
import ComposableArchitecture
import FirebaseFirestore

/// Domain model for a contact in the TCA architecture
struct Contact: Identifiable, Equatable, Codable {
    // MARK: - Identifiable Conformance

    /// Unique identifier for the contact (user ID)
    var id: String

    // MARK: - Relationship Properties

    /// Whether this contact is a responder for the user
    var isResponder: Bool

    /// Whether this contact is a dependent of the user
    var isDependent: Bool

    /// Whether to send pings to this contact
    var sendPings: Bool = true

    /// Whether to receive pings from this contact
    var receivePings: Bool = true

    /// Optional nickname for this contact
    var nickname: String?

    /// Optional notes about this contact
    var notes: String?

    /// When this contact was last updated
    var lastUpdated: Date = Date()

    /// When this contact was added
    var addedAt: Date = Date()

    // MARK: - Cached User Data Properties

    /// User's full name
    var name: String = "Unknown User"

    /// User's phone number (E.164 format)
    var phoneNumber: String = ""

    /// User's phone region (ISO country code)
    var phoneRegion: String = "US"

    /// User's emergency profile description
    var note: String = ""

    /// User's QR code ID
    var qrCodeId: String?

    /// User's last check-in time
    var lastCheckedIn: Date?

    /// User's check-in interval in seconds
    var checkInInterval: TimeInterval?

    // MARK: - Alert and Ping Properties

    /// Whether this contact has an active manual alert
    var manualAlertActive: Bool = false

    /// Timestamp when the manual alert was activated
    var manualAlertTimestamp: Date?

    /// Whether this contact has an incoming ping
    var hasIncomingPing: Bool = false

    /// Whether this contact has an outgoing ping
    var hasOutgoingPing: Bool = false

    /// Timestamp when the incoming ping was received
    var incomingPingTimestamp: Date?

    /// Timestamp when the outgoing ping was sent
    var outgoingPingTimestamp: Date?

    // MARK: - Computed Properties

    /// Whether this contact is non-responsive (past check-in time)
    var isNonResponsive: Bool {
        guard let lastCheckedIn = lastCheckedIn, let checkInInterval = checkInInterval else {
            return false
        }

        let expirationTime = lastCheckedIn.addingTimeInterval(checkInInterval)
        return Date() > expirationTime
    }

    /// Whether this contact's check-in has expired
    var checkInExpired: Bool {
        return isNonResponsive
    }

    /// Formatted time remaining until check-in expiration
    var formattedTimeRemaining: String {
        guard let lastCheckedIn = lastCheckedIn, let checkInInterval = checkInInterval else {
            return ""
        }

        let expirationTime = lastCheckedIn.addingTimeInterval(checkInInterval)
        let timeRemaining = expirationTime.timeIntervalSince(Date())

        if timeRemaining <= 0 {
            return "Overdue"
        }

        // Format the time remaining
        let days = Int(timeRemaining / (60 * 60 * 24))
        let hours = Int((timeRemaining.truncatingRemainder(dividingBy: 60 * 60 * 24)) / (60 * 60))

        if days > 0 {
            return "\(days)d \(hours)h"
        } else {
            let minutes = Int((timeRemaining.truncatingRemainder(dividingBy: 60 * 60)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }

    // MARK: - Initialization

    /// Initialize a new Contact with all properties
    init(
        id: String,
        name: String = "Unknown User",
        isResponder: Bool = false,
        isDependent: Bool = false,
        phoneNumber: String = "",
        phoneRegion: String = "US",
        note: String = "",
        lastCheckedIn: Date? = nil,
        checkInInterval: TimeInterval? = nil,
        hasIncomingPing: Bool = false,
        hasOutgoingPing: Bool = false,
        incomingPingTimestamp: Date? = nil,
        outgoingPingTimestamp: Date? = nil,
        manualAlertActive: Bool = false,
        manualAlertTimestamp: Date? = nil,
        sendPings: Bool = true,
        receivePings: Bool = true,
        nickname: String? = nil,
        notes: String? = nil,
        qrCodeId: String? = nil,
        addedAt: Date = Date(),
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.isResponder = isResponder
        self.isDependent = isDependent
        self.phoneNumber = phoneNumber
        self.phoneRegion = phoneRegion
        self.note = note
        self.lastCheckedIn = lastCheckedIn
        self.checkInInterval = checkInInterval
        self.hasIncomingPing = hasIncomingPing
        self.hasOutgoingPing = hasOutgoingPing
        self.incomingPingTimestamp = incomingPingTimestamp
        self.outgoingPingTimestamp = outgoingPingTimestamp
        self.manualAlertActive = manualAlertActive
        self.manualAlertTimestamp = manualAlertTimestamp
        self.sendPings = sendPings
        self.receivePings = receivePings
        self.nickname = nickname
        self.notes = notes
        self.qrCodeId = qrCodeId
        self.addedAt = addedAt
        self.lastUpdated = lastUpdated
    }

    /// Create a default Contact for display in UI previews
    static func createDefault(
        name: String,
        isResponder: Bool = false,
        isDependent: Bool = false
    ) -> Contact {
        return Contact(
            id: UUID().uuidString,
            name: name,
            isResponder: isResponder,
            isDependent: isDependent
        )
    }

    // MARK: - Firestore Methods

    /// Convert to Firestore data
    /// - Returns: Dictionary representation for Firestore
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            FirestoreConstants.ContactFields.referencePath: "users/\(id)",
            FirestoreConstants.ContactFields.isResponder: isResponder,
            FirestoreConstants.ContactFields.isDependent: isDependent,
            FirestoreConstants.ContactFields.sendPings: sendPings,
            FirestoreConstants.ContactFields.receivePings: receivePings,
            FirestoreConstants.ContactFields.lastUpdated: Timestamp(date: lastUpdated),
            FirestoreConstants.ContactFields.addedAt: Timestamp(date: addedAt)
        ]

        // Add optional fields if they exist
        if let nickname = nickname {
            data[FirestoreConstants.ContactFields.nickname] = nickname
        }

        if let notes = notes {
            data[FirestoreConstants.ContactFields.notes] = notes
        }

        // Add cached user data properties
        data[FirestoreConstants.ContactFields.name] = name
        data[FirestoreConstants.ContactFields.phoneNumber] = phoneNumber
        data[FirestoreConstants.ContactFields.phoneRegion] = phoneRegion
        data[FirestoreConstants.ContactFields.note] = note

        if let qrCodeId = qrCodeId {
            data[FirestoreConstants.ContactFields.qrCodeId] = qrCodeId
        }

        if let lastCheckedIn = lastCheckedIn {
            data[FirestoreConstants.ContactFields.lastCheckedIn] = Timestamp(date: lastCheckedIn)
        }

        if let checkInInterval = checkInInterval {
            data[FirestoreConstants.ContactFields.checkInInterval] = checkInInterval
        }

        // Add alert and ping properties
        data[FirestoreConstants.ContactFields.manualAlertActive] = manualAlertActive

        if let manualAlertTimestamp = manualAlertTimestamp {
            data[FirestoreConstants.ContactFields.manualAlertTimestamp] = Timestamp(date: manualAlertTimestamp)
        }

        data[FirestoreConstants.ContactFields.hasIncomingPing] = hasIncomingPing
        data[FirestoreConstants.ContactFields.hasOutgoingPing] = hasOutgoingPing

        if let incomingPingTimestamp = incomingPingTimestamp {
            data[FirestoreConstants.ContactFields.incomingPingTimestamp] = Timestamp(date: incomingPingTimestamp)
        }

        if let outgoingPingTimestamp = outgoingPingTimestamp {
            data[FirestoreConstants.ContactFields.outgoingPingTimestamp] = Timestamp(date: outgoingPingTimestamp)
        }

        return data
    }

    /// Create a Contact from Firestore data
    /// - Parameter data: Dictionary containing contact data from Firestore
    /// - Returns: A new Contact instance, or nil if required data is missing
    static func fromFirestore(_ data: [String: Any], contactId: String) -> Contact? {
        // Extract relationship data
        let isResponder = data[FirestoreConstants.ContactFields.isResponder] as? Bool ?? false
        let isDependent = data[FirestoreConstants.ContactFields.isDependent] as? Bool ?? false

        // Extract user data
        let name = data[FirestoreConstants.ContactFields.name] as? String ?? "Unknown User"

        // Create contact with basic info
        var contact = Contact(
            id: contactId,
            name: name,
            isResponder: isResponder,
            isDependent: isDependent
        )

        // Set relationship properties
        contact.sendPings = data[FirestoreConstants.ContactFields.sendPings] as? Bool ?? true
        contact.receivePings = data[FirestoreConstants.ContactFields.receivePings] as? Bool ?? true
        contact.nickname = data[FirestoreConstants.ContactFields.nickname] as? String
        contact.notes = data[FirestoreConstants.ContactFields.notes] as? String

        // Set timestamps
        if let lastUpdated = data[FirestoreConstants.ContactFields.lastUpdated] as? Timestamp {
            contact.lastUpdated = lastUpdated.dateValue()
        }

        if let addedAt = data[FirestoreConstants.ContactFields.addedAt] as? Timestamp {
            contact.addedAt = addedAt.dateValue()
        }

        // Set cached user data properties

        // Phone number
        if let phoneNumber = data[FirestoreConstants.ContactFields.phoneNumber] as? String, !phoneNumber.isEmpty {
            contact.phoneNumber = phoneNumber
        }

        // Phone region
        if let phoneRegion = data[FirestoreConstants.ContactFields.phoneRegion] as? String, !phoneRegion.isEmpty {
            contact.phoneRegion = phoneRegion
        }

        // Note
        contact.note = data[FirestoreConstants.ContactFields.note] as? String ?? ""

        // QR code ID
        contact.qrCodeId = data[FirestoreConstants.ContactFields.qrCodeId] as? String

        // Last checked in
        if let lastCheckedIn = data[FirestoreConstants.ContactFields.lastCheckedIn] as? Timestamp {
            contact.lastCheckedIn = lastCheckedIn.dateValue()
        }

        // Check-in interval
        if let checkInInterval = data[FirestoreConstants.ContactFields.checkInInterval] as? TimeInterval {
            contact.checkInInterval = checkInInterval
        }

        // Set alert and ping properties
        contact.manualAlertActive = data[FirestoreConstants.ContactFields.manualAlertActive] as? Bool ?? false

        if let manualAlertTimestamp = data[FirestoreConstants.ContactFields.manualAlertTimestamp] as? Timestamp {
            contact.manualAlertTimestamp = manualAlertTimestamp.dateValue()
        }

        contact.hasIncomingPing = data[FirestoreConstants.ContactFields.hasIncomingPing] as? Bool ?? false
        contact.hasOutgoingPing = data[FirestoreConstants.ContactFields.hasOutgoingPing] as? Bool ?? false

        if let incomingPingTimestamp = data[FirestoreConstants.ContactFields.incomingPingTimestamp] as? Timestamp {
            contact.incomingPingTimestamp = incomingPingTimestamp.dateValue()
        }

        if let outgoingPingTimestamp = data[FirestoreConstants.ContactFields.outgoingPingTimestamp] as? Timestamp {
            contact.outgoingPingTimestamp = outgoingPingTimestamp.dateValue()
        }

        return contact
    }
}

/// Feature for managing user contacts
@Reducer
struct ContactsFeature {
    /// Cancellation IDs for long-running effects
    enum CancelID: Hashable {
        case contactsStream
    }

    /// The state of the contacts feature
    struct State: Equatable {
        // MARK: - Contact Data

        /// List of all contacts (both responders and dependents)
        var contacts: IdentifiedArrayOf<Contact> = []

        // MARK: - UI State

        /// Loading state
        var isLoading: Bool = false

        /// Error state
        var error: Error? = nil

        /// Count of non-responsive dependents
        var nonResponsiveDependentsCount: Int = 0

        /// Count of pending pings
        var pendingPingsCount: Int = 0

        // MARK: - Computed Properties

        /// Computed property for responders
        var responders: [Contact] {
            contacts.filter { $0.isResponder }
        }

        /// Computed property for dependents
        var dependents: [Contact] {
            contacts.filter { $0.isDependent }
        }

        /// Custom Equatable implementation to handle Error? property
        static func == (lhs: State, rhs: State) -> Bool {
            lhs.contacts == rhs.contacts &&
            lhs.isLoading == rhs.isLoading &&
            lhs.nonResponsiveDependentsCount == rhs.nonResponsiveDependentsCount &&
            lhs.pendingPingsCount == rhs.pendingPingsCount &&
            (lhs.error != nil) == (rhs.error != nil)
        }
    }

    /// Actions that can be performed on the contacts feature
    enum Action: Equatable {
        // MARK: - Data Loading

        /// Load contacts from Firestore
        case loadContacts
        case loadContactsResponse(TaskResult<[Contact]>)

        /// Stream contacts for real-time updates
        case startContactsStream
        case contactsStreamResponse([Contact])
        case stopContactsStream

        // MARK: - Contact Management

        /// Add a contact
        case addContact(Contact)
        case addContactResponse(TaskResult<Bool>)

        /// Update a contact's roles
        case updateContactRoles(id: String, isResponder: Bool, isDependent: Bool)
        case updateContactRolesResponse(TaskResult<Bool>)

        /// Delete a contact
        case deleteContact(id: String)
        case deleteContactResponse(TaskResult<Bool>)

        // MARK: - Ping Operations

        /// Ping a dependent
        case pingDependent(id: String)
        case pingDependentResponse(TaskResult<Bool>)

        /// Clear a ping for a dependent
        case clearPing(id: String)
        case clearPingResponse(TaskResult<Bool>)

        /// Respond to a ping
        case respondToPing(id: String)
        case respondToPingResponse(TaskResult<Bool>)

        /// Respond to all pings
        case respondToAllPings
        case respondToAllPingsResponse(TaskResult<Bool>)

        // MARK: - User Lookup

        /// Look up a user by QR code
        case lookupUserByQRCode(String)
        case lookupUserByQRCodeResponse(TaskResult<Contact?>)
    }

    /// Dependencies for the contacts feature
    @Dependency(\.contactsClient) var contactsClient

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            // MARK: - Data Loading

            case .loadContacts:
                state.isLoading = true
                return .run { send in
                    do {
                        // Load all contacts at once
                        let contacts = try await contactsClient.loadContacts()
                        await send(.loadContactsResponse(.success(contacts)))
                    } catch {
                        await send(.loadContactsResponse(.failure(error)))
                    }
                }

            case let .loadContactsResponse(result):
                state.isLoading = false
                switch result {
                case let .success(contacts):
                    state.contacts = IdentifiedArray(uniqueElements: contacts)
                    state.nonResponsiveDependentsCount = contacts.filter { $0.isDependent && $0.checkInExpired }.count
                    state.pendingPingsCount = contacts.filter { $0.hasIncomingPing }.count
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }

            case .startContactsStream:
                // Start streaming contacts
                return .run { send in
                    // Get the contacts stream
                    let stream = contactsClient.streamContacts()

                    // Process each update from the stream
                    for await contacts in stream {
                        await send(.contactsStreamResponse(contacts))
                    }
                }
                .cancellable(id: CancelID.contactsStream)

            case let .contactsStreamResponse(contacts):
                // Update state with the latest contacts from the stream
                state.contacts = IdentifiedArray(uniqueElements: contacts)
                state.nonResponsiveDependentsCount = contacts.filter { $0.isDependent && $0.checkInExpired }.count
                state.pendingPingsCount = contacts.filter { $0.hasIncomingPing }.count
                return .none

            case .stopContactsStream:
                // Cancel the contacts stream
                return .cancel(id: CancelID.contactsStream)

            // MARK: - Contact Management

            case let .addContact(contact):
                state.isLoading = true
                return .run { send in
                    let result = await TaskResult {
                        try await contactsClient.addContact(contact)
                    }
                    await send(.addContactResponse(result))
                }

            case let .addContactResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Reload contacts to get the updated list
                    return .send(.loadContacts)
                case let .failure(error):
                    state.error = error
                    return .none
                }

            case let .updateContactRoles(id, isResponder, isDependent):
                state.isLoading = true

                // Update local state immediately for better UX
                if let index = state.contacts.index(id: id) {
                    state.contacts[index].isResponder = isResponder
                    state.contacts[index].isDependent = isDependent
                }

                return .run { send in
                    let result = await TaskResult {
                        try await contactsClient.updateContactRoles(id, isResponder, isDependent)
                    }
                    await send(.updateContactRolesResponse(result))
                }

            case let .updateContactRolesResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Roles were already updated in state when action was dispatched
                    return .none
                case let .failure(error):
                    state.error = error
                    // Reload contacts to revert changes if there was an error
                    return .send(.loadContacts)
                }

            case let .deleteContact(id):
                state.isLoading = true

                // Remove from local state immediately for better UX
                state.contacts.remove(id: id)

                return .run { send in
                    let result = await TaskResult {
                        try await contactsClient.deleteContact(id)
                    }
                    await send(.deleteContactResponse(result))
                }

            case let .deleteContactResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Contact was already removed from state when action was dispatched
                    return .none
                case let .failure(error):
                    state.error = error
                    // Reload contacts to revert changes if there was an error
                    return .send(.loadContacts)
                }

            // MARK: - Ping Operations

            case let .pingDependent(id):
                state.isLoading = true

                // Update local state immediately for better UX
                if let index = state.contacts.index(id: id) {
                    state.contacts[index].hasOutgoingPing = true
                }

                return .run { send in
                    let result = await TaskResult {
                        try await contactsClient.pingDependent(id)
                    }
                    await send(.pingDependentResponse(result))
                }

            case let .pingDependentResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Ping was already updated in state when action was dispatched
                    return .none
                case let .failure(error):
                    state.error = error
                    // Reload contacts to revert changes if there was an error
                    return .send(.loadContacts)
                }

            case let .clearPing(id):
                state.isLoading = true

                // Update local state immediately for better UX
                if let index = state.contacts.index(id: id) {
                    state.contacts[index].hasOutgoingPing = false
                }

                return .run { send in
                    let result = await TaskResult {
                        try await contactsClient.clearPing(id)
                    }
                    await send(.clearPingResponse(result))
                }

            case let .clearPingResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Ping was already cleared in state when action was dispatched
                    return .none
                case let .failure(error):
                    state.error = error
                    // Reload contacts to revert changes if there was an error
                    return .send(.loadContacts)
                }

            case let .respondToPing(id):
                state.isLoading = true

                // Update local state immediately for better UX
                if let index = state.contacts.index(id: id) {
                    state.contacts[index].hasIncomingPing = false
                    state.pendingPingsCount = max(0, state.pendingPingsCount - 1)
                }

                return .run { send in
                    let result = await TaskResult {
                        try await contactsClient.respondToPing(id)
                    }
                    await send(.respondToPingResponse(result))
                }

            case let .respondToPingResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Response was already updated in state when action was dispatched
                    return .none
                case let .failure(error):
                    state.error = error
                    // Reload contacts to revert changes if there was an error
                    return .send(.loadContacts)
                }

            case .respondToAllPings:
                state.isLoading = true

                // Update local state immediately for better UX
                for i in state.contacts.indices where state.contacts[i].hasIncomingPing {
                    state.contacts[i].hasIncomingPing = false
                }
                state.pendingPingsCount = 0

                return .run { send in
                    let result = await TaskResult {
                        try await contactsClient.respondToAllPings()
                    }
                    await send(.respondToAllPingsResponse(result))
                }

            case let .respondToAllPingsResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Responses were already updated in state when action was dispatched
                    return .none
                case let .failure(error):
                    state.error = error
                    // Reload contacts to revert changes if there was an error
                    return .send(.loadContacts)
                }

            // MARK: - User Lookup

            case let .lookupUserByQRCode(code):
                state.isLoading = true
                return .run { send in
                    let result = await TaskResult {
                        try await contactsClient.lookupUserByQRCode(code)
                    }
                    await send(.lookupUserByQRCodeResponse(result))
                }

            case let .lookupUserByQRCodeResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Handle in the view
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }
            }
        }
    }
}
