import SwiftUI

struct SettingRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var showDisclosure: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 30, height: 30)
                    .foregroundColor(.blue)

                VStack(alignment: .leading) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if showDisclosure {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(UIColor.systemGray5))
        .cornerRadius(12)
    }
}

struct ToggleSettingRow: View {
    let icon: String
    let title: String
    let isOn: Bool
    let action: (Bool) -> Void

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 30, height: 30)
                .foregroundColor(.blue)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
            }

            Spacer()

            Toggle(isOn: .constant(isOn)) {
                EmptyView()
            }
            .onChange(of: isOn) { oldValue, newValue in
                action(newValue)
            }
            .labelsHidden()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemGray5))
        .cornerRadius(12)
    }
}