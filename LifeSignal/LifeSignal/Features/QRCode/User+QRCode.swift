import Foundation
import UIKit

/// Extension to add QR code related functionality to the User model
extension User {
    /// Generate a new QR code ID
    /// - Returns: A new random QR code ID
    static func generateQRCodeId() -> String {
        return UUID().uuidString
    }
    
    /// Generate a QR code image from the user's QR code ID
    /// - Parameter size: The size of the QR code image
    /// - Returns: A UIImage containing the QR code, or nil if generation fails
    func generateQRCodeImage(size: CGSize = CGSize(width: 200, height: 200)) -> UIImage? {
        guard let data = qrCodeId.data(using: .utf8) else {
            return nil
        }
        
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction
            
            if let outputImage = filter.outputImage {
                let scale = min(size.width, size.height) / outputImage.extent.width
                let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                
                let context = CIContext()
                if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                    return UIImage(cgImage: cgImage)
                }
            }
        }
        
        return nil
    }
    
    /// Update the user's QR code ID
    /// - Returns: The new QR code ID
    mutating func regenerateQRCode() -> String {
        let newQRCodeId = User.generateQRCodeId()
        qrCodeId = newQRCodeId
        lastUpdated = Date()
        return newQRCodeId
    }
}
