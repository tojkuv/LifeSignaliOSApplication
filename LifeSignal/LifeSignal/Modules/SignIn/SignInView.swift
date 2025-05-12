import SwiftUI
import ComposableArchitecture

/// A SwiftUI view for authentication using TCA
struct SignInView: View {
    /// The store for the sign-in feature
    @Bindable var store: StoreOf<SignInFeature>

    var body: some View {
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
                if !store.isCodeSent {
                    // Phone number input
                    VStack(spacing: 20) {
                        // Region picker
                        Picker("Region", selection: $store.phoneRegion) {
                            Text("US (+1)").tag("US")
                            Text("CA (+1)").tag("CA")
                            Text("UK (+44)").tag("GB")
                            Text("AU (+61)").tag("AU")
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding(.horizontal)

                        // Phone number field
                        TextField("Phone Number", text: $store.phoneNumber)
                        .keyboardType(.phonePad)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)

                        // Send code button
                        Button(action: {
                            store.send(.sendVerificationCode)
                        }) {
                            Text(store.isLoading ? "Sending..." : "Send Verification Code")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .disabled(store.isLoading || store.phoneNumber.isEmpty)
                        .padding(.horizontal)
                    }
                } else {
                    // Verification code input
                    VStack(spacing: 20) {
                        Text("Enter the verification code sent to \(store.formattedPhoneNumber())")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        // Verification code field
                        TextField("Verification Code", text: $store.verificationCode)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)

                        // Verify code button
                        Button(action: {
                            store.send(.verifyCode)
                        }) {
                            Text(store.isLoading ? "Verifying..." : "Verify Code")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .disabled(store.isLoading || store.verificationCode.isEmpty)
                        .padding(.horizontal)

                        // Back button
                        Button(action: {
                            // Reset verification state
                            store.send(.binding(.set(\.$verificationCode, "")))
                            store.send(.binding(.set(\.$isCodeSent, false)))
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
            .alert(
                title: { _ in Text("Error") },
                isPresented: .init(
                    get: { store.error != nil },
                    set: { if !$0 { store.send(.clearError) } }
                ),
                actions: { _ in
                    Button("OK") {
                        store.send(.clearError)
                    }
                },
                message: { _ in Text(store.error?.localizedDescription ?? "An unknown error occurred") }
            )
            .onReceive(ViewStore(store, observe: { $0 }).publisher.map(\.isAuthenticated)) { isAuthenticated in
                if isAuthenticated {
                    // Notify the app that auth state changed
                    NotificationCenter.default.post(name: NSNotification.Name("AuthStateChanged"), object: nil)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    SignInView(
        store: Store(initialState: SignInFeature.State()) {
            SignInFeature()
        }
    )
}
