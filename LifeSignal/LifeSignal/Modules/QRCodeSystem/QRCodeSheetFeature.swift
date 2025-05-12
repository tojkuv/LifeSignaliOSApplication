import Foundation
import ComposableArchitecture
import SwiftUI
import UIKit

/// Feature for QR code sheet functionality
@Reducer
struct QRCodeSheetFeature {
    /// The state of the QR code sheet feature
    @ObservableState
    struct State: Equatable, Sendable {
        /// The name to display
        var name: String = ""
        
        /// The footer text to display
        var footer: String = "Let others scan this code to add you as a contact."
        
        /// Whether the sheet is showing
        var isShowing: Bool = false
        
        /// The QR code card feature state
        var qrCodeCard: QRCodeCardFeature.State
        
        /// Initialize with default values
        init(
            name: String = "",
            qrCodeId: String = "",
            footer: String = "Let others scan this code to add you as a contact.",
            isShowing: Bool = false
        ) {
            self.name = name
            self.footer = footer
            self.isShowing = isShowing
            self.qrCodeCard = QRCodeCardFeature.State(
                name: name,
                qrCodeId: qrCodeId,
                footer: footer
            )
        }
    }
    
    /// Actions that can be performed on the QR code sheet feature
    enum Action: Equatable, Sendable {
        /// Set whether the sheet is showing
        case setShowing(Bool)
        
        /// QR code card actions
        case qrCodeCard(QRCodeCardFeature.Action)
        
        /// Share the QR code
        case shareQRCode
        
        /// Dismiss the sheet
        case dismiss
    }
    
    /// Dependencies for the QR code sheet feature
    @Dependency(\.qrCodeClient) var qrCodeClient
    
    var body: some ReducerOf<Self> {
        Scope(state: \.qrCodeCard, action: \.qrCodeCard) {
            QRCodeCardFeature()
        }
        
        Reduce { state, action in
            switch action {
            case let .setShowing(isShowing):
                state.isShowing = isShowing
                return .none
                
            case .qrCodeCard:
                // Handled by the scoped reducer
                return .none
                
            case .shareQRCode:
                return .run { [qrCodeId = state.qrCodeCard.qrCodeGenerator.qrCodeId, qrCodeClient] _ in
                    await qrCodeClient.shareQRCode(qrCodeId)
                }
                
            case .dismiss:
                state.isShowing = false
                return .none
            }
        }
    }
}
