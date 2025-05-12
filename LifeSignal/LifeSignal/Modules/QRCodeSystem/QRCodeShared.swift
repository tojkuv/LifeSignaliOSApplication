import Foundation
import ComposableArchitecture

/// Shared state for QR code data across features
@Reducer
struct QRCodeSharedFeature {
    /// The state of the QR code shared feature
    @ObservableState
    struct State: Equatable, Sendable {
        /// The QR code data
        @Shared(.inMemory("qrCode")) var qrCode = QRCodeData()
        
        /// Initialize with default values
        init() {}
    }
    
    /// Actions that can be performed on the QR code shared feature
    enum Action: Equatable, Sendable {
        /// Update the QR code
        case updateQRCode(String)
        
        /// Clear the QR code
        case clearQRCode
    }
    
    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .updateQRCode(code):
                state.$qrCode.withLock { $0.code = code }
                return .none
                
            case .clearQRCode:
                state.$qrCode.withLock { $0 = QRCodeData() }
                return .none
            }
        }
    }
}

/// QR code data model
struct QRCodeData: Equatable, Sendable {
    /// The QR code string
    var code: String = ""
    
    /// Whether the QR code is valid
    var isValid: Bool {
        !code.isEmpty
    }
}
