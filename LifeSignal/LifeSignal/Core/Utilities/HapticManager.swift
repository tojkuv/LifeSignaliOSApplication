import UIKit

/// A manager for haptic feedback
class HapticManager {
    /// Shared instance
    static let shared = HapticManager()
    
    /// Private initializer for singleton
    private init() {}
    
    /// Trigger a light impact haptic feedback
    func lightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    /// Trigger a medium impact haptic feedback
    func mediumImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    /// Trigger a heavy impact haptic feedback
    func heavyImpact() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    /// Trigger a selection haptic feedback
    func selectionFeedback() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    /// Trigger a notification haptic feedback
    /// - Parameter type: The type of notification feedback
    func notificationFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    /// Trigger a success notification haptic feedback
    func success() {
        notificationFeedback(.success)
    }
    
    /// Trigger a warning notification haptic feedback
    func warning() {
        notificationFeedback(.warning)
    }
    
    /// Trigger an error notification haptic feedback
    func error() {
        notificationFeedback(.error)
    }
}

/// Global function to trigger a standard haptic feedback
func triggerHaptic() {
    HapticManager.shared.mediumImpact()
}
