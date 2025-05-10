import SwiftUI
import ComposableArchitecture
import AVFoundation
import PhotosUI
import Vision
import Photos
import UIKit

/// Feature for scanning QR codes
@Reducer
struct QRScannerFeature {
    /// The state of the QR scanner feature
    struct State: Equatable {
        /// Flag indicating if the torch is on
        var torchOn: Bool = false

        /// Flag indicating if the gallery is showing
        var isShowingGallery: Bool = false

        /// Flag indicating if the user's QR code is showing
        var isShowingMyCode: Bool = false

        /// Flag indicating if the camera permission denied alert is showing
        var showCameraDeniedAlert: Bool = false

        /// Flag indicating if a QR code has been scanned
        var didScan: Bool = false

        /// Flag indicating if the no QR code alert is showing
        var showNoQRCodeAlert: Bool = false

        /// Flag indicating if the camera is ready
        var isCameraReady: Bool = false

        /// Flag indicating if the camera failed to load
        var cameraLoadFailed: Bool = false

        /// Flag indicating if an image is being scanned
        var scanningImage: Bool = false

        /// The scanned QR code
        var scannedCode: String? = nil

        /// Selected photo item
        @PresentationState var photoPickerItem: PhotoPickerFeature.State? = nil
    }

    /// Actions that can be performed on the QR scanner feature
    enum Action: Equatable {
        /// Toggle the torch
        case toggleTorch

        /// Show the gallery
        case showGallery

        /// Show the user's QR code
        case showMyCode

        /// Set the camera denied alert
        case setCameraDeniedAlert(Bool)

        /// Set the no QR code alert
        case setNoQRCodeAlert(Bool)

        /// Set the camera ready state
        case setCameraReady(Bool)

        /// Set the camera load failed state
        case setCameraLoadFailed(Bool)

        /// Set the scanning image state
        case setScanningImage(Bool)

        /// Handle a scanned QR code
        case handleScannedCode(String)

        /// Dismiss the scanner
        case dismiss

        /// Photo picker actions
        case photoPickerItem(PresentationAction<PhotoPickerFeature.Action>)
        case selectPhoto
    }

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .toggleTorch:
                state.torchOn.toggle()
                return .none

            case .showGallery:
                state.isShowingGallery = true
                state.photoPickerItem = PhotoPickerFeature.State()
                return .none

            case .showMyCode:
                state.isShowingMyCode = true
                return .none

            case let .setCameraDeniedAlert(show):
                state.showCameraDeniedAlert = show
                return .none

            case let .setNoQRCodeAlert(show):
                state.showNoQRCodeAlert = show
                return .none

            case let .setCameraReady(ready):
                state.isCameraReady = ready
                return .none

            case let .setCameraLoadFailed(failed):
                state.cameraLoadFailed = failed
                return .none

            case let .setScanningImage(scanning):
                state.scanningImage = scanning
                return .none

            case let .handleScannedCode(code):
                state.scannedCode = code
                state.didScan = true
                return .none

            case .dismiss:
                return .none

            case .photoPickerItem:
                return .none

            case .selectPhoto:
                return .none
            }
        }
        .ifLet(\.$photoPickerItem, action: /Action.photoPickerItem) {
            PhotoPickerFeature()
        }
    }
}

/// Feature for picking photos
@Reducer
struct PhotoPickerFeature {
    /// The state of the photo picker feature
    struct State: Equatable {
        /// Selected photo items
        var selectedItems: [PhotosPickerItem] = []
    }

    /// Actions that can be performed on the photo picker feature
    enum Action: Equatable {
        /// Update selected items
        case updateSelectedItems([PhotosPickerItem])

        /// Process selected items
        case processSelectedItems

        /// Dismiss the photo picker
        case dismiss
    }

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .updateSelectedItems(items):
                state.selectedItems = items
                return .none

            case .processSelectedItems:
                return .none

            case .dismiss:
                return .none
            }
        }
    }
}

/// A SwiftUI view for scanning QR codes using TCA
struct QRScannerView: View {
    /// The store for the QR scanner feature
    let store: StoreOf<QRScannerFeature>

    /// Callback for when a QR code is scanned
    let onScanned: (String) -> Void

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            ZStack {
                // Camera view
                if !viewStore.cameraLoadFailed {
                    QRScannerViewControllerRepresentable(
                        torchOn: viewStore.torchOn,
                        onCodeScanned: { code in
                            viewStore.send(.handleScannedCode(code))
                            onScanned(code)
                        },
                        onCameraReady: {
                            viewStore.send(.setCameraReady(true))
                        },
                        onCameraFailed: {
                            viewStore.send(.setCameraLoadFailed(true))
                        },
                        onCameraDenied: {
                            viewStore.send(.setCameraDeniedAlert(true))
                        }
                    )
                    .edgesIgnoringSafeArea(.all)
                } else {
                    // Camera failed view
                    VStack {
                        Text("Camera Failed to Load")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()

                        Text("Please try again or use the gallery to scan a QR code.")
                            .font(.body)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding()

                        Button(action: {
                            viewStore.send(.showGallery)
                        }) {
                            Text("Open Gallery")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .edgesIgnoringSafeArea(.all)
                }

                // Overlay
                VStack {
                    HStack {
                        // Close button
                        Button(action: {
                            viewStore.send(.dismiss)
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding(.leading, 20)
                        .padding(.top, 20)

                        Spacer()

                        // Torch button
                        Button(action: {
                            viewStore.send(.toggleTorch)
                        }) {
                            Image(systemName: viewStore.torchOn ? "bolt.fill" : "bolt.slash")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 20)
                    }

                    Spacer()

                    // Bottom controls
                    HStack(spacing: 30) {
                        // Gallery button
                        Button(action: {
                            viewStore.send(.showGallery)
                        }) {
                            VStack {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)

                                Text("Gallery")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(10)
                        }

                        // My QR code button
                        Button(action: {
                            viewStore.send(.showMyCode)
                        }) {
                            VStack {
                                Image(systemName: "qrcode")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)

                                Text("My QR")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
            .alert("Camera Access Denied", isPresented: viewStore.binding(
                get: \.showCameraDeniedAlert,
                send: { QRScannerFeature.Action.setCameraDeniedAlert($0) }
            )) {
                Button("Cancel", role: .cancel) {
                    viewStore.send(.dismiss)
                }
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text("Please allow camera access in Settings to scan QR codes.")
            }
            .alert("No QR Code Found", isPresented: viewStore.binding(
                get: \.showNoQRCodeAlert,
                send: { QRScannerFeature.Action.setNoQRCodeAlert($0) }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The selected image does not contain a valid QR code.")
            }
            .photosPicker(
                isPresented: viewStore.binding(
                    get: \.isShowingGallery,
                    send: { _ in .showGallery }
                ),
                selection: viewStore.binding(
                    get: { _ in [] },
                    send: { items, _ in
                        if let item = items.first {
                            // Process the selected photo
                            viewStore.send(.setScanningImage(true))

                            // This would be handled in a real implementation
                            // For now, just show the no QR code alert
                            viewStore.send(.setScanningImage(false))
                            viewStore.send(.setNoQRCodeAlert(true))
                        }
                        return .selectPhoto
                    }
                ),
                matching: .images
            )
        }
    }
}

/// UIViewControllerRepresentable for the QR scanner
struct QRScannerViewControllerRepresentable: UIViewControllerRepresentable {
    /// Flag indicating if the torch is on
    var torchOn: Bool

    /// Callback for when a QR code is scanned
    var onCodeScanned: (String) -> Void

    /// Callback for when the camera is ready
    var onCameraReady: () -> Void

    /// Callback for when the camera fails to load
    var onCameraFailed: () -> Void

    /// Callback for when camera access is denied
    var onCameraDenied: () -> Void

    /// Create the view controller
    func makeUIViewController(context: Context) -> QRScannerViewController {
        let viewController = QRScannerViewController()
        viewController.delegate = context.coordinator
        return viewController
    }

    /// Update the view controller
    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {
        if let device = AVCaptureDevice.default(for: .video) {
            if device.hasTorch {
                try? device.lockForConfiguration()
                device.torchMode = torchOn ? .on : .off
                device.unlockForConfiguration()
            }
        }
    }

    /// Create the coordinator
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// Coordinator for handling QR code scanning
    class Coordinator: NSObject, QRScannerViewControllerDelegate {
        var parent: QRScannerViewControllerRepresentable

        init(_ parent: QRScannerViewControllerRepresentable) {
            self.parent = parent
        }

        func qrScanningDidFail() {
            parent.onCameraFailed()
        }

        func qrScanningSucceededWithCode(_ code: String) {
            parent.onCodeScanned(code)
        }

        func qrScanningDidStop() {
            // Not used
        }

        func qrScanningDidSetup() {
            parent.onCameraReady()
        }

        func qrScanningDidDeny() {
            parent.onCameraDenied()
        }
    }
}

#Preview {
    QRScannerView(
        store: Store(initialState: QRScannerFeature.State()) {
            QRScannerFeature()
        },
        onScanned: { _ in }
    )
}