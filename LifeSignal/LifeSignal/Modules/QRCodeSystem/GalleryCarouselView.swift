import SwiftUI
import Photos
import UIKit
import ComposableArchitecture

/// A view for displaying a gallery of recent images
struct GalleryCarouselView: View {
    /// The store for the QR scanner feature
    let store: StoreOf<QRScannerFeature>

    // Constants
    private let thumbnailSize = CGSize(width: 80, height: 80)
    private let fetchLimit = 15

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(store.galleryAssets.indices, id: \.self) { idx in
                    let image = store.galleryThumbnails[safe: idx] ?? nil
                    ZStack {
                        if let image = image {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipped()
                                .padding(.vertical, 5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(store.selectedGalleryIndex == idx ? Color.blue : Color.clear, lineWidth: 3)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    store.send(.setSelectedGalleryIndex(idx))
                                    // Send action to feature to load and process the full image
                                    store.send(.loadAndProcessFullImage(store.galleryAssets[idx]))
                                }
                        } else {
                            Rectangle()
                                .foregroundColor(.gray.opacity(0.2))
                                .frame(width: 80, height: 80)
                        }
                    }
                }
            }
            .padding(.horizontal, 15)
        }
        .frame(height: 90)
        .onAppear {
            // Send action to feature to load assets if needed
            if store.galleryAssets.isEmpty {
                store.send(.loadGalleryAssets(fetchLimit))
            }
        }
    }
}

// Extension to safely access array elements
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
