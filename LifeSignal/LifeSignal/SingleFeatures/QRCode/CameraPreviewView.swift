import SwiftUI
import AVFoundation

@available(iOS 16.0, *)
struct CameraPreview: UIViewRepresentable {
    @MainActor let onScanned: @Sendable (String) -> Void
    @Binding var torchOn: Bool
    @Binding var isCameraReady: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        context.coordinator.setupCamera(in: view) { success in
            Task { @MainActor in
                self.isCameraReady = success
            }
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.updateTorch(torchOn)
        if let previewLayer = context.coordinator.previewLayer {
            previewLayer.frame = uiView.bounds
        }
    }

    @MainActor
    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate, @unchecked Sendable {
        let parent: CameraPreview
        let session = AVCaptureSession()
        var previewLayer: AVCaptureVideoPreviewLayer?
        var torchDevice: AVCaptureDevice?

        init(parent: CameraPreview) {
            self.parent = parent
            super.init()
        }

        func setupCamera(in view: UIView, completion: @Sendable @escaping (Bool) -> Void) {
            guard previewLayer == nil else {
                Task { @MainActor in
                    completion(true)
                }
                return
            }

            Task.detached { [weak self] in
                guard let self = self else { return }
                guard let device = AVCaptureDevice.default(for: .video) else {
                    await MainActor.run {
                        completion(false)
                    }
                    return
                }

                await MainActor.run {
                    self.torchDevice = device
                }

                let input = try? AVCaptureDeviceInput(device: device)
                let output = AVCaptureMetadataOutput()

                await MainActor.run {
                    if let input = input, self.session.canAddInput(input) {
                        self.session.addInput(input)
                    }
                    if self.session.canAddOutput(output) {
                        self.session.addOutput(output)
                        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                        output.metadataObjectTypes = [.qr]
                    }
                    self.session.startRunning()

                    let previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
                    previewLayer.videoGravity = .resizeAspectFill
                    previewLayer.frame = view.bounds
                    self.previewLayer = previewLayer
                    view.layer.addSublayer(previewLayer)
                    completion(true)
                }
            }
        }

        func updateTorch(_ on: Bool) {
            guard let device = torchDevice, device.hasTorch else { return }
            do {
                try device.lockForConfiguration()
                device.torchMode = on ? .on : .off
                device.unlockForConfiguration()
            } catch {}
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            if let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject, let str = obj.stringValue {
                Task { @MainActor in
                    parent.onScanned(str)
                    session.stopRunning()
                }
            }
        }
    }
}
