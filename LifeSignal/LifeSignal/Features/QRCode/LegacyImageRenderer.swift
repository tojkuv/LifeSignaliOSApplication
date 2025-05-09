import SwiftUI

struct LegacyImageRenderer {
    let content: AnyView
    var uiImage: UIImage? {
        let controller = UIHostingController(rootView: content)
        let view = controller.view
        let targetSize = CGSize(width: 300, height: 300)
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            view?.drawHierarchy(in: view?.bounds ?? .zero, afterScreenUpdates: true)
        }
    }
}
