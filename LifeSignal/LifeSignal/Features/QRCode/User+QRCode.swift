import Foundation
import UIKit

/// Extension to add QR code related functionality to the User model
extension User {
    /// Generate a QR code image from the user's QR code ID
    /// - Parameter size: The size of the QR code image
    /// - Returns: A UIImage containing the QR code, or nil if generation fails
    func generateQRCodeImage(size: CGSize = CGSize(width: 200, height: 200)) -> UIImage? {
        return QRCodeGenerator.generateQRCode(from: qrCodeId, size: size)
    }

    /// Update the user's QR code ID
    /// - Returns: The new QR code ID
    mutating func regenerateQRCode() -> String {
        let newQRCodeId = QRCodeGenerator.generateQRCodeId()
        qrCodeId = newQRCodeId
        lastUpdated = Date()
        return newQRCodeId
    }
}
