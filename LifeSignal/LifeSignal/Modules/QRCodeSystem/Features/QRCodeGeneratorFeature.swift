import Foundation
import ComposableArchitecture
import SwiftUI
import UIKit

/// Feature for QR code generation functionality
@Reducer
struct QRCodeGeneratorFeature {
    /// The state of the QR code generator feature
    @ObservableState
    struct State: Equatable, Sendable {
        /// The string to encode in the QR code
        var qrCodeId: String = ""
        
        /// The size of the QR code
        var size: CGFloat = 200
        
        /// Whether to use branded styling
        var branded: Bool = true
        
        /// The foreground color (only used when branded is false)
        var foregroundColor: UIColor = .black
        
        /// The background color (only used when branded is false)
        var backgroundColor: UIColor = .white
        
        /// The generated QR code image
        @MainActor var qrCodeImage: UIImage?
        
        /// Initialize with default values
        init(
            qrCodeId: String = "",
            size: CGFloat = 200,
            branded: Bool = true,
            foregroundColor: UIColor = .black,
            backgroundColor: UIColor = .white
        ) {
            self.qrCodeId = qrCodeId
            self.size = size
            self.branded = branded
            self.foregroundColor = foregroundColor
            self.backgroundColor = backgroundColor
        }
    }
    
    /// Actions that can be performed on the QR code generator feature
    enum Action: Equatable, Sendable {
        /// Generate the QR code image
        case generateQRCodeImage
        
        /// Set the QR code image
        case setQRCodeImage(UIImage?)
        
        /// Update the QR code ID
        case updateQRCodeId(String)
        
        /// Update the size
        case updateSize(CGFloat)
        
        /// Update whether to use branded styling
        case updateBranded(Bool)
        
        /// Update the foreground color
        case updateForegroundColor(UIColor)
        
        /// Update the background color
        case updateBackgroundColor(UIColor)
    }
    
    /// Dependencies for the QR code generator feature
    @Dependency(\.qrCodeClient) var qrCodeClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .generateQRCodeImage:
                // Generate the QR code image using the client
                return .run { [qrCodeClient, state] send in
                    let image: UIImage?
                    if state.branded {
                        image = qrCodeClient.generateBrandedQRCode(state.qrCodeId, state.size)
                    } else {
                        image = qrCodeClient.generateQRCode(
                            state.qrCodeId,
                            state.size,
                            state.backgroundColor,
                            state.foregroundColor
                        )
                    }
                    await send(.setQRCodeImage(image))
                }
                
            @MainActor case let .setQRCodeImage(image):
                state.qrCodeImage = image
                return .none
                
            case let .updateQRCodeId(qrCodeId):
                state.qrCodeId = qrCodeId
                return .send(.generateQRCodeImage)
                
            case let .updateSize(size):
                state.size = size
                return .send(.generateQRCodeImage)
                
            case let .updateBranded(branded):
                state.branded = branded
                return .send(.generateQRCodeImage)
                
            case let .updateForegroundColor(color):
                state.foregroundColor = color
                if !state.branded {
                    return .send(.generateQRCodeImage)
                }
                return .none
                
            case let .updateBackgroundColor(color):
                state.backgroundColor = color
                if !state.branded {
                    return .send(.generateQRCodeImage)
                }
                return .none
            }
        }
    }
}
