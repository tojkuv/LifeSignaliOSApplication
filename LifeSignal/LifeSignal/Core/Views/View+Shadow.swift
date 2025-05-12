import SwiftUI

extension View {
    /// Apply a standard shadow to a view
    /// - Parameters:
    ///   - radius: The shadow radius
    ///   - x: The horizontal offset of the shadow
    ///   - y: The vertical offset of the shadow
    ///   - opacity: The opacity of the shadow
    /// - Returns: The view with a shadow applied
    func standardShadow(radius: CGFloat = 4, x: CGFloat = 0, y: CGFloat = 2, opacity: CGFloat = 0.1) -> some View {
        self.shadow(color: Color.black.opacity(opacity), radius: radius, x: x, y: y)
    }
}
