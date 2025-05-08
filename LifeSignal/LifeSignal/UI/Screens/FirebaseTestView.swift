import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

struct FirebaseTestView: View {
    @State private var firebaseStatus: String = "Checking Firebase status..."
    @State private var firestoreStatus: String = "Firestore not tested yet"
    @State private var authStatus: String = "Authentication not tested yet"
    @State private var userDocStatus: String = "User document not tested yet"
    @State private var isRefreshing: Bool = false
    @State private var isTestingFirestore: Bool = false
    @State private var firestoreTestSuccess: Bool = false
    @State private var isTestingAuth: Bool = false
    @State private var authTestSuccess: Bool = false
    @State private var isTestingUserDoc: Bool = false
    @State private var userDocTestSuccess: Bool = false
    @State private var phoneNumber: String = "+16505553434" // Test phone number
    @State private var verificationCode: String = "123456" // Test verification code
    @State private var verificationID: String = ""
    @State private var isSigningOut: Bool = false
    @State private var showMainApp: Bool = false
    @State private var userData: [String: Any] = [:]
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
                        .frame(minHeight: 120, maxHeight: 150)
                    }
                    .padding(.horizontal)

                    // Authentication Status
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Authentication Status:")
                                .font(.headline)

                            if AuthenticationService.shared.isAuthenticated {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Authenticated")
                                        .foregroundColor(.green)
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }

                        ScrollView {
                            Text(authStatus)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(authTestSuccess ? Color.green.opacity(0.1) : Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .frame(minHeight: 120, maxHeight: 150)
                    }
                    .padding(.horizontal)

                    // User Document Status
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("User Document Status:")
                                .font(.headline)

                            if userDocTestSuccess {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Document Found")
                                        .foregroundColor(.green)
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }

                        ScrollView {
                            Text(userDocStatus)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(userDocTestSuccess ? Color.green.opacity(0.1) : Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .frame(minHeight: 120, maxHeight: 150)
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

                        // Authentication Buttons
                        Group {
                            // Send Verification Code Button
                            Button(action: {
                                sendVerificationCode()
                            }) {
                                HStack {
                                    Text("Send Verification Code")
                                    if isTestingAuth {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                    } else {
                                        Image(systemName: "envelope.fill")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(isTestingAuth || isSigningOut)

                            // Verify Code Button
                            Button(action: {
                                verifyCode()
                            }) {
                                HStack {
                                    Text("Verify Code")
                                    if isTestingAuth {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                    } else {
                                        Image(systemName: "checkmark.shield.fill")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.indigo)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(isTestingAuth || isSigningOut || verificationID.isEmpty)

                            // Sign Out Button (only show if authenticated)
                            if AuthenticationService.shared.isAuthenticated {
                                Button(action: {
                                    signOut()
                                }) {
                                    HStack {
                                        Text("Sign Out")
                                        if isSigningOut {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle())
                                        } else {
                                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                .disabled(isTestingAuth || isSigningOut)
                            }
                        }

                        // User Document Buttons (only show if authenticated)
                        if AuthenticationService.shared.isAuthenticated {
                            Group {
                                // Check User Document Button
                                Button(action: {
                                    checkUserDocument()
                                }) {
                                    HStack {
                                        Text("Check User Document")
                                        if isTestingUserDoc {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle())
                                        } else {
                                            Image(systemName: "doc.text.magnifyingglass")
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.teal)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                .disabled(isTestingUserDoc)

                                // Create User Document Button
                                Button(action: {
                                    createUserDocument()
                                }) {
                                    HStack {
                                        Text("Create User Document")
                                        if isTestingUserDoc {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle())
                                        } else {
                                            Image(systemName: "doc.badge.plus")
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.mint)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                .disabled(isTestingUserDoc)
                            }
                        }

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
                updateAuthStatus()
                if AuthenticationService.shared.isAuthenticated {
                    checkUserDocument()
                }
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
        updateAuthStatus()
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

    private func updateAuthStatus() {
        authStatus = AuthenticationService.shared.getAuthenticationStatus()
    }

    private func sendVerificationCode() {
        isTestingAuth = true
        authStatus = "Sending verification code to \(phoneNumber)..."
        authTestSuccess = false

        AuthenticationService.shared.signInWithPhoneNumber(phoneNumber) { verificationId, error in
            DispatchQueue.main.async {
                if let error = error {
                    authStatus = "Error sending verification code: \(error.localizedDescription)"
                    isTestingAuth = false
                    return
                }

                if let verificationId = verificationId {
                    verificationID = verificationId
                    authStatus = "Verification code sent successfully to \(phoneNumber). Please verify with code: \(verificationCode)"
                    isTestingAuth = false
                }
            }
        }
    }

    private func verifyCode() {
        isTestingAuth = true
        authStatus = "Verifying code..."

        AuthenticationService.shared.verifyCode(verificationID: verificationID, verificationCode: verificationCode) { authResult, error in
            DispatchQueue.main.async {
                if let error = error {
                    authStatus = "Error verifying code: \(error.localizedDescription)"
                    isTestingAuth = false
                    return
                }

                // Mark verification as successful
                authTestSuccess = true

                if let user = authResult?.user {
                    authStatus = """
                    ✅ Authentication Successful!
                    User ID: \(user.uid)
                    Phone: \(user.phoneNumber ?? "Not available")
                    """
                } else if AuthenticationService.shared.isAuthenticated {
                    // Handle the case where we're using the test user
                    let userId = AuthenticationService.shared.getCurrentUserID() ?? "Unknown"
                    authStatus = """
                    ✅ Authentication Successful! (Test User)
                    User ID: \(userId)
                    Phone: \(phoneNumber)
                    """
                }

                // Reset verification fields
                verificationID = ""
                isTestingAuth = false
            }
        }
    }

    private func signOut() {
        isSigningOut = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let success = AuthenticationService.shared.signOut()
            isSigningOut = false

            if success {
                authStatus = "Signed out successfully"
                authTestSuccess = false
                userDocStatus = "User document not tested yet"
                userDocTestSuccess = false
            } else {
                authStatus = "Error signing out"
            }
        }
    }

    private func checkUserDocument() {
        guard AuthenticationService.shared.isAuthenticated else {
            userDocStatus = "Error: User not authenticated. Please sign in first."
            return
        }

        isTestingUserDoc = true
        userDocStatus = "Checking user document..."
        userDocTestSuccess = false

        UserService.shared.getCurrentUserData { data, error in
            DispatchQueue.main.async {
                if let error = error {
                    userDocStatus = "Error checking user document: \(error.localizedDescription)"
                    isTestingUserDoc = false
                    return
                }

                if let data = data {
                    // Format the data for display
                    let formattedData = formatUserData(data)
                    userDocStatus = "User document found!\n\n\(formattedData)"
                    userDocTestSuccess = true
                    userData = data
                } else {
                    userDocStatus = "User document not found. You can create it using the button below."
                }

                isTestingUserDoc = false
            }
        }
    }

    private func createUserDocument() {
        guard AuthenticationService.shared.isAuthenticated else {
            userDocStatus = "Error: User not authenticated. Please sign in first."
            return
        }

        isTestingUserDoc = true
        userDocStatus = "Creating user document..."
        userDocTestSuccess = false

        // Create default user data
        let defaultUserData: [String: Any] = [
            "name": "New User",
            "note": "This is a test user created from the Firebase Test View.",
            "profileComplete": true,
            "notificationEnabled": true,
            "testUser": true
        ]

        UserService.shared.createUserDataIfNeeded(data: defaultUserData) { success, error in
            DispatchQueue.main.async {
                if let error = error {
                    userDocStatus = "Error creating user document: \(error.localizedDescription)"
                    isTestingUserDoc = false
                    return
                }

                if success {
                    // Document created or already exists, now get the data
                    UserService.shared.getCurrentUserData { data, error in
                        DispatchQueue.main.async {
                            if let error = error {
                                userDocStatus = "Document created but error retrieving it: \(error.localizedDescription)"
                                isTestingUserDoc = false
                                return
                            }

                            if let data = data {
                                // Format the data for display
                                let formattedData = formatUserData(data)
                                userDocStatus = "User document created/updated successfully!\n\n\(formattedData)"
                                userDocTestSuccess = true
                                userData = data
                            } else {
                                userDocStatus = "Document created but no data returned."
                            }

                            isTestingUserDoc = false
                        }
                    }
                } else {
                    userDocStatus = "Failed to create user document."
                    isTestingUserDoc = false
                }
            }
        }
    }

    private func formatUserData(_ data: [String: Any]) -> String {
        var result = ""

        // Sort keys for consistent display
        let sortedKeys = data.keys.sorted()

        for key in sortedKeys {
            let value = data[key]

            // Format the value based on its type
            var formattedValue = "nil"

            if let timestamp = value as? Timestamp {
                let date = timestamp.dateValue()
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .medium
                formattedValue = formatter.string(from: date)
            } else if let value = value {
                formattedValue = "\(value)"
            }

            result += "\(key): \(formattedValue)\n"
        }

        return result
    }
}

#Preview {
    FirebaseTestView()
        .environmentObject(UserViewModel())
}
