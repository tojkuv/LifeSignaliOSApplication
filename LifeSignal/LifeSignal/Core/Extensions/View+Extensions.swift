import SwiftUI

// MARK: - Conditional Modifier
extension View {
    /// Conditionally apply a modifier to a view
    /// - Parameters:
    ///   - condition: The condition to check
    ///   - transform: The transform to apply if the condition is true
    /// - Returns: The modified view if the condition is true, otherwise the original view
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Apply a shadow with standard values
    /// - Parameters:
    ///   - radius: The shadow radius
    ///   - y: The vertical offset
    /// - Returns: The view with a shadow applied
    func standardShadow(radius: CGFloat = 4, y: CGFloat = 2) -> some View {
        self.shadow(color: Color.black.opacity(0.2), radius: radius, x: 0, y: y)
    }
    
    /// Apply a card style to a view
    /// - Returns: The view with card styling
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
            .standardShadow()
    }
}
