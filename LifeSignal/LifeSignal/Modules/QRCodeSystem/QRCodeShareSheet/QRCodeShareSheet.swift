import SwiftUI
import UIKit
import ComposableArchitecture

/// A feature for sharing QR codes
@Reducer
struct QRCodeShareFeature {
    /// The state for the QR code share feature
    @ObservableState
    struct State: Equatable, Sendable {
        /// The user's name
        var name: String = ""

        /// Whether the share sheet is showing
        var isShowingShareSheet: Bool = false

        /// The QR code generator state
        var qrCodeGenerator: QRCodeGeneratorFeature.State

        /// Initialize with default values
        init(
            name: String = "",
            qrCodeId: String = "",
            isShowingShareSheet: Bool = false
        ) {
            self.name = name
            self.isShowingShareSheet = isShowingShareSheet
            self.qrCodeGenerator = QRCodeGeneratorFeature.State(
                qrCodeId: qrCodeId,
                size: 1024,
                branded: true
            )
        }
    }

    /// The actions for the QR code share feature
    enum Action: Equatable, Sendable {
        /// Set whether the share sheet is showing
        case setShowingShareSheet(Bool)

        /// QR code generator actions
        case qrCodeGenerator(QRCodeGeneratorFeature.Action)

        /// Share the QR code
        case shareQRCode

        /// Dismiss the sheet
        case dismiss

        /// Internal action for handling dismiss callback
        case _onDismissCallback
    }

    /// Dependencies for the QR code share feature
    @Dependency(\.qrCodeClient) var qrCodeClient

    /// Dismiss callback
    var onDismiss: (() -> Void)?

    /// Set the dismiss callback
    /// - Parameter callback: The callback to call when the sheet is dismissed
    /// - Returns: A new feature with the callback set
    func _onDismiss(_ callback: @escaping () -> Void) -> Self {
        var feature = self
        feature.onDismiss = callback
        return feature
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.qrCodeGenerator, action: \.qrCodeGenerator) {
            QRCodeGeneratorFeature()
        }

        Reduce { state, action in
            switch action {
            case let .setShowingShareSheet(isShowing):
                state.isShowingShareSheet = isShowing
                return .none

            case .qrCodeGenerator:
                // Handled by the scoped reducer
                return .none

            case .shareQRCode:
                return .run { [qrCodeId = state.qrCodeGenerator.qrCodeId, qrCodeClient] _ in
                    await qrCodeClient.shareQRCode(qrCodeId)
                }

            case .dismiss:
                // Call the dismiss callback if it exists
                if let onDismiss = self.onDismiss {
                    return .run { send in
                        await send(._onDismissCallback)
                        onDismiss()
                    }
                }
                return .none

            case ._onDismissCallback:
                // This is just a marker action for testing
                return .none
            }
        }
    }
}

/// A SwiftUI view for sharing a QR code using TCA
struct QRCodeShareSheet: View {
    /// The store for the QR code share feature
    @Bindable var store: StoreOf<QRCodeShareFeature>

    var body: some View {
        VStack(spacing: 20) {
            Text("Share QR Code")
                .font(.title)
                .padding(.top)

            Text("Share this QR code with others to add \(store.name) as a contact")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            QRCodeView(
                store: store.scope(
                    state: \.qrCodeGenerator,
                    action: \.qrCodeGenerator
                )
            )
            .padding()
            .frame(width: 250, height: 250)

            Button(action: {
                store.send(.setShowingShareSheet(true))
            }) {
                Label("Share QR Code", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)

            Button(action: {
                store.send(.dismiss)
            }) {
                Text("Close")
                    .foregroundColor(.blue)
            }
            .padding(.bottom)
        }
        .padding()
        .sheet(isPresented: $store.isShowingShareSheet.sending(\.setShowingShareSheet)) {
            if let image = store.qrCodeGenerator.qrCodeImage {
                ShareSheet(items: [image])
            }
        }
    }
}

/// Extension for QRCodeShareSheet with convenience initializers
extension QRCodeShareSheet {
    /// Initialize with a QR code ID and name
    /// - Parameters:
    ///   - qrCodeId: The QR code ID to display
    ///   - name: The name to display
    ///   - onDismiss: Callback for when the sheet is dismissed
    init(qrCodeId: String, name: String, onDismiss: @escaping () -> Void) {
        // Create a QRCodeShareFeature store
        self.store = Store(
            initialState: QRCodeShareFeature.State(
                name: name,
                qrCodeId: qrCodeId
            )
        ) {
            QRCodeShareFeature()._onDismiss { onDismiss() }
        }
    }
}

/// A UIViewControllerRepresentable for sharing content
struct ShareSheet: UIViewControllerRepresentable {
    /// The items to share
    let items: [Any]

    /// Create the UIActivityViewController
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    /// Update the UIActivityViewController (not needed)
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
