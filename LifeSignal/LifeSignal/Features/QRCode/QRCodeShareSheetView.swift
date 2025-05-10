import SwiftUI
import UIKit

/// QR Code sharing sheet view for displaying in a modal
struct QRCodeShareSheetView: View {
    let name: String
    let qrCodeId: String
    @Environment(\.presentationMode) var presentationMode

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
                    shareQRCode()
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
                presentationMode.wrappedValue.dismiss()
            })
        }
    }

    private func shareQRCode() {
        guard let qrImage = QRCodeGenerator.generateQRCode(from: qrCodeId, size: CGSize(width: 300, height: 300)) else {
            return
        }

        let activityItem = QRCodeActivityItem(
            image: qrImage,
            title: "\(name)'s LifeSignal QR Code"
        )

        let activityViewController = UIActivityViewController(
            activityItems: [activityItem],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityViewController, animated: true, completion: nil)
        }
    }
}

#Preview {
    QRCodeShareSheetView(
        name: "John Doe",
        qrCodeId: "12345678-1234-1234-1234-123456789012"
    )
}