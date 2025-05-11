import Foundation
import ComposableArchitecture
import FirebaseFirestore
import FirebaseFunctions
import FirebaseAuth

/// Domain model for a contact in the TCA architecture
struct Contact: Identifiable, Equatable, Codable, Sendable {
    // MARK: - Identifiable Conformance

    /// Unique identifier for the contact (user ID)
    var id: String

    // MARK: - Relationship Properties

    /// Whether this contact is a responder for the user
    var isResponder: Bool

    /// Whether this contact is a dependent of the user
    var isDependent: Bool

    /// User's emergency note
    var emergencyNote: String?

    /// When this contact was last updated
    var lastUpdated: Date = Date()

    /// When this contact was added
    var addedAt: Date = Date()

    // MARK: - Cached User Data Properties

    /// User's full name
    var name: String = "Unknown User"

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

    // MARK: - Additional Properties

    /// User's last check-in time
    var lastCheckedIn: Date?

    /// User's check-in interval in seconds
    var checkInInterval: TimeInterval?

    /// Whether this contact has an incoming ping
    var hasIncomingPing: Bool = false

    /// Whether this contact has an outgoing ping
    var hasOutgoingPing: Bool = false

    // MARK: - Initialization

    /// Initialize a new Contact with essential properties
    init(
        id: String,
        name: String = "Unknown User",
        isResponder: Bool = false,
        isDependent: Bool = false,
        emergencyNote: String? = nil,
        lastCheckedIn: Date? = nil,
        checkInInterval: TimeInterval? = nil,
        hasIncomingPing: Bool = false,
        hasOutgoingPing: Bool = false,
        addedAt: Date = Date(),
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.isResponder = isResponder
        self.isDependent = isDependent
        self.emergencyNote = emergencyNote
        self.lastCheckedIn = lastCheckedIn
        self.checkInInterval = checkInInterval
        self.hasIncomingPing = hasIncomingPing
        self.hasOutgoingPing = hasOutgoingPing
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
            FirestoreConstants.ContactFields.lastUpdated: Timestamp(date: lastUpdated),
            FirestoreConstants.ContactFields.addedAt: Timestamp(date: addedAt)
        ]

        // Add optional fields if they exist
        if let emergencyNote = emergencyNote {
            data[FirestoreConstants.UserFields.emergencyNote] = emergencyNote
        }

        // Add name
        data[FirestoreConstants.UserFields.name] = name

        if let lastCheckedIn = lastCheckedIn {
            data[FirestoreConstants.UserFields.lastCheckedIn] = Timestamp(date: lastCheckedIn)
        }

        if let checkInInterval = checkInInterval {
            data[FirestoreConstants.UserFields.checkInInterval] = checkInInterval
        }

        // Add ping properties
        data[FirestoreConstants.ContactFields.incomingPing] = hasIncomingPing
        data[FirestoreConstants.ContactFields.outgoingPing] = hasOutgoingPing

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
        let name = data[FirestoreConstants.UserFields.name] as? String ?? "Unknown User"

        // Create contact with basic info
        var contact = Contact(
            id: contactId,
            name: name,
            isResponder: isResponder,
            isDependent: isDependent
        )

        // Set relationship properties
        contact.emergencyNote = data[FirestoreConstants.UserFields.emergencyNote] as? String

        // Set timestamps
        if let lastUpdated = data[FirestoreConstants.ContactFields.lastUpdated] as? Timestamp {
            contact.lastUpdated = lastUpdated.dateValue()
        }

        if let addedAt = data[FirestoreConstants.ContactFields.addedAt] as? Timestamp {
            contact.addedAt = addedAt.dateValue()
        }

        // Last checked in
        if let lastCheckedIn = data[FirestoreConstants.UserFields.lastCheckedIn] as? Timestamp {
            contact.lastCheckedIn = lastCheckedIn.dateValue()
        }

        // Check-in interval
        if let checkInInterval = data[FirestoreConstants.UserFields.checkInInterval] as? TimeInterval {
            contact.checkInInterval = checkInInterval
        }

        // Set ping properties
        contact.hasIncomingPing = data[FirestoreConstants.ContactFields.incomingPing] as? Bool ?? false
        contact.hasOutgoingPing = data[FirestoreConstants.ContactFields.outgoingPing] as? Bool ?? false

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

        // MARK: - Add Contact State

        /// QR code or contact ID for adding a new contact
        var newContactId: String = ""

        /// Name for the new contact
        var newContactName: String = ""

        /// Phone number for the new contact
        var newContactPhone: String = ""

        /// Whether the new contact should be a responder
        var newContactIsResponder: Bool = false

        /// Whether the new contact should be a dependent
        var newContactIsDependent: Bool = false

        // MARK: - Computed Properties

        /// Computed property for responders
        var responders: [Contact] {
            contacts.filter { $0.isResponder }
        }

        /// Computed property for dependents
        var dependents: [Contact] {
            contacts.filter { $0.isDependent }
        }
    }

    /// Actions that can be performed on the contacts feature
    enum Action: Equatable, Sendable {
        // MARK: - Data Loading

        /// Load contacts from Firestore
        case loadContacts
        case loadContactsResponse(TaskResult<[Contact]>)

        /// Stream contacts for real-time updates
        case startContactsStream
        case contactsStreamResponse([Contact])
        case stopContactsStream

        // MARK: - Contact Management

        /// Update a contact's roles
        case updateContactRoles(id: String, isResponder: Bool, isDependent: Bool)
        case updateContactRolesResponse(TaskResult<Bool>)

        /// Delete a contact
        case deleteContact(id: String)
        case deleteContactResponse(TaskResult<Bool>)

        // MARK: - Add Contact Operations

        /// Update the new contact ID (QR code)
        case updateNewContactId(String)

        /// Update the new contact name
        case updateNewContactName(String)

        /// Update the new contact phone
        case updateNewContactPhone(String)

        /// Update whether the new contact should be a responder
        case updateNewContactIsResponder(Bool)

        /// Update whether the new contact should be a dependent
        case updateNewContactIsDependent(Bool)

        /// Add a new contact using the QR code
        case addNewContact
        case addNewContactResponse(TaskResult<Bool>)

        /// Dismiss the add contact sheet
        case dismissAddContactSheet

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

        /// Contacts stream feature actions
        case contactsStream(ContactsStreamFeature.Action)
    }

    /// Dependencies for the contacts feature

    @Dependency(\.contactsStreamFeature) var contactsStreamFeature

    /// Helper method to create a Contact from Firestore data
    private func createContactFromData(from contactData: [String: Any], userData: [String: Any], contactId: String) -> Contact? {
        // Extract user info
        let name = userData[FirestoreConstants.UserFields.name] as? String ?? "Unknown"

        // Create a contact with simplified properties
        return Contact(
            id: contactId,
            name: name,
            isResponder: contactData[FirestoreConstants.ContactFields.isResponder] as? Bool ?? false,
            isDependent: contactData[FirestoreConstants.ContactFields.isDependent] as? Bool ?? false,
            emergencyNote: userData[FirestoreConstants.UserFields.emergencyNote] as? String,
            lastCheckedIn: (userData[FirestoreConstants.UserFields.lastCheckedIn] as? Timestamp)?.dateValue(),
            checkInInterval: userData[FirestoreConstants.UserFields.checkInInterval] as? TimeInterval,
            hasIncomingPing: contactData[FirestoreConstants.ContactFields.hasIncomingPing] as? Bool ?? false,
            hasOutgoingPing: contactData[FirestoreConstants.ContactFields.hasOutgoingPing] as? Bool ?? false,
            addedAt: (contactData[FirestoreConstants.ContactFields.addedAt] as? Timestamp)?.dateValue() ?? Date(),
            lastUpdated: (contactData[FirestoreConstants.ContactFields.lastUpdated] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    /// Helper method to load contacts directly from Firebase
    private func loadContactsDirectly() async throws -> [Contact] {
        // Get the current user ID directly from Firebase Auth
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ContactsFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        // Get contacts from the contacts subcollection
        let contactsPath = "\(FirestoreConstants.Collections.users)/\(userId)/\(FirestoreConstants.Collections.contacts)"
        let db = Firestore.firestore()
        let collectionRef = db.collection(contactsPath)
        let querySnapshot = try await collectionRef.getDocuments()
        let contactsSnapshot = querySnapshot.documents

        var contacts: [Contact] = []

        // Process each contact document
        for contactDoc in contactsSnapshot {
            let contactId = contactDoc.documentID
            let contactData = contactDoc.data()

            // Get the contact's user document
            let documentSnapshot = try await db.collection(FirestoreConstants.Collections.users).document(contactId).getDocument()

            guard documentSnapshot.exists, let contactUserData = documentSnapshot.data() else {
                continue // Skip this contact if user document not found
            }

            // Create contact using the simplified helper method
            if let contact = createContactFromData(from: contactData, userData: contactUserData, contactId: contactId) {
                contacts.append(contact)
            }
        }

        return contacts
    }

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            // Handle contacts stream feature actions
            if case let .contactsStream(.contactsUpdated(contacts, _)) = action {
                // Process the updated contacts data
                Task {
                    do {
                        var processedContacts: [Contact] = []

                        // Process each contact document
                        for contactDoc in contacts {
                            let contactId = contactDoc.documentID
                            let contactData = contactDoc.data() ?? [:]

                            // Get the contact's user document
                            let db = Firestore.firestore()
                            let documentSnapshot = try await db.collection(FirestoreConstants.Collections.users).document(contactId).getDocument()

                            guard documentSnapshot.exists, let contactUserData = documentSnapshot.data() else {
                                continue
                            }

                            // Create contact using helper method
                            if let contact = createContactFromData(from: contactData, userData: contactUserData, contactId: contactId) {
                                processedContacts.append(contact)
                            }
                        }

                        // Send the processed contacts
                        await send(.contactsStreamResponse(processedContacts))
                    } catch {
                        print("Error processing contacts: \(error.localizedDescription)")
                    }
                }
                return .none
            } else if case .contactsStream = action {
                return .none
            }

            switch action {
            // MARK: - Data Loading

            case .loadContacts:
                state.isLoading = true
                return .run { send in
                    do {
                        let contacts = try await loadContactsDirectly()
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
                // Start streaming contacts using the ContactsStreamFeature
                return .run { send in
                    do {
                        guard let userId = Auth.auth().currentUser?.uid else {
                            throw NSError(domain: "ContactsFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }

                        // Get the initial contacts data
                        let initialContacts = try await loadContactsDirectly()

                        // Send the initial data
                        await send(.contactsStreamResponse(initialContacts))

                        // Start the contacts stream
                        await send(.contactsStream(.startStream(userId: userId)))
                    } catch {
                        print("Error starting contacts stream: \(error.localizedDescription)")
                    }
                }

            case let .contactsStreamResponse(contacts):
                // Update state with the latest contacts from the stream
                state.contacts = IdentifiedArray(uniqueElements: contacts)
                state.nonResponsiveDependentsCount = contacts.filter { $0.isDependent && $0.checkInExpired }.count
                state.pendingPingsCount = contacts.filter { $0.hasIncomingPing }.count
                return .none

            case .stopContactsStream:
                // Stop the contacts stream
                return .send(.contactsStream(.stopStream))

            // MARK: - Contact Management

            case let .updateContactRoles(id, isResponder, isDependent):
                state.isLoading = true

                // Update local state immediately for better UX
                if let index = state.contacts.index(id: id) {
                    state.contacts[index].isResponder = isResponder
                    state.contacts[index].isDependent = isDependent
                }

                return .run { send in
                    let result = await TaskResult {
                        guard let userId = Auth.auth().currentUser?.uid else {
                            throw NSError(domain: "ContactsFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }

                        // Call the Firebase function to update the contact roles
                        let data: [String: Any] = [
                            "userRefPath": "users/\(userId)",
                            "contactRefPath": "users/\(id)",
                            "isResponder": isResponder,
                            "isDependent": isDependent
                        ]

                        let functions = Functions.functions()
                        let result = try await functions.httpsCallable("updateContactRoles").call(data)

                        guard let _ = result.data as? [String: Any] else {
                            throw FirebaseError.invalidData
                        }

                        return true
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
                        guard let userId = Auth.auth().currentUser?.uid else {
                            throw NSError(domain: "ContactsFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }

                        // Call the Firebase function to delete the contact
                        let data: [String: Any] = [
                            "userARefPath": "users/\(userId)",
                            "userBRefPath": "users/\(id)"
                        ]

                        let functions = Functions.functions()
                        let result = try await functions.httpsCallable("deleteContactRelation").call(data)

                        guard let _ = result.data as? [String: Any] else {
                            throw FirebaseError.invalidData
                        }

                        return true
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
                        guard Auth.auth().currentUser?.uid != nil else {
                            throw NSError(domain: "ContactsFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }

                        // Call the Firebase function to ping the dependent
                        let data: [String: Any] = [
                            "dependentId": id
                        ]

                        let functions = Functions.functions()
                        let result = try await functions.httpsCallable("pingDependent").call(data)

                        guard let _ = result.data as? [String: Any] else {
                            throw FirebaseError.invalidData
                        }

                        return true
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
                        guard let userId = Auth.auth().currentUser?.uid else {
                            throw NSError(domain: "ContactsFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }

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

                        return true
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
                        guard Auth.auth().currentUser?.uid != nil else {
                            throw NSError(domain: "ContactsFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }

                        // Call the Firebase function to respond to the ping
                        let data: [String: Any] = [
                            "responderId": id
                        ]

                        let functions = Functions.functions()
                        let result = try await functions.httpsCallable("respondToPing").call(data)

                        guard let _ = result.data as? [String: Any] else {
                            throw FirebaseError.invalidData
                        }

                        return true
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
                        guard Auth.auth().currentUser?.uid != nil else {
                            throw NSError(domain: "ContactsFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }

                        // Call the Firebase function to respond to all pings
                        let functions = Functions.functions()
                        let result = try await functions.httpsCallable("respondToAllPings").call(nil)

                        guard let _ = result.data as? [String: Any] else {
                            throw FirebaseError.invalidData
                        }

                        return true
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

            // MARK: - Add Contact Operations

            case let .updateNewContactId(id):
                state.newContactId = id
                return .none

            case let .updateNewContactName(name):
                state.newContactName = name
                return .none

            case let .updateNewContactPhone(phone):
                state.newContactPhone = phone
                return .none

            case let .updateNewContactIsResponder(isResponder):
                state.newContactIsResponder = isResponder
                return .none

            case let .updateNewContactIsDependent(isDependent):
                state.newContactIsDependent = isDependent
                return .none

            case .addNewContact:
                state.isLoading = true

                // Ensure at least one role is selected
                guard state.newContactIsResponder || state.newContactIsDependent else {
                    state.isLoading = false
                    state.error = NSError(domain: "ContactsFeature", code: 400, userInfo: [NSLocalizedDescriptionKey: "At least one role must be selected"])
                    return .none
                }

                return .run { [qrCode = state.newContactId, isResponder = state.newContactIsResponder, isDependent = state.newContactIsDependent] send in
                    let result = await TaskResult {
                        guard let userId = Auth.auth().currentUser?.uid else {
                            throw NSError(domain: "ContactsFeature", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        }

                        // Call the Firebase function to add a contact using the QR code
                        // The Firebase function only needs userId, qrCode, isResponder, and isDependent
                        // The name and phone are not needed as they are retrieved from the target user's document
                        let data: [String: Any] = [
                            "userId": userId,
                            "qrCode": qrCode,
                            "isResponder": isResponder,
                            "isDependent": isDependent
                        ]

                        let functions = Functions.functions()
                        let result = try await functions.httpsCallable("addContactRelation").call(data)

                        guard let _ = result.data as? [String: Any] else {
                            throw FirebaseError.invalidData
                        }

                        return true
                    }
                    await send(.addNewContactResponse(result))
                }

            case let .addNewContactResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Reset the add contact form
                    state.newContactId = ""
                    state.newContactName = ""
                    state.newContactPhone = ""
                    state.newContactIsResponder = false
                    state.newContactIsDependent = false

                    // Reload contacts to get the newly added contact
                    return .send(.loadContacts)
                case let .failure(error):
                    state.error = error
                    return .none
                }

            case .dismissAddContactSheet:
                // Reset the add contact form
                state.newContactId = ""
                state.newContactName = ""
                state.newContactPhone = ""
                state.newContactIsResponder = false
                state.newContactIsDependent = false
                return .none
            }
        }
        .ifLet(\.contactsStream, action: /Action.contactsStream) {
            ContactsStreamFeature()
        }
    }
}
