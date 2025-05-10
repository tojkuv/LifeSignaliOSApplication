import XCTest
import ComposableArchitecture
@testable import LifeSignal
@testable import LifeSignal.Features.Contacts

/// Tests for the ContactsFeature
final class ContactsFeatureTests: XCTestCase {

    /// Sample contacts for testing
    let sampleContacts = [
        Contact(
            id: "user1",
            name: "John Doe",
            isResponder: true,
            isDependent: false,
            phoneNumber: "+1 (555) 123-4567",
            phoneRegion: "US",
            note: "Friend",
            lastCheckedIn: Date(),
            checkInInterval: 24 * 60 * 60,
            hasIncomingPing: false,
            hasOutgoingPing: false,
            receivePings: true,
            sendPings: true
        ),
        Contact(
            id: "user2",
            name: "Jane Smith",
            isResponder: false,
            isDependent: true,
            phoneNumber: "+1 (555) 987-6543",
            phoneRegion: "US",
            note: "Family",
            lastCheckedIn: Date().addingTimeInterval(-30 * 60 * 60), // 30 hours ago
            checkInInterval: 24 * 60 * 60,
            hasIncomingPing: false,
            hasOutgoingPing: false,
            receivePings: true,
            sendPings: true
        )
    ]

    /// Test loading contacts
    func testLoadContacts() async {
        let store = TestStore(initialState: ContactsFeature.State()) {
            ContactsFeature()
        } withDependencies: {
            $0.contactsClient.loadContacts = { self.sampleContacts }
        }

        await store.send(.loadContacts) {
            $0.isLoading = true
        }

        await store.receive(.loadContactsResponse(.success(self.sampleContacts))) {
            $0.isLoading = false
            $0.contacts = IdentifiedArray(uniqueElements: self.sampleContacts)
            $0.nonResponsiveDependentsCount = 1 // Jane Smith is a dependent with expired check-in
            $0.pendingPingsCount = 0
        }
    }

    /// Test adding a contact
    func testAddContact() async {
        let newContact = Contact(
            id: "user3",
            name: "Bob Johnson",
            isResponder: true,
            isDependent: true,
            phoneNumber: "+1 (555) 555-5555",
            phoneRegion: "US",
            note: "Colleague",
            lastCheckedIn: Date(),
            checkInInterval: 24 * 60 * 60,
            hasIncomingPing: false,
            hasOutgoingPing: false,
            receivePings: true,
            sendPings: true
        )

        let store = TestStore(initialState: ContactsFeature.State()) {
            ContactsFeature()
        } withDependencies: {
            $0.contactsClient.addContact = { _ in true }
            $0.contactsClient.loadContacts = { self.sampleContacts + [newContact] }
        }

        await store.send(.addContact(newContact)) {
            $0.isLoading = true
        }

        await store.receive(.addContactResponse(.success(true))) {
            $0.isLoading = false
        }

        await store.send(.loadContacts) {
            $0.isLoading = true
        }

        await store.receive(.loadContactsResponse(.success(self.sampleContacts + [newContact]))) {
            $0.isLoading = false
            $0.contacts = IdentifiedArray(uniqueElements: self.sampleContacts + [newContact])
            $0.nonResponsiveDependentsCount = 1
            $0.pendingPingsCount = 0
        }
    }

    /// Test updating contact roles
    func testUpdateContactRoles() async {
        let initialState = ContactsFeature.State(contacts: IdentifiedArray(uniqueElements: sampleContacts))

        let store = TestStore(initialState: initialState) {
            ContactsFeature()
        } withDependencies: {
            $0.contactsClient.updateContactRoles = { _, _, _ in true }
        }

        let contactId = "user1"
        let newIsResponder = false
        let newIsDependent = true

        await store.send(.updateContactRoles(id: contactId, isResponder: newIsResponder, isDependent: newIsDependent)) {
            $0.isLoading = true
            if let index = $0.contacts.index(id: contactId) {
                $0.contacts[index].isResponder = newIsResponder
                $0.contacts[index].isDependent = newIsDependent
            }
        }

        await store.receive(.updateContactRolesResponse(.success(true))) {
            $0.isLoading = false
        }
    }

    /// Test deleting a contact
    func testDeleteContact() async {
        let initialState = ContactsFeature.State(contacts: IdentifiedArray(uniqueElements: sampleContacts))

        let store = TestStore(initialState: initialState) {
            ContactsFeature()
        } withDependencies: {
            $0.contactsClient.deleteContact = { _ in true }
        }

        let contactId = "user1"

        await store.send(.deleteContact(id: contactId)) {
            $0.isLoading = true
            $0.contacts.remove(id: contactId)
        }

        await store.receive(.deleteContactResponse(.success(true))) {
            $0.isLoading = false
        }
    }

    /// Test pinging a dependent
    func testPingDependent() async {
        let initialState = ContactsFeature.State(contacts: IdentifiedArray(uniqueElements: sampleContacts))

        let store = TestStore(initialState: initialState) {
            ContactsFeature()
        } withDependencies: {
            $0.contactsClient.pingDependent = { _ in true }
        }

        let dependentId = "user2"

        await store.send(.pingDependent(id: dependentId)) {
            $0.isLoading = true
            if let index = $0.contacts.index(id: dependentId) {
                $0.contacts[index].hasOutgoingPing = true
            }
        }

        await store.receive(.pingDependentResponse(.success(true))) {
            $0.isLoading = false
        }
    }

    /// Test responding to a ping
    func testRespondToPing() async {
        var contacts = sampleContacts
        contacts[0].hasIncomingPing = true

        let initialState = ContactsFeature.State(
            contacts: IdentifiedArray(uniqueElements: contacts),
            pendingPingsCount: 1
        )

        let store = TestStore(initialState: initialState) {
            ContactsFeature()
        } withDependencies: {
            $0.contactsClient.respondToPing = { _ in true }
        }

        let responderId = "user1"

        await store.send(.respondToPing(id: responderId)) {
            $0.isLoading = true
            if let index = $0.contacts.index(id: responderId) {
                $0.contacts[index].hasIncomingPing = false
            }
            $0.pendingPingsCount = 0
        }

        await store.receive(.respondToPingResponse(.success(true))) {
            $0.isLoading = false
        }
    }

    /// Test responding to all pings
    func testRespondToAllPings() async {
        var contacts = sampleContacts
        contacts[0].hasIncomingPing = true
        contacts[1].hasIncomingPing = true

        let initialState = ContactsFeature.State(
            contacts: IdentifiedArray(uniqueElements: contacts),
            pendingPingsCount: 2
        )

        let store = TestStore(initialState: initialState) {
            ContactsFeature()
        } withDependencies: {
            $0.contactsClient.respondToAllPings = { true }
        }

        await store.send(.respondToAllPings) {
            $0.isLoading = true
            for i in $0.contacts.indices where $0.contacts[i].hasIncomingPing {
                $0.contacts[i].hasIncomingPing = false
            }
            $0.pendingPingsCount = 0
        }

        await store.receive(.respondToAllPingsResponse(.success(true))) {
            $0.isLoading = false
        }
    }

    /// Test looking up a user by QR code
    func testLookupUserByQRCode() async {
        let qrCode = "test-qr-code"
        let foundContact = Contact(
            id: "user3",
            name: "Bob Johnson",
            isResponder: true,
            isDependent: false,
            phoneNumber: "+1 (555) 555-5555",
            phoneRegion: "US",
            note: "Colleague",
            lastCheckedIn: Date(),
            checkInInterval: 24 * 60 * 60,
            hasIncomingPing: false,
            hasOutgoingPing: false,
            receivePings: true,
            sendPings: true
        )

        let store = TestStore(initialState: ContactsFeature.State()) {
            ContactsFeature()
        } withDependencies: {
            $0.contactsClient.lookupUserByQRCode = { _ in foundContact }
        }

        await store.send(.lookupUserByQRCode(qrCode)) {
            $0.isLoading = true
        }

        await store.receive(.lookupUserByQRCodeResponse(.success(foundContact))) {
            $0.isLoading = false
        }
    }

    /// Test error handling
    func testErrorHandling() async {
        let testError = NSError(domain: "ContactsFeatureTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])

        let store = TestStore(initialState: ContactsFeature.State()) {
            ContactsFeature()
        } withDependencies: {
            $0.contactsClient.loadContacts = { throw testError }
        }

        await store.send(.loadContacts) {
            $0.isLoading = true
        }

        await store.receive(.loadContactsResponse(.failure(testError))) {
            $0.isLoading = false
            $0.error = testError
        }
    }
}
