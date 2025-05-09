import SwiftUI
import Foundation

struct AuthenticationView: View {
    @StateObject private var viewModel = AuthenticationViewModel()
    @Binding var isAuthenticated: Bool
    @Binding var needsOnboarding: Bool
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Logo
                    Image("LogoTransparent")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .padding(.top, 50)
                    
                    Text("LifeSignal")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Stay connected with your loved ones")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if !viewModel.isCodeSent {
                        // Phone number input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Enter your phone number")
                                .font(.headline)
                            
                            HStack {
                                // Region picker
                                Picker("Region", selection: $viewModel.phoneRegion) {
                                    Text("US").tag("US")
                                    Text("CA").tag("CA")
                                    Text("UK").tag("UK")
                                    // Add more regions as needed
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(width: 80)
                                
                                // Phone number field
                                TextField("Phone Number", text: $viewModel.phoneNumber)
                                    .keyboardType(.phonePad)
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(8)
                            }
                            
                            Text("We'll send you a verification code")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        // Send code button
                        Button(action: {
                            viewModel.sendVerificationCode { success, error in
                                if !success, let error = error {
                                    viewModel.error = error
                                    showError = true
                                }
                            }
                        }) {
                            Text("Send Verification Code")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .disabled(viewModel.phoneNumber.isEmpty || viewModel.isLoading)
                        .opacity(viewModel.phoneNumber.isEmpty || viewModel.isLoading ? 0.6 : 1)
                    } else {
                        // Verification code input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Enter verification code")
                                .font(.headline)
                            
                            TextField("Code", text: $viewModel.verificationCode)
                                .keyboardType(.numberPad)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                            
                            Text("Enter the 6-digit code sent to your phone")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        // Verify code button
                        Button(action: {
                            viewModel.verifyCode(
                                isAuthenticated: $isAuthenticated,
                                needsOnboarding: $needsOnboarding
                            ) { success, error in
                                if !success, let error = error {
                                    viewModel.error = error
                                    showError = true
                                }
                            }
                        }) {
                            Text("Verify Code")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .disabled(viewModel.verificationCode.isEmpty || viewModel.isLoading)
                        .opacity(viewModel.verificationCode.isEmpty || viewModel.isLoading ? 0.6 : 1)
                        
                        // Back button
                        Button(action: {
                            viewModel.isCodeSent = false
                            viewModel.verificationCode = ""
                        }) {
                            Text("Back")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        .padding(.top, 10)
                    }
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                    }
                    
                    Spacer()
                }
                .padding(.bottom, 50)
            }
            .alert(isPresented: $showError) {
                Alert(
                    title: Text("Error"),
                    message: Text(viewModel.error?.localizedDescription ?? "An unknown error occurred"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

#Preview {
    AuthenticationView(
        isAuthenticated: .constant(false),
        needsOnboarding: .constant(false)
    )
}
