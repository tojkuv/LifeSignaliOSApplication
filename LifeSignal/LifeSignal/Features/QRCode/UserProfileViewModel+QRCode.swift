import Foundation
import FirebaseFirestore
import UIKit

/// Extension to add QR code functionality to the UserProfileViewModel
extension UserProfileViewModel {
    /// Generate a new QR code for the user
    /// - Parameter completion: Optional callback with success flag and error
    func generateNewQRCode(completion: ((Bool, Error?) -> Void)? = nil) {
        guard let userId = validateAuthentication() else {
            completion?(false, NSError(domain: "UserProfileViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }

        isLoading = true

        // Generate a new QR code ID
        let newQRCodeId = QRCodeGenerator.generateQRCodeId()

        // Update the local state immediately for better UX
        qrCodeId = newQRCodeId

        // Update Firestore with the new QR code ID
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreCollections.users).document(userId)

        userRef.updateData([
            User.Fields.qrCodeId: newQRCodeId,
            User.Fields.lastUpdated: Timestamp(date: Date())
        ]) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                print("Error updating QR code ID: \(error.localizedDescription)")

                // Revert the local state
                self.loadUserData()

                DispatchQueue.main.async {
                    self.isLoading = false
                    self.error = error
                }

                completion?(false, error)
                return
            }

            // Now update the QR lookup collection
            self.updateQRLookup(userId: userId, qrCodeId: newQRCodeId) { success, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                }

                if let error = error {
                    print("Error updating QR lookup: \(error.localizedDescription)")
                    self.error = error
                    completion?(false, error)
                    return
                }

                print("QR code updated successfully")
                completion?(true, nil)
            }
        }
    }

    /// Update the QR lookup collection with the new QR code ID
    /// - Parameters:
    ///   - userId: The user ID
    ///   - qrCodeId: The new QR code ID
    ///   - completion: Optional callback with success flag and error
    private func updateQRLookup(userId: String, qrCodeId: String, completion: ((Bool, Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        let qrLookupRef = db.collection(FirestoreCollections.qrLookup).document(userId)

        qrLookupRef.setData([
            "qrCodeId": qrCodeId,
            "updatedAt": Timestamp(date: Date())
        ]) { error in
            if let error = error {
                print("Error updating QR lookup: \(error.localizedDescription)")
                completion?(false, error)
                return
            }

            print("QR lookup updated successfully")
            completion?(true, nil)
        }
    }

    /// Generate a QR code image from the user's QR code ID
    /// - Parameter size: The size of the QR code image
    /// - Returns: A UIImage containing the QR code, or nil if generation fails
    func generateQRCodeImage(size: CGSize = CGSize(width: 200, height: 200)) -> UIImage? {
        guard !qrCodeId.isEmpty else {
            return nil
        }

        return QRCodeGenerator.generateQRCode(from: qrCodeId, size: size)
    }
}
