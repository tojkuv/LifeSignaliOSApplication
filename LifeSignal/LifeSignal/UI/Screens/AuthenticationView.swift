import SwiftUI
import Foundation

struct AuthenticationView: View {
    @Binding var isAuthenticated: Bool
    @State private var showPhoneEntry = true
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @EnvironmentObject private var userViewModel: UserViewModel

    var body: some View {
        if showPhoneEntry {
            PhoneEntryView(
                phoneNumber: $phoneNumber,
                onContinue: {
                    // In a real app, this would send the verification code to the phone
                    showPhoneEntry = false
                }
            )
        } else {
            VerificationView(
                phoneNumber: phoneNumber,
                verificationCode: $verificationCode,
                onVerify: {
                    // In a real app, this would verify the code with a backend service
                    userViewModel.phone = phoneNumber
                    isAuthenticated = true
                },
                onChangeNumber: {
                    showPhoneEntry = true
                }
            )
        }
    }
}

struct PhoneEntryView: View {
    @Binding var phoneNumber: String
    let onContinue: () -> Void

    @State private var isPhoneValid = false

    var body: some View {
        Group {
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
                    .onChange(of: phoneNumber) { oldValue, newValue in
                        isPhoneValid = newValue.count > 0
                    }

                Button(action: onContinue) {
                    Text("Continue")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isPhoneValid ? Color.blue : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(!isPhoneValid)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.horizontal)
        }
    }
}

struct VerificationView: View {
    let phoneNumber: String
    @Binding var verificationCode: String
    let onVerify: () -> Void
    let onChangeNumber: () -> Void

    @State private var isCodeValid = false

    var body: some View {
        Group {
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
                    .onChange(of: verificationCode) { oldValue, newValue in
                        isCodeValid = newValue.count == 6
                    }

                Button(action: onVerify) {
                    Text("Verify")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isCodeValid ? Color.blue : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(!isCodeValid)
                .padding(.horizontal)

                Button(action: onChangeNumber) {
                    Text("Change phone number")
                        .foregroundColor(.blue)
                }

                Spacer()
            }
            .padding(.horizontal)
        }
    }
}