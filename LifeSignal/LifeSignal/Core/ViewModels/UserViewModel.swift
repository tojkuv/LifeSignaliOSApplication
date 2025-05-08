import Foundation
import Combine
import FirebaseFirestore

/// ViewModel for managing user data and contacts
class UserViewModel: ObservableObject {
    // MARK: - Published Properties

    /// User's full name
    @Published var name = "First Last"

    /// User's phone number
    @Published var phone: String = ""

    /// User's unique QR code identifier
    @Published var qrCodeId = UUID().uuidString

    /// User's check-in interval in seconds (default: 24 hours)
    @Published var checkInInterval: TimeInterval = TimeManager.defaultInterval

    /// Timestamp of the user's last check-in
    @Published var lastCheckedIn = Date()

    /// Time in minutes before expiration to send notification (30 or 120)
    @Published var notificationLeadTime: Int = 30

    /// Combined list of all contacts
    @Published var contacts: [Contact] = [] {
        didSet {
            // Update counts when contacts change
            updateNonResponsiveDependentsCount()
            updatePendingPingsCount()
        }
    }

    /// Computed property to get responders
    var responders: [Contact] {
        contacts.filter { $0.isResponder }
    }

    /// Computed property to get dependents
    var dependents: [Contact] {
        contacts.filter { $0.isDependent }
    }

    /// Count of non-responsive dependents
    @Published var nonResponsiveDependentsCount: Int = 0

    /// Count of pending pings
    @Published var pendingPingsCount: Int = 0

    /// User's emergency profile description
    @Published var profileDescription: String = "I have a severe peanut allergy - EpiPen is always in my backpack's front pocket."

    /// Alert toggle state for HomeView
    @Published var sendAlertActive: Bool = false

    /// Flag indicating if user data has been loaded from Firestore
    @Published var isDataLoaded: Bool = false

    // MARK: - Computed Properties

    /// Date when the user's check-in expires
    var checkInExpiration: Date {
        return TimeManager.shared.calculateExpirationDate(from: lastCheckedIn, interval: checkInInterval)
    }

    /// Formatted string showing time until next check-in
    var timeUntilNextCheckIn: String {
        let timeInterval = max(0, checkInExpiration.timeIntervalSince(Date()))
        return TimeManager.shared.formatTimeInterval(timeInterval)
    }

    // MARK: - Initialization

    init() {
        // Generate a random QR code ID for the user
        qrCodeId = UUID().uuidString

        // Create sample contacts (both responders and dependents)
        contacts = createSampleContacts()

        // Safely update counts after initialization
        DispatchQueue.main.async {
            self.updateNonResponsiveDependentsCount()
            self.updatePendingPingsCount()
        }
    }

    // MARK: - Firestore Integration

    /// Load user data from Firestore
    /// - Parameter completion: Optional callback when data is loaded
    func loadUserData(completion: ((Bool) -> Void)? = nil) {
        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            print("Cannot load user data: No authenticated user")
            completion?(false)
            return
        }

        UserService.shared.getCurrentUserData { [weak self] userData, error in
            guard let self = self else { return }

            if let error = error {
                print("Error loading user data: \(error.localizedDescription)")
                completion?(false)
                return
            }

            if let userData = userData {
                self.updateFromFirestore(userData: userData)
                completion?(true)
            } else {
                print("No user data found")
                completion?(false)
            }
        }
    }

    /// Update the view model with data from Firestore
    /// - Parameter userData: The user data from Firestore
    func updateFromFirestore(userData: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Update basic user information
            if let name = userData["name"] as? String {
                self.name = name
            }

            if let phone = userData["phoneNumber"] as? String {
                self.phone = phone
            }

            if let qrCodeId = userData["qrCodeId"] as? String {
                self.qrCodeId = qrCodeId
            }

            if let note = userData["note"] as? String {
                self.profileDescription = note
            }

            // Update check-in related data
            if let checkInInterval = userData["checkInInterval"] as? TimeInterval {
                self.checkInInterval = checkInInterval
            }

            if let lastCheckedInTimestamp = userData["lastCheckedIn"] as? Timestamp {
                self.lastCheckedIn = lastCheckedInTimestamp.dateValue()
            }

            // Update notification preferences
            if let notify30Min = userData["notify30MinBefore"] as? Bool, notify30Min {
                self.notificationLeadTime = 30
            } else if let notify2Hours = userData["notify2HoursBefore"] as? Bool, notify2Hours {
                self.notificationLeadTime = 120
            }

            // Mark data as loaded
            self.isDataLoaded = true

            print("User data updated from Firestore")
        }
    }

    /// Save user data to Firestore
    /// - Parameters:
    ///   - data: Additional data to save
    ///   - completion: Optional callback with success flag and error
    func saveUserData(additionalData: [String: Any]? = nil, completion: ((Bool, Error?) -> Void)? = nil) {
        guard AuthenticationService.shared.isAuthenticated else {
            completion?(false, NSError(domain: "UserViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }

        // Create base user data
        var userData: [String: Any] = [
            "name": name,
            "note": profileDescription,
            "qrCodeId": qrCodeId,
            "checkInInterval": checkInInterval,
            "lastCheckedIn": lastCheckedIn,
            "notify30MinBefore": notificationLeadTime == 30,
            "notify2HoursBefore": notificationLeadTime == 120,
            "lastUpdated": FieldValue.serverTimestamp()
        ]

        // Add any additional data
        if let additionalData = additionalData {
            for (key, value) in additionalData {
                userData[key] = value
            }
        }

        // Save to Firestore
        UserService.shared.updateCurrentUserData(data: userData) { success, error in
            if let error = error {
                print("Error saving user data: \(error.localizedDescription)")
                completion?(false, error)
                return
            }

            print("User data saved to Firestore")
            completion?(true, nil)
        }
    }

    /// Creates sample contacts for demo purposes (both responders and dependents)
    private func createSampleContacts() -> [Contact] {
        // Combine sample responders and dependents
        let sampleResponders = createSampleResponders()
        let sampleDependents = createSampleDependents()

        return sampleResponders + sampleDependents
    }

    /// Creates sample responders for demo purposes
    private func createSampleResponders() -> [Contact] {
        let timeManager = TimeManager.shared

        return [
            // 1. Regular responder with standard interval (recently checked in)
            Contact(
                name: "Sarah Chen",
                phone: "555-123-4567",
                note: "Emergency contact for my elderly father. I'm a nurse at Memorial Hospital and work day shifts. My roommate Alex (555-888-2222) has a spare key to my apartment. I have a dog that needs walking twice daily.",
                qrCodeId: UUID().uuidString,
                isResponder: true,
                isDependent: false,
                lastCheckIn: timeManager.createPastDate(hoursAgo: 1),
                interval: TimeManager.defaultInterval,
                addedAt: timeManager.createPastDate(hoursAgo: 28),
                hasIncomingPing: false,
                hasOutgoingPing: false
            ),

            // 2. Responder with shorter interval (checked in a while ago)
            Contact(
                name: "James Wilson",
                phone: "555-987-6543",
                note: "I'm a park ranger at Redwood National Park. If I don't respond, contact the ranger station at 555-444-3333. I have a medical condition that requires daily medication. My sister Elaine (555-777-8888) has a key to my cabin.",
                qrCodeId: UUID().uuidString,
                isResponder: true,
                isDependent: false,
                lastCheckIn: timeManager.createPastDate(hoursAgo: 8),
                interval: 12 * TimeManager.TimeUnits.hour,
                addedAt: timeManager.createPastDate(hoursAgo: 45),
                hasIncomingPing: false,
                hasOutgoingPing: false
            ),

            // 3. Responder with incoming ping (we've pinged them)
            Contact(
                name: "Olivia Martinez",
                phone: "555-555-5555",
                note: "I live alone and work as a freelance photographer. I often go on solo hiking trips to remote locations. My emergency contacts are my brother David (555-222-1111) and my neighbor Mrs. Johnson (555-333-4444). I have a cat named Luna who needs feeding.",
                qrCodeId: UUID().uuidString,
                isResponder: true,
                isDependent: false,
                lastCheckIn: timeManager.createPastDate(hoursAgo: 3),
                interval: 36 * TimeManager.TimeUnits.hour,
                addedAt: timeManager.createPastDate(hoursAgo: 22),
                hasIncomingPing: false,
                hasOutgoingPing: true,
                outgoingPingTimestamp: timeManager.createPastDate(hoursAgo: 0.1)
            ),

            // 4. Responder who has pinged us (incoming ping)
            Contact(
                name: "Daniel Kim",
                phone: "555-444-3333",
                note: "I'm a mountain guide who frequently leads expeditions. When not on trips, I work from my home office. My roommate Chris (555-666-7777) knows my schedule. I have a severe allergy to bee stings and carry an EpiPen in my backpack.",
                qrCodeId: UUID().uuidString,
                isResponder: true,
                isDependent: false,
                lastCheckIn: timeManager.createPastDate(hoursAgo: 5),
                interval: TimeManager.defaultInterval,
                addedAt: timeManager.createPastDate(hoursAgo: 60),
                hasIncomingPing: true,
                hasOutgoingPing: false,
                incomingPingTimestamp: timeManager.createPastDate(hoursAgo: 0.3)
            ),

            // 5. Responder who is both a responder and dependent (dual role)
            Contact(
                name: "Emma Rodriguez",
                phone: "555-111-2222",
                note: "I'm both a caregiver and someone who needs occasional check-ins. I have type 1 diabetes and live alone. My medical information is in a red folder on my refrigerator. My sister Maria (555-999-8888) checks on me regularly.",
                qrCodeId: UUID().uuidString,
                isResponder: true,
                isDependent: true,
                lastCheckIn: timeManager.createPastDate(hoursAgo: 10),
                interval: 48 * TimeManager.TimeUnits.hour,
                addedAt: timeManager.createPastDate(hoursAgo: 75),
                hasIncomingPing: false,
                hasOutgoingPing: false
            )
        ]
    }

    /// Creates sample dependents for demo purposes
    private func createSampleDependents() -> [Contact] {
        let timeManager = TimeManager.shared

        return [
            // 1. Manual alert active (recent) - HIGHEST PRIORITY
            Contact(
                name: "Robert Taylor",
                phone: "555-222-0001",
                note: "I'm a solo backpacker who frequently goes on multi-day trips. I have asthma and carry an inhaler at all times. My emergency contact is my brother Michael (555-333-4444). My car is usually parked at the trailhead - blue Honda CRV license ABC-123.",
                qrCodeId: UUID().uuidString,
                isResponder: false,
                isDependent: true,
                lastCheckIn: timeManager.createPastDate(hoursAgo: 1),
                interval: TimeManager.defaultInterval,
                addedAt: timeManager.createPastDate(hoursAgo: 33),
                manualAlertActive: true,
                manualAlertTimestamp: timeManager.createPastDate(hoursAgo: 0.05),
                hasIncomingPing: false,
                hasOutgoingPing: false
            ),

            // 2. Not responsive (recent expiration) - HIGH PRIORITY
            Contact(
                name: "Sophia Garcia",
                phone: "555-222-0003",
                note: "I live alone and work as a night shift nurse. I have a heart condition and take medication daily. My spare key is with the building manager (555-777-8888). My sister Lisa (555-666-9999) should be contacted in emergencies.",
                qrCodeId: UUID().uuidString,
                isResponder: false,
                isDependent: true,
                lastCheckIn: timeManager.createPastDate(hoursAgo: 25),
                interval: TimeManager.defaultInterval,
                addedAt: timeManager.createPastDate(hoursAgo: 28),
                hasIncomingPing: false,
                hasOutgoingPing: false
            ),

            // 3. Never checked in (not responsive) - HIGH PRIORITY
            Contact(
                name: "William Johnson",
                phone: "555-222-0005",
                note: "I'm a wildlife photographer who often works in remote areas. I have a GPS tracker in my backpack. My emergency contacts are my partner Sam (555-444-3333) and my father (555-888-7777). I have no known medical conditions.",
                qrCodeId: UUID().uuidString,
                isResponder: false,
                isDependent: true,
                lastCheckIn: nil,
                interval: TimeManager.defaultInterval,
                addedAt: timeManager.createPastDate(hoursAgo: 22),
                hasIncomingPing: false,
                hasOutgoingPing: false
            ),

            // 4. Recently checked in (responsive) - NORMAL PRIORITY
            Contact(
                name: "Ava Williams",
                phone: "555-222-0006",
                note: "I'm a graduate student who lives alone. I have severe food allergies (peanuts, shellfish). My EpiPen is in the medicine cabinet. My roommate is usually home after 6 PM. My parents can be reached at 555-111-2222 in emergencies.",
                qrCodeId: UUID().uuidString,
                isResponder: false,
                isDependent: true,
                lastCheckIn: timeManager.createPastDate(hoursAgo: 0.2),
                interval: TimeManager.defaultInterval,
                addedAt: timeManager.createPastDate(hoursAgo: 19),
                hasIncomingPing: false,
                hasOutgoingPing: false
            ),

            // 5. Pinged dependent (we've pinged them) - MEDIUM PRIORITY
            Contact(
                name: "Noah Thompson",
                phone: "555-222-0007",
                note: "I work as a forest ranger and often patrol remote areas alone. My work truck is a white Ford Ranger with Forest Service logos. My supervisor can be reached at 555-444-5555. I have a service dog named Rex who is always with me.",
                qrCodeId: UUID().uuidString,
                isResponder: false,
                isDependent: true,
                lastCheckIn: timeManager.createPastDate(hoursAgo: 1),
                interval: TimeManager.defaultInterval,
                addedAt: timeManager.createPastDate(hoursAgo: 15),
                hasIncomingPing: false,
                hasOutgoingPing: true,
                outgoingPingTimestamp: timeManager.createPastDate(hoursAgo: 0.05)
            ),

            // 6. Dependent with custom interval (longer) - NORMAL PRIORITY
            Contact(
                name: "Isabella Clark",
                phone: "555-222-0008",
                note: "I'm a travel writer who frequently visits remote locations. I check in weekly when on assignment. My editor knows my itinerary (555-999-1111). I have a prescription for high blood pressure medication that I take daily.",
                qrCodeId: UUID().uuidString,
                isResponder: false,
                isDependent: true,
                lastCheckIn: timeManager.createPastDate(hoursAgo: 36),
                interval: 72 * TimeManager.TimeUnits.hour, // 3-day interval
                addedAt: timeManager.createPastDate(hoursAgo: 100),
                hasIncomingPing: false,
                hasOutgoingPing: false
            ),

            // 7. Dependent with custom interval (shorter) - NORMAL PRIORITY
            Contact(
                name: "Ethan Brooks",
                phone: "555-222-0009",
                note: "I have a medical condition that requires frequent monitoring. I live with my elderly mother who has dementia. Our neighbor Mrs. Wilson (555-333-2222) checks on us daily. Home health nurse visits on Tuesdays and Thursdays.",
                qrCodeId: UUID().uuidString,
                isResponder: false,
                isDependent: true,
                lastCheckIn: timeManager.createPastDate(hoursAgo: 3),
                interval: 6 * TimeManager.TimeUnits.hour, // 6-hour interval
                addedAt: timeManager.createPastDate(hoursAgo: 50),
                hasIncomingPing: false,
                hasOutgoingPing: false
            ),

            // 8. Dependent who has pinged us (incoming ping) - MEDIUM PRIORITY
            Contact(
                name: "Mia Anderson",
                phone: "555-222-0010",
                note: "I'm a solo hiker who frequently explores national parks. I always leave my itinerary with the park rangers. My emergency contact is my partner Jordan (555-777-6666). I have no known medical conditions but am allergic to penicillin.",
                qrCodeId: UUID().uuidString,
                isResponder: false,
                isDependent: true,
                lastCheckIn: timeManager.createPastDate(hoursAgo: 12),
                interval: TimeManager.defaultInterval,
                addedAt: timeManager.createPastDate(hoursAgo: 40),
                hasIncomingPing: true,
                hasOutgoingPing: false,
                incomingPingTimestamp: timeManager.createPastDate(hoursAgo: 0.4)
            )
        ]
    }

    // MARK: - User Actions

    /// Generates a new QR code ID for the user
    func generateNewQRCode() {
        qrCodeId = UUID().uuidString
    }

    /// Updates the user's last check-in time to now
    func updateLastCheckedIn() {
        lastCheckedIn = Date()
    }

    /// Sets the notification lead time in minutes
    /// - Parameter minutes: The lead time in minutes (30 or 120)
    func setNotificationLeadTime(_ minutes: Int) {
        notificationLeadTime = minutes
    }

    // MARK: - Contact Management

    /// Adds a new contact with the given QR code ID and role
    /// - Parameters:
    ///   - qrCodeId: The QR code ID of the contact
    ///   - isResponder: True if the contact is a responder, false if dependent
    func addContact(qrCodeId: String, isResponder: Bool) {
        // Create a new contact with safe default values
        let newContact = Contact.createDefault(
            name: "Jane Doe",
            phone: "555-123-4567",
            note: "I live alone and work remotely. If I don't respond, my neighbor Tom (555-999-1234) has a spare key. I have a cat that needs feeding if I'm away. I have a peanut allergy and keep an EpiPen in my kitchen drawer.",
            qrCodeId: qrCodeId,
            isResponder: isResponder,
            isDependent: !isResponder
        )

        // Add the contact to the combined list
        contacts.append(newContact)
    }

    /// Removes a contact from the contacts list
    /// - Parameter contact: The contact to remove
    func removeContact(_ contact: Contact) {
        print("Before removal - Responders count: \(responders.count), Dependents count: \(dependents.count)")

        // Remove the contact from the combined list
        contacts.removeAll { $0.id == contact.id }
        print("Removed contact: \(contact.name)")

        print("After removal - Responders count: \(responders.count), Dependents count: \(dependents.count)")

        // Post notification to refresh the lists views
        NotificationCenter.default.post(name: NSNotification.Name("RefreshDependentsView"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("RefreshRespondersView"), object: nil)
    }

    /// Updates a contact's role in the contacts list
    /// - Parameters:
    ///   - contact: The contact to update
    ///   - wasResponder: Whether the contact was previously a responder
    ///   - wasDependent: Whether the contact was previously a dependent
    func updateContactRole(contact: Contact, wasResponder: Bool, wasDependent: Bool) {
        print("\n==== UPDATE CONTACT ROLE ====\nBefore update - Responders count: \(responders.count), Dependents count: \(dependents.count)")
        print("Updating contact role: \(contact.name) (ID: \(contact.id))")
        print("  Was responder: \(wasResponder), is now: \(contact.isResponder)")
        print("  Was dependent: \(wasDependent), is now: \(contact.isDependent)")

        // Simply update the contact in the combined list
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            contacts[index] = contact
            print("  Updated contact in the contacts list")
        } else {
            // If not found (shouldn't happen), add it
            contacts.append(contact)
            print("  Added contact to the contacts list (not found but should be there)")
        }

        // Print the current state of the lists
        print("After update - Responders count: \(responders.count), Dependents count: \(dependents.count)")
        print("==== END UPDATE CONTACT ROLE ====\n")

        // Post notification to refresh the lists views
        NotificationCenter.default.post(name: NSNotification.Name("RefreshDependentsView"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("RefreshRespondersView"), object: nil)
    }

    // MARK: - Status Updates

    /// Updates the count of non-responsive dependents
    func updateNonResponsiveDependentsCount() {
        // Count dependents who are either non-responsive or have a manual alert active
        let count = contacts.filter { contact in
            // Only count dependents
            guard contact.isDependent else { return false }

            // If manual alert is active, always count as non-responsive
            if contact.manualAlertActive { return true }

            // Use the contact's isNonResponsive computed property
            return contact.isNonResponsive
        }.count

        nonResponsiveDependentsCount = count
    }

    // MARK: - Ping Methods

    /// Send a ping to a responder
    /// - Parameter responder: The responder to ping
    func sendPing(to responder: Contact) {
        let now = Date()

        // Find the contact in the contacts list
        if let index = contacts.firstIndex(where: { $0.id == responder.id }) {
            // Set outgoing ping for the contact
            var updatedContact = contacts[index]
            updatedContact.hasOutgoingPing = true
            updatedContact.outgoingPingTimestamp = now
            contacts[index] = updatedContact
            print("Sent ping to contact: \(updatedContact.name)")

            // Post notifications to refresh the UI
            NotificationCenter.default.post(name: NSNotification.Name("RefreshDependentsView"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("RefreshRespondersView"), object: nil)
        }

        updatePendingPingsCount()
    }

    /// Send a ping to a dependent
    /// - Parameter dependent: The dependent to ping
    func pingDependent(_ dependent: Contact) {
        // This is now just an alias for sendPing for consistency
        sendPing(to: dependent)
    }

    /// Respond to a ping from a responder
    /// - Parameter responder: The responder whose ping to respond to
    func respondToPing(from responder: Contact) {
        // Find the contact in the contacts list
        if let index = contacts.firstIndex(where: { $0.id == responder.id }) {
            // Clear incoming ping
            var updatedContact = contacts[index]
            updatedContact.hasIncomingPing = false
            updatedContact.incomingPingTimestamp = nil
            contacts[index] = updatedContact
            print("Responded to ping from contact: \(updatedContact.name)")

            // Post notifications to refresh the UI
            NotificationCenter.default.post(name: NSNotification.Name("RefreshDependentsView"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("RefreshRespondersView"), object: nil)
        }

        updatePendingPingsCount()
    }

    /// Clear an outgoing ping for a dependent
    /// - Parameter dependent: The dependent whose ping to clear
    func clearPing(for dependent: Contact) {
        // This is now just an alias for clearOutgoingPing for consistency
        clearOutgoingPing(for: dependent)
    }

    /// Clear an outgoing ping for a contact
    /// - Parameter contact: The contact whose ping to clear
    func clearOutgoingPing(for contact: Contact) {
        // Find the contact in the contacts list
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            // Clear outgoing ping
            var updatedContact = contacts[index]
            updatedContact.hasOutgoingPing = false
            updatedContact.outgoingPingTimestamp = nil
            contacts[index] = updatedContact
            print("Cleared outgoing ping for contact: \(updatedContact.name)")

            // Post notifications to refresh the UI
            NotificationCenter.default.post(name: NSNotification.Name("RefreshDependentsView"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("RefreshRespondersView"), object: nil)
        }
    }

    /// Respond to all pending pings
    func respondToAllPings() {
        // Create a copy of the contacts array to avoid modifying while iterating
        var updatedContacts = contacts

        // Clear incoming pings for all responders
        for i in 0..<updatedContacts.count {
            if updatedContacts[i].isResponder && updatedContacts[i].hasIncomingPing {
                updatedContacts[i].hasIncomingPing = false
                updatedContacts[i].incomingPingTimestamp = nil
            }
        }

        // Update the contacts array
        contacts = updatedContacts

        updatePendingPingsCount()

        // Post notifications to refresh the UI
        NotificationCenter.default.post(name: NSNotification.Name("RefreshDependentsView"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("RefreshRespondersView"), object: nil)
    }

    /// Update the count of pending pings
    func updatePendingPingsCount() {
        pendingPingsCount = contacts.filter { $0.isResponder && $0.hasIncomingPing }.count
    }
}