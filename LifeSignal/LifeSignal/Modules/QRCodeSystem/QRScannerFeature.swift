import Foundation
import ComposableArchitecture
import SwiftUI
import PhotosUI
import Dependencies
import UIKit

/// Shared QR code state between QRScannerFeature and AddContactFeature
struct QRCodeSharedState: Equatable, Sendable {
    /// The scanned QR code
    var qrCode: String = ""

    /// The last scan timestamp - useful for tracking when the QR code was last updated
    var lastScanTimestamp: Date = Date.distantPast
}

/// Feature for QR code scanning functionality - UI state only
@Reducer
struct QRScannerFeature {
    /// The state of the QR scanner feature
    @ObservableState
    struct State: Equatable, Sendable {
        /// Whether to show the scanner sheet
        var showScanner: Bool = false

        /// Whether the torch is on
        var torchOn: Bool = false

        /// Whether the gallery picker is showing
        var isShowingGallery: Bool = false

        /// Whether the user's QR code is showing
        var isShowingMyCode: Bool = false

        /// Whether the camera is ready
        var isCameraReady: Bool = false

        /// Whether the camera failed to load
        var cameraLoadFailed: Bool = false

        /// Whether a QR code is being processed
        var isProcessingQRCode: Bool = false

        /// Alert to show
        var alert: AlertState<Action>?

        /// State for no QR code alert
        var showNoQRCodeAlert: Bool = false

        /// Gallery assets for the carousel
        var galleryAssets: [PHAsset] = []

        /// Gallery thumbnails for the carousel
        var galleryThumbnails: [UIImage?] = []

        /// Selected gallery index
        var selectedGalleryIndex: Int? = nil

        /// Shared QR code state with AddContactFeature
        @Shared(.inMemory("scannedQRCode")) var qrCodeShared = QRCodeSharedState()

        /// Initialize with default values
        init() {}

        /// Computed property to determine if a QR code has been scanned
        var qrCodeScanned: Bool {
            return !qrCodeShared.qrCode.isEmpty && qrCodeShared.lastScanTimestamp != Date.distantPast
        }
    }

    /// Actions that can be performed on the QR scanner feature
    enum Action: BindableAction, Equatable, Sendable {
        /// Binding action
        case binding(BindingAction<State>)

        // MARK: - Camera Actions

        /// Toggle the torch
        case toggleTorch

        /// Initialize camera
        case initializeCamera

        /// Camera initialization result
        case cameraInitialized(Bool)

        /// Start scanning
        case startScanning

        /// Stop scanning
        case stopScanning

        /// Set up QR code handler
        case setupQRCodeHandler

        // MARK: - QR Code Actions

        /// QR code was scanned - will be handled by parent
        case qrCodeScanned(String)

        /// QR code was selected from gallery - will be handled by parent
        case qrCodeSelectedFromGallery(String?)

        /// Handle a scanned QR code
        case handleScannedQRCode(String)

        // MARK: - Gallery Actions

        /// Load gallery assets
        case loadGalleryAssets(Int)

        /// Gallery assets loaded
        case galleryAssetsLoaded([PHAsset])

        /// Load thumbnail for asset
        case loadThumbnail(PHAsset, CGSize, Int)

        /// Thumbnail loaded
        case thumbnailLoaded(UIImage?, Int)

        /// Load and process full image
        case loadAndProcessFullImage(PHAsset)

        /// Set selected gallery index
        case setSelectedGalleryIndex(Int)
    }

    /// Dependencies for the QR scanner feature
    @Dependency(\.qrCodeClient) var qrCodeClient

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.$showScanner):
                if !state.showScanner {
                    // Reset state when scanner is dismissed
                    state.torchOn = false
                    state.isShowingGallery = false
                    state.isShowingMyCode = false
                    state.alert = nil
                    state.showNoQRCodeAlert = false
                    state.selectedGalleryIndex = nil
                }
                return .none

            case .binding(\.$isShowingGallery):
                if !state.isShowingGallery {
                    // Reset selected gallery index when gallery is closed
                    state.selectedGalleryIndex = nil
                }
                return .none

            case .binding:
                // Handle other binding actions
                return .none

            case .toggleTorch:
                state.torchOn.toggle()

                // Use the QRCodeClient to toggle the torch
                return .run { [isOn = state.torchOn, qrCodeClient] _ in
                    await qrCodeClient.toggleTorch(isOn)
                }

            case .initializeCamera:
                return .run { [qrCodeClient] send in
                    // First set up the QR code handler
                    await send(.setupQRCodeHandler)

                    // Then initialize the camera
                    let success = await qrCodeClient.initializeCamera()
                    await send(.cameraInitialized(success))
                }

            case .setupQRCodeHandler:
                return .run { [qrCodeClient] send in
                    qrCodeClient.setQRCodeScannedHandler { code in
                        Task {
                            await send(.handleScannedQRCode(code))
                        }
                    }
                }

            case let .cameraInitialized(success):
                state.isCameraReady = success
                if !success {
                    state.cameraLoadFailed = true
                    return .none
                }

                // If camera initialized successfully, start scanning
                return .send(.startScanning)

            case .startScanning:
                return .run { [qrCodeClient] _ in
                    await qrCodeClient.startScanning()
                }

            case .stopScanning:
                return .run { [qrCodeClient] _ in
                    await qrCodeClient.stopScanning()
                }

            case let .qrCodeScanned(code):
                // Set processing state
                state.isProcessingQRCode = true

                // Update the shared QR code state with timestamp
                state.$qrCodeShared.withLock {
                    $0.qrCode = code
                    $0.lastScanTimestamp = Date()
                }

                // Reset processing state after a short delay
                return .run { send in
                    try await Task.sleep(for: .milliseconds(500))
                    await send(.binding(.set(\.$isProcessingQRCode, false)))
                }

            case let .qrCodeSelectedFromGallery(code):
                // Set processing state
                state.isProcessingQRCode = true

                // Update the shared QR code state if code is not nil
                if let code = code {
                    state.$qrCodeShared.withLock {
                        $0.qrCode = code
                        $0.lastScanTimestamp = Date()
                    }
                }

                // Reset processing state after a short delay
                return .run { send in
                    try await Task.sleep(for: .milliseconds(500))
                    await send(.binding(.set(\.$isProcessingQRCode, false)))
                }

            case let .handleScannedQRCode(code):
                // Validate the QR code format
                guard !code.isEmpty else {
                    // Handle empty QR code
                    return .send(.binding(.set(\.$showNoQRCodeAlert, true)))
                }

                // Update the shared QR code state
                state.$qrCodeShared.withLock {
                    $0.qrCode = code
                    $0.lastScanTimestamp = Date()
                }

                // Close the scanner
                state.showScanner = false

                // Reset processing state after a short delay
                return .run { [code] send in
                    try await Task.sleep(for: .milliseconds(500))
                    await send(.binding(.set(\.$isProcessingQRCode, false)))

                    // This action will be handled by the parent to show the add contact sheet
                    await send(.qrCodeScanned(code))
                }

            // MARK: - Gallery Actions

            case let .loadGalleryAssets(fetchLimit):
                return .run { [qrCodeClient] send in
                    let assets = await qrCodeClient.loadRecentPhotos(fetchLimit)
                    await send(.galleryAssetsLoaded(assets))
                }

            case let .galleryAssetsLoaded(assets):
                state.galleryAssets = assets
                state.galleryThumbnails = Array<UIImage?>(repeating: nil, count: assets.count)

                // Request thumbnails for each asset
                return .run { [assets] send in
                    for (i, asset) in assets.enumerated() {
                        await send(.loadThumbnail(asset, CGSize(width: 80, height: 80), i))
                    }
                }

            case let .loadThumbnail(asset, size, index):
                return .run { [qrCodeClient] send in
                    let thumbnail = await qrCodeClient.loadThumbnail(asset, size)
                    await send(.thumbnailLoaded(thumbnail, index))
                }

            case let .thumbnailLoaded(thumbnail, index):
                if index < state.galleryThumbnails.count {
                    var thumbnails = state.galleryThumbnails
                    thumbnails[index] = thumbnail
                    state.galleryThumbnails = thumbnails
                }
                return .none

            case let .loadAndProcessFullImage(asset):
                state.isProcessingQRCode = true

                return .run { [qrCodeClient] send in
                    if let image = await qrCodeClient.loadFullSizeImage(asset) {
                        if let qrCode = qrCodeClient.scanQRCode(image) {
                            // QR code found, handle it
                            await send(.handleScannedQRCode(qrCode))
                        } else {
                            // No QR code found
                            await send(.binding(.set(\.$showNoQRCodeAlert, true)))
                            await send(.binding(.set(\.$isProcessingQRCode, false)))
                        }
                    } else {
                        // Failed to load image
                        await send(.binding(.set(\.$showNoQRCodeAlert, true)))
                        await send(.binding(.set(\.$isProcessingQRCode, false)))
                    }
                }

            case let .setSelectedGalleryIndex(index):
                state.selectedGalleryIndex = index
                return .none
            }
        }
    }
}
