import UIKit

/// A manager for haptic feedback
@MainActor
final class HapticManager: Sendable {
    /// Shared instance
    static let shared = HapticManager()

    /// Private initializer for singleton
    private init() {}

    /// Trigger a light impact haptic feedback
    @MainActor
    func lightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Trigger a medium impact haptic feedback
    @MainActor
    func mediumImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Trigger a heavy impact haptic feedback
    @MainActor
    func heavyImpact() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    /// Trigger a selection haptic feedback
    @MainActor
    func selectionFeedback() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    /// Trigger a notification haptic feedback
    /// - Parameter type: The type of notification feedback
    @MainActor
    func notificationFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    /// Trigger a success notification haptic feedback
    @MainActor
    func success() {
        notificationFeedback(.success)
    }

    /// Trigger a warning notification haptic feedback
    @MainActor
    func warning() {
        notificationFeedback(.warning)
    }

    /// Trigger an error notification haptic feedback
    @MainActor
    func error() {
        notificationFeedback(.error)
    }
}

/// Global function to trigger a standard haptic feedback
@MainActor
func triggerHaptic() {
    HapticManager.shared.mediumImpact()
}
