import SwiftUI
import UIKit
import ComposableArchitecture

/// A SwiftUI view that displays a QR code
struct QRCodeView: View {
    /// The store for the QR code generator feature
    @Bindable var store: StoreOf<QRCodeGeneratorFeature>

    var body: some View {
        Group {
            if let qrCodeImage = store.qrCodeImage {
                Image(uiImage: qrCodeImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: store.size, height: store.size)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            } else {
                // Fallback if QR code generation fails
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: store.size, height: store.size)

                    Text("QR Code\nUnavailable")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            store.send(.generateQRCodeImage)
        }
        .onChange(of: store.qrCodeId) { _, _ in
            store.send(.generateQRCodeImage)
        }
    }
}

/// Extension for QRCodeView with convenience initializers
extension QRCodeView {
    /// Initialize with a QR code ID, size, and branded flag
    /// - Parameters:
    ///   - qrCodeId: The string to encode in the QR code
    ///   - size: The size of the QR code (default: 200)
    ///   - branded: Whether to use branded styling (default: true)
    init(qrCodeId: String, size: CGFloat = 200, branded: Bool = true) {
        self.store = Store(
            initialState: QRCodeGeneratorFeature.State(
                qrCodeId: qrCodeId,
                size: size,
                branded: branded
            )
        ) {
            QRCodeGeneratorFeature()
        }
    }
}