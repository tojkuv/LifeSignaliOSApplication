import UIKit
import ComposableArchitecture

/// A client for haptic feedback
@DependencyClient
struct HapticClient: Sendable {
    /// Trigger a light impact haptic feedback
    var lightImpact: @Sendable () -> Void = {}

    /// Trigger a medium impact haptic feedback
    var mediumImpact: @Sendable () -> Void = {}

    /// Trigger a heavy impact haptic feedback
    var heavyImpact: @Sendable () -> Void = {}

    /// Trigger a selection haptic feedback
    var selectionFeedback: @Sendable () -> Void = {}

    /// Trigger a notification haptic feedback
    var notificationFeedback: @Sendable (_ type: UINotificationFeedbackGenerator.FeedbackType) -> Void = { _ in }

    /// Trigger a success notification haptic feedback
    var success: @Sendable () -> Void = {}

    /// Trigger a warning notification haptic feedback
    var warning: @Sendable () -> Void = {}

    /// Trigger an error notification haptic feedback
    var error: @Sendable () -> Void = {}
}

// MARK: - Live Implementation

extension HapticClient {
    /// The live implementation of the haptic client
    static let live = HapticClient(
        lightImpact: {
            Task { @MainActor in
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        },

        mediumImpact: {
            Task { @MainActor in
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }
        },

        heavyImpact: {
            Task { @MainActor in
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
            }
        },

        selectionFeedback: {
            Task { @MainActor in
                let generator = UISelectionFeedbackGenerator()
                generator.selectionChanged()
            }
        },

        notificationFeedback: { type in
            Task { @MainActor in
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(type)
            }
        },

        success: {
            Task { @MainActor in
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        },

        warning: {
            Task { @MainActor in
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.warning)
            }
        },

        error: {
            Task { @MainActor in
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }
        }
    )
}

// MARK: - Mock Implementation

extension HapticClient {
    /// A mock implementation that does nothing, for testing
    static let mock = Self(
        lightImpact: {},
        mediumImpact: {},
        heavyImpact: {},
        selectionFeedback: {},
        notificationFeedback: { _ in },
        success: {},
        warning: {},
        error: {}
    )
}

// MARK: - Dependency Registration

extension DependencyValues {
    /// The haptic client dependency
    var haptic: HapticClient {
        get { self[HapticClient.self] }
        set { self[HapticClient.self] = newValue }
    }
}

extension HapticClient: DependencyKey {
    /// The live value of the haptic client
    static var liveValue: HapticClient {
        return .live
    }

    /// The test value of the haptic client
    static var testValue: HapticClient {
        return .mock
    }
}

// MARK: - Global Convenience Function

/// Global function to trigger a standard haptic feedback
func triggerHaptic() {
    @Dependency(\.haptic) var haptic
    haptic.mediumImpact()
}
