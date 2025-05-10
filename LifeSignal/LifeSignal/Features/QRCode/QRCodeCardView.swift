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

/// A SwiftUI view for displaying a QR code card using TCA
struct QRCodeCardView: View {
    /// The store for the QR code card feature
    let store: StoreOf<QRCodeCardFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(spacing: 0) {
                // Avatar at the top, overlapping the card
                AvatarView(name: viewStore.name, size: 80)
                    .offset(y: -40)
                    .padding(.bottom, -40)

                // Card content
                VStack(spacing: 16) {
                    // Name and subtitle
                    VStack(spacing: 4) {
                        Text(viewStore.name)
                            .font(.headline)
                            .multilineTextAlignment(.center)

                        Text(viewStore.subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)

                    // QR Code
                    if !viewStore.qrCodeId.isEmpty {
                        QRCodeView(qrCodeId: viewStore.qrCodeId, size: 200)
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
                    if !viewStore.footer.isEmpty {
                        Text(viewStore.footer)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Share button
                    Button(action: {
                        viewStore.send(.showShareSheet(true))
                    }) {
                        Label("Share QR Code", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                    .disabled(viewStore.qrCodeId.isEmpty)
                }
                .padding(.horizontal)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )
            .padding(.horizontal)
            .sheet(isPresented: viewStore.binding(
                get: \.showShareSheet,
                send: QRCodeCardFeature.Action.showShareSheet
            )) {
                if !viewStore.qrCodeId.isEmpty {
                    QRCodeShareSheetView(
                        name: viewStore.name,
                        qrCodeId: viewStore.qrCodeId,
                        onDismiss: {
                            viewStore.send(.showShareSheet(false))
                        }
                    )
                }
            }
        }
    }
}

/// A SwiftUI view for displaying a QR code card using TCA (convenience initializer)
extension QRCodeCardView {
    /// Initialize with QR code card data
    /// - Parameters:
    ///   - name: The name to display
    ///   - subtitle: The subtitle to display
    ///   - qrCodeId: The QR code ID to display
    ///   - footer: The footer text to display
    init(name: String, subtitle: String, qrCodeId: String, footer: String) {
        self.store = Store(initialState: QRCodeCardFeature.State(
            name: name,
            subtitle: subtitle,
            qrCodeId: qrCodeId,
            footer: footer
        )) {
            QRCodeCardFeature()
        }
    }
}

#Preview {
    QRCodeCardView(
        name: "John Doe",
        subtitle: "LifeSignal contact",
        qrCodeId: "12345678-1234-1234-1234-123456789012",
        footer: "Your QR code is unique. If you share it with someone, they can scan it and add you as a contact"
    )
}
