import SwiftUI

struct IntervalPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    let interval: TimeInterval
    let onSave: (TimeInterval) -> Void

    @State private var unit: String
    @State private var value: Int

    init(interval: TimeInterval, onSave: @escaping (TimeInterval) -> Void) {
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
                }
            }
            .navigationTitle("Interval")
            .navigationBarItems(
                trailing: Button("Save") {
                    onSave(computedIntervalInSeconds)
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}