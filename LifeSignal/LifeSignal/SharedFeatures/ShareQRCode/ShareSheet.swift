import SwiftUI
import UIKit

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

#Preview {
    Text("ShareSheet cannot be previewed directly")
}
