import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

/// ViewModel for managing user contacts and their relationships
class ContactsViewModel: BaseViewModel {
    // MARK: - Published Properties

    /// Combined list of all contacts (both responders and dependents)
    @Published var contacts: [ContactReference] = []

    /// Dictionary for faster contact lookup by ID
    internal var contactsById: [String: ContactReference] = [:]

    /// Loading state for contacts
    @Published var isLoadingContacts: Bool = false

    /// Error state for contact operations
    @Published var contactError: Error? = nil

    /// Count of non-responsive dependents
    @Published var nonResponsiveDependentsCount: Int = 0

    /// Count of pending pings
    @Published var pendingPingsCount: Int = 0

    // MARK: - Computed Properties

    /// Filtered list of contacts who are responders
    var responders: [ContactReference] {
        contacts.filter { $0.isResponder }
    }

    /// Filtered list of contacts who are dependents
    var dependents: [ContactReference] {
        contacts.filter { $0.isDependent }
    }

    // MARK: - Initialization

    override init() {
        super.init()

        // Initialize with empty contacts array
        contacts = []

        // Initialize counts
        DispatchQueue.main.async {
            self.nonResponsiveDependentsCount = 0
            self.pendingPingsCount = 0
        }

        // Load contacts if user is authenticated
        if AuthenticationService.shared.isAuthenticated {
            loadContactsFromFirestore()
        }

        // Set up notification observers for alerts
        setupAlertNotificationObservers()
    }

    /// Set up notification observers for alerts from dependents
    private func setupAlertNotificationObservers() {
        // Observer for when a dependent sends an alert
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DependentAlertReceived"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let dependentId = userInfo["dependentId"] as? String else {
                return
            }

            // Refresh contacts from Firestore to get the latest alert status
            self.loadContactsFromFirestore { success in
                if success {
                    print("Contacts refreshed after receiving alert from dependent: \(dependentId)")

                    // Update the UI
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshDependentsView"), object: nil)
                }
            }
        }

        // Observer for when a dependent cancels an alert
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DependentAlertCanceled"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let dependentId = userInfo["dependentId"] as? String else {
                return
            }

            // Refresh contacts from Firestore to get the latest alert status
            self.loadContactsFromFirestore { success in
                if success {
                    print("Contacts refreshed after dependent canceled alert: \(dependentId)")

                    // Update the UI
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshDependentsView"), object: nil)
                }
            }
        }
    }

    // MARK: - Helper Methods

    /// Get a contact by ID
    /// - Parameter id: The contact ID (Firestore document ID)
    /// - Returns: The ContactReference object if found, nil if no contact exists with the given ID
    func getContact(by id: String) -> ContactReference? {
        return contactsById[id]
    }

    /// Posts notifications to refresh UI views
    private func postUIRefreshNotifications() {
        NotificationCenter.default.post(name: NSNotification.Name("RefreshDependentsView"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("RefreshRespondersView"), object: nil)
    }

    /// Updates a contact in the local contacts array and dictionary
    /// - Parameters:
    ///   - contact: The contact to update
    ///   - updateAction: Optional closure to modify the contact before updating
    ///   - notifyChanges: Whether to post notifications about the change
    /// - Returns: True if the contact was found and updated, false otherwise
    @discardableResult
    func updateLocalContact(_ contact: ContactReference, updateAction: ((inout ContactReference) -> Void)? = nil, notifyChanges: Bool = true) -> Bool {
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            var updatedContact = contacts[index]

            // Apply the update action if provided
            updateAction?(&updatedContact)

            // Update the contact in the array
            contacts[index] = updatedContact

            // Update the contact in the dictionary
            contactsById[updatedContact.id] = updatedContact

            // Post notifications to refresh the UI if requested
            if notifyChanges {
                postUIRefreshNotifications()
            }

            return true
        }

        return false
    }
}
