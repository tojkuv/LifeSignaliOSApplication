import SwiftUI
import AVFoundation
import PhotosUI
import Vision
import Photos
import UIKit

struct QRScannerView: View {
    let onScanned: (String) -> Void
    @Environment(\.presentationMode) private var presentationMode
    @State private var torchOn = false
    @State private var isShowingGallery = false
    @State private var isShowingMyCode = false
    @State private var showCameraDeniedAlert = false
    @State private var didScan = false
    @State private var showNoQRCodeAlert = false
    @State private var isCameraReady = false
    @State private var cameraLoadFailed = false
    @State private var scanningImage = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CameraPreview(onScanned: { code in
                    if !didScan {
                        didScan = true
                        triggerHaptic()
                        onScanned(code)
                        presentationMode.wrappedValue.dismiss()
                    }
                }, torchOn: $torchOn, isCameraReady: $isCameraReady)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .accessibility(hidden: true)


                VStack {
                    HStack {
                        Button(action: { isShowingGallery = true }) {
                            Image(systemName: "photo")
                                .font(.system(size: 22))
                                .padding(16)
                                .clipShape(Circle())
                                .foregroundColor(.white)
                                .accessibilityLabel("Open photo gallery")
                        }
                        Spacer()
                        Button(action: { torchOn.toggle() }) {
                            Image(systemName: torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(torchOn ? .yellow : .white)
                                .padding(16)
                                .accessibilityLabel(torchOn ? "Turn off flashlight" : "Turn on flashlight")
                        }
                    }
                    .padding(.top, geometry.safeAreaInsets.top)

                    Spacer()

                    // Animated instruction text
                    AnimatedPromptText(text: "Scan or upload a LifeSignal QR code")

                    GalleryCarousel(onImageSelected: { image in
                            scanningImage = true
                            detectQRCode(in: image)
                    })
                    .frame(height: 150)

                    HStack {
                        Spacer()
                        Button(action: { isShowingMyCode = true }) {
                            Text("My code")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 36)
                                .padding(.vertical, 12)
                                .background(Color.black.opacity(0.3))
                                .clipShape(Capsule())
                                .accessibilityLabel("Show my QR code")
                        }
                        Spacer()
                    }
                }
                .padding(.bottom, geometry.safeAreaInsets.bottom)
                .padding(.horizontal, 0)

                // Loading and error overlays
                if !isCameraReady && !cameraLoadFailed {
                    ProgressView("Loading camera…")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.8))
                        .ignoresSafeArea()
                }
                if cameraLoadFailed {
                    VStack(spacing: 24) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.yellow)
                        Text("Camera failed to load.")
                            .font(.title3)
                            .foregroundColor(.white)
                        Button("Retry") {
                            cameraLoadFailed = false
                            isCameraReady = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isCameraReady = false
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.8))
                    .ignoresSafeArea()
                }

                if scanningImage {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    ProgressView("Scanning image…")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                }
            }
        }
        .sheet(isPresented: $isShowingGallery) {
            PhotoPicker { image in
                isShowingGallery = false
                if let image = image {
                    detectQRCode(in: image)
                }
            }
        }
        .sheet(isPresented: $isShowingMyCode) {
            MyQRCodeSheet()
        }
        .alert(isPresented: $showCameraDeniedAlert) {
            Alert(
                title: Text("Camera Access Denied"),
                message: Text("Please enable camera access in Settings to scan QR codes."),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $showNoQRCodeAlert) {
            Alert(
                title: Text("No QR Code Found"),
                message: Text("No QR code was detected in the selected image."),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if !granted {
                    showCameraDeniedAlert = true
                }
            }
            // Timeout fallback: if camera not ready in 5 seconds, show error
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if !isCameraReady {
                    cameraLoadFailed = true
                }
            }
        }
    }

    private func detectQRCode(in image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        let request = VNDetectBarcodesRequest { request, error in
            if let results = request.results as? [VNBarcodeObservation], let qr = results.first(where: { $0.symbology == .qr }), let payload = qr.payloadStringValue {
                triggerHaptic()
                onScanned(payload)
                presentationMode.wrappedValue.dismiss()
            } else {
                showNoQRCodeAlert = true
            }
            scanningImage = false
        }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }
}

struct MyQRCodeSheet: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var userProfileViewModel: UserProfileViewModel
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(16)
                        .accessibilityLabel("Close")
                }
            }
            QRCodeCardView(
                name: userProfileViewModel.name,
                subtitle: "LifeSignal contact",
                qrCodeId: userProfileViewModel.qrCodeId,
                footer: "Let others scan this code to add you as a contact."
            )
            .padding(.top, 8)
            Spacer()
        }
        .padding()
    }
}

struct PhotoPicker: UIViewControllerRepresentable {
    var onImagePicked: (UIImage?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        init(_ parent: PhotoPicker) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
                self.parent.onImagePicked(nil)
                return
            }
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async {
                    self.parent.onImagePicked(image as? UIImage)
                }
            }
        }
    }
}

// Animated text prompt that fades in and out
struct AnimatedPromptText: View {
    let text: String
    @State private var opacity: Double = 0.0

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .cornerRadius(20)
            .opacity(opacity)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    opacity = 0.6
                }
            }
            .accessibilityLabel(text)
    }
}