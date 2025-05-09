import Foundation
import Combine
import FirebaseFirestore

/// ViewModel for managing user check-in functionality and timing
class CheckInViewModel: BaseViewModel {
    // MARK: - Published Properties
    
    /// User's check-in interval in seconds (default: 24 hours)
    @Published var checkInInterval: TimeInterval = TimeManager.defaultInterval
    
    /// Timestamp of user's last check-in
    @Published var lastCheckedIn: Date = Date()
    
    /// Flag indicating if user should be notified 30 minutes before check-in expiration
    @Published var notify30MinBefore: Bool = true
    
    /// Flag indicating if user should be notified 2 hours before check-in expiration
    @Published var notify2HoursBefore: Bool = true
    
    /// Computed property for check-in expiration time
    var checkInExpiration: Date {
        return lastCheckedIn.addingTimeInterval(checkInInterval)
    }
    
    /// Computed property for time remaining until check-in expiration
    var timeRemaining: TimeInterval {
        return checkInExpiration.timeIntervalSince(Date())
    }
    
    /// Computed property for formatted time remaining until check-in expiration
    var formattedTimeRemaining: String {
        let timeRemaining = checkInExpiration.timeIntervalSince(Date())
        
        if timeRemaining <= 0 {
            return "Expired"
        }
        
        return TimeManager.shared.formatTimeInterval(timeRemaining)
    }
    
    /// Computed property for progress towards check-in expiration (0.0 to 1.0)
    var checkInProgress: Double {
        let elapsed = Date().timeIntervalSince(lastCheckedIn)
        let progress = elapsed / checkInInterval
        return min(max(progress, 0.0), 1.0)
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupTimers()
    }
    
    // MARK: - Private Methods
    
    /// Set up timers for updating the UI
    private func setupTimers() {
        // Create a timer that fires every second to update the UI
        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                // Force UI update by triggering objectWillChange
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Update the user's last check-in time to now
    /// - Parameter completion: Optional callback with success flag and error
    func updateLastCheckedIn(completion: ((Bool, Error?) -> Void)? = nil) {
        guard let userId = validateAuthentication() else {
            completion?(false, NSError(domain: "CheckInViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }
        
        isLoading = true
        
        // Update the local state immediately for better UX
        lastCheckedIn = Date()
        
        // Update Firestore
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreCollections.users).document(userId)
        
        userRef.updateData([
            UserFields.lastCheckedIn: Timestamp(date: lastCheckedIn),
            UserFields.lastUpdated: Timestamp(date: Date())
        ]) { [weak self] error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("Error updating last check-in: \(error.localizedDescription)")
                    self.error = error
                    completion?(false, error)
                    return
                }
                
                print("Last check-in updated successfully")
                completion?(true, nil)
            }
        }
    }
    
    /// Update the user's check-in interval
    /// - Parameters:
    ///   - interval: The new interval in seconds
    ///   - completion: Optional callback with success flag and error
    func updateCheckInInterval(_ interval: TimeInterval, completion: ((Bool, Error?) -> Void)? = nil) {
        guard let userId = validateAuthentication() else {
            completion?(false, NSError(domain: "CheckInViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }
        
        isLoading = true
        
        // Update the local state immediately for better UX
        checkInInterval = interval
        
        // Update Firestore
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreCollections.users).document(userId)
        
        userRef.updateData([
            UserFields.checkInInterval: interval,
            UserFields.lastUpdated: Timestamp(date: Date())
        ]) { [weak self] error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("Error updating check-in interval: \(error.localizedDescription)")
                    self.error = error
                    completion?(false, error)
                    return
                }
                
                print("Check-in interval updated successfully")
                completion?(true, nil)
            }
        }
    }
    
    /// Update the user's notification preferences
    /// - Parameters:
    ///   - notify30MinBefore: Whether to notify 30 minutes before expiration
    ///   - notify2HoursBefore: Whether to notify 2 hours before expiration
    ///   - completion: Optional callback with success flag and error
    func updateNotificationPreferences(notify30MinBefore: Bool, notify2HoursBefore: Bool, completion: ((Bool, Error?) -> Void)? = nil) {
        guard let userId = validateAuthentication() else {
            completion?(false, NSError(domain: "CheckInViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }
        
        isLoading = true
        
        // Update the local state immediately for better UX
        self.notify30MinBefore = notify30MinBefore
        self.notify2HoursBefore = notify2HoursBefore
        
        // Update Firestore
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreCollections.users).document(userId)
        
        userRef.updateData([
            UserFields.notify30MinBefore: notify30MinBefore,
            UserFields.notify2HoursBefore: notify2HoursBefore,
            UserFields.lastUpdated: Timestamp(date: Date())
        ]) { [weak self] error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("Error updating notification preferences: \(error.localizedDescription)")
                    self.error = error
                    completion?(false, error)
                    return
                }
                
                print("Notification preferences updated successfully")
                completion?(true, nil)
            }
        }
    }
}
