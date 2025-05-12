import SwiftUI

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

extension View {
    /// Conditionally apply a transformation to a view
    /// - Parameters:
    ///   - condition: The condition to evaluate
    ///   - transform: The transformation to apply if the condition is true
    /// - Returns: The transformed view if the condition is true, otherwise the original view
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Apply a transformation only if a value is not nil
    /// - Parameters:
    ///   - value: The optional value to check
    ///   - transform: The transformation to apply if the value is not nil
    /// - Returns: The transformed view if the value is not nil, otherwise the original view
    @ViewBuilder func ifLet<T, Content: View>(_ value: T?, transform: (Self, T) -> Content) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }

    /// Apply rounded corners to specific corners of a view
    /// - Parameters:
    ///   - radius: The corner radius
    ///   - corners: The corners to round
    /// - Returns: The view with rounded corners
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}
