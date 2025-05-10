import SwiftUI
import ComposableArchitecture

/// A SwiftUI view for selecting the check-in interval using TCA
struct CheckInIntervalPickerView: View {
    /// The store for the check-in feature
    let store: StoreOf<CheckInFeature>

    /// Binding to control the presentation of this view
    @Binding var isPresented: Bool

    /// State for the interval picker
    @State private var unit: String
    @State private var value: Int

    /// Computed properties for the picker
    private var isDayUnit: Bool { unit == "days" }
    private var dayValues: [Int] { Array(1...7) }
    private var hourValues: [Int] { Array(8...60) }
    private var computedIntervalInSeconds: TimeInterval {
        if isDayUnit {
            return TimeInterval(value * 24 * 60 * 60)
        } else {
            return TimeInterval(value * 60 * 60)
        }
    }

    init(store: StoreOf<CheckInFeature>, isPresented: Binding<Bool>) {
        self.store = store
        self._isPresented = isPresented

        let viewStore = ViewStore(store, observe: { $0 })
        let interval = viewStore.checkInInterval

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

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
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
                        .disabled(viewStore.isLoading)

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
                        .disabled(viewStore.isLoading)
                    }

                    if viewStore.isLoading {
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
                    trailing: Button(viewStore.isLoading ? "Saving..." : "Save") {
                        viewStore.send(.updateInterval(computedIntervalInSeconds))
                        isPresented = false
                    }
                    .disabled(viewStore.isLoading)
                )
            }
        }
    }
}
