import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

/// A view that generates and displays a QR code
struct QRCodeView: View {
    let qrContent: String
    let backgroundColor: Color

    init(qrContent: String, backgroundColor: Color = .white) {
        self.qrContent = qrContent
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let qrCode = generateQRCode(from: qrContent)

            Image(uiImage: qrCode)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: size, height: size)
                .background(backgroundColor)
        }
    }

    /// Generates a QR code image from a string
    /// - Parameter string: The string to encode in the QR code
    /// - Returns: A UIImage containing the QR code
    private func generateQRCode(from string: String) -> UIImage {
        let data = string.data(using: .ascii, allowLossyConversion: false)
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")

        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let output = filter.outputImage?.transformed(by: transform)

        let context = CIContext()
        guard let cgImage = context.createCGImage(output ?? CIImage(), from: output?.extent ?? CGRect.zero) else {
            return UIImage()
        }

        return UIImage(cgImage: cgImage)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    QRCodeView(qrContent: "https://example.com")
        .frame(width: 200, height: 200)
}
