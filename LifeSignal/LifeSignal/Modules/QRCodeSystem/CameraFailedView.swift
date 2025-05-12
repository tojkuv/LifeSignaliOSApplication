import SwiftUI
import ComposableArchitecture

/// A SwiftUI view for displaying when the camera fails to load
struct CameraFailedView: View {
    /// The store for the QR scanner feature
    let store: StoreOf<QRScannerFeature>
    
    var body: some View {
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
                store.send(.binding(.set(\.$isShowingGallery, true)))
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
}
