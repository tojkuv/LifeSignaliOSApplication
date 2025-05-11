import SwiftUI
import UIKit

/// A SwiftUI view for sharing a QR code
struct QRCodeShareSheetView: View {
    /// The name to display
    let name: String

    /// The QR code ID to share
    let qrCodeId: String

    /// Callback for when the share sheet is dismissed
    let onDismiss: () -> Void

    /// State for UI controls
    @State private var showSystemShareSheet = false
    @State private var qrCodeImage: UIImage? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Share Your QR Code")
                    .font(.headline)
                    .padding(.top)

                Text("Let others scan this QR code to add you as a contact")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                QRCodeView(qrCodeId: qrCodeId, size: 250)
                    .padding()

                Text(name)
                    .font(.title3)
                    .fontWeight(.bold)

                Button(action: {
                    // Generate QR code image
                    qrCodeImage = QRCodeUtilities.generateQRCode(from: qrCodeId, size: 1024)
                    showSystemShareSheet = true
                }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationBarItems(trailing: Button("Done") {
                onDismiss()
            })
            .background(
                ShareSheetPresenter(
                    isPresented: $showSystemShareSheet,
                    content: {
                        if let image = qrCodeImage {
                            return [
                                QRCodeActivityItemView(
                                    image: image,
                                    title: "\(name)'s LifeSignal QR Code"
                                )
                            ]
                        }
                        return []
                    }
                )
            )
        }
    }
}

/// A UIViewControllerRepresentable for presenting a share sheet
struct ShareSheetPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let content: () -> [Any]

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented {
            let activityItems = content()
            let activityViewController = UIActivityViewController(
                activityItems: activityItems,
                applicationActivities: nil
            )

            activityViewController.completionWithItemsHandler = { _, _, _, _ in
                isPresented = false
            }

            uiViewController.present(activityViewController, animated: true)
        }
    }
}

/// A custom activity item for sharing QR codes
struct QRCodeActivityItemView: UIActivityItemProvider {
    let image: UIImage
    let title: String

    override var item: Any {
        return image
    }

    override func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return image
    }

    override func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return title
    }
}

#Preview {
    QRCodeShareSheetView(
        name: "John Doe",
        qrCodeId: "12345678-1234-1234-1234-123456789012",
        onDismiss: {}
    )
}
