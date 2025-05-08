import SwiftUI
import FirebaseCore
import FirebaseFirestore

struct FirebaseTestView: View {
    @State private var firebaseStatus: String = "Checking Firebase status..."
    @State private var firestoreStatus: String = "Firestore not tested yet"
    @State private var isRefreshing: Bool = false
    @State private var isTestingFirestore: Bool = false
    @State private var firestoreTestSuccess: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Firebase Test")
                .font(.largeTitle)
                .fontWeight(.bold)

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
                .frame(height: 150)
            }

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
                .frame(height: 200)
            }

            HStack(spacing: 20) {
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
                    .frame(minWidth: 150)
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
                    .frame(minWidth: 150)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isTestingFirestore)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            checkFirebaseStatus()
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
}
