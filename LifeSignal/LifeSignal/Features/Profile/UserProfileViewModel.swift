import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

/// ViewModel for managing user profile data and interactions with Firestore
class UserProfileViewModel: BaseViewModel {
    // MARK: - Published Properties
    
    /// User's full name
    @Published var name: String = ""
    
    /// User's phone number (E.164 format)
    @Published var phoneNumber: String = ""
    
    /// User's phone region (ISO country code)
    @Published var phoneRegion: String = "US"
    
    /// User's emergency profile description/note
    @Published var profileDescription: String = ""
    
    /// User's unique QR code identifier
    @Published var qrCodeId: String = ""
    
    /// Flag indicating if user has enabled notifications
    @Published var notificationEnabled: Bool = true
    
    /// Flag indicating if user has completed profile setup
    @Published var profileComplete: Bool = false
    
    /// User's FCM token for push notifications
    @Published var fcmToken: String?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        // Load user data if authenticated
        if AuthenticationService.shared.isAuthenticated {
            loadUserData()
        }
    }
    
    // MARK: - User Data Management
    
    /// Load user data from Firestore
    /// - Parameter completion: Optional callback with success flag
    func loadUserData(completion: ((Bool) -> Void)? = nil) {
        guard let userId = validateAuthentication() else {
            completion?(false)
            return
        }
        
        isLoading = true
        
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreCollections.users).document(userId)
        
        userRef.getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            if let error = error {
                print("Error loading user data: \(error.localizedDescription)")
                self.error = error
                completion?(false)
                return
            }
            
            guard let document = document, document.exists, let data = document.data() else {
                print("User document not found")
                completion?(false)
                return
            }
            
            // Update the view model with the user data
            DispatchQueue.main.async {
                self.name = data[User.Fields.name] as? String ?? ""
                self.phoneNumber = data[User.Fields.phoneNumber] as? String ?? ""
                self.phoneRegion = data[User.Fields.phoneRegion] as? String ?? "US"
                self.profileDescription = data[User.Fields.note] as? String ?? ""
                self.qrCodeId = data[User.Fields.qrCodeId] as? String ?? ""
                self.notificationEnabled = data[User.Fields.notificationEnabled] as? Bool ?? true
                self.profileComplete = data[User.Fields.profileComplete] as? Bool ?? false
                self.fcmToken = data[User.Fields.fcmToken] as? String
            }
            
            print("User data loaded successfully")
            completion?(true)
        }
    }
    
    /// Save user data to Firestore
    /// - Parameter completion: Optional callback with success flag and error
    func saveUserData(completion: ((Bool, Error?) -> Void)? = nil) {
        guard let userId = validateAuthentication() else {
            completion?(false, NSError(domain: "UserProfileViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }
        
        isLoading = true
        
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreCollections.users).document(userId)
        
        // Prepare the data to update
        let userData: [String: Any] = [
            User.Fields.name: name,
            User.Fields.phoneNumber: phoneNumber,
            User.Fields.phoneRegion: phoneRegion,
            User.Fields.note: profileDescription,
            User.Fields.profileComplete: true,
            User.Fields.lastUpdated: Timestamp(date: Date())
        ]
        
        userRef.updateData(userData) { [weak self] error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            if let error = error {
                print("Error saving user data: \(error.localizedDescription)")
                self.error = error
                completion?(false, error)
                return
            }
            
            // Update the profile complete flag
            DispatchQueue.main.async {
                self.profileComplete = true
            }
            
            print("User data saved successfully")
            completion?(true, nil)
        }
    }
    
    /// Update the user's notification settings
    /// - Parameters:
    ///   - enabled: Whether notifications are enabled
    ///   - completion: Optional callback with success flag and error
    func updateNotificationSettings(enabled: Bool, completion: ((Bool, Error?) -> Void)? = nil) {
        guard let userId = validateAuthentication() else {
            completion?(false, NSError(domain: "UserProfileViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }
        
        isLoading = true
        
        // Update the local state immediately for better UX
        notificationEnabled = enabled
        
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreCollections.users).document(userId)
        
        userRef.updateData([
            User.Fields.notificationEnabled: enabled,
            User.Fields.lastUpdated: Timestamp(date: Date())
        ]) { [weak self] error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            if let error = error {
                print("Error updating notification settings: \(error.localizedDescription)")
                self.error = error
                completion?(false, error)
                return
            }
            
            print("Notification settings updated successfully")
            completion?(true, nil)
        }
    }
    
    /// Update the user's FCM token for push notifications
    /// - Parameters:
    ///   - token: The new FCM token
    ///   - completion: Optional callback with success flag and error
    func updateFCMToken(_ token: String?, completion: ((Bool, Error?) -> Void)? = nil) {
        guard let userId = validateAuthentication() else {
            completion?(false, NSError(domain: "UserProfileViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }
        
        // Update the local state
        fcmToken = token
        
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreCollections.users).document(userId)
        
        var updateData: [String: Any] = [
            User.Fields.lastUpdated: Timestamp(date: Date())
        ]
        
        if let token = token {
            updateData[User.Fields.fcmToken] = token
        } else {
            // If token is nil, remove the field
            updateData[User.Fields.fcmToken] = FieldValue.delete()
        }
        
        userRef.updateData(updateData) { error in
            if let error = error {
                print("Error updating FCM token: \(error.localizedDescription)")
                completion?(false, error)
                return
            }
            
            print("FCM token updated successfully")
            completion?(true, nil)
        }
    }
}
