import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

/// ViewModel for managing user check-in functionality and timing
///
/// This view model is responsible for handling all check-in related operations including:
/// - Managing the user's check-in interval and last check-in time
/// - Calculating check-in expiration times
/// - Handling check-in actions and updates
/// - Managing notification preferences for check-in reminders
///
/// The check-in system allows users to regularly confirm they are safe, and alerts
/// their responders if they fail to check in within the specified interval.
///
/// It is part of the app's MVVM architecture and works alongside other view models
/// like UserProfileViewModel and ContactsViewModel to provide a complete user data management solution.
class CheckInViewModel: ObservableObject {
    // MARK: - Published Properties

    /// User's check-in interval in seconds (default: 24 hours)
    ///
    /// This property defines how long the user has between required check-ins.
    /// It is synchronized with Firestore and can be modified by the user.
    /// The default value is defined in TimeManager.defaultInterval (typically 24 hours).
    /// Values are in seconds to allow for precise timing calculations.
    @Published var checkInInterval: TimeInterval = TimeManager.defaultInterval

    /// Timestamp of the user's last check-in
    ///
    /// This property stores when the user last checked in.
    /// It is used to calculate when the next check-in is due.
    /// It is synchronized with Firestore and updated whenever the user checks in.
    /// The default value is the current date/time when the view model is initialized.
    @Published var lastCheckedIn = Date()

    /// Time in minutes before expiration to send notification (30 or 120)
    ///
    /// This property defines how long before the check-in expires that the user
    /// should receive a notification reminder. The app supports two options:
    /// - 30 minutes before expiration
    /// - 2 hours (120 minutes) before expiration
    /// This preference is synchronized with Firestore.
    @Published var notificationLeadTime: Int = 30

    // MARK: - Computed Properties

    /// Date when the user's check-in expires
    ///
    /// This computed property calculates the exact date and time when the user's
    /// current check-in will expire. It is calculated by adding the check-in interval
    /// to the last check-in time.
    ///
    /// This property is used to:
    /// - Display the expiration time to the user
    /// - Calculate the time remaining until expiration
    /// - Determine if a check-in has expired
    /// - Schedule notification reminders
    var checkInExpiration: Date {
        return TimeManager.shared.calculateExpirationDate(from: lastCheckedIn, interval: checkInInterval)
    }

    /// Formatted string showing time until next check-in
    ///
    /// This computed property provides a human-readable string representing the
    /// time remaining until the check-in expires. The format adapts based on the
    /// amount of time remaining (e.g., "2 days 3 hours", "45 minutes", etc.).
    ///
    /// This property is used in the UI to display the countdown timer.
    /// If the check-in has already expired, it will return a string for 0 time remaining.
    var timeUntilNextCheckIn: String {
        let timeInterval = max(0, checkInExpiration.timeIntervalSince(Date()))
        return TimeManager.shared.formatTimeInterval(timeInterval)
    }

    // MARK: - Initialization

    init() {
        // Try to load user data from Firestore if authenticated
        if AuthenticationService.shared.isAuthenticated {
            loadCheckInData()
        }
    }

    // MARK: - Firestore Integration

    /// Load check-in data from Firestore
    ///
    /// This method retrieves the user's check-in related data from Firestore and updates
    /// the view model properties. It loads the check-in interval, last check-in time,
    /// and notification preferences.
    ///
    /// - Parameter completion: Optional callback that is called when data loading completes.
    ///   The boolean parameter indicates success (true) or failure (false).
    ///
    /// - Note: This method is automatically called during initialization if a user is authenticated.
    /// - Important: This method requires an authenticated user and will fail if no user is signed in.
    func loadCheckInData(completion: ((Bool) -> Void)? = nil) {
        guard AuthenticationService.shared.isAuthenticated else {
            print("CheckInViewModel: ERROR - Cannot load check-in data: No authenticated user")
            completion?(false)
            return
        }

        // Get the current user ID
        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            print("CheckInViewModel: ERROR - Cannot load check-in data: User ID not available")
            completion?(false)
            return
        }

        // Get reference to the user document
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)

        // Get the document
        userRef.getDocument { [weak self] (document: DocumentSnapshot?, error: Error?) in
            guard let self = self else { return }

            if let error = error {
                print("CheckInViewModel: ERROR - Failed to load check-in data: \(error.localizedDescription)")
                completion?(false)
                return
            }

            guard let document = document, document.exists, let userData = document.data() else {
                print("CheckInViewModel: ERROR - No user data found in Firestore")
                completion?(false)
                return
            }

            self.updateFromFirestore(userData: userData)
            completion?(true)
        }
    }

    /// Update the view model with check-in data from Firestore
    ///
    /// This method updates the view model's properties with check-in related values
    /// from a Firestore document. It handles type conversion and safely updates
    /// only the properties that exist in the document.
    /// All updates are performed on the main thread to ensure UI updates are thread-safe.
    ///
    /// - Parameter userData: Dictionary containing user data retrieved from Firestore.
    ///   Expected keys are defined in FirestoreSchema.User.
    ///
    /// - Note: This method specifically looks for check-in related fields:
    ///   - checkInInterval: The time interval between required check-ins
    ///   - lastCheckedIn: The timestamp of the last check-in
    ///   - notify30MinBefore: Whether to notify 30 minutes before expiration
    ///   - notify2HoursBefore: Whether to notify 2 hours before expiration
    func updateFromFirestore(userData: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Update check-in related data
            if let checkInInterval = userData[UserFields.checkInInterval] as? TimeInterval {
                self.checkInInterval = checkInInterval
            }

            if let lastCheckedInTimestamp = userData[UserFields.lastCheckedIn] as? Timestamp {
                self.lastCheckedIn = lastCheckedInTimestamp.dateValue()
            }

            // Update notification preferences
            if let notify30Min = userData[UserFields.notify30MinBefore] as? Bool, notify30Min {
                self.notificationLeadTime = 30
            } else if let notify2Hours = userData[UserFields.notify2HoursBefore] as? Bool, notify2Hours {
                self.notificationLeadTime = 120
            }

            print("CheckInViewModel: Check-in data successfully updated from Firestore")
        }
    }

    /// Updates the user's last check-in time to the current time
    ///
    /// This method is called when the user performs a check-in action. It updates
    /// the lastCheckedIn property to the current time and saves this change to Firestore.
    /// This effectively resets the check-in timer and extends the expiration time
    /// by the full check-in interval.
    ///
    /// - Parameter completion: Optional callback that is called when the update completes.
    ///   The boolean parameter indicates success (true) or failure (false).
    ///   If an error occurs, it will be passed as the second parameter.
    ///
    /// - Note: This method updates the local property immediately and then
    ///   synchronizes with Firestore. If the Firestore update fails, the local
    ///   property will still have been updated.
    /// - Important: This method requires an authenticated user and will fail if no user is signed in.
    func updateLastCheckedIn(completion: ((Bool, Error?) -> Void)? = nil) {
        lastCheckedIn = Date()

        // Save to Firestore
        let updateData: [String: Any] = [
            UserFields.lastCheckedIn: lastCheckedIn,
            UserFields.lastUpdated: FieldValue.serverTimestamp()
        ]

        // Get the current user ID
        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            let error = NSError(domain: "CheckInViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User ID not available"])
            print("CheckInViewModel: ERROR - Failed to update last check-in time: \(error.localizedDescription)")
            completion?(false, error)
            return
        }

        // Get reference to the user document
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)

        // Update the document
        userRef.updateData(updateData) { error in
            if let error = error {
                print("CheckInViewModel: ERROR - Failed to update last check-in time in Firestore: \(error.localizedDescription)")
                completion?(false, error)
                return
            }

            print("CheckInViewModel: Last check-in time successfully updated in Firestore")
            completion?(true, nil)
        }
    }

    /// Sets the notification lead time in minutes
    ///
    /// This method updates the user's preference for when to receive check-in reminder
    /// notifications before the check-in expires. The app supports two options:
    /// - 30 minutes before expiration
    /// - 2 hours (120 minutes) before expiration
    ///
    /// - Parameters:
    ///   - minutes: The lead time in minutes. Must be either 30 or 120.
    ///   - completion: Optional callback that is called when the update completes.
    ///     The boolean parameter indicates success (true) or failure (false).
    ///     If an error occurs, it will be passed as the second parameter.
    ///
    /// - Note: This method updates the local property immediately and then
    ///   synchronizes with Firestore. If the Firestore update fails, the local
    ///   property will still have been updated.
    /// - Important: This method requires an authenticated user and will fail if no user is signed in.
    /// - Important: The minutes parameter should be either 30 or 120. Other values may cause
    ///   unexpected behavior in the notification system.
    func setNotificationLeadTime(_ minutes: Int, completion: ((Bool, Error?) -> Void)? = nil) {
        notificationLeadTime = minutes

        // Save to Firestore
        let updateData: [String: Any] = [
            UserFields.notify30MinBefore: minutes == 30,
            UserFields.notify2HoursBefore: minutes == 120,
            UserFields.lastUpdated: FieldValue.serverTimestamp()
        ]

        // Get the current user ID
        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            let error = NSError(domain: "CheckInViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User ID not available"])
            print("CheckInViewModel: ERROR - Failed to update notification lead time: \(error.localizedDescription)")
            completion?(false, error)
            return
        }

        // Get reference to the user document
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)

        // Update the document
        userRef.updateData(updateData) { error in
            if let error = error {
                print("CheckInViewModel: ERROR - Failed to update notification lead time in Firestore: \(error.localizedDescription)")
                completion?(false, error)
                return
            }

            print("CheckInViewModel: Notification lead time successfully updated in Firestore")
            completion?(true, nil)
        }
    }
}
