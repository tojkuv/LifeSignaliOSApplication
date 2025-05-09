import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct OnboardingView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    @Binding var needsOnboarding: Bool

    @State private var name = "First Last"
    @State private var emergencyNote = "Emergency Note"
    @State private var isLoading = false
    @State private var currentStep = 0
    @State private var errorMessage = ""
    @State private var showError = false

    var body: some View {
        NavigationStack {
            VStack {
                // Progress indicator
                HStack(spacing: 4) {
                    ForEach(0..<2) { step in
                        Circle()
                            .fill(step == currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.top, 20)

                // Content based on current step
                if currentStep == 0 {
                    nameEntryView
                } else {
                    emergencyNoteView
                }
            }
            .padding()
            .navigationTitle("Complete Your Profile")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .disabled(isLoading)
        }
    }

    private var nameEntryView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
                .padding(.top, 40)

            Text("What's your name?")
                .font(.title2)
                .fontWeight(.bold)

            Text("This will be displayed to your contacts")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            TextField("Your name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .autocapitalization(.words)
                .disableAutocorrection(true)

            Button(action: {
                if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    withAnimation {
                        currentStep = 1
                    }
                }
            }) {
                Text("Continue")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(12)
            }
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.horizontal)

            Spacer()
        }
    }

    private var emergencyNoteView: some View {
        VStack(spacing: 24) {
            Image(systemName: "note.text")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
                .padding(.top, 40)

            Text("Emergency Note")
                .font(.title2)
                .fontWeight(.bold)

            Text("Add important information that responders should know in case of emergency")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            TextEditor(text: $emergencyNote)
                .frame(minHeight: 100)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal)

            HStack {
                Button(action: {
                    withAnimation {
                        currentStep = 0
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                    .foregroundColor(.blue)
                }

                Spacer()

                Button(action: completeOnboarding) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Complete")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                    }
                }
                .background(isLoading ? Color.gray : Color.blue)
                .cornerRadius(12)
                .disabled(isLoading)
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    private func completeOnboarding() {
        isLoading = true

        // Update UserViewModel with the user input
        userViewModel.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        userViewModel.profileDescription = emergencyNote.trimmingCharacters(in: .whitespacesAndNewlines)

        // Create a new QR code ID
        userViewModel.qrCodeId = UUID().uuidString

        // Ensure profile is marked as complete
        let additionalData: [String: Any] = [
            FirestoreSchema.User.profileComplete: true
        ]

        // Create the user document using UserViewModel
        // This will also create the QR lookup document and empty contacts collection
        userViewModel.saveUserData(additionalData: additionalData) { success, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Error creating user profile: \(error.localizedDescription)"
                    self.showError = true
                }
                return
            }

            if !success {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Failed to create user profile"
                    self.showError = true
                }
                return
            }

            DispatchQueue.main.async {
                self.isLoading = false

                // Mark onboarding as complete
                self.needsOnboarding = false
            }
        }
    }
}

#Preview {
    OnboardingView(needsOnboarding: .constant(true))
        .environmentObject(UserViewModel())
}
