import SwiftUI
import UIKit
import ComposableArchitecture

/// A feature for QR code card display
@Reducer
struct QRCodeCardFeature {
    /// The state for the QR code card feature
    @ObservableState
    struct State: Equatable, Sendable {
        /// The name to display
        var name: String = ""

        /// The footer text to display
        var footer: String = ""

        /// The QR code generator state
        var qrCodeGenerator: QRCodeGeneratorFeature.State

        /// Initialize with default values
        init(
            name: String = "",
            qrCodeId: String = "",
            footer: String = ""
        ) {
            self.name = name
            self.footer = footer
            self.qrCodeGenerator = QRCodeGeneratorFeature.State(
                qrCodeId: qrCodeId,
                size: 200,
                branded: true
            )
        }
    }

    /// Actions that can be performed on the QR code card feature
    enum Action: Equatable, Sendable {
        /// QR code generator actions
        case qrCodeGenerator(QRCodeGeneratorFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.qrCodeGenerator, action: \.qrCodeGenerator) {
            QRCodeGeneratorFeature()
        }

        Reduce { state, action in
            switch action {
            case .qrCodeGenerator:
                // Handled by the scoped reducer
                return .none
            }
        }
    }
}

/// A SwiftUI view for displaying a QR code card
struct QRCodeCardView: View {
    /// The store for the QR code card feature
    @Bindable var store: StoreOf<QRCodeCardFeature>

    var body: some View {
        VStack(spacing: 0) {
            // Avatar at the top, overlapping the card
            AvatarView(name: store.name, size: 80)
                .offset(y: -40)
                .padding(.bottom, -40)

            // Card content
            VStack(spacing: 16) {
                // Name and subtitle
                VStack(spacing: 4) {
                    Text(store.name)
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    Text("LifeSignal contact")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)

                // QR Code
                if !store.qrCodeGenerator.qrCodeId.isEmpty {
                    QRCodeView(
                        store: store.scope(
                            state: \.qrCodeGenerator,
                            action: \.qrCodeGenerator
                        )
                    )
                    .padding(.vertical, 8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 200, height: 200)
                        .overlay(
                            Text("QR Code Not Available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        )
                }

                // Footer text
                Text(store.footer)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.horizontal)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
}

/// Extension for QRCodeCardView with convenience initializers
extension QRCodeCardView {
    /// Initialize with name, QR code ID, and footer text
    /// - Parameters:
    ///   - name: The name to display
    ///   - qrCodeId: The QR code ID to display
    ///   - footer: The footer text to display
    init(
        name: String,
        qrCodeId: String,
        footer: String
    ) {
        self.store = Store(
            initialState: QRCodeCardFeature.State(
                name: name,
                qrCodeId: qrCodeId,
                footer: footer
            )
        ) {
            QRCodeCardFeature()
        }
    }
}
