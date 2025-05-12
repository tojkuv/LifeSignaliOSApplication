import SwiftUI
import UIKit
import LifeSignal
import ComposableArchitecture

/// A SwiftUI view for displaying a dependent card
struct DependentCardView: View {
    /// The dependent to display
    let dependent: ContactData

    /// Callback for when the card is tapped
    let onTap: () -> Void

    /// Callback for when the ping button is tapped
    let onPing: () -> Void

    /// Callback for when the clear ping button is tapped
    let onClearPing: () -> Void

    /// Whether the view is disabled
    let isDisabled: Bool

    /// Initialize with a dependent and callbacks
    /// - Parameters:
    ///   - dependent: The dependent to display
    ///   - onTap: Callback for when the card is tapped
    ///   - onPing: Callback for when the ping button is tapped
    ///   - onClearPing: Callback for when the clear ping button is tapped
    ///   - isDisabled: Whether the view is disabled
    init(
        dependent: ContactData,
        onTap: @escaping () -> Void,
        onPing: @escaping () -> Void,
        onClearPing: @escaping () -> Void,
        isDisabled: Bool = false
    ) {
        self.dependent = dependent
        self.onTap = onTap
        self.onPing = onPing
        self.onClearPing = onClearPing
        self.isDisabled = isDisabled
    }

    /// Get the status color for the dependent
    private var statusColor: Color {
        if dependent.manualAlertActive {
            return .red
        } else if dependent.isNonResponsive {
            return .yellow
        } else if dependent.hasOutgoingPing {
            return .blue
        } else {
            return .secondary
        }
    }

    /// Time formatter dependency
    @Dependency(\.timeFormatter) private var timeFormatter

    /// Get the status text for the dependent
    private var statusText: String {
        if dependent.isNonResponsive {
            if let lastCheckedIn = dependent.lastCheckedIn, let interval = dependent.checkInInterval {
                let expiration = lastCheckedIn.addingTimeInterval(interval)
                return "Expired \(timeFormatter.formatTimeAgo(expiration))"
            }
            return "Check-in expired"
        } else if dependent.hasOutgoingPing {
            return "Ping sent"
        } else {
            return dependent.formattedTimeRemaining
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: dependent.name)

            VStack(alignment: .leading, spacing: 4) {
                Text(dependent.name)
                    .font(.body)
                    .foregroundColor(.primary)

                if !statusText.isEmpty {
                    Text(statusText)
                        .font(.footnote)
                        .foregroundColor(statusColor)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)

            Spacer()

            // Trailing content (ping button)
            if !dependent.hasOutgoingPing {
                Button(action: onPing) {
                    Circle()
                        .fill(Color(UIColor.systemBackground))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "bell")
                                .foregroundColor(.blue)
                                .font(.system(size: 18))
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Ping \(dependent.name)")
            } else {
                Button(action: onClearPing) {
                    Circle()
                        .fill(Color(UIColor.systemBackground))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "bell.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 18))
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Clear ping for \(dependent.name)")
            }
        }
        .padding()
        .background(
            dependent.manualAlertActive ? Color.red.opacity(0.1) :
            dependent.isNonResponsive ? Color.yellow.opacity(0.15) :
            Color(UIColor.systemGray6)
        )
        .cornerRadius(12)
        .standardShadow(radius: 2, y: 1)
        .onTapGesture(perform: onTap)
        .disabled(isDisabled)
    }
}

