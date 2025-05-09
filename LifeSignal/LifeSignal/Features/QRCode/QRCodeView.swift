import SwiftUI
import UIKit

/// A view that generates and displays a QR code
struct QRCodeView: View {
    let qrContent: String
    let backgroundColor: Color
    let size: CGFloat

    init(qrContent: String, size: CGFloat = 200, backgroundColor: Color = .white) {
        self.qrContent = qrContent
        self.size = size
        self.backgroundColor = backgroundColor
    }

    init(qrCodeId: String, size: CGFloat = 200, backgroundColor: Color = .white) {
        self.qrContent = qrCodeId
        self.size = size
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        if let qrImage = QRCodeGenerator.generateQRCode(from: qrContent, size: CGSize(width: size, height: size)) {
            Image(uiImage: qrImage)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .background(backgroundColor)
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size, height: size)
                .overlay(
                    Text("QR Code Error")
                        .font(.caption)
                        .foregroundColor(.secondary)
                )
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    QRCodeView(qrContent: "https://example.com")
        .frame(width: 200, height: 200)
}
