import Foundation
import UIKit
import Vision
import AVFoundation
import CoreImage
import Dependencies
import ComposableArchitecture
import Photos

/// A client for QR code functionality (scanning, camera operations, and QR code generation)
@DependencyClient
struct QRCodeClient {
    // MARK: - QR Code Scanning

    /// Scan a QR code from a UIImage
    var scanQRCode: @Sendable (UIImage) -> String?

    /// Initialize the camera for QR scanning
    var initializeCamera: @Sendable () async -> Bool

    /// Start scanning for QR codes
    var startScanning: @Sendable () async -> Void

    /// Stop scanning for QR codes
    var stopScanning: @Sendable () async -> Void

    /// Toggle the torch
    var toggleTorch: @Sendable (Bool) async -> Void

    /// Set the QR code scanned handler
    var setQRCodeScannedHandler: @Sendable (@escaping @Sendable (String) -> Void) -> Void

    // MARK: - Photo Library Access

    /// Load recent photos from the photo library
    var loadRecentPhotos: @Sendable (Int) async -> [PHAsset]

    /// Load a thumbnail for a photo asset
    var loadThumbnail: @Sendable (PHAsset, CGSize) async -> UIImage?

    /// Load a full-size image for a photo asset
    var loadFullSizeImage: @Sendable (PHAsset) async -> UIImage?

    // MARK: - QR Code Generation

    /// Generate a QR code image from a string
    var generateQRCode: @Sendable (String, CGFloat, UIColor, UIColor) -> UIImage?

    /// Generate a QR code image with the app's branding
    var generateBrandedQRCode: @Sendable (String, CGFloat) -> UIImage?

    /// Share a QR code using UIActivityViewController
    var shareQRCode: @Sendable (String) async -> Void
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
            cameraController.onQRCodeScanned = handler
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

        client.loadThumbnail = { @Sendable asset, size in
            return await withCheckedContinuation { continuation in
                let options = PHImageRequestOptions()
                options.deliveryMode = .opportunistic
                options.resizeMode = .exact

                imageManager.requestImage(
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

                imageManager.requestImage(
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

        client.generateBrandedQRCode = { @Sendable string, size in
            // Generate the basic QR code with app colors
            return client.generateQRCode(string, size, .white, .blue)
        }

        client.shareQRCode = { @Sendable qrCodeId in
            if let qrCodeImage = client.generateBrandedQRCode(qrCodeId, 1024) {
                let activityVC = UIActivityViewController(activityItems: [qrCodeImage], applicationActivities: nil)
                await MainActor.run {
                    UIApplication.shared.windows.first?.rootViewController?.present(activityVC, animated: true, completion: nil)
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

            for result in results where result is VNBarcodeObservation {
                guard let barcode = result as? VNBarcodeObservation,
                      let payload = barcode.payloadStringValue,
                      barcode.symbology == .qr else {
                    continue
                }

                return payload
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
@MainActor
final class QRScannerController: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    /// The capture session for the camera
    private var captureSession: AVCaptureSession?

    /// The preview layer for the camera
    private var previewLayer: AVCaptureVideoPreviewLayer?

    /// The scanning area view
    private var scanningAreaView: UIView?

    /// Flag indicating if the scanner is running
    private var isRunning = false

    /// The device used for the torch
    private var torchDevice: AVCaptureDevice?

    /// Callback for when a QR code is scanned
    var onQRCodeScanned: @Sendable ((String) -> Void)?

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
                self?.isRunning = true
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
                self?.isRunning = false
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
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
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

            // Stop scanning
            Task {
                await stopScanning()

                // Notify callback
                if let onQRCodeScanned = onQRCodeScanned {
                    onQRCodeScanned(stringValue)
                }
            }

            // Only process the first valid QR code
            break
        }
    }
}
