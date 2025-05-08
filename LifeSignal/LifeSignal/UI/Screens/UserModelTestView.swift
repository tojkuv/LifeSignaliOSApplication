import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct UserModelTestView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    
    // Test status states
    @State private var userDataStatus: String = "User data not tested yet"
    @State private var contactsStatus: String = "Contacts not tested yet"
    @State private var checkInStatus: String = "Check-in not tested yet"
    @State private var qrCodeStatus: String = "QR code not tested yet"
    @State private var notificationStatus: String = "Notification settings not tested yet"
    
    // Test success states
    @State private var userDataTestSuccess: Bool = false
    @State private var contactsTestSuccess: Bool = false
    @State private var checkInTestSuccess: Bool = false
    @State private var qrCodeTestSuccess: Bool = false
    @State private var notificationTestSuccess: Bool = false
    
    // Loading states
    @State private var isTestingUserData: Bool = false
    @State private var isTestingContacts: Bool = false
    @State private var isTestingCheckIn: Bool = false
    @State private var isTestingQRCode: Bool = false
    @State private var isTestingNotification: Bool = false
    @State private var isRefreshing: Bool = false
    
    // Navigation state
    @State private var showMainApp: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("User Model Test")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 8)
                    
                    Divider()
                    
                    // User Data Status
                    statusSection(
                        title: "User Data Status:",
                        status: userDataStatus,
                        isSuccess: userDataTestSuccess
                    )
                    
                    // Contacts Status
                    statusSection(
                        title: "Contacts Status:",
                        status: contactsStatus,
                        isSuccess: contactsTestSuccess
                    )
                    
                    // Check-in Status
                    statusSection(
                        title: "Check-in Status:",
                        status: checkInStatus,
                        isSuccess: checkInTestSuccess
                    )
                    
                    // QR Code Status
                    statusSection(
                        title: "QR Code Status:",
                        status: qrCodeStatus,
                        isSuccess: qrCodeTestSuccess
                    )
                    
                    // Notification Settings Status
                    statusSection(
                        title: "Notification Settings Status:",
                        status: notificationStatus,
                        isSuccess: notificationTestSuccess
                    )
                    
                    // Button layout with better spacing and responsiveness
                    VStack(spacing: 16) {
                        // Refresh Status Button
                        actionButton(
                            title: "Refresh Status",
                            icon: "arrow.clockwise",
                            color: .blue,
                            isLoading: isRefreshing,
                            action: refreshStatus
                        )
                        
                        // Test User Data Button
                        actionButton(
                            title: "Test User Data",
                            icon: "person.fill",
                            color: .green,
                            isLoading: isTestingUserData,
                            action: testUserData,
                            isDisabled: isTestingUserData
                        )
                        
                        // Test Contacts Button
                        actionButton(
                            title: "Test Contacts",
                            icon: "person.2.fill",
                            color: .orange,
                            isLoading: isTestingContacts,
                            action: testContacts,
                            isDisabled: isTestingContacts
                        )
                        
                        // Test Check-in Button
                        actionButton(
                            title: "Test Check-in",
                            icon: "clock.fill",
                            color: .purple,
                            isLoading: isTestingCheckIn,
                            action: testCheckIn,
                            isDisabled: isTestingCheckIn
                        )
                        
                        // Test QR Code Button
                        actionButton(
                            title: "Test QR Code",
                            icon: "qrcode",
                            color: .teal,
                            isLoading: isTestingQRCode,
                            action: testQRCode,
                            isDisabled: isTestingQRCode
                        )
                        
                        // Test Notification Settings Button
                        actionButton(
                            title: "Test Notification Settings",
                            icon: "bell.fill",
                            color: .indigo,
                            isLoading: isTestingNotification,
                            action: testNotificationSettings,
                            isDisabled: isTestingNotification
                        )
                        
                        // Continue to Main App Button
                        actionButton(
                            title: "Continue to App",
                            icon: "arrow.right",
                            color: .green,
                            action: { showMainApp = true }
                        )
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
                refreshStatus()
            }
            .navigationDestination(isPresented: $showMainApp) {
                ContentView()
                    .environmentObject(userViewModel)
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func statusSection(title: String, status: String, isSuccess: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                
                if isSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Success")
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
                Text(status)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(isSuccess ? Color.green.opacity(0.1) : Color(.systemGray6))
                    .cornerRadius(8)
            }
            .frame(minHeight: 120, maxHeight: 150)
        }
        .padding(.horizontal)
    }
    
    private func actionButton(
        title: String,
        icon: String,
        color: Color,
        isLoading: Bool = false,
        action: @escaping () -> Void,
        isDisabled: Bool = false
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Image(systemName: icon)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(isDisabled)
    }
    
    // MARK: - Test Methods
    
    private func refreshStatus() {
        withAnimation {
            isRefreshing = true
        }
        
        // Check if user is authenticated
        if !AuthenticationService.shared.isAuthenticated {
            userDataStatus = "Error: User not authenticated. Please sign in first."
            contactsStatus = "Error: User not authenticated. Please sign in first."
            checkInStatus = "Error: User not authenticated. Please sign in first."
            qrCodeStatus = "Error: User not authenticated. Please sign in first."
            notificationStatus = "Error: User not authenticated. Please sign in first."
            
            // Simulate refresh animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    isRefreshing = false
                }
            }
            return
        }
        
        // Load user data
        userViewModel.loadUserData { success in
            if success {
                userDataStatus = "User data loaded successfully.\n\nName: \(self.userViewModel.name)\nPhone: \(self.userViewModel.phone)\nQR Code ID: \(self.userViewModel.qrCodeId)\nProfile Description: \(self.userViewModel.profileDescription)"
                userDataTestSuccess = true
            } else {
                userDataStatus = "Failed to load user data."
                userDataTestSuccess = false
            }
            
            // Load contacts
            self.userViewModel.loadContactsFromFirestore { success in
                if success {
                    let responders = self.userViewModel.responders.count
                    let dependents = self.userViewModel.dependents.count
                    contactsStatus = "Contacts loaded successfully.\n\nTotal Contacts: \(self.userViewModel.contacts.count)\nResponders: \(responders)\nDependents: \(dependents)"
                    contactsTestSuccess = true
                } else {
                    contactsStatus = "Failed to load contacts."
                    contactsTestSuccess = false
                }
                
                // Simulate refresh animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        isRefreshing = false
                    }
                }
            }
        }
    }
    
    private func testUserData() {
        guard AuthenticationService.shared.isAuthenticated else {
            userDataStatus = "Error: User not authenticated. Please sign in first."
            return
        }
        
        isTestingUserData = true
        userDataStatus = "Testing user data..."
        userDataTestSuccess = false
        
        // Save user data
        let testName = "Test User \(Int.random(in: 100...999))"
        let testNote = "This is a test note updated at \(Date())"
        
        userViewModel.name = testName
        userViewModel.profileDescription = testNote
        
        userViewModel.saveUserData { success, error in
            if let error = error {
                DispatchQueue.main.async {
                    userDataStatus = "Error saving user data: \(error.localizedDescription)"
                    isTestingUserData = false
                }
                return
            }
            
            if success {
                // Now try to load the data back
                userViewModel.loadUserData { loadSuccess in
                    DispatchQueue.main.async {
                        if loadSuccess {
                            userDataStatus = "User data test successful!\n\nSaved and loaded user data:\nName: \(userViewModel.name)\nNote: \(userViewModel.profileDescription)"
                            userDataTestSuccess = true
                        } else {
                            userDataStatus = "Saved user data but failed to load it back."
                            userDataTestSuccess = false
                        }
                        isTestingUserData = false
                    }
                }
            } else {
                DispatchQueue.main.async {
                    userDataStatus = "Failed to save user data."
                    isTestingUserData = false
                }
            }
        }
    }
    
    private func testContacts() {
        guard AuthenticationService.shared.isAuthenticated else {
            contactsStatus = "Error: User not authenticated. Please sign in first."
            return
        }
        
        isTestingContacts = true
        contactsStatus = "Testing contacts..."
        contactsTestSuccess = false
        
        // Create a test contact
        let testContactName = "Test Contact \(Int.random(in: 100...999))"
        let testContactQRCode = UUID().uuidString
        
        userViewModel.addContact(qrCodeId: testContactQRCode, isResponder: true) { success, error in
            if let error = error {
                DispatchQueue.main.async {
                    contactsStatus = "Error adding contact: \(error.localizedDescription)"
                    isTestingContacts = false
                }
                return
            }
            
            if success {
                // Find the contact we just added
                if let addedContact = userViewModel.contacts.first(where: { $0.qrCodeId == testContactQRCode }) {
                    // Update the contact name
                    var updatedContact = addedContact
                    updatedContact.name = testContactName
                    
                    userViewModel.updateContactRole(
                        contact: updatedContact,
                        wasResponder: updatedContact.isResponder,
                        wasDependent: updatedContact.isDependent
                    ) { updateSuccess, updateError in
                        if let updateError = updateError {
                            DispatchQueue.main.async {
                                contactsStatus = "Error updating contact: \(updateError.localizedDescription)"
                                isTestingContacts = false
                            }
                            return
                        }
                        
                        if updateSuccess {
                            // Now load contacts to verify
                            userViewModel.loadContactsFromFirestore { loadSuccess in
                                DispatchQueue.main.async {
                                    if loadSuccess {
                                        // Check if our contact is there with the updated name
                                        if let loadedContact = userViewModel.contacts.first(where: { $0.qrCodeId == testContactQRCode }) {
                                            contactsStatus = "Contact test successful!\n\nAdded and updated contact:\nName: \(loadedContact.name)\nQR Code: \(loadedContact.qrCodeId ?? "None")\nIs Responder: \(loadedContact.isResponder)\nIs Dependent: \(loadedContact.isDependent)"
                                            contactsTestSuccess = true
                                        } else {
                                            contactsStatus = "Contact was added and updated but not found after reload."
                                            contactsTestSuccess = false
                                        }
                                    } else {
                                        contactsStatus = "Contact was added and updated but failed to reload contacts."
                                        contactsTestSuccess = false
                                    }
                                    isTestingContacts = false
                                }
                            }
                        } else {
                            DispatchQueue.main.async {
                                contactsStatus = "Failed to update contact."
                                isTestingContacts = false
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        contactsStatus = "Contact was added but not found in the contacts list."
                        isTestingContacts = false
                    }
                }
            } else {
                DispatchQueue.main.async {
                    contactsStatus = "Failed to add contact."
                    isTestingContacts = false
                }
            }
        }
    }
    
    private func testCheckIn() {
        guard AuthenticationService.shared.isAuthenticated else {
            checkInStatus = "Error: User not authenticated. Please sign in first."
            return
        }
        
        isTestingCheckIn = true
        checkInStatus = "Testing check-in..."
        checkInTestSuccess = false
        
        // Record the current check-in time
        let oldCheckInTime = userViewModel.lastCheckedIn
        
        // Update check-in time
        userViewModel.updateLastCheckedIn { success, error in
            if let error = error {
                DispatchQueue.main.async {
                    checkInStatus = "Error updating check-in time: \(error.localizedDescription)"
                    isTestingCheckIn = false
                }
                return
            }
            
            if success {
                // Now load user data to verify
                userViewModel.loadUserData { loadSuccess in
                    DispatchQueue.main.async {
                        if loadSuccess {
                            let newCheckInTime = userViewModel.lastCheckedIn
                            let formatter = DateFormatter()
                            formatter.dateStyle = .medium
                            formatter.timeStyle = .medium
                            
                            checkInStatus = "Check-in test successful!\n\nOld check-in time: \(formatter.string(from: oldCheckInTime))\nNew check-in time: \(formatter.string(from: newCheckInTime))"
                            checkInTestSuccess = true
                        } else {
                            checkInStatus = "Check-in time was updated but failed to load it back."
                            checkInTestSuccess = false
                        }
                        isTestingCheckIn = false
                    }
                }
            } else {
                DispatchQueue.main.async {
                    checkInStatus = "Failed to update check-in time."
                    isTestingCheckIn = false
                }
            }
        }
    }
    
    private func testQRCode() {
        guard AuthenticationService.shared.isAuthenticated else {
            qrCodeStatus = "Error: User not authenticated. Please sign in first."
            return
        }
        
        isTestingQRCode = true
        qrCodeStatus = "Testing QR code generation..."
        qrCodeTestSuccess = false
        
        // Record the current QR code
        let oldQRCode = userViewModel.qrCodeId
        
        // Generate new QR code
        userViewModel.generateNewQRCode { success, error in
            if let error = error {
                DispatchQueue.main.async {
                    qrCodeStatus = "Error generating QR code: \(error.localizedDescription)"
                    isTestingQRCode = false
                }
                return
            }
            
            if success {
                // Now load user data to verify
                userViewModel.loadUserData { loadSuccess in
                    DispatchQueue.main.async {
                        if loadSuccess {
                            let newQRCode = userViewModel.qrCodeId
                            
                            qrCodeStatus = "QR code test successful!\n\nOld QR code: \(oldQRCode)\nNew QR code: \(newQRCode)"
                            qrCodeTestSuccess = true
                        } else {
                            qrCodeStatus = "QR code was updated but failed to load it back."
                            qrCodeTestSuccess = false
                        }
                        isTestingQRCode = false
                    }
                }
            } else {
                DispatchQueue.main.async {
                    qrCodeStatus = "Failed to generate new QR code."
                    isTestingQRCode = false
                }
            }
        }
    }
    
    private func testNotificationSettings() {
        guard AuthenticationService.shared.isAuthenticated else {
            notificationStatus = "Error: User not authenticated. Please sign in first."
            return
        }
        
        isTestingNotification = true
        notificationStatus = "Testing notification settings..."
        notificationTestSuccess = false
        
        // Record the current notification lead time
        let oldLeadTime = userViewModel.notificationLeadTime
        
        // Toggle notification lead time between 30 and 120 minutes
        let newLeadTime = oldLeadTime == 30 ? 120 : 30
        
        userViewModel.setNotificationLeadTime(newLeadTime) { success, error in
            if let error = error {
                DispatchQueue.main.async {
                    notificationStatus = "Error updating notification settings: \(error.localizedDescription)"
                    isTestingNotification = false
                }
                return
            }
            
            if success {
                // Now load user data to verify
                userViewModel.loadUserData { loadSuccess in
                    DispatchQueue.main.async {
                        if loadSuccess {
                            let updatedLeadTime = userViewModel.notificationLeadTime
                            
                            notificationStatus = "Notification settings test successful!\n\nOld lead time: \(oldLeadTime) minutes\nNew lead time: \(updatedLeadTime) minutes"
                            notificationTestSuccess = true
                        } else {
                            notificationStatus = "Notification settings were updated but failed to load them back."
                            notificationTestSuccess = false
                        }
                        isTestingNotification = false
                    }
                }
            } else {
                DispatchQueue.main.async {
                    notificationStatus = "Failed to update notification settings."
                    isTestingNotification = false
                }
            }
        }
    }
}

#Preview {
    UserModelTestView()
        .environmentObject(UserViewModel())
}
