import SwiftUI

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
}
