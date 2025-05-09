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
                self.name = data[UserFields.name] as? String ?? ""
                self.phoneNumber = data[UserFields.phoneNumber] as? String ?? ""
                self.phoneRegion = data[UserFields.phoneRegion] as? String ?? "US"
                self.profileDescription = data[UserFields.note] as? String ?? ""
                self.qrCodeId = data[UserFields.qrCodeId] as? String ?? ""
                self.notificationEnabled = data[UserFields.notificationEnabled] as? Bool ?? true
                self.profileComplete = data[UserFields.profileComplete] as? Bool ?? false
                self.fcmToken = data[UserFields.fcmToken] as? String
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
            UserFields.name: name,
            UserFields.phoneNumber: phoneNumber,
            UserFields.phoneRegion: phoneRegion,
            UserFields.note: profileDescription,
            UserFields.profileComplete: true,
            UserFields.lastUpdated: Timestamp(date: Date())
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
            UserFields.notificationEnabled: enabled,
            UserFields.lastUpdated: Timestamp(date: Date())
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
            UserFields.lastUpdated: Timestamp(date: Date())
        ]
        
        if let token = token {
            updateData[UserFields.fcmToken] = token
        } else {
            // If token is nil, remove the field
            updateData[UserFields.fcmToken] = FieldValue.delete()
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
