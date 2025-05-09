import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UIKit

struct AuthenticationView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    @Binding var isAuthenticated: Bool
    @Binding var needsOnboarding: Bool

    @State private var showPhoneEntry = true
    @State private var phoneNumber: String
    @State private var verificationCode = "123456" // Test verification code
    @State private var verificationId = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false

    init(isAuthenticated: Binding<Bool>, needsOnboarding: Binding<Bool>) {
        self._isAuthenticated = isAuthenticated
        self._needsOnboarding = needsOnboarding

        // Set the initial phone number based on device model
        // iPhone 13 Mini uses +16505553434, iPhone 16 Pro uses +11234567890 (flipped)
        let initialPhoneNumber = DeviceHelper.shared.testPhoneNumber
        self._phoneNumber = State(initialValue: initialPhoneNumber)

        print("Device detected: \(DeviceHelper.shared.deviceModel.rawValue)")
        print("Using test phone number: \(initialPhoneNumber)")
    }

    var body: some View {
        NavigationStack {
            VStack {
                if showPhoneEntry {
                    phoneEntryView
                } else {
                    verificationView
                }
            }
            .padding()
            .navigationTitle("Sign In")
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var phoneEntryView: some View {
        VStack(spacing: 24) {
            Image(systemName: "phone.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
                .padding(.top, 40)

            Text("Enter your phone number")
                .font(.title2)
                .fontWeight(.bold)

            TextField("Phone number", text: $phoneNumber)
                .keyboardType(.phonePad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .disabled(isLoading) // Disable during loading

            // Display device information for debugging
            VStack(spacing: 4) {
                Text("Device: \(DeviceHelper.shared.deviceDisplayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Model: \(DeviceHelper.shared.deviceModel.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Test User: \(phoneNumber)")
                    .font(.caption)
                    .foregroundColor(.blue)

                // Show which test user is being used
                Text(phoneNumber == "+11234567890" ? "iPhone 16 Pro User" : "iPhone 13 Mini User")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(4)
            }

            Button(action: sendVerificationCode) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text("Continue")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .background(isLoading ? Color.gray : Color.blue)
            .cornerRadius(12)
            .padding(.horizontal)
            .disabled(isLoading || phoneNumber.isEmpty)

            Spacer()
        }
    }

    private var verificationView: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
                .padding(.top, 40)

            Text("Enter verification code")
                .font(.title2)
                .fontWeight(.bold)

            Text("We sent a verification code to \(phoneNumber)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            TextField("Verification code", text: $verificationCode)
                .keyboardType(.numberPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .disabled(isLoading) // Disable during loading

            Button(action: verifyCode) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text("Verify")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .background(isLoading ? Color.gray : Color.blue)
            .cornerRadius(12)
            .padding(.horizontal)
            .disabled(isLoading || verificationCode.isEmpty)

            Button(action: {
                showPhoneEntry = true
                verificationId = ""
            }) {
                Text("Change phone number")
                    .foregroundColor(.blue)
            }
            .disabled(isLoading)

            Spacer()
        }
    }

    private func sendVerificationCode() {
        isLoading = true
        errorMessage = ""

        AuthenticationService.shared.signInWithPhoneNumber(phoneNumber) { verId, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    errorMessage = "Error sending verification code: \(error.localizedDescription)"
                    showError = true
                    return
                }

                if let verId = verId {
                    verificationId = verId
                    showPhoneEntry = false
                }
            }
        }
    }

    private func verifyCode() {
        isLoading = true
        errorMessage = ""

        print("Starting verification for phone number: \(phoneNumber)")

        // Check if this is a test user
        let isTestUser = phoneNumber == "+11234567890" || phoneNumber == "+16505553434"
        if isTestUser {
            print("This is a test user: \(phoneNumber)")
        }

        // Use stored verification ID or get from UserDefaults
        let verId = verificationId.isEmpty ?
            UserDefaults.standard.string(forKey: "authVerificationID") ?? "" :
            verificationId

        print("Using verification ID: \(verId)")

        AuthenticationService.shared.verifyCode(verificationID: verId, verificationCode: verificationCode) { authResult, error in
            if let error = error {
                print("Authentication error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = "Error verifying code: \(error.localizedDescription)"
                    showError = true
                }
                return
            }

            print("Authentication successful")

            // Successfully authenticated, now check if user has a document
            guard let userId = AuthenticationService.shared.getCurrentUserID() else {
                print("Authentication succeeded but user ID is missing")
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = "Authentication succeeded but user ID is missing"
                    showError = true
                }
                return
            }

            print("Authenticated user ID: \(userId)")

            // Check if this is a new user
            let isNewUser = authResult?.additionalUserInfo?.isNewUser ?? false
            print("Is new user: \(isNewUser)")

            // Update session (will create user document if needed)
            print("Updating session for user: \(userId)")
            SessionManager.shared.updateSession(userId: userId) { success, error in
                if let error = error {
                    print("Session update error: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        isLoading = false
                        errorMessage = "Error updating session: \(error.localizedDescription)"
                        showError = true
                    }
                    return
                }

                print("Session updated successfully")

                // Continue with getting user data
                print("Continuing with user data")
                continueWithUserData()
            }
        }
    }

    /// Continue the authentication flow by checking user data
    private func continueWithUserData() {
        // Load user data using UserViewModel
        userViewModel.loadUserData { success in
            DispatchQueue.main.async {
                self.isLoading = false

                if !success {
                    // If loading failed, user needs onboarding
                    print("Failed to load user data, assuming user needs onboarding")
                    self.needsOnboarding = true
                    self.isAuthenticated = true
                    return
                }

                // Check if profile is complete based on UserViewModel data
                let profileComplete = !self.userViewModel.name.isEmpty && !self.userViewModel.profileDescription.isEmpty

                if profileComplete {
                    // User is authenticated and has a complete profile
                    print("Profile is complete, skipping onboarding")
                    self.needsOnboarding = false
                    self.isAuthenticated = true
                } else {
                    // User exists but profile is incomplete
                    print("Profile is incomplete, showing onboarding")
                    self.needsOnboarding = true
                    self.isAuthenticated = true
                }
            }
        }
    }
}

#Preview {
    AuthenticationView(
        isAuthenticated: .constant(false),
        needsOnboarding: .constant(false)
    )
    .environmentObject(UserViewModel())
}
