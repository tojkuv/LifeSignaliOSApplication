import SwiftUI

struct SettingRowView: View {
    let title: String
    let value: String
    let icon: String
    var showDivider: Bool = true
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: {
            action?()
        }) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 25, height: 25)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(value)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if action != nil {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 15)
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color.clear)
        .overlay(
            VStack {
                Spacer()
                if showDivider {
                    Divider()
                }
            }
        )
    }
}

// Original SettingRow (legacy version)
struct SettingRowOriginal: View {
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

struct ToggleSettingRowView: View {
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

#Preview {
    VStack(spacing: 0) {
        SettingRowView(
            title: "Name",
            value: "John Doe",
            icon: "person.fill",
            showDivider: true
        )

        SettingRowView(
            title: "Phone",
            value: "+1 (555) 123-4567",
            icon: "phone.fill",
            showDivider: true
        )

        SettingRowView(
            title: "Email",
            value: "john.doe@example.com",
            icon: "envelope.fill",
            showDivider: false
        )
    }
    .background(Color(.secondarySystemBackground))
    .cornerRadius(10)
    .padding()
}
