import SwiftUI
import ComposableArchitecture
import Combine

/// A SwiftUI view for displaying the check-in countdown using TCA
struct CheckInView: View {
    /// The store for the app feature
    let store: StoreOf<AppFeature>

    /// State for UI controls
    @State private var showCheckInConfirmation = false
    @State private var showIntervalPicker = false
    @State private var showNotificationSettings = false
    @State private var timerSubscription: AnyCancellable? = nil

    var body: some View {
        WithViewStore(store, observe: \.user) { viewStore in
            if let user = viewStore.state {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Countdown timer
                            ZStack {
                                Circle()
                                    .stroke(lineWidth: 15)
                                    .opacity(0.3)
                                    .foregroundColor(.blue)

                                let checkInProgress = calculateCheckInProgress(user)
                                Circle()
                                    .trim(from: 0.0, to: 1.0 - checkInProgress)
                                    .stroke(style: StrokeStyle(lineWidth: 15, lineCap: .round, lineJoin: .round))
                                    .foregroundColor(.blue)
                                    .rotationEffect(Angle(degrees: 270.0))
                                    .animation(.linear, value: checkInProgress)

                                VStack {
                                    Text(formatTimeRemaining(user))
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

                                Text(user.lastCheckedIn.formatted(date: .abbreviated, time: .shortened))
                                    .font(.headline)
                            }
                            .padding(.top, 10)

                            // Check-in interval
                            VStack(spacing: 5) {
                                Text("Check-in interval")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text(formatInterval(user.checkInInterval))
                                    .font(.headline)
                            }
                            .padding(.top, 5)
                            .onTapGesture {
                                showIntervalPicker = true
                            }

                            // Notification settings
                            VStack(spacing: 5) {
                                Text("Notification lead time")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text("\(user.notify2HoursBefore ? 120 : 30) minutes")
                                    .font(.headline)
                            }
                            .padding(.top, 5)
                            .onTapGesture {
                                showNotificationSettings = true
                            }

                            // Check-in button
                            Button(action: {
                                showCheckInConfirmation = true
                            }) {
                                Text("Check In Now")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                            .padding(.top, 20)
                            .padding(.horizontal, 20)

                            Spacer()
                        }
                    }
                } else {
                    // Show loading or placeholder view when user data is not available
                    ProgressView("Loading check-in data...")
                }
            }
            .padding()
            .navigationTitle("Check In")
            .alert(isPresented: $showCheckInConfirmation) {
                Alert(
                    title: Text("Confirm Check-in"),
                    message: Text("Are you sure you want to check in now? This will reset your timer."),
                    primaryButton: .default(Text("Check In")) {
                        store.send(.user(.checkIn))
                    },
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $showIntervalPicker) {
                IntervalPickerView(
                    interval: viewStore.state?.checkInInterval ?? TimeManager.defaultInterval,
                    onSave: { interval in
                        store.send(.user(.updateCheckInInterval(interval)))
                        showIntervalPicker = false
                    },
                    onCancel: {
                        showIntervalPicker = false
                    }
                )
            }
            .sheet(isPresented: $showNotificationSettings) {
                NavigationStack {
                    Form {
                        Section(header: Text("Notification Lead Time")) {
                            if let user = viewStore.state {
                                Toggle("30 minutes before expiration", isOn: Binding(
                                    get: { user.notify30MinBefore },
                                    set: { newValue in
                                        store.send(.user(.updateNotificationPreferences(
                                            notify30Min: newValue,
                                            notify2Hours: user.notify2HoursBefore
                                        )))
                                    }
                                ))

                                Toggle("2 hours before expiration", isOn: Binding(
                                    get: { user.notify2HoursBefore },
                                    set: { newValue in
                                        store.send(.user(.updateNotificationPreferences(
                                            notify30Min: user.notify30MinBefore,
                                            notify2Hours: newValue
                                        )))
                                    }
                                ))
                            }
                        }
                    }
                    .navigationTitle("Notification Settings")
                    .navigationBarItems(trailing: Button("Done") {
                        showNotificationSettings = false
                    })
                }
            }
            .onAppear {
                // Set up a timer to update the UI
                timerSubscription = Timer.publish(every: 1, on: .main, in: .common)
                    .autoconnect()
                    .sink { _ in
                        // Just trigger a UI update, no need to send an action
                    }
            }
            .onDisappear {
                timerSubscription?.cancel()
                timerSubscription = nil
            }
        }
    }

    /// Calculate the check-in progress for the progress circle
    /// - Parameter user: The user state
    /// - Returns: The progress value (0.0 to 1.0)
    private func calculateCheckInProgress(_ user: UserFeature.State) -> Double {
        let elapsed = Date().timeIntervalSince(user.lastCheckedIn)
        let progress = elapsed / user.checkInInterval
        return min(max(progress, 0.0), 1.0)
    }

    /// Format the time remaining until check-in expiration
    /// - Parameter user: The user state
    /// - Returns: A formatted string representation of the time remaining
    private func formatTimeRemaining(_ user: UserFeature.State) -> String {
        let checkInExpiration = user.lastCheckedIn.addingTimeInterval(user.checkInInterval)
        let timeRemaining = checkInExpiration.timeIntervalSince(Date())

        if timeRemaining <= 0 {
            return "Expired"
        }

        return TimeManager.shared.formatTimeInterval(timeRemaining)
    }

    /// Format the check-in interval for display
    /// - Parameter interval: The interval in seconds
    /// - Returns: A formatted string representation of the interval
    private func formatInterval(_ interval: TimeInterval) -> String {
        if interval.truncatingRemainder(dividingBy: 86400) == 0 {
            let days = Int(interval / 86400)
            return "\(days) \(days == 1 ? "day" : "days")"
        } else {
            let hours = Int(interval / 3600)
            return "\(hours) \(hours == 1 ? "hour" : "hours")"
        }
    }
}
