import SwiftUI
import AVFoundation
import ComposableArchitecture

/// A UIViewRepresentable for displaying the camera preview and scanning QR codes
struct CameraPreviewView: UIViewRepresentable {
    /// The store for the QR scanner feature
    let store: StoreOf<QRScannerFeature>

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)

        // Initialize the camera through the feature
        store.send(.initializeCamera)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // No need to update torch state here as it's handled in the feature
    }

    class Coordinator {
        let parent: CameraPreviewView

        init(parent: CameraPreviewView) {
            self.parent = parent
        }
    }
}
