import Foundation
import FirebaseFirestore

/// Extension to add additional data functionality to the UserProfileViewModel
extension UserProfileViewModel {
    
    /// Save user data to Firestore with additional data
    /// - Parameters:
    ///   - additionalData: Additional data to include in the update
    ///   - completion: Optional callback with success flag and error
    func saveUserData(additionalData: [String: Any], completion: ((Bool, Error?) -> Void)? = nil) {
        guard let userId = validateAuthentication() else {
            completion?(false, NSError(domain: "UserProfileViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }
        
        isLoading = true
        
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreCollections.users).document(userId)
        
        // Prepare the data to update
        var userData: [String: Any] = [
            User.Fields.name: name,
            User.Fields.phoneNumber: phoneNumber,
            User.Fields.phoneRegion: phoneRegion,
            User.Fields.note: profileDescription,
            User.Fields.lastUpdated: Timestamp(date: Date())
        ]
        
        // Add the additional data
        for (key, value) in additionalData {
            userData[key] = value
        }
        
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
            
            // Update the profile complete flag if it was set in additionalData
            if let profileComplete = additionalData[User.Fields.profileComplete] as? Bool, profileComplete {
                DispatchQueue.main.async {
                    self.profileComplete = true
                }
            }
            
            print("User data saved successfully")
            completion?(true, nil)
        }
    }
}
