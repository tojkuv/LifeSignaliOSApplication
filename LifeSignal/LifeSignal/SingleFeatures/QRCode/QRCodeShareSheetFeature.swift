import SwiftUI
import ComposableArchitecture
import UIKit

/// Feature for sharing a QR code
@Reducer
struct QRCodeShareSheetFeature {
    /// The state of the QR code share sheet feature
    struct State: Equatable {
        /// The name to display
        var name: String
        
        /// The QR code ID to share
        var qrCodeId: String
        
        /// Flag indicating if the share sheet is showing
        var showSystemShareSheet: Bool = false
        
        /// The QR code image
        var qrCodeImage: UIImage? = nil
    }
    
    /// Actions that can be performed on the QR code share sheet feature
    enum Action: Equatable {
        /// Generate the QR code image
        case generateQRCode
        case generateQRCodeResponse(TaskResult<UIImage?>)
        
        /// Show the system share sheet
        case showSystemShareSheet(Bool)
        
        /// Dismiss the share sheet
        case dismiss
    }
    
    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .generateQRCode:
                return .run { [qrCodeId = state.qrCodeId] send in
                    let result = await TaskResult<UIImage?> {
                        guard !qrCodeId.isEmpty else {
                            return nil
                        }
                        
                        guard let data = qrCodeId.data(using: .utf8) else {
                            return nil
                        }
                        
                        if let filter = CIFilter(name: "CIQRCodeGenerator") {
                            filter.setValue(data, forKey: "inputMessage")
                            filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction
                            
                            if let outputImage = filter.outputImage {
                                let scale = 300 / outputImage.extent.width
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
                    state.qrCodeImage = image
                    return .none
                case .failure:
                    return .none
                }
                
            case let .showSystemShareSheet(show):
                state.showSystemShareSheet = show
                return .none
                
            case .dismiss:
                return .none
            }
        }
    }
}
