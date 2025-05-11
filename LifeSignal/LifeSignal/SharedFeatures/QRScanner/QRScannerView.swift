import SwiftUI
import AVFoundation
import PhotosUI
import Vision
import Photos
import UIKit

/// A SwiftUI view for scanning QR codes
struct QRScannerView: View {
    /// Callback for when a QR code is scanned
    let onScanned: (String) -> Void

    /// State for UI controls
    @State private var torchOn: Bool = false
    @State private var isShowingGallery: Bool = false
    @State private var isShowingMyCode: Bool = false
    @State private var showCameraDeniedAlert: Bool = false
    @State private var didScan: Bool = false
    @State private var showNoQRCodeAlert: Bool = false
    @State private var isCameraReady: Bool = false
    @State private var cameraLoadFailed: Bool = false
    @State private var scanningImage: Bool = false
    @State private var scannedCode: String? = nil
    @State private var photoPickerItems: [PhotosPickerItem] = []

    var body: some View {
            ZStack {
                // Camera view
                if !cameraLoadFailed {
                    QRScannerViewControllerRepresentable(
                        torchOn: torchOn,
                        onCodeScanned: { code in
                            scannedCode = code
                            didScan = true
                            onScanned(code)
                        },
                        onCameraReady: {
                            isCameraReady = true
                        },
                        onCameraFailed: {
                            cameraLoadFailed = true
                        },
                        onCameraDenied: {
                            showCameraDeniedAlert = true
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
                            isShowingGallery = true
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
                            // Dismiss the view
                            // In a real implementation, this would dismiss the sheet
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
                            torchOn.toggle()
                        }) {
                            Image(systemName: torchOn ? "bolt.fill" : "bolt.slash")
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
                            isShowingGallery = true
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
                            isShowingMyCode = true
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
            .alert("Camera Access Denied", isPresented: $showCameraDeniedAlert) {
                Button("Cancel", role: .cancel) {
                    // Dismiss the view
                    // In a real implementation, this would dismiss the sheet
                }
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text("Please allow camera access in Settings to scan QR codes.")
            }
            .alert("No QR Code Found", isPresented: $showNoQRCodeAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The selected image does not contain a valid QR code.")
            }
            .photosPicker(
                isPresented: $isShowingGallery,
                selection: $photoPickerItems,
                matching: .images
            )
            .onChange(of: photoPickerItems) { items in
                if let item = items.first {
                    // Process the selected photo
                    scanningImage = true

                    // This would be handled in a real implementation
                    // For now, just show the no QR code alert
                    scanningImage = false
                    showNoQRCodeAlert = true
                    photoPickerItems = []
                }
            }
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
        onScanned: { _ in }
    )
}