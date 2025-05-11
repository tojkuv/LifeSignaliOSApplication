import SwiftUI
import ComposableArchitecture

/// A SwiftUI view for authentication using TCA
struct AuthenticationView: View {
    /// The store for the authentication feature
    let store: StoreOf<AuthenticationFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                VStack(spacing: 30) {
                    // Logo
                    Image("Logo_Transparent")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                        .padding(.top, 50)

                    // Title
                    Text("LifeSignal")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    // Description
                    Text("Stay connected with your loved ones and ensure everyone's safety.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Spacer()

                    // Phone number input or verification code input
                    if !viewStore.isCodeSent {
                        // Phone number input
                        VStack(spacing: 20) {
                            // Region picker
                            Picker("Region", selection: viewStore.binding(
                                get: \.phoneRegion,
                                send: AuthenticationFeature.Action.updatePhoneRegion
                            )) {
                                Text("US (+1)").tag("US")
                                Text("CA (+1)").tag("CA")
                                Text("UK (+44)").tag("GB")
                                Text("AU (+61)").tag("AU")
                            }
                            .pickerStyle(MenuPickerStyle())
                            .padding(.horizontal)

                            // Phone number field
                            TextField("Phone Number", text: viewStore.binding(
                                get: \.phoneNumber,
                                send: AuthenticationFeature.Action.updatePhoneNumber
                            ))
                            .keyboardType(.phonePad)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .padding(.horizontal)

                            // Send code button
                            Button(action: {
                                viewStore.send(.sendVerificationCode)
                            }) {
                                Text(viewStore.isLoading ? "Sending..." : "Send Verification Code")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                            .disabled(viewStore.isLoading || viewStore.phoneNumber.isEmpty)
                            .padding(.horizontal)
                        }
                    } else {
                        // Verification code input
                        VStack(spacing: 20) {
                            Text("Enter the verification code sent to \(formatPhoneNumber(viewStore.phoneNumber, region: viewStore.phoneRegion))")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            // Verification code field
                            TextField("Verification Code", text: viewStore.binding(
                                get: \.verificationCode,
                                send: AuthenticationFeature.Action.updateVerificationCode
                            ))
                            .keyboardType(.numberPad)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .padding(.horizontal)

                            // Verify code button
                            Button(action: {
                                viewStore.send(.verifyCode)
                            }) {
                                Text(viewStore.isLoading ? "Verifying..." : "Verify Code")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                            .disabled(viewStore.isLoading || viewStore.verificationCode.isEmpty)
                            .padding(.horizontal)

                            // Back button
                            Button(action: {
                                // Reset verification state
                                viewStore.send(.updateVerificationCode(""))
                                viewStore.send(.updatePhoneNumber(""))
                            }) {
                                Text("Back")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                            .padding(.top, 10)
                        }
                    }

                    Spacer()
                }
                .padding(.bottom, 50)
                .alert(isPresented: .constant(viewStore.error != nil)) {
                    Alert(
                        title: Text("Error"),
                        message: Text(viewStore.error?.localizedDescription ?? "An unknown error occurred"),
                        dismissButton: .default(Text("OK")) {
                            viewStore.send(.clearError)
                        }
                    )
                }
            }
        }
    }

    /// Format a phone number for display
    /// - Parameters:
    ///   - phoneNumber: The phone number to format
    ///   - region: The phone region
    /// - Returns: A formatted phone number string
    private func formatPhoneNumber(_ phoneNumber: String, region: String) -> String {
        return PhoneFormatter.formatPhoneNumber(phoneNumber, region: region)
    }
}
