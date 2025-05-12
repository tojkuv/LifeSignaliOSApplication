import SwiftUI

/// A reusable avatar view that displays the first letter of a name
struct AvatarView: View {
    /// The name to display the first letter of
    let name: String
    
    /// The size of the avatar
    let size: CGFloat
    
    /// The color of the text
    let color: Color
    
    /// The width of the stroke around the avatar
    let strokeWidth: CGFloat
    
    /// The color of the stroke
    let strokeColor: Color
    
    /// Initialize a new avatar view
    /// - Parameters:
    ///   - name: The name to display the first letter of
    ///   - size: The size of the avatar (default: 40)
    ///   - color: The color of the text (default: .blue)
    ///   - strokeWidth: The width of the stroke around the avatar (default: 0)
    ///   - strokeColor: The color of the stroke (default: same as text color)
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
                Text(String(name.prefix(1).uppercased()))
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

#Preview {
    VStack(spacing: 20) {
        AvatarView(name: "John Doe")
        
        AvatarView(
            name: "Jane Smith",
            size: 60,
            color: .red,
            strokeWidth: 2,
            strokeColor: .blue
        )
        
        AvatarView(
            name: "Alex Johnson",
            size: 80,
            color: .green,
            strokeWidth: 3
        )
    }
    .padding()
    .previewLayout(.sizeThatFits)
}
