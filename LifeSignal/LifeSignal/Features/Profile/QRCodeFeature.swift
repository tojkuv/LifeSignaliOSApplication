import Foundation
import ComposableArchitecture

/// Feature for displaying a QR code
@Reducer
struct QRCodeFeature {
    /// The state of the QR code feature
    struct State: Equatable {
        /// The QR code ID to display
        var qrCodeId: String
        
        /// The user's name for display
        var userName: String
    }
    
    /// Actions that can be performed on the QR code feature
    enum Action: Equatable {
        /// Dismiss the QR code view
        case dismiss
    }
    
    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .dismiss:
                return .none
            }
        }
    }
}
