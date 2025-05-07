import SwiftUI

/// A half circle shape
struct HalfCircle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(center: CGPoint(x: rect.midX, y: rect.minY),
                   radius: rect.width / 2,
                   startAngle: .zero,
                   endAngle: .degrees(180),
                   clockwise: false)
        path.closeSubpath()
        return path
    }
}

/// A rounded rectangle with customizable corners
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension View {
    /// Apply rounded corners to specific corners of a view
    /// - Parameters:
    ///   - radius: The corner radius
    ///   - corners: The corners to round
    /// - Returns: The view with rounded corners
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}
