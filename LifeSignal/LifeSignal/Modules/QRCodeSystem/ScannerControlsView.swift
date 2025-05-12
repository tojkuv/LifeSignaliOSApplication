import SwiftUI
import ComposableArchitecture

/// A SwiftUI view for displaying the scanner controls overlay
struct ScannerControlsView: View {
    /// The store for the QR scanner feature
    @Bindable var store: StoreOf<QRScannerFeature>
    
    var body: some View {
        VStack {
            HStack {
                // Close button
                Button(action: {
                    // Dismiss the scanner
                    store.send(.binding(.set(\.$showScanner, false)))
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
                    store.send(.toggleTorch)
                }) {
                    Image(systemName: store.torchOn ? "bolt.fill" : "bolt.slash")
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
                    store.send(.binding(.set(\.$isShowingGallery, true)))
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
                    store.send(.binding(.set(\.$isShowingMyCode, true)))
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
}
