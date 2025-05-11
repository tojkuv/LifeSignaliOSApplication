import SwiftUI
import ComposableArchitecture

/// A SwiftUI view for picking a check-in interval
struct IntervalPickerView: View {
    /// The current interval in seconds
    let interval: TimeInterval

    /// Flag indicating if the view is in a loading state
    @State private var isLoading = false

    /// Callback when an interval is saved
    let onSave: (TimeInterval) -> Void

    /// Callback when picking is canceled
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Check-in Interval")) {
                    ForEach([1, 2, 4, 8, 12, 24, 48, 72], id: \.self) { hours in
                        let seconds = TimeInterval(hours * 3600)
                        Button {
                            isLoading = true
                            // Simulate a brief loading state for better UX
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isLoading = false
                                onSave(seconds)
                            }
                        } label: {
                            HStack {
                                Text(formatInterval(seconds))
                                Spacer()
                                if interval == seconds {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Check-in Interval")
            .navigationBarItems(trailing: Button("Cancel") {
                onCancel()
            })
            .disabled(isLoading)
            .overlay(
                Group {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                            .background(Color(.systemBackground).opacity(0.8))
                            .cornerRadius(10)
                    }
                }
            )
        }
    }

    /// Format a time interval for display
    /// - Parameter interval: The time interval in seconds
    /// - Returns: A formatted string representation of the interval
    private func formatInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600

        if hours < 24 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            let days = hours / 24
            return "\(days) day\(days == 1 ? "" : "s")"
        }
    }
}

// No extension needed as we've simplified the view to use direct initialization

#Preview {
    IntervalPickerView(
        interval: 24 * 3600,
        onSave: { _ in },
        onCancel: { }
    )
}
