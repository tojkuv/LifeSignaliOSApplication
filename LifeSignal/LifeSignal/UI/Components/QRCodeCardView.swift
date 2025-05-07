import SwiftUI
import UIKit

/// A card view that displays a QR code with a name and subtitle
struct QRCodeCardView: View {
    let name: String
    let subtitle: String
    let qrCodeId: String
    let footer: String?

    init(
        name: String,
        subtitle: String,
        qrCodeId: String,
        footer: String? = nil
    ) {
        self.name = name
        self.subtitle = subtitle
        self.qrCodeId = qrCodeId
        self.footer = footer
    }

    var body: some View {
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
                        .background(Color.white)
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
            .frame(width: 300, height: 350)
            .background(Color(.systemBackground))

            if let footer = footer {
                Text(footer)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.top, 16)
                    .frame(maxWidth: 300)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    QRCodeCardView(
        name: "John Doe",
        subtitle: "LifeSignal contact",
        qrCodeId: UUID().uuidString,
        footer: "Your QR code is unique. If you share it with someone, they can scan it and add you as a contact"
    )
}
