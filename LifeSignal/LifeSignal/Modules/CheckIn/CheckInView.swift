import SwiftUI
import ComposableArchitecture
import Combine

/// A SwiftUI view for displaying the check-in countdown using TCA
struct CheckInView: View {
    /// The user feature store
    @Bindable var store: StoreOf<UserFeature>

    /// Timer publisher for UI updates
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            ScrollView {
                VStack(spacing: 20) {
                    // Countdown timer
                    ZStack {
                        Circle()
                            .stroke(lineWidth: 15)
                            .opacity(0.3)
                            .foregroundColor(.blue)

                        let checkInProgress = calculateCheckInProgress()
                        Circle()
                            .trim(from: 0.0, to: 1.0 - checkInProgress)
                            .stroke(style: StrokeStyle(lineWidth: 15, lineCap: .round, lineJoin: .round))
                            .foregroundColor(.blue)
                            .rotationEffect(Angle(degrees: 270.0))
                            .animation(.linear, value: checkInProgress)

                        VStack {
                            Text(formatTimeRemaining())
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.primary)

                            Text("until check-in")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 250, height: 250)
                    .padding(.top, 20)

                    // Last checked in
                    VStack(spacing: 5) {
                        Text("Last checked in")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(store.checkIn?.lastCheckedIn.formatted(date: .abbreviated, time: .shortened) ?? Date().formatted(date: .abbreviated, time: .shortened))
                            .font(.headline)
                    }
                    .padding(.top, 10)

                    // Check-in interval
                    VStack(spacing: 5) {
                        Text("Check-in interval")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(formatCheckInInterval())
                            .font(.headline)
                    }
                    .padding(.top, 5)

                    // Check-in button
                    Button(action: {
                        store.send(.checkIn(.setShowCheckInConfirmation(true)))
                    }) {
                        Text("Check In Now")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(store.isLoading ? Color.gray : Color.blue)
                            .cornerRadius(10)
                    }
                    .disabled(store.isLoading)
                    .padding(.top, 20)
                    .padding(.horizontal, 20)

                    if let error = store.error {
                        Text("Error: \(error.localizedDescription)")
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.top, 10)
                    }

                    Spacer()
                }
            }
        }
        .padding()
        .navigationTitle("Check In")
        .alert(
            "Confirm Check-in",
            isPresented: $store.checkIn!.showCheckInConfirmation.sending(\.checkIn.setShowCheckInConfirmation),
            actions: {
                Button("Cancel", role: .cancel) { }
                Button("Check In") {
                    store.send(.checkIn)
                    store.send(.checkIn(.setShowCheckInConfirmation(false)))
                }
            },
            message: {
                Text("Are you sure you want to check in now? This will reset your timer.")
            }
        )
        .onReceive(timer) { _ in
            store.send(.checkIn(.updateCurrentTime))
        }
        .onDisappear {
            timer.upstream.connect().cancel()
        }
    }

    // MARK: - Helper Methods

    /// Calculate the check-in progress for the progress circle
    /// - Returns: The progress value (0.0 to 1.0)
    private func calculateCheckInProgress() -> Double {
        guard let checkIn = store.checkIn else { return 0.0 }

        let elapsed = Date().timeIntervalSince(checkIn.lastCheckedIn)
        let progress = elapsed / checkIn.checkInInterval
        return min(max(progress, 0.0), 1.0)
    }

    /// Format the time remaining until check-in expiration
    /// - Returns: A formatted string representation of the time remaining
    private func formatTimeRemaining() -> String {
        guard let checkIn = store.checkIn else { return "Loading..." }

        let timeRemaining = calculateTimeRemaining()

        if timeRemaining <= 0 {
            return "Expired"
        }

        return TimeFormatter.formatTimeInterval(timeRemaining)
    }

    /// Calculate the time remaining until check-in expiration
    /// - Returns: The time remaining in seconds
    private func calculateTimeRemaining() -> TimeInterval {
        guard let checkIn = store.checkIn else { return 0 }

        let checkInExpiration = checkIn.lastCheckedIn.addingTimeInterval(checkIn.checkInInterval)
        return max(0, checkInExpiration.timeIntervalSince(Date()))
    }

    /// Format the check-in interval
    /// - Returns: A formatted string representation of the check-in interval
    private func formatCheckInInterval() -> String {
        guard let checkIn = store.checkIn else { return "" }

        return TimeFormatter.formatTimeIntervalWithFullUnits(checkIn.checkInInterval)
    }
}
