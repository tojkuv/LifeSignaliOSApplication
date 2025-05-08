import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct AuthenticationView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    @Binding var isAuthenticated: Bool
    @Binding var needsOnboarding: Bool

    @State private var showPhoneEntry = true
    @State private var phoneNumber = "+11234567890" // Test phone number
    @State private var verificationCode = "123456" // Test verification code
    @State private var verificationId = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false

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

        // Use stored verification ID or get from UserDefaults
        let verId = verificationId.isEmpty ?
            UserDefaults.standard.string(forKey: "authVerificationID") ?? "" :
            verificationId

        AuthenticationService.shared.verifyCode(verificationID: verId, verificationCode: verificationCode) { authResult, error in
            if let error = error {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = "Error verifying code: \(error.localizedDescription)"
                    showError = true
                }
                return
            }

            // Successfully authenticated, now check if user has a document
            guard let userId = AuthenticationService.shared.getCurrentUserID() else {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = "Authentication succeeded but user ID is missing"
                    showError = true
                }
                return
            }

            // Update session
            SessionManager.shared.updateSession(userId: userId) { success, error in
                if let error = error {
                    DispatchQueue.main.async {
                        isLoading = false
                        errorMessage = "Error updating session: \(error.localizedDescription)"
                        showError = true
                    }
                    return
                }

                // Check if user has a document
                UserService.shared.getCurrentUserData { userData, error in
                    DispatchQueue.main.async {
                        isLoading = false

                        if let error = error {
                            // If error is "User document not found", user needs onboarding
                            if (error as NSError).domain == "UserService" && (error as NSError).code == 404 {
                                needsOnboarding = true
                                isAuthenticated = true
                            } else {
                                errorMessage = "Error checking user data: \(error.localizedDescription)"
                                showError = true
                            }
                            return
                        }

                        if let userData = userData {
                            // User exists, check if profile is complete
                            let profileComplete = userData["profileComplete"] as? Bool ?? false

                            if profileComplete {
                                // User is authenticated and has a complete profile
                                needsOnboarding = false
                                isAuthenticated = true

                                // Update UserViewModel with user data
                                userViewModel.updateFromFirestore(userData: userData)
                            } else {
                                // User exists but profile is incomplete
                                needsOnboarding = true
                                isAuthenticated = true
                            }
                        } else {
                            // No user data, needs onboarding
                            needsOnboarding = true
                            isAuthenticated = true
                        }
                    }
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
