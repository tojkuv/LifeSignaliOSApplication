import SwiftUI

// Import feature view models
import LifeSignal.Features.Profile.UserProfileViewModel

struct IntervalPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var userProfileViewModel: UserProfileViewModel

    let interval: TimeInterval
    let onSave: (TimeInterval, @escaping (Bool, Error?) -> Void) -> Void

    @State private var unit: String
    @State private var value: Int
    @State private var isSaving = false
    @State private var showSaveError = false
    @State private var saveError: Error? = nil

    init(interval: TimeInterval, onSave: @escaping (TimeInterval, @escaping (Bool, Error?) -> Void) -> Void) {
        self.interval = interval
        self.onSave = onSave
        if interval.truncatingRemainder(dividingBy: 86400) == 0,
           (1...7).contains(Int(interval / 86400)) {
            _unit = State(initialValue: "days")
            _value = State(initialValue: Int(interval / 86400))
        } else if interval.truncatingRemainder(dividingBy: 3600) == 0,
                  (8...60).contains(Int(interval / 3600)) {
            _unit = State(initialValue: "hours")
            _value = State(initialValue: Int(interval / 3600))
        } else {
            _unit = State(initialValue: "days")
            _value = State(initialValue: 1)
        }
    }

    private var computedIntervalInSeconds: TimeInterval {
        if unit == "days" {
            return TimeInterval(value * 86400)
        } else {
            return TimeInterval(value * 3600)
        }
    }

    private var dayValues: [Int] { Array(1...7) }
    private var hourValues: [Int] { Array(stride(from: 8, through: 60, by: 8)) }
    private var isDayUnit: Bool { unit == "days" }

    private var formattedInterval: String {
        if unit == "days" {
            return "\(value) day\(value > 1 ? "s" : "")"
        } else {
            return "\(value) hours"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Unit", selection: $unit) {
                        Text("Days").tag("days")
                        Text("Hours").tag("hours")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: unit) { oldUnit, newUnit in
                        if newUnit == "days" {
                            value = 1
                        } else {
                            value = 8
                        }
                    }
                    .disabled(isSaving)

                    Picker("Value", selection: $value) {
                        if isDayUnit {
                            ForEach(dayValues, id: \.self) { day in
                                Text("\(day) day\(day > 1 ? "s" : "")").tag(day)
                            }
                        } else {
                            ForEach(hourValues, id: \.self) { hour in
                                Text("\(hour) hours").tag(hour)
                            }
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 150)
                    .clipped()
                    .disabled(isSaving)
                }

                if isSaving {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.vertical, 8)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Interval")
            .navigationBarItems(
                trailing: Button(isSaving ? "Saving..." : "Save") {
                    saveInterval()
                }
                .disabled(isSaving)
            )
            .alert(isPresented: $showSaveError) {
                Alert(
                    title: Text("Error Saving Interval"),
                    message: Text(saveError?.localizedDescription ?? "An unknown error occurred."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func saveInterval() {
        isSaving = true
        let newInterval = computedIntervalInSeconds

        onSave(newInterval) { success, error in
            DispatchQueue.main.async {
                isSaving = false

                if success {
                    // Successfully saved to Firestore
                    presentationMode.wrappedValue.dismiss()
                } else {
                    // Show error alert
                    saveError = error
                    showSaveError = true
                }
            }
        }
    }
}

#Preview {
    IntervalPickerView(
        interval: 24 * 60 * 60,
        onSave: { _, completion in
            completion(true, nil)
        }
    )
    .environmentObject(UserProfileViewModel())
}
