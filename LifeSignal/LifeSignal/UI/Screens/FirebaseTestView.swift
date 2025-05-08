import SwiftUI
import FirebaseCore
import FirebaseFirestore

struct FirebaseTestView: View {
    @State private var firebaseStatus: String = "Checking Firebase status..."
    @State private var firestoreStatus: String = "Firestore not tested yet"
    @State private var isRefreshing: Bool = false
    @State private var isTestingFirestore: Bool = false
    @State private var firestoreTestSuccess: Bool = false
    @State private var showMainApp: Bool = false
    @EnvironmentObject private var userViewModel: UserViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Firebase Test")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 8)

                    Divider()

                    // Firebase Core Status
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Firebase Core Status:")
                            .font(.headline)

                        ScrollView {
                            Text(firebaseStatus)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .frame(minHeight: 120, maxHeight: 150)
                    }
                    .padding(.horizontal)

                    // Firestore Status
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Firestore Status:")
                            .font(.headline)

                        ScrollView {
                            Text(firestoreStatus)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(firestoreTestSuccess ? Color.green.opacity(0.1) : Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .frame(minHeight: 150, maxHeight: 200)
                    }
                    .padding(.horizontal)

                    // Button layout with better spacing and responsiveness
                    VStack(spacing: 16) {
                        // Refresh Firebase Status Button
                        Button(action: {
                            checkFirebaseStatus()
                            withAnimation {
                                isRefreshing = true
                            }

                            // Simulate refresh animation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation {
                                    isRefreshing = false
                                }
                            }
                        }) {
                            HStack {
                                Text("Refresh Status")
                                if isRefreshing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }

                        // Test Firestore Button
                        Button(action: {
                            testFirestore()
                        }) {
                            HStack {
                                Text("Test Firestore")
                                if isTestingFirestore {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                } else {
                                    Image(systemName: "flame.fill")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isTestingFirestore)

                        // Continue to Main App Button
                        Button(action: {
                            showMainApp = true
                        }) {
                            HStack {
                                Text("Continue to App")
                                Image(systemName: "arrow.right")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Add some bottom padding to prevent clipping
                    Spacer()
                        .frame(height: 20)
                }
            }
            .padding(.vertical)
            .onAppear {
                checkFirebaseStatus()
            }
            .navigationDestination(isPresented: $showMainApp) {
                ContentView()
                    .environmentObject(userViewModel)
                    .navigationBarBackButtonHidden(true)
            }
        }
    }

    private func checkFirebaseStatus() {
        firebaseStatus = FirebaseService.shared.getInitializationStatus()
    }

    private func testFirestore() {
        withAnimation {
            isTestingFirestore = true
            firestoreStatus = "Testing Firestore connection..."
            firestoreTestSuccess = false
        }

        FirebaseService.shared.testFirestoreConnection { result, success in
            DispatchQueue.main.async {
                withAnimation {
                    firestoreStatus = result
                    firestoreTestSuccess = success
                    isTestingFirestore = false
                }
            }
        }
    }
}

#Preview {
    FirebaseTestView()
        .environmentObject(UserViewModel())
}
