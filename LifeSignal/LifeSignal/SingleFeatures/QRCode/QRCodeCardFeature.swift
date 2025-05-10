import SwiftUI
import ComposableArchitecture
import UIKit

/// Feature for displaying a QR code card
@Reducer
struct QRCodeCardFeature {
    /// The state of the QR code card feature
    struct State: Equatable {
        /// The name to display
        var name: String

        /// The subtitle to display
        var subtitle: String

        /// The QR code ID to display
        var qrCodeId: String

        /// The footer text to display
        var footer: String

        /// Flag indicating if the share sheet is showing
        var showShareSheet: Bool = false
    }

    /// Actions that can be performed on the QR code card feature
    enum Action: Equatable {
        /// Show the share sheet
        case showShareSheet(Bool)

        /// Share the QR code
        case shareQRCode
    }

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .showShareSheet(show):
                state.showShareSheet = show
                return .none

            case .shareQRCode:
                return .none
            }
        }
    }
}
