import SwiftUI
import ComposableArchitecture

/// A SwiftUI view for picking a check-in interval using TCA
struct IntervalPickerView: View {
    /// The store for the interval picker feature
    let store: StoreOf<IntervalPickerFeature>

    /// Callback when an interval is saved
    let onSave: (TimeInterval) -> Void

    /// Callback when picking is canceled
    let onCancel: () -> Void

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                Form {
                    Section(header: Text("Check-in Interval")) {
                        ForEach([1, 2, 4, 8, 12, 24, 48, 72], id: \.self) { hours in
                            let seconds = TimeInterval(hours * 3600)
                            Button {
                                viewStore.send(.updateInterval(seconds))
                                onSave(seconds)
                            } label: {
                                HStack {
                                    Text(formatInterval(seconds))
                                    Spacer()
                                    if viewStore.interval == seconds {
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
                    viewStore.send(.cancel)
                    onCancel()
                })
                .disabled(viewStore.isLoading)
                .overlay(
                    Group {
                        if viewStore.isLoading {
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

/// A SwiftUI view for picking a check-in interval using TCA (convenience initializer)
extension IntervalPickerView {
    /// Initialize with an interval and callbacks
    /// - Parameters:
    ///   - interval: The current interval
    ///   - onSave: Callback when an interval is saved
    ///   - onCancel: Callback when picking is canceled
    init(interval: TimeInterval, onSave: @escaping (TimeInterval) -> Void, onCancel: @escaping () -> Void) {
        self.store = Store(initialState: IntervalPickerFeature.State(
            interval: interval
        )) {
            IntervalPickerFeature()
        }
        self.onSave = onSave
        self.onCancel = onCancel
    }
}

#Preview {
    IntervalPickerView(
        interval: 24 * 3600,
        onSave: { _ in },
        onCancel: { }
    )
}
