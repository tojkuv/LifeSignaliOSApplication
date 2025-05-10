import SwiftUI
import ComposableArchitecture

/// A SwiftUI view for displaying the check-in countdown using TCA
struct CountdownView: View {
    /// The store for the check-in feature
    let store: StoreOf<CheckInFeature>

    /// State for UI controls
    @State private var showCheckInConfirmation = false
    @State private var showIntervalPicker = false
    @State private var showNotificationSettings = false

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            ScrollView {
                VStack(spacing: 20) {
                    // Countdown timer
                    ZStack {
                        Circle()
                            .stroke(lineWidth: 15)
                            .opacity(0.3)
                            .foregroundColor(.blue)

                        Circle()
                            .trim(from: 0.0, to: 1.0 - viewStore.checkInProgress)
                            .stroke(style: StrokeStyle(lineWidth: 15, lineCap: .round, lineJoin: .round))
                            .foregroundColor(.blue)
                            .rotationEffect(Angle(degrees: 270.0))
                            .animation(.linear, value: viewStore.checkInProgress)

                        VStack {
                            Text(viewStore.formattedTimeRemaining)
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

                        Text(viewStore.lastCheckedIn.formatted(date: .abbreviated, time: .shortened))
                            .font(.headline)
                    }
                    .padding(.top, 10)

                    // Check-in interval
                    VStack(spacing: 5) {
                        Text("Check-in interval")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(formatInterval(viewStore.checkInInterval))
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

                        Text("\(viewStore.notificationLeadTime) minutes")
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
                .padding()
            }
            .navigationTitle("Check In")
            .alert(isPresented: $showCheckInConfirmation) {
                Alert(
                    title: Text("Confirm Check-in"),
                    message: Text("Are you sure you want to check in now? This will reset your timer."),
                    primaryButton: .default(Text("Check In")) {
                        viewStore.send(.checkIn)
                    },
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $showIntervalPicker) {
                CheckInIntervalPickerView(
                    store: store,
                    isPresented: $showIntervalPicker
                )
            }
            .sheet(isPresented: $showNotificationSettings) {
                NotificationSettingsView(
                    store: store,
                    isPresented: $showNotificationSettings
                )
            }
            .onAppear {
                viewStore.send(.loadCheckInData)

                // Set up a timer to update the UI
                let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

                Timer.publish(every: 1, on: .main, in: .common)
                    .autoconnect()
                    .sink { _ in
                        viewStore.send(.timerTick)
                    }
            }
        }
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
