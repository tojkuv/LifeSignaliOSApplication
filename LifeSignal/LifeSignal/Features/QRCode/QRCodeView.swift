import SwiftUI
import ComposableArchitecture
import UIKit

/// Feature for displaying a QR code
@Reducer
struct QRCodeViewFeature {
    /// The state of the QR code view feature
    struct State: Equatable {
        /// The content to encode in the QR code
        var qrContent: String
        
        /// The size of the QR code
        var size: CGFloat
        
        /// The background color of the QR code
        var backgroundColor: Color
        
        /// Flag indicating if the QR code generation failed
        var generationFailed: Bool = false
        
        /// The generated QR code image
        var qrImage: UIImage? = nil
    }
    
    /// Actions that can be performed on the QR code view feature
    enum Action: Equatable {
        /// Generate the QR code
        case generateQRCode
        case generateQRCodeResponse(TaskResult<UIImage?>)
    }
    
    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .generateQRCode:
                return .run { [qrContent = state.qrContent, size = state.size] send in
                    let result = await TaskResult {
                        guard !qrContent.isEmpty else {
                            return nil
                        }
                        
                        guard let data = qrContent.data(using: .utf8) else {
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
                    await send(.generateQRCodeResponse(result))
                }
                
            case let .generateQRCodeResponse(result):
                switch result {
                case let .success(image):
                    state.qrImage = image
                    state.generationFailed = image == nil
                    return .none
                case .failure:
                    state.generationFailed = true
                    return .none
                }
            }
        }
    }
}

/// A SwiftUI view for displaying a QR code using TCA
struct QRCodeView: View {
    /// The store for the QR code view feature
    let store: StoreOf<QRCodeViewFeature>
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            Group {
                if let qrImage = viewStore.qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: viewStore.size, height: viewStore.size)
                        .background(viewStore.backgroundColor)
                } else if viewStore.generationFailed {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: viewStore.size, height: viewStore.size)
                        .overlay(
                            Text("QR Code Error")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        )
                } else {
                    ProgressView()
                        .frame(width: viewStore.size, height: viewStore.size)
                        .onAppear {
                            viewStore.send(.generateQRCode)
                        }
                }
            }
        }
    }
}

/// A SwiftUI view for displaying a QR code using TCA (convenience initializer)
extension QRCodeView {
    /// Initialize with QR content
    /// - Parameters:
    ///   - qrContent: The content to encode in the QR code
    ///   - size: The size of the QR code
    ///   - backgroundColor: The background color of the QR code
    init(qrContent: String, size: CGFloat = 200, backgroundColor: Color = .white) {
        self.store = Store(initialState: QRCodeViewFeature.State(
            qrContent: qrContent,
            size: size,
            backgroundColor: backgroundColor
        )) {
            QRCodeViewFeature()
        }
    }
    
    /// Initialize with QR code ID
    /// - Parameters:
    ///   - qrCodeId: The QR code ID to encode
    ///   - size: The size of the QR code
    ///   - backgroundColor: The background color of the QR code
    init(qrCodeId: String, size: CGFloat = 200, backgroundColor: Color = .white) {
        self.init(qrContent: qrCodeId, size: size, backgroundColor: backgroundColor)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    QRCodeView(qrContent: "https://example.com")
        .frame(width: 200, height: 200)
}
