import SwiftUI
import Foundation

struct CountdownView: View {
    @EnvironmentObject private var checkInViewModel: CheckInViewModel
    @State private var showCheckInConfirmation = false
    @State private var showIntervalPicker = false
    @State private var showNotificationSettings = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Countdown timer
                ZStack {
                    Circle()
                        .stroke(lineWidth: 15)
                        .opacity(0.3)
                        .foregroundColor(.blue)

                    Circle()
                        .trim(from: 0.0, to: 1.0 - checkInViewModel.checkInProgress)
                        .stroke(style: StrokeStyle(lineWidth: 15, lineCap: .round, lineJoin: .round))
                        .foregroundColor(.blue)
                        .rotationEffect(Angle(degrees: 270.0))
                        .animation(.linear, value: checkInViewModel.checkInProgress)

                    VStack {
                        Text("Time Remaining")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text(checkInViewModel.formattedTimeRemaining)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .padding(.top, 4)

                        Text("Expires at")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)

                        Text(checkInViewModel.checkInExpiration, style: .time)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }
                .frame(width: 250, height: 250)
                .padding(.top, 20)

                // Check-in button
                Button(action: {
                    showCheckInConfirmation = true
                }) {
                    Text("Check In Now")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                // Interval settings
                VStack(alignment: .leading, spacing: 8) {
                    Text("Check-In Interval")
                        .font(.headline)

                    HStack {
                        Text("Current interval: \(TimeManager.shared.formatTimeInterval(checkInViewModel.checkInInterval))")
                            .foregroundColor(.secondary)

                        Spacer()

                        Button(action: {
                            showIntervalPicker = true
                        }) {
                            Text("Change")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal, 20)

                // Notification settings
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notification Settings")
                        .font(.headline)

                    HStack {
                        VStack(alignment: .leading) {
                            Text("30 min before: \(checkInViewModel.notify30MinBefore ? "On" : "Off")")
                                .foregroundColor(.secondary)

                            Text("2 hours before: \(checkInViewModel.notify2HoursBefore ? "On" : "Off")")
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: {
                            showNotificationSettings = true
                        }) {
                            Text("Change")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.bottom, 30)
        }
        .alert(isPresented: $showCheckInConfirmation) {
            Alert(
                title: Text("Confirm Check-in"),
                message: Text("Are you sure you want to check in now? This will reset your timer."),
                primaryButton: .default(Text("Check In")) {
                    checkInViewModel.updateLastCheckedIn()
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showIntervalPicker) {
            IntervalPickerView(
                currentInterval: checkInViewModel.checkInInterval,
                onSave: { newInterval in
                    checkInViewModel.updateCheckInInterval(newInterval)
                }
            )
        }
        .sheet(isPresented: $showNotificationSettings) {
            NotificationSettingsView(
                notify30MinBefore: checkInViewModel.notify30MinBefore,
                notify2HoursBefore: checkInViewModel.notify2HoursBefore,
                onSave: { notify30Min, notify2Hours in
                    checkInViewModel.updateNotificationPreferences(
                        notify30MinBefore: notify30Min,
                        notify2HoursBefore: notify2Hours
                    )
                }
            )
        }
    }
}

struct NotificationSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var notify30MinBefore: Bool
    @State private var notify2HoursBefore: Bool
    let onSave: (Bool, Bool) -> Void

    init(notify30MinBefore: Bool, notify2HoursBefore: Bool, onSave: @escaping (Bool, Bool) -> Void) {
        self._notify30MinBefore = State(initialValue: notify30MinBefore)
        self._notify2HoursBefore = State(initialValue: notify2HoursBefore)
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Reminder Settings")) {
                    Toggle("30 minutes before expiration", isOn: $notify30MinBefore)
                    Toggle("2 hours before expiration", isOn: $notify2HoursBefore)
                }

                Section {
                    Button("Save Changes") {
                        onSave(notify30MinBefore, notify2HoursBefore)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .navigationTitle("Notification Settings")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

#Preview {
    CountdownView()
        .environmentObject(CheckInViewModel())
}
