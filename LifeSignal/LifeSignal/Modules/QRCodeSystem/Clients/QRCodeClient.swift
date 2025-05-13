import Foundation
import UIKit
import Vision
@preconcurrency import AVFoundation
import CoreImage
import Dependencies
import ComposableArchitecture
@preconcurrency import Photos

/// A client for QR code functionality (scanning, camera operations, and QR code generation)
@DependencyClient
struct QRCodeClient {
    // MARK: - QR Code Scanning

    /// Scan a QR code from a UIImage
    var scanQRCode: @Sendable (UIImage) -> String? = { _ in nil }

    /// Initialize the camera for QR scanning
    var initializeCamera: @Sendable () async -> Bool = { false }

    /// Start scanning for QR codes
    var startScanning: @Sendable () async -> Void = { }

    /// Stop scanning for QR codes
    var stopScanning: @Sendable () async -> Void = { }

    /// Toggle the torch
    var toggleTorch: @Sendable (Bool) async -> Void = { _ in }

    /// Set the QR code scanned handler
    var setQRCodeScannedHandler: @Sendable (@escaping @Sendable (String) -> Void) -> Void = { _ in }

    // MARK: - Photo Library Access

    /// Load recent photos from the photo library
    var loadRecentPhotos: @Sendable (Int) async -> [PHAsset] = { _ in [] }

    /// Load a thumbnail for a photo asset
    var loadThumbnail: @Sendable (PHAsset, CGSize) async -> UIImage? = { _, _ in nil }

    /// Load a full-size image for a photo asset
    var loadFullSizeImage: @Sendable (PHAsset) async -> UIImage? = { _ in nil }

    // MARK: - QR Code Generation

    /// Generate a QR code image from a string
    var generateQRCode: @Sendable (String, CGFloat, UIColor, UIColor) -> UIImage? = { _, _, _, _ in nil }

    /// Generate a QR code image with the app's branding
    var generateBrandedQRCode: @Sendable (String, CGFloat) -> UIImage? = { _, _ in nil }

    /// Share a QR code using UIActivityViewController
    var shareQRCode: @Sendable (String) async -> Void = { _ in }
}

// MARK: - DependencyKey Conformance

extension QRCodeClient: DependencyKey {
    static let liveValue: QRCodeClient = {
        // Create a camera controller for QR scanning
        let cameraController = QRScannerController()
        let imageManager = PHCachingImageManager()

        var client = QRCodeClient()

        // MARK: - QR Code Scanning Implementation

        client.scanQRCode = { image in
            // Try Vision framework first
            if let qrCode = scanQRCodeUsingVision(from: image) {
                return qrCode
            }

            // Fall back to CIDetector
            return extractQRCode(from: image)
        }

        client.initializeCamera = { @Sendable in
            await cameraController.initialize()
        }

        client.startScanning = { @Sendable in
            await cameraController.startScanning()
        }

        client.stopScanning = { @Sendable in
            await cameraController.stopScanning()
        }

        client.toggleTorch = { @Sendable isOn in
            await cameraController.toggleTorch(isOn: isOn)
        }

        client.setQRCodeScannedHandler = { @Sendable handler in
            Task { @MainActor in
                cameraController.onQRCodeScanned = handler
            }
        }

        // MARK: - Photo Library Access Implementation

        client.loadRecentPhotos = { @Sendable fetchLimit in
            return await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization { status in
                    guard status == .authorized || status == .limited else {
                        continuation.resume(returning: [])
                        return
                    }

                    let fetchOptions = PHFetchOptions()
                    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                    fetchOptions.fetchLimit = fetchLimit
                    let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)

                    var assets: [PHAsset] = []
                    result.enumerateObjects { asset, _, _ in
                        assets.append(asset)
                    }

                    continuation.resume(returning: assets)
                }
            }
        }

        // Create a local copy of the image manager to avoid capturing the non-Sendable type
        let localImageManager = PHCachingImageManager()

        client.loadThumbnail = { @Sendable asset, size in
            return await withCheckedContinuation { continuation in
                let options = PHImageRequestOptions()
                options.deliveryMode = .opportunistic
                options.resizeMode = .exact

                // Use the local copy instead of capturing the outer variable
                localImageManager.requestImage(
                    for: asset,
                    targetSize: size,
                    contentMode: .aspectFill,
                    options: options
                ) { image, _ in
                    continuation.resume(returning: image)
                }
            }
        }

        client.loadFullSizeImage = { @Sendable asset in
            return await withCheckedContinuation { continuation in
                let options = PHImageRequestOptions()
                options.isSynchronous = false
                options.deliveryMode = .highQualityFormat

                // Use the local copy instead of capturing the outer variable
                localImageManager.requestImage(
                    for: asset,
                    targetSize: PHImageManagerMaximumSize,
                    contentMode: .aspectFill,
                    options: options
                ) { image, _ in
                    continuation.resume(returning: image)
                }
            }
        }

        // MARK: - QR Code Generation Implementation

        client.generateQRCode = { @Sendable string, size, backgroundColor, foregroundColor in
            // Create a QR code generator
            guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
                return nil
            }

            // Set the message to encode
            let data = string.data(using: .utf8)
            filter.setValue(data, forKey: "inputMessage")

            // Set the error correction level
            filter.setValue("M", forKey: "inputCorrectionLevel")

            // Get the output image
            guard let ciImage = filter.outputImage else {
                return nil
            }

            // Scale the image to the desired size
            let scale = size / ciImage.extent.width
            let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

            // Create a colored version of the QR code
            let colorParameters = [
                "inputImage": scaledImage,
                "inputColor0": CIColor(color: backgroundColor),
                "inputColor1": CIColor(color: foregroundColor)
            ]

            guard let coloredQRCode = CIFilter(name: "CIFalseColor", parameters: colorParameters)?.outputImage else {
                // If coloring fails, return the black and white version
                return UIImage(ciImage: scaledImage)
            }

            // Convert to UIImage
            let context = CIContext()
            guard let cgImage = context.createCGImage(coloredQRCode, from: coloredQRCode.extent) else {
                return nil
            }

            return UIImage(cgImage: cgImage)
        }

        // Create a local copy of the generateQRCode function to avoid capturing 'client'
        let generateQRCode = client.generateQRCode

        client.generateBrandedQRCode = { @Sendable string, size in
            // Generate the basic QR code with app colors
            // This is a synchronous function
            return generateQRCode(string, size, .white, .blue)
        }

        // Create a local copy of the generateBrandedQRCode function to avoid capturing 'client'
        let generateBrandedQRCode = client.generateBrandedQRCode

        client.shareQRCode = { @Sendable qrCodeId in
            // The generateBrandedQRCode function is synchronous, so no await is needed
            if let qrCodeImage = generateBrandedQRCode(qrCodeId, 1024) {
                // Move all UI operations to the MainActor
                await MainActor.run {
                    // Create UIActivityViewController on the main thread
                    let activityVC = UIActivityViewController(activityItems: [qrCodeImage], applicationActivities: nil)

                    // Use UIWindowScene.windows instead of the deprecated UIApplication.shared.windows
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootViewController = windowScene.windows.first?.rootViewController {
                        // present is not async in UIKit, so no await is needed
                        rootViewController.present(activityVC, animated: true, completion: nil)
                    }
                }
            }
        }

        return client
    }()

    /// Scan a QR code using Vision framework
    private static func scanQRCodeUsingVision(from image: UIImage) -> String? {
        guard let cgImage = image.cgImage else {
            return nil
        }

        let request = VNDetectBarcodesRequest()
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try requestHandler.perform([request])

            guard let results = request.results else {
                return nil
            }

            // Process each result to find QR codes
            for result in results {
                // First check if this is a barcode observation
                if result is VNBarcodeObservation {
                    // Safe to force cast since we've checked the type
                    let barcode = result as! VNBarcodeObservation
                    // Check if it's a QR code with a valid payload
                    if barcode.symbology == .qr, let payload = barcode.payloadStringValue {
                        return payload
                    }
                }
            }

            return nil
        } catch {
            print("Vision framework error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Extract string from a QR code in an image using CIDetector
    private static func extractQRCode(from image: UIImage) -> String? {
        guard let ciImage = CIImage(image: image) else {
            return nil
        }

        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        guard let features = detector?.features(in: ciImage) as? [CIQRCodeFeature] else {
            return nil
        }

        return features.first?.messageString
    }



    /// A test implementation that returns predefined values
    static let testValue = Self(
        // QR Code Scanning
        scanQRCode: { _ in "test-qr-code" },
        initializeCamera: { true },
        startScanning: { },
        stopScanning: { },
        toggleTorch: { _ in },
        setQRCodeScannedHandler: { _ in },

        // Photo Library Access
        loadRecentPhotos: { _ in [] },
        loadThumbnail: { _, _ in nil },
        loadFullSizeImage: { _ in nil },

        // QR Code Generation
        generateQRCode: { _, _, _, _ in nil },
        generateBrandedQRCode: { _, _ in nil },
        shareQRCode: { _ in }
    )
}

// MARK: - DependencyValues Extension

extension DependencyValues {
    var qrCodeClient: QRCodeClient {
        get { self[QRCodeClient.self] }
        set { self[QRCodeClient.self] = newValue }
    }
}

// MARK: - QRScannerController

/// Controller for QR code scanning functionality
// Using @unchecked Sendable because we're manually ensuring thread safety
final class QRScannerController: NSObject, AVCaptureMetadataOutputObjectsDelegate, @unchecked Sendable {
    /// The capture session for the camera
    private var captureSession: AVCaptureSession?

    /// The preview layer for the camera
    private var previewLayer: AVCaptureVideoPreviewLayer?

    /// The scanning area view
    private var scanningAreaView: UIView?

    /// Flag indicating if the scanner is running
    @MainActor private var isRunning = false

    /// The device used for the torch
    private var torchDevice: AVCaptureDevice?

    /// Callback for when a QR code is scanned
    @MainActor var onQRCodeScanned: ((String) -> Void)?

    /// Initialize the camera for QR scanning
    func initialize() async -> Bool {
        // Create a capture session
        let captureSession = AVCaptureSession()
        self.captureSession = captureSession

        // Check camera authorization status
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Already authorized, continue setup
            return await setupCaptureSession(captureSession)
        case .notDetermined:
            // Request authorization
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }

            if granted {
                // Authorization granted, continue setup
                return await setupCaptureSession(captureSession)
            } else {
                // Authorization denied
                return false
            }
        case .denied, .restricted:
            // Authorization denied or restricted
            return false
        @unknown default:
            // Unknown status
            return false
        }
    }

    /// Setup the capture session
    private func setupCaptureSession(_ captureSession: AVCaptureSession) async -> Bool {
        // Get the default video device
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            return false
        }

        self.torchDevice = videoCaptureDevice

        // Create a video input
        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return false
        }

        // Add the video input to the session
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            return false
        }

        // Create a metadata output
        let metadataOutput = AVCaptureMetadataOutput()

        // Add the metadata output to the session
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)

            // Set the metadata delegate
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            return false
        }

        // Start the session
        await startScanning()
        return true
    }

    /// Start scanning for QR codes
    func startScanning() async {
        guard let captureSession = captureSession, !captureSession.isRunning else {
            return
        }

        // Start the session on a background thread
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                captureSession.startRunning()
                Task { @MainActor [weak self] in
                    self?.isRunning = true
                }
                continuation.resume()
            }
        }
    }

    /// Stop scanning for QR codes
    func stopScanning() async {
        guard let captureSession = captureSession, captureSession.isRunning else {
            return
        }

        // Stop the session on a background thread
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                captureSession.stopRunning()
                Task { @MainActor [weak self] in
                    self?.isRunning = false
                }
                continuation.resume()
            }
        }
    }

    /// Toggle the torch
    func toggleTorch(isOn: Bool) async {
        guard let device = torchDevice, device.hasTorch else {
            return
        }

        do {
            try device.lockForConfiguration()

            // Check if the torch is available
            if device.isTorchAvailable {
                device.torchMode = isOn ? .on : .off
            }

            device.unlockForConfiguration()
        } catch {
            print("Failed to configure torch: \(error.localizedDescription)")
        }
    }

    /// Called when metadata objects are captured
    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Check if we have a QR code
        for metadataObject in metadataObjects {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
                  let stringValue = readableObject.stringValue,
                  readableObject.type == .qr,
                  !stringValue.isEmpty else {
                continue
            }

            // We found a valid QR code
            print("QR code scanned: \(stringValue)")

            // Stop scanning and notify callback on the main actor
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                await self.stopScanning()

                // Notify callback
                if let onQRCodeScanned = self.onQRCodeScanned {
                    onQRCodeScanned(stringValue)
                }
            }

            // Only process the first valid QR code
            break
        }
    }
}
