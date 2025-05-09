import SwiftUI
import UIKit

struct QRCodeCardView: View {
    let name: String
    let subtitle: String
    let qrCodeId: String
    let footer: String
    @State private var showShareSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Avatar at the top, overlapping the card
            AvatarView(name: name, size: 80)
                .offset(y: -40)
                .padding(.bottom, -40)

            // Card content
            VStack(spacing: 16) {
                // Name and subtitle
                VStack(spacing: 4) {
                    Text(name)
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)

                // QR Code
                if !qrCodeId.isEmpty {
                    QRCodeView(qrCodeId: qrCodeId, size: 200)
                        .padding(.vertical, 8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 200, height: 200)
                        .overlay(
                            Text("QR Code Not Available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        )
                }

                // Footer text
                if !footer.isEmpty {
                    Text(footer)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Share button
                Button(action: {
                    showShareSheet = true
                }) {
                    Label("Share QR Code", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
                .disabled(qrCodeId.isEmpty)
            }
            .padding(.horizontal)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
        .sheet(isPresented: $showShareSheet) {
            if !qrCodeId.isEmpty {
                QRCodeShareView(name: name, qrCodeId: qrCodeId)
            }
        }
    }
}

// Note: This is now defined in QRCodeView.swift

struct QRCodeShareView: View {
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
            title: "\(name)'s LifeSignal QR Code",
            image: qrImage
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

struct QRCodeActivityItem: UIActivityItemProvider {
    let title: String
    let image: UIImage

    override var item: Any {
        return image
    }

    override func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return title
    }
}

#Preview {
    QRCodeCardView(
        name: "John Doe",
        subtitle: "LifeSignal contact",
        qrCodeId: "12345678-1234-1234-1234-123456789012",
        footer: "Your QR code is unique. If you share it with someone, they can scan it and add you as a contact"
    )
}
