import SwiftUI
import Foundation
import AVFoundation
import UIKit
import FirebaseFirestore

struct HomeView: View {
    @EnvironmentObject private var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject private var contactsViewModel: ContactsViewModel
    @State private var showQRScanner = false
    @State private var showIntervalPicker = false
    @State private var showInstructions = false
    @State private var showCheckInConfirmation = false
    @State private var showShareSheet = false
    @State private var qrCodeImage: UIImage? = nil
    @State private var isImageReady = false
    @State private var isGeneratingImage = false
    @State private var showCameraDeniedAlert = false
    @State private var newContact: ContactReference? = nil
    @State private var pendingScannedCode: String? = nil
    @State private var shareImage: ShareImage? = nil
    @State private var showContactAddedAlert = false
    @State private var showContactExistsAlert = false
    @State private var showContactErrorAlert = false
    @State private var contactErrorMessage = ""
    @State private var showAlertToggleConfirmation = false
    @State private var pendingAlertToggleValue: Bool? = nil

    func generateQRCodeImage(completion: @escaping () -> Void = {}) {
        if isGeneratingImage { return }

        isImageReady = false
        isGeneratingImage = true
        let qrContent = userProfileViewModel.qrCodeId
        let content = AnyView(
            QRCodeShareView(
                name: userProfileViewModel.name,
                subtitle: "LifeSignal contact",
                qrCodeId: qrContent,
                footer: "Use LifeSignal's QR code scanner to add this contact"
            )
        )

        if #available(iOS 16.0, *) {
            let renderer = ImageRenderer(content: content)
            renderer.scale = UIScreen.main.scale
            qrCodeImage = renderer.uiImage
            isImageReady = true
            isGeneratingImage = false
            completion()
        } else {
            let renderer = LegacyImageRenderer(content: content)
            qrCodeImage = renderer.uiImage
            isImageReady = true
            isGeneratingImage = false
            completion()
        }
    }

    func shareQRCode() {
        if isImageReady, let image = qrCodeImage {
            shareImage = ShareImage(image: image)
        } else if !isGeneratingImage {
            generateQRCodeImage {
                if let image = qrCodeImage {
                    shareImage = ShareImage(image: image)
                }
            }
        }
    }

    func formatInterval(_ interval: TimeInterval) -> String {
        let days = Int(interval / (24 * 60 * 60))
        let hours = Int((interval.truncatingRemainder(dividingBy: 24 * 60 * 60)) / (60 * 60))

        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s")"
        } else {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // QR Code Card with avatar above (overlapping, improved layout)
                QRCodeCardView(
                    name: userProfileViewModel.name,
                    subtitle: "LifeSignal contact",
                    qrCodeId: userProfileViewModel.qrCodeId,
                    footer: "Your QR code is unique. If you share it with someone, they can scan it and add you as a contact"
                )
                .padding(EdgeInsets(top: 16, leading: 0, bottom: 0, trailing: 0))

                Button("Reset QR Code") {
                    userProfileViewModel.generateNewQRCode()
                }
                .foregroundColor(.blue)
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    AVCaptureDevice.requestAccess(for: .video) { granted in
                        if granted {
                            DispatchQueue.main.async {
                                showQRScanner = true
                            }
                        } else {
                            DispatchQueue.main.async {
                                showCameraDeniedAlert = true
                            }
                        }
                    }
                }) {
                    Text("Add Contact")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .frame(width: 200)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 16)

                // Information about check-in
                HStack {
                    Text("Check-in status")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("Active")
                        .foregroundColor(.green)
                }
                .padding(.vertical, 12)
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemGray5))
                .cornerRadius(12)
                .padding(.horizontal)

                // Settings Section
                VStack(alignment: .leading, spacing: 24) {
                    // Section: Check-in Interval
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Button(action: {
                                showIntervalPicker = true
                            }) {
                                HStack {
                                    Text("Check-in time interval")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("\(formatInterval(userProfileViewModel.checkInInterval))")
                                        .foregroundColor(.secondary)
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal)
                                .frame(maxWidth: .infinity)
                                .background(Color(UIColor.systemGray5))
                                .cornerRadius(12)
                            }

                            Text("Time until your countdown expires and responders are notified if you don't check in.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    // Section: Notifications
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Check-in notification")
                            .foregroundColor(.primary)
                            .padding(.horizontal)
                            .padding(.leading)
                        Picker("Check-in notification", selection: Binding(
                            get: { self.userProfileViewModel.notificationLeadTime },
                            set: { newValue in
                                // Update local state immediately for responsive UI
                                self.userProfileViewModel.notificationLeadTime = newValue

                                // Save to Firestore in the background
                                self.userProfileViewModel.setNotificationLeadTime(newValue) { success, error in
                                    if let error = error {
                                        // Just log the error, don't show to user
                                        print("Error saving notification lead time: \(error.localizedDescription)")
                                    }
                                }
                            }
                        )) {
                            Text("30 mins").tag(30)
                            Text("2 hours").tag(120)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        Text("Choose when you'd like to be reminded before your countdown expires.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .onAppear {
                        if ![30, 120].contains(userProfileViewModel.notificationLeadTime) {
                            // Set default value and save to Firestore in the background
                            userProfileViewModel.notificationLeadTime = 30
                            userProfileViewModel.setNotificationLeadTime(30) { _, _ in }
                        }
                    }
                    // Section: Help/Instructions
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: {
                            showInstructions = true
                        }) {
                            HStack {
                                Text("Review instructions")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity)
                            .background(Color(UIColor.systemGray5))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }

                    // Alert Toggle Row (new component)
                    Button(action: {
                        pendingAlertToggleValue = !userProfileViewModel.sendAlertActive
                        showAlertToggleConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 20))
                                .padding(.trailing, 4)
                            Text("Alert to responders")
                                .foregroundColor(.primary)
                                .fontWeight(.medium)
                            Spacer()
                            Text(userProfileViewModel.sendAlertActive ? "Active" : "Inactive")
                                .foregroundColor(userProfileViewModel.sendAlertActive ? .red : .secondary)
                                .fontWeight(userProfileViewModel.sendAlertActive ? .semibold : .medium)
                        }
                        .frame(height: 35)
                        .padding(.vertical, 12)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity)
                        .background(
                            userProfileViewModel.sendAlertActive ?
                                Color.red.opacity(0.15) :
                                Color(UIColor.systemGray5)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(userProfileViewModel.sendAlertActive ? Color.red.opacity(0.3) : Color.clear, lineWidth: 2)
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)
                    .shadow(color: userProfileViewModel.sendAlertActive ? Color.red.opacity(0.1) : Color.clear, radius: 4, x: 0, y: 2)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.bottom, 60)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showQRScanner, onDismiss: {
            if let code = pendingScannedCode {
                // Look up the user by QR code
                contactsViewModel.lookupUserByQRCode(code) { userData, error in
                    if let error = error {
                        print("Error looking up user by QR code: \(error.localizedDescription)")
                        return
                    }

                    guard let userData = userData else {
                        print("No user found with QR code: \(code)")
                        return
                    }

                    // Create a new contact with the user data
                    DispatchQueue.main.async {
                        self.newContact = ContactReference.createDefault(
                            name: userData[User.Fields.name] as? String ?? "Unknown Name",
                            phone: userData[User.Fields.phoneNumber] as? String ?? "",
                            note: userData[User.Fields.note] as? String ?? "",
                            qrCodeId: code,
                            isResponder: false,
                            isDependent: false
                        )
                    }
                }
                pendingScannedCode = nil
            }
        }) {
            QRScannerView { result in
                pendingScannedCode = result
            }
        }
        .sheet(item: $newContact, onDismiss: { newContact = nil }) { contact in
            AddContactSheet(
                contact: contact,
                onAdd: { confirmedContact in
                    // Use the QR code to add the contact via Firebase
                    if let qrCodeId = confirmedContact.qrCodeId {
                        contactsViewModel.addContact(
                            qrCodeId: qrCodeId,
                            isResponder: confirmedContact.isResponder,
                            isDependent: confirmedContact.isDependent
                        ) { success, error in
                            if success {
                                if let error = error as NSError?,
                                   error.domain == "ContactsViewModel",
                                   error.code == 400,
                                   error.localizedDescription.contains("already exists") {
                                    // Contact already exists - show appropriate alert
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showContactExistsAlert = true
                                    }
                                } else {
                                    // Contact was added successfully
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showContactAddedAlert = true
                                    }
                                }
                            } else if let error = error {
                                print("Error adding contact: \(error.localizedDescription)")
                                // Show error alert to the user
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    contactErrorMessage = error.localizedDescription
                                    showContactErrorAlert = true
                                }
                            }
                        }
                    }
                },
                onClose: { newContact = nil }
            )
        }
        .sheet(isPresented: $showIntervalPicker) {
            IntervalPickerView(
                interval: userProfileViewModel.checkInInterval,
                onSave: { newInterval, completion in
                    // Create data to update in Firestore
                    let updateData: [String: Any] = [
                        FirestoreSchema.User.checkInInterval: newInterval,
                        FirestoreSchema.User.lastUpdated: FieldValue.serverTimestamp()
                    ]

                    // Save to Firestore
                    userProfileViewModel.saveUserData(additionalData: updateData) { success, error in
                        if success {
                            // Update local property if Firestore update was successful
                            DispatchQueue.main.async {
                                userProfileViewModel.checkInInterval = newInterval
                            }
                        }
                        // Pass result back to the IntervalPickerView
                        completion(success, error)
                    }
                }
            )
            .environmentObject(userProfileViewModel)
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showInstructions) {
            InstructionsView()
        }
        .sheet(item: $shareImage) { shareImage in
            ShareSheet(activityItems: [shareImage.image], title: "Share QR Code")
        }
        .onAppear {
            generateQRCodeImage()
        }
        .onChange(of: userProfileViewModel.qrCodeId) { oldValue, newValue in
            generateQRCodeImage()
        }
        .alert(isPresented: $showCheckInConfirmation) {
            Alert(
                title: Text("Confirm Check-in"),
                message: Text("Are you sure you want to check in now? This will reset your timer."),
                primaryButton: .default(Text("Check In")) {
                    userProfileViewModel.updateLastCheckedIn()
                },
                secondaryButton: .cancel()
            )
        }
        .alert(isPresented: $showCameraDeniedAlert) {
            Alert(
                title: Text("Camera Access Denied"),
                message: Text("Please enable camera access in Settings to scan QR codes."),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $showContactAddedAlert) {
            Alert(
                title: Text("Contact Added"),
                message: Text("The contact was successfully added."),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $showContactExistsAlert) {
            Alert(
                title: Text("Contact Already Exists"),
                message: Text("This user is already in your contacts list."),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $showContactErrorAlert) {
            Alert(
                title: Text("Error Adding Contact"),
                message: Text(contactErrorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $showAlertToggleConfirmation) {
            Alert(
                title: Text(userProfileViewModel.sendAlertActive ? "Deactivate Alert?" : "Send Alert?"),
                message: Text(userProfileViewModel.sendAlertActive ? "Are you sure you want to deactivate the alert to responders?" : "Are you sure you want to send an alert to responders?"),
                primaryButton: .destructive(Text(userProfileViewModel.sendAlertActive ? "Deactivate" : "Activate")) {
                    if let value = pendingAlertToggleValue {
                        userProfileViewModel.sendAlertActive = value
                    }
                    pendingAlertToggleValue = nil
                },
                secondaryButton: .cancel {
                    pendingAlertToggleValue = nil
                }
            )
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    shareQRCode()
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }
}

// MARK: - Instructions
struct InstructionsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject private var contactsViewModel: ContactsViewModel
    @State private var showCheckInConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    instructionSection(
                        title: "Welcome to LifeSignal",
                        content: "LifeSignal helps you stay connected with your trusted contacts. It automatically notifies your responders if you don't check in within your specified time interval.",
                        icon: "app.badge.checkmark.fill"
                    )

                    instructionSection(
                        title: "Setting Up",
                        content: "1. Set your check-in interval in the Home tab\n2. Add responders by scanning their QR code\n3. Enable notifications to receive reminders before timeout",
                        icon: "gear"
                    )

                    instructionSection(
                        title: "Regular Check-ins",
                        content: "Remember to check in regularly by tapping the 'Check-In' tab in the navigation bar. This resets your timer and prevents notifications from being sent to your responders.",
                        icon: "clock.fill"
                    )

                    instructionSection(
                        title: "Adding Responders",
                        content: "Responders are people who will be notified if you don't check in. To add a responder:\n1. Go to the Responders tab\n2. Tap the QR code icon in the navigation bar\n3. Scan their QR code",
                        icon: "person.2.fill"
                    )

                    instructionSection(
                        title: "Adding Dependents",
                        content: "Dependents are people you're responsible for. You'll be notified if they don't check in. To add a dependent:\n1. Go to the Dependents tab\n2. Tap the QR code icon in the navigation bar\n3. Scan their QR code",
                        icon: "person.3.fill"
                    )

                    instructionSection(
                        title: "Notifications",
                        content: "You can choose to receive notifications:\n• 30 minutes before timeout\n• 2 hours before timeout\n\nThese help remind you to check in before your responders are alerted.",
                        icon: "bell.fill"
                    )

                    instructionSection(
                        title: "Privacy & Security",
                        content: "Your data is private and secure. Your location is never shared without your explicit permission. You can reset your QR code at any time from the Home screen.",
                        icon: "lock.shield.fill"
                    )
                }
                .padding()
            }
            .navigationTitle("Instructions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    private func instructionSection(title: String, content: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)

                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
            }

            Text(content)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 10)
    }
}

struct ShareImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

#Preview {
    HomeView()
        .environmentObject(UserProfileViewModel())
        .environmentObject(ContactsViewModel())
}
