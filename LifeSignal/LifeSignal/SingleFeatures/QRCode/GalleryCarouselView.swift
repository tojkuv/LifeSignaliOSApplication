import SwiftUI
import Photos

// GalleryCarousel: Shows recent images from the photo library in a horizontal scroll view
struct GalleryCarousel: View {
    let onImageSelected: (UIImage) -> Void
    @State private var assets: [PHAsset] = []
    @State private var thumbnails: [UIImage?] = []
    @State private var selectedIndex: Int? = nil
    private let imageManager = PHCachingImageManager()
    private let thumbnailSize = CGSize(width: 80, height: 80)
    private let fetchLimit = 15
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(assets.indices, id: \.self) { idx in
                    let image = thumbnails[safe: idx] ?? nil
                    ZStack {
                        if let image = image {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipped()
                                .padding(.vertical, 5)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedIndex = idx
                                    requestFullImage(for: assets[idx])
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
        .onAppear(perform: loadAssets)
    }
    
    private func loadAssets() {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else { return }
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.fetchLimit = fetchLimit
            let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            var newAssets: [PHAsset] = []
            result.enumerateObjects { asset, _, _ in
                newAssets.append(asset)
            }
            let newThumbs = Array<UIImage?>(repeating: nil, count: newAssets.count)
            DispatchQueue.main.async {
                self.assets = newAssets
                self.thumbnails = newThumbs
            }
            for (i, asset) in newAssets.enumerated() {
                let options = PHImageRequestOptions()
                options.deliveryMode = .opportunistic
                options.resizeMode = .exact
                
                imageManager.requestImage(for: asset, targetSize: thumbnailSize, contentMode: .aspectFill, options: options) { image, _ in
                    DispatchQueue.main.async {
                        if i < self.thumbnails.count {
                            self.thumbnails[i] = image
                        }
                    }
                }
            }
        }
    }
    
    private func requestFullImage(for asset: PHAsset) {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        imageManager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFill, options: options) { image, _ in
            if let image = image {
                onImageSelected(image)
            }
        }
    }
}

// Safe subscript for arrays
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
