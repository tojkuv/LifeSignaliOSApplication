import SwiftUI
import ComposableArchitecture
import UIKit

/// A SwiftUI view for sharing content using TCA
struct ShareSheetView: View {
    /// The store for the share feature
    let store: StoreOf<ShareFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            if let image = viewStore.qrCodeImage {
                ShareSheet(items: [QRCodeActivityItemSource(image: image, title: viewStore.title)])
                    .onDisappear {
                        viewStore.send(.dismiss)
                    }
            }
        }
    }
}

/// A UIViewControllerRepresentable for sharing content
struct ShareSheet: UIViewControllerRepresentable {
    /// The items to share
    let items: [Any]

    /// Create the UIActivityViewController
    /// - Parameter context: The context
    /// - Returns: A UIActivityViewController
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    /// Update the UIActivityViewController
    /// - Parameters:
    ///   - uiViewController: The UIActivityViewController
    ///   - context: The context
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Activity item source for QR code sharing
class QRCodeActivityItemSource: NSObject, UIActivityItemSource {
    let image: UIImage
    let title: String

    init(image: UIImage, title: String) {
        self.image = image
        self.title = title
        super.init()
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return image
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return image
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return title
    }
}

/// A SwiftUI view for sharing content using TCA (convenience initializer)
extension ShareSheetView {
    /// Initialize with QR code image and title
    /// - Parameters:
    ///   - qrCodeImage: The QR code image to share
    ///   - title: The title for the shared content
    init(qrCodeImage: UIImage, title: String) {
        self.store = Store(initialState: ShareFeature.State(qrCodeImage: qrCodeImage, title: title), reducer: {
            ShareFeature()
        })
    }
}

#Preview {
    if let image = UIImage(systemName: "qrcode") {
        ShareSheetView(qrCodeImage: image, title: "Test QR Code")
    } else {
        Text("Preview not available")
    }
}
