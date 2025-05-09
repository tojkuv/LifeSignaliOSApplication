import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    var title: String = "Share QR Code"
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Convert UIImage to QRCodeActivityItem if present
        let items = activityItems.map { item -> Any in
            if let image = item as? UIImage {
                return QRCodeActivityItem(image: image, title: title)
            }
            return item
        }
        
        let controller = UIActivityViewController(activityItems: items, applicationActivities: applicationActivities)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
