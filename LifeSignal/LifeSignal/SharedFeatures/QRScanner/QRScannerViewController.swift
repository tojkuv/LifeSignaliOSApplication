import UIKit
import AVFoundation

/// Protocol for QR scanner view controller delegate
protocol QRScannerViewControllerDelegate: AnyObject {
    /// Called when QR scanning fails
    func qrScanningDidFail()
    
    /// Called when QR scanning succeeds with a code
    func qrScanningSucceededWithCode(_ code: String)
    
    /// Called when QR scanning stops
    func qrScanningDidStop()
    
    /// Called when QR scanning setup is complete
    func qrScanningDidSetup()
    
    /// Called when camera access is denied
    func qrScanningDidDeny()
}

/// View controller for QR code scanning
class QRScannerViewController: UIViewController {
    /// The capture session for the camera
    var captureSession: AVCaptureSession?
    
    /// The preview layer for the camera
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    /// The delegate for the QR scanner
    weak var delegate: QRScannerViewControllerDelegate?
    
    /// The scanning area view
    var scanningAreaView: UIView?
    
    /// Flag indicating if the scanner is running
    var isRunning = false
    
    /// View did load
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup the camera
        setupCamera()
    }
    
    /// View will appear
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Start the session if it's not running
        if let captureSession = captureSession, !captureSession.isRunning {
            captureSession.startRunning()
            isRunning = true
        }
    }
    
    /// View will disappear
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Stop the session if it's running
        if let captureSession = captureSession, captureSession.isRunning {
            captureSession.stopRunning()
            isRunning = false
        }
    }
    
    /// Setup the camera for QR code scanning
    private func setupCamera() {
        // Create a capture session
        let captureSession = AVCaptureSession()
        self.captureSession = captureSession
        
        // Check camera authorization status
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Already authorized, continue setup
            setupCaptureSession(captureSession)
        case .notDetermined:
            // Request authorization
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self = self else { return }
                
                if granted {
                    // Authorization granted, continue setup on main thread
                    DispatchQueue.main.async {
                        self.setupCaptureSession(captureSession)
                    }
                } else {
                    // Authorization denied
                    DispatchQueue.main.async {
                        self.delegate?.qrScanningDidDeny()
                    }
                }
            }
        case .denied, .restricted:
            // Authorization denied or restricted
            delegate?.qrScanningDidDeny()
        @unknown default:
            // Unknown status
            delegate?.qrScanningDidFail()
        }
    }
    
    /// Setup the capture session
    private func setupCaptureSession(_ captureSession: AVCaptureSession) {
        // Get the default video device
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            delegate?.qrScanningDidFail()
            return
        }
        
        // Create a video input
        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            delegate?.qrScanningDidFail()
            return
        }
        
        // Add the video input to the session
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            delegate?.qrScanningDidFail()
            return
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
            delegate?.qrScanningDidFail()
            return
        }
        
        // Create a preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.layer.bounds
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
        
        // Start the session
        captureSession.startRunning()
        isRunning = true
        
        // Notify the delegate that setup is complete
        delegate?.qrScanningDidSetup()
    }
}

/// Extension for AVCaptureMetadataOutputObjectsDelegate
extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    /// Called when metadata objects are captured
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Check if there are any metadata objects
        if let metadataObject = metadataObjects.first {
            // Check if the metadata object is a QR code
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            // Stop the session
            captureSession?.stopRunning()
            isRunning = false
            
            // Notify the delegate that scanning succeeded
            delegate?.qrScanningSucceededWithCode(stringValue)
        }
    }
}
