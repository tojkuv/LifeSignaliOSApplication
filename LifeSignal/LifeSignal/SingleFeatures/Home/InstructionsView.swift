import SwiftUI

/// A SwiftUI view for displaying instructions
struct InstructionsView: View {
    /// Callback when the view is dismissed
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    instructionSection(
                        title: "Welcome to LifeSignal",
                        content: "LifeSignal helps you stay connected with your trusted contacts. It automatically notifies your responders if you don't check in within your specified time interval.",
                        icon: "app.badge.checkmark.fill"
                    )

                    instructionSection(
                        title: "Setting Up",
                        content: "1. Set your check-in interval in the Home tab\n2. Add responders by scanning their QR code\n3. Enable notifications to receive reminders before timeout",
                        icon: "gear"
                    )

                    instructionSection(
                        title: "Check-In Process",
                        content: "1. Check in regularly before your timer expires\n2. Receive notifications before expiration\n3. If you don't check in, your responders will be notified",
                        icon: "clock"
                    )

                    instructionSection(
                        title: "Responders",
                        content: "Responders are trusted contacts who will be notified if you don't check in on time. They can then take appropriate action to ensure your safety.",
                        icon: "person.2"
                    )

                    instructionSection(
                        title: "Dependents",
                        content: "Dependents are people you're responsible for checking on. You'll be notified if they don't check in on time.",
                        icon: "person.3"
                    )

                    instructionSection(
                        title: "QR Codes",
                        content: "Share your QR code with trusted contacts to let them add you. Scan others' QR codes to add them as contacts.",
                        icon: "qrcode"
                    )

                    instructionSection(
                        title: "Privacy",
                        content: "LifeSignal respects your privacy. Your location is never shared, only your check-in status.",
                        icon: "lock.shield"
                    )
                }
                .padding()
            }
            .navigationTitle("How LifeSignal Works")
            .navigationBarItems(trailing: Button("Done") {
                onDismiss()
            })
        }
    }

    /// Create an instruction section
    /// - Parameters:
    ///   - title: The section title
    ///   - content: The section content
    ///   - icon: The section icon
    /// - Returns: A view containing the instruction section
    private func instructionSection(title: String, content: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(.blue)

                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
            }

            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// No extension needed as we've simplified the view to use direct initialization

#Preview {
    InstructionsView(onDismiss: { })
}
