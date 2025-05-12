import SwiftUI
import ComposableArchitecture

/// A SwiftUI view for displaying a user's QR code in a sheet
struct QRCodeSheetView: View {
    /// The store for the QR code sheet feature
    @Bindable var store: StoreOf<QRCodeSheetFeature>

    /// Callback when the sheet is dismissed
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Button(action: {
                    store.send(.dismiss)
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(16)
                        .accessibilityLabel("Close")
                }
            }

            QRCodeCardView(
                store: store.scope(
                    state: \.qrCodeCard,
                    action: \.qrCodeCard
                )
            )
            .padding(.top, 8)

            // Share button
            Button(action: {
                store.send(.shareQRCode)
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

            Spacer()
        }
        .padding()
    }
}

/// Extension for QRCodeSheetView with convenience initializers
extension QRCodeSheetView {
    /// Initialize with name, QR code ID, and onDismiss callback
    /// - Parameters:
    ///   - name: The name to display
    ///   - qrCodeId: The QR code ID to display
    ///   - onDismiss: Callback for when the sheet is dismissed
    init(
        name: String,
        qrCodeId: String,
        onDismiss: @escaping () -> Void
    ) {
        self.onDismiss = onDismiss

        // Create a QRCodeSheetFeature store
        self.store = Store(
            initialState: QRCodeSheetFeature.State(
                name: name,
                qrCodeId: qrCodeId
            )
        ) {
            QRCodeSheetFeature()
        }
    }
}
