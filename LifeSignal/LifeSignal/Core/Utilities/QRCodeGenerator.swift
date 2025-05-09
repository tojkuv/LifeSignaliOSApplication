import Foundation
import UIKit
import CoreImage.CIFilterBuiltins

/// Utility class for generating QR codes
class QRCodeGenerator {
    /// Generate a QR code image from a string
    /// - Parameters:
    ///   - string: The string to encode in the QR code
    ///   - size: The size of the QR code image
    /// - Returns: A UIImage containing the QR code, or nil if generation fails
    static func generateQRCode(from string: String, size: CGSize = CGSize(width: 200, height: 200)) -> UIImage? {
        guard !string.isEmpty else {
            return nil
        }
        
        guard let data = string.data(using: .utf8) else {
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
    
    /// Generate a new QR code ID
    /// - Returns: A new random QR code ID
    static func generateQRCodeId() -> String {
        return UUID().uuidString
    }
}
