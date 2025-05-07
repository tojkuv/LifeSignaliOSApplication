import SwiftUI
import UIKit

/// A QR code view for sharing
struct QRCodeShareView: View {
    let name: String
    let subtitle: String
    let qrCodeId: String
    let footer: String?
    var showShadow: Bool = false

    var body: some View {
        ZStack {
            Color.blue
                .ignoresSafeArea()
            VStack(spacing: 0) {
                ZStack {
                    VStack(spacing: 6) {
                        Text(name)
                            .font(.headline)
                            .bold()

                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)

                        QRCodeView(qrContent: qrCodeId)
                            .frame(width: 180, height: 180)
                            .padding(18)
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(12)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 35)
                    .frame(maxWidth: 300)
                    .background(Color(UIColor.systemGray5))
                    .cornerRadius(20)

                    AvatarView(
                        name: name,
                        size: 60,
                        strokeWidth: 4,
                        strokeColor: Color(UIColor.systemGray5)
                    )
                    .offset(y: -170)
                }
                .padding(.bottom, 40)
                .if(showShadow) { view in
                    view.shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 18)
                }

                if let footer = footer {
                    Text(footer)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .frame(maxWidth: 300)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .frame(width: 390, height: 844)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    QRCodeShareView(
        name: "John Doe",
        subtitle: "LifeSignal contact",
        qrCodeId: UUID().uuidString,
        footer: "Use LifeSignal's QR code scanner to add this contact"
    )
}
