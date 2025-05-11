import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

/// A SwiftUI view for displaying a QR code
struct QRCodeView: View {
    /// The QR code ID to display
    let qrCodeId: String
    
    /// The size of the QR code
    let size: CGFloat
    
    /// The background color of the QR code
    let backgroundColor: Color
    
    /// The foreground color of the QR code
    let foregroundColor: Color
    
    /// Initialize with QR code ID and size
    /// - Parameters:
    ///   - qrCodeId: The QR code ID to display
    ///   - size: The size of the QR code
    ///   - backgroundColor: The background color of the QR code (default: white)
    ///   - foregroundColor: The foreground color of the QR code (default: black)
    init(
        qrCodeId: String,
        size: CGFloat,
        backgroundColor: Color = .white,
        foregroundColor: Color = .black
    ) {
        self.qrCodeId = qrCodeId
        self.size = size
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }
    
    var body: some View {
        Image(uiImage: generateQRCode(from: qrCodeId))
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .background(backgroundColor)
            .cornerRadius(8)
    }
    
    /// Generate a QR code image from a string
    /// - Parameter string: The string to encode in the QR code
    /// - Returns: A UIImage containing the QR code
    private func generateQRCode(from string: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(string.utf8)
        filter.correctionLevel = "H" // High error correction
        
        if let outputImage = filter.outputImage {
            let scale = size / outputImage.extent.width
            let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                let uiImage = UIImage(cgImage: cgImage)
                
                // If using default colors (white background, black foreground), return as is
                if backgroundColor == .white && foregroundColor == .black {
                    return uiImage
                }
                
                // Otherwise, apply custom colors
                return applyColors(to: uiImage)
            }
        }
        
        return UIImage(systemName: "qrcode") ?? UIImage()
    }
    
    /// Apply custom colors to a QR code image
    /// - Parameter image: The QR code image to colorize
    /// - Returns: A colorized QR code image
    private func applyColors(to image: UIImage) -> UIImage {
        let ciImage = CIImage(image: image)
        
        guard let colorFilter = CIFilter(name: "CIFalseColor") else {
            return image
        }
        
        colorFilter.setValue(ciImage, forKey: kCIInputImageKey)
        colorFilter.setValue(CIColor(color: UIColor(foregroundColor)), forKey: "inputColor0")
        colorFilter.setValue(CIColor(color: UIColor(backgroundColor)), forKey: "inputColor1")
        
        guard let outputImage = colorFilter.outputImage else {
            return image
        }
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    VStack(spacing: 20) {
        QRCodeView(
            qrCodeId: "12345678-1234-1234-1234-123456789012",
            size: 200
        )
        
        QRCodeView(
            qrCodeId: "12345678-1234-1234-1234-123456789012",
            size: 150,
            backgroundColor: .blue.opacity(0.1),
            foregroundColor: .blue
        )
        
        QRCodeView(
            qrCodeId: "12345678-1234-1234-1234-123456789012",
            size: 100,
            backgroundColor: .black,
            foregroundColor: .white
        )
    }
    .padding()
}
