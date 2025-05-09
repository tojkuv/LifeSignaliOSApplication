import SwiftUI

struct ScannerView: UIViewControllerRepresentable {
    let onScanned: (String) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        UIHostingController(rootView: QRScannerView(onScanned: onScanned))
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

struct ModalPresenter<Content: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let content: () -> Content

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        context.coordinator.parent = controller
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented && context.coordinator.presentedController == nil {
            let modal = UIHostingController(rootView: content())
            modal.modalPresentationStyle = .fullScreen
            uiViewController.present(modal, animated: true) {
                context.coordinator.presentedController = modal
            }
        } else if !isPresented, let presented = context.coordinator.presentedController {
            presented.dismiss(animated: true) {
                context.coordinator.presentedController = nil
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    
    class Coordinator {
        weak var parent: UIViewController?
        weak var presentedController: UIViewController?
    }
}
