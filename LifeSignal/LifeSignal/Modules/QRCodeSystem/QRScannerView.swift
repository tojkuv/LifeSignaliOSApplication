import SwiftUI
import AVFoundation
import PhotosUI
import Vision
import Photos
import UIKit
import ComposableArchitecture

/// A SwiftUI view for scanning QR codes using TCA
struct QRScannerView: View {
    /// The store for the QR scanner feature
    @Bindable var store: StoreOf<QRScannerFeature>

    /// The store for the add contact feature
    @Bindable var addContactStore: StoreOf<AddContactFeature>

    /// The store for the user feature (for QR code sharing)
    @Bindable var userStore: StoreOf<UserFeature>

    var body: some View {
        ZStack {
            // Camera view
            if !store.cameraLoadFailed {
                CameraPreviewView(store: store)
                    .edgesIgnoringSafeArea(.all)
            } else {
                CameraFailedView(store: store)
            }

            // Overlay
            ScannerControlsView(store: store)

            // Gallery carousel overlay when gallery is showing
            if store.isShowingGallery {
                VStack {
                    Spacer()

                    // Gallery carousel
                    GalleryCarouselView(store: store)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(10)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                }
            }

            // Loading overlay
            if store.isProcessingQRCode {
                LoadingOverlayView()
            }
        }
        .alert(
            title: { _ in Text("Camera Access Denied") },
            unwrapping: $store.alert,
            actions: { _ in
                Button("Cancel", role: .cancel) {
                    store.send(.binding(.set(\.$showScanner, false)))
                }
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            },
            message: { _ in
                Text("Please allow camera access in Settings to scan QR codes.")
            }
        )
        .alert("No QR Code Found", isPresented: $store.showNoQRCodeAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The selected image does not contain a valid QR code.")
        }
        .onChange(of: store.qrCodeScanned) { oldValue, newValue in
            // If a QR code was scanned, show the add contact sheet
            if newValue && !oldValue {
                addContactStore.send(.setSheetPresented(true))
            }
        }
        .sheet(
            isPresented: $store.isShowingMyCode
        ) {
            QRCodeSheetView(
                name: userStore.userData.name,
                qrCodeId: userStore.userData.qrCodeId,
                onDismiss: {
                    store.send(.binding(.set(\.$isShowingMyCode, false)))
                }
            )
        }
    }
}

/// Extension for QRScannerView with convenience initializers
extension QRScannerView {
    /// Initialize with a QR scanner store, add contact store, and user store
    /// - Parameters:
    ///   - store: The store for the QR scanner feature
    ///   - addContactStore: The store for the add contact feature
    ///   - userStore: The store for the user feature
    init(
        store: StoreOf<QRScannerFeature>,
        addContactStore: StoreOf<AddContactFeature>,
        userStore: StoreOf<UserFeature>
    ) {
        self._store = Bindable(wrappedValue: store)
        self._addContactStore = Bindable(wrappedValue: addContactStore)
        self._userStore = Bindable(wrappedValue: userStore)
    }
}
