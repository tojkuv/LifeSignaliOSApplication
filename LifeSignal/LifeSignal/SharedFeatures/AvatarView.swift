import SwiftUI
import UIKit

/// A reusable avatar view that displays the first letter of a name
struct AvatarView: View {
    let name: String
    let size: CGFloat
    let color: Color
    let strokeWidth: CGFloat
    let strokeColor: Color

    init(
        name: String,
        size: CGFloat = 40,
        color: Color = .blue,
        strokeWidth: CGFloat = 0,
        strokeColor: Color? = nil
    ) {
        self.name = name
        self.size = size
        self.color = color
        self.strokeWidth = strokeWidth
        self.strokeColor = strokeColor ?? color
    }

    var body: some View {
        Circle()
            .fill(Color(UIColor.systemBackground))
            .frame(width: size, height: size)
            .overlay(
                Text(String(name.prefix(1)))
                    .foregroundColor(color)
                    .font(size > 60 ? .title : .headline)
            )
            .if(strokeWidth > 0) { view in
                view.overlay(
                    Circle()
                        .stroke(strokeColor, lineWidth: strokeWidth)
                )
            }
    }
}

struct AvatarView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            AvatarView(name: "John Doe", size: 100, strokeWidth: 2)
            AvatarView(name: "Jane Smith", size: 60, color: .red, strokeWidth: 1)
            AvatarView(name: "Alex Johnson", size: 40, color: .green)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
