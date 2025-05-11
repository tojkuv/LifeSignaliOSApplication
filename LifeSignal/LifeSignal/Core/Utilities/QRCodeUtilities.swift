import UIKit
import CoreImage.CIFilterBuiltins

/// Utilities for QR code generation and processing
enum QRCodeUtilities {
    /// Generate a QR code image from a string
    /// - Parameters:
    ///   - content: The string content to encode in the QR code
    ///   - size: The desired size of the QR code image
    /// - Returns: A UIImage containing the QR code, or nil if generation failed
    static func generateQRCode(from content: String, size: CGFloat) -> UIImage? {
        guard !content.isEmpty else {
            return nil
        }

        guard let data = content.data(using: .utf8) else {
            return nil
        }

        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction

            if let outputImage = filter.outputImage {
                let scale = min(size, size) / outputImage.extent.width
                let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

                let context = CIContext()
                if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                    return UIImage(cgImage: cgImage)
                }
            }
        }

        return nil
    }
}
