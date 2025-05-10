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
                    let result = await TaskResult {
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

/// A SwiftUI view for sharing a QR code using TCA
struct QRCodeShareSheetView: View {
    /// The store for the QR code share sheet feature
    let store: StoreOf<QRCodeShareSheetFeature>
    
    /// Callback for when the share sheet is dismissed
    let onDismiss: () -> Void
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationView {
                VStack(spacing: 20) {
                    Text("Share Your QR Code")
                        .font(.headline)
                        .padding(.top)
                    
                    Text("Let others scan this QR code to add you as a contact")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    QRCodeView(qrCodeId: viewStore.qrCodeId, size: 250)
                        .padding()
                    
                    Text(viewStore.name)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Button(action: {
                        viewStore.send(.generateQRCode)
                        viewStore.send(.showSystemShareSheet(true))
                    }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding()
                .navigationBarItems(trailing: Button("Done") {
                    viewStore.send(.dismiss)
                    onDismiss()
                })
                .background(
                    ShareSheetPresenter(
                        isPresented: viewStore.binding(
                            get: \.showSystemShareSheet,
                            send: QRCodeShareSheetFeature.Action.showSystemShareSheet
                        ),
                        content: {
                            if let image = viewStore.qrCodeImage {
                                return [
                                    QRCodeActivityItem(
                                        image: image,
                                        title: "\(viewStore.name)'s LifeSignal QR Code"
                                    )
                                ]
                            }
                            return []
                        }
                    )
                )
            }
        }
    }
}

/// A UIViewControllerRepresentable for presenting a share sheet
struct ShareSheetPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let content: () -> [Any]
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented {
            let activityItems = content()
            let activityViewController = UIActivityViewController(
                activityItems: activityItems,
                applicationActivities: nil
            )
            
            activityViewController.completionWithItemsHandler = { _, _, _, _ in
                isPresented = false
            }
            
            uiViewController.present(activityViewController, animated: true)
        }
    }
}

/// A SwiftUI view for sharing a QR code using TCA (convenience initializer)
extension QRCodeShareSheetView {
    /// Initialize with QR code share sheet data
    /// - Parameters:
    ///   - name: The name to display
    ///   - qrCodeId: The QR code ID to share
    ///   - onDismiss: Callback for when the share sheet is dismissed
    init(name: String, qrCodeId: String, onDismiss: @escaping () -> Void) {
        self.store = Store(initialState: QRCodeShareSheetFeature.State(
            name: name,
            qrCodeId: qrCodeId
        )) {
            QRCodeShareSheetFeature()
        }
        self.onDismiss = onDismiss
    }
}

#Preview {
    QRCodeShareSheetView(
        name: "John Doe",
        qrCodeId: "12345678-1234-1234-1234-123456789012",
        onDismiss: {}
    )
}
