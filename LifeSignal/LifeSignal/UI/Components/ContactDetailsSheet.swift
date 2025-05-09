import SwiftUI
import Foundation
import UIKit

struct ContactDetailsSheet: View {
    let contactID: UUID // Store the contact ID instead of a binding
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var userViewModel: UserViewModel
    @State private var showDeleteAlert = false
    @State private var isResponder: Bool
    @State private var isDependent: Bool
    @State private var showRoleAlert = false
    @State private var lastValidRoles: (Bool, Bool)
    @State private var activeAlert: ContactAlertType?
    @State private var pendingToggleRevert: RoleChanged?
    @State private var refreshID = UUID() // Used to force refresh the view
    @State private var shouldDismiss = false // Flag to indicate when sheet should dismiss
    @State private var originalList: String // Tracks which list the contact was opened from

    // Computed property to find the contact in the view model's contacts list
    private var contact: Contact? {
        // Get the contact from the UserViewModel using the more efficient lookup method
        let foundContact = userViewModel.getContact(by: contactID)

        // Synchronize local state with the contact in the view model
        syncLocalStateWithContact(foundContact)

        return foundContact
    }

    // Helper method to synchronize local state with the contact
    private func syncLocalStateWithContact(_ foundContact: Contact?) {
        guard let foundContact = foundContact else { return }

        // Only update if there's a mismatch to avoid unnecessary state changes
        if foundContact.isResponder != isResponder || foundContact.isDependent != isDependent {
            // Use DispatchQueue to avoid modifying state during view update
            DispatchQueue.main.async {
                self.isResponder = foundContact.isResponder
                self.isDependent = foundContact.isDependent
                self.lastValidRoles = (foundContact.isResponder, foundContact.isDependent)
            }
        }
    }

    init(contact: Contact) {
        self.contactID = contact.id
        self._isResponder = State(initialValue: contact.isResponder)
        self._isDependent = State(initialValue: contact.isDependent)
        self._lastValidRoles = State(initialValue: (contact.isResponder, contact.isDependent))

        // Determine which list the contact was opened from
        if contact.isResponder && contact.isDependent {
            self._originalList = State(initialValue: "both")
        } else if contact.isResponder {
            self._originalList = State(initialValue: "responders")
        } else {
            self._originalList = State(initialValue: "dependents")
        }
    }

    // MARK: - Contact Dismissed View
    private var contactDismissedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Contact role updated")
                .font(.headline)
            Text("This contact has been moved to a different list.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("Close") {
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            Spacer()
        }
        .padding()
        .onAppear {
            // Auto-dismiss after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }

    // MARK: - Contact Header View
    private var contactHeaderView: some View {
        Group {
            if let contact = contact {
                VStack(spacing: 12) {
                    Circle()
                        .fill(Color(UIColor.systemBackground))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Text(String(contact.name.prefix(1)))
                                .foregroundColor(.blue)
                                .font(.title)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.blue, lineWidth: 2)
                        )
                        .padding(.top, 24)
                    Text(contact.name)
                        .font(.headline)
                        .bold()
                        .foregroundColor(.primary)
                    Text(contact.phone)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            } else {
                Text("Contact not found")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Action Buttons View
    private var actionButtonsView: some View {
        Group {
            if let contact = contact {
                HStack(spacing: 12) {
                    ForEach(ActionButtonType.allCases) { type in
                        Button(action: {
                            // Show alert for disabled ping button, otherwise handle action normally
                            if type == .ping && !contact.isDependent {
                                activeAlert = .pingDisabled
                            } else {
                                handleAction(type)
                            }
                        }) {
                            // Visual styling for disabled ping button for non-dependents
                            VStack(spacing: 6) {
                                Image(systemName: type.icon(for: contact))
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)
                                Text(type.label(for: contact))
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 75)
                            .background(Color(UIColor.systemGray5))
                            .cornerRadius(12)
                            .opacity(type == .ping && !contact.isDependent ? 0.5 : 1.0)
                        }
                    }
                }
                .padding(.horizontal)
            } else {
                EmptyView()
            }
        }
    }

    // MARK: - Alert Card Views
    private var manualAlertCardView: some View {
        Group {
            if let contact = contact, contact.manualAlertActive, let ts = contact.manualAlertTimestamp {
                VStack(spacing: 0) {
                    HStack {
                        Text("Sent out an Alert")
                            .font(.body)
                            .foregroundColor(.red)
                        Spacer()
                        Text(formatTimeAgo(ts))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                }
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    private var pingCardView: some View {
        Group {
            if let contact = contact, contact.isResponder && contact.hasIncomingPing, let pingTime = contact.incomingPingTimestamp {
                VStack(spacing: 0) {
                    HStack {
                        Text("Pinged You")
                            .font(.body)
                            .foregroundColor(.blue)
                        Spacer()
                        Text(formatTimeAgo(pingTime))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                }
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    private var notResponsiveCardView: some View {
        Group {
            if let contact = contact, isNotResponsive(contact) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Countdown expired")
                            .font(.body)
                            .foregroundColor(.yellow)
                        Spacer()
                        if let lastCheckIn = contact.lastCheckIn {
                            let interval = contact.interval ?? 24 * 60 * 60
                            let expiration = lastCheckIn.addingTimeInterval(interval)
                            Text(formatTimeAgo(expiration))
                                .font(.body)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Never")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                }
                .background(Color.yellow.opacity(0.15))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Information Card Views
    private var noteCardView: some View {
        Group {
            if let contact = contact {
                VStack(spacing: 0) {
                    HStack {
                        Text(contact.note.isEmpty ? "No emergency information provided yet." : contact.note)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                }
                .background(Color(UIColor.systemGray5))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    private var rolesCardView: some View {
        Group {
            VStack(spacing: 0) {
                HStack {
                    Text("Dependent")
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    Toggle("", isOn: $isDependent)
                        .labelsHidden()
                        .onChange(of: isDependent) { oldValue, newValue in
                            validateRoles(changed: .dependent)
                        }
                }
                .padding(.vertical, 12)
                .padding(.horizontal)
                Divider().padding(.leading)
                HStack {
                    Text("Responder")
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    Toggle("", isOn: $isResponder)
                        .labelsHidden()
                        .onChange(of: isResponder) { oldValue, newValue in
                            validateRoles(changed: .responder)
                        }
                }
                .padding(.vertical, 12)
                .padding(.horizontal)
            }
            .background(Color(UIColor.systemGray5))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    private var checkInCardView: some View {
        Group {
            if let contact = contact {
                VStack(spacing: 0) {
                    HStack {
                        Text("Check-in interval")
                            .foregroundColor(.primary)
                            .font(.body)
                        Spacer()
                        Text(formatInterval(contact.interval ?? 24 * 60 * 60))
                            .foregroundColor(.secondary)
                            .font(.body)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                    Divider().padding(.leading)
                    HStack {
                        Text("Last check-in")
                            .foregroundColor(.primary)
                            .font(.body)
                        Spacer()
                        if let lastCheckIn = contact.lastCheckIn {
                            Text(formatTimeAgo(lastCheckIn))
                                .foregroundColor(.secondary)
                                .font(.body)
                        } else {
                            Text("Never")
                                .foregroundColor(.secondary)
                                .font(.body)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                }
                .background(Color(UIColor.systemGray5))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    private var deleteButtonView: some View {
        Group {
            if contact != nil {
                Button(action: {
                    activeAlert = .delete
                }) {
                    Text("Delete Contact")
                        .font(.body)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal)
                        .background(Color(UIColor.systemGray5))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if shouldDismiss {
                    // Show a message when the contact is removed from its original list
                    contactDismissedView
                } else if userViewModel.isLoadingContacts {
                    // Show loading indicator
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Loading contact details...")
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = userViewModel.contactError {
                    // Show error view
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.red)

                        Text("Error Loading Contact")
                            .font(.headline)

                        Text(error.localizedDescription)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)

                        Button("Retry") {
                            userViewModel.forceReloadContacts()
                            refreshID = UUID()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // This is a hidden view that will trigger a refresh when refreshID changes
                            Text("")
                                .frame(width: 0, height: 0)
                                .opacity(0)
                                .id(refreshID)

                            // Header
                            contactHeaderView

                            // Button Row (moved above note)
                            actionButtonsView

                            // Alert Cards
                            manualAlertCardView
                            pingCardView
                            notResponsiveCardView

                            // Information Cards
                            noteCardView
                            rolesCardView
                            checkInCardView
                            deleteButtonView
                        }
                    }
                }
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationTitle("Contact Info")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Ensure our local state is in sync with the contact in the view model
                syncLocalStateWithContact(contact)

                // Force refresh to ensure we have the latest data
                refreshID = UUID()
            }
        }
        .alert(item: $activeAlert) { alertType in
            switch alertType {
            case .role:
                return Alert(
                    title: Text("Role Required"),
                    message: Text("You must have at least one role selected. To remove this contact, use Delete Contact."),
                    dismissButton: .default(Text("OK")) {
                        if let pending = pendingToggleRevert {
                            switch pending {
                            case .dependent:
                                isDependent = lastValidRoles.1
                            case .responder:
                                isResponder = lastValidRoles.0
                            }
                            pendingToggleRevert = nil
                        }
                    }
                )
            case .delete:
                return Alert(
                    title: Text("Delete Contact"),
                    message: Text("Are you sure you want to delete this contact? This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) { deleteContact() },
                    secondaryButton: .cancel()
                )
            case .ping:
                // Only allow pinging dependents
                // Check if the dependent has an outgoing ping
                guard let currentContact = contact else { return Alert(title: Text("Error"), message: Text("Contact not found"), dismissButton: .default(Text("OK"))) }
                if currentContact.isDependent && currentContact.hasOutgoingPing {
                    return Alert(
                        title: Text("Clear Ping"),
                        message: Text("Do you want to clear the pending ping to this contact?"),
                        primaryButton: .default(Text("Clear")) {
                            pingContact()
                        },
                        secondaryButton: .cancel()
                    )
                } else {
                    return Alert(
                        title: Text("Ping Contact"),
                        message: Text("Are you sure you want to ping this contact?"),
                        primaryButton: .default(Text("Ping")) {
                            pingContact()
                            activeAlert = .pingConfirmation
                        },
                        secondaryButton: .cancel()
                    )
                }
            case .pingConfirmation:
                return Alert(
                    title: Text("Ping Sent"),
                    message: Text("The contact was successfully pinged."),
                    dismissButton: .default(Text("OK"))
                )
            case .pingDisabled:
                return Alert(
                    title: Text("Cannot Ping"),
                    message: Text("This contact must have the Dependent role to be pinged. Enable the Dependent role in the contact settings to use this feature."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private enum ActionButtonType: CaseIterable, Identifiable {
        case call, message, ping

        // Conform to Identifiable
        var id: Self { self }

        // Icon for the button
        func icon(for contact: Contact) -> String {
            switch self {
            case .call:
                return "phone"
            case .message:
                return "message"
            case .ping:
                return contact.isDependent
                    ? (contact.hasOutgoingPing ? "bell.fill" : "bell")
                    : "bell.slash"
            }
        }

        // Label for the button
        func label(for contact: Contact) -> String {
            switch self {
            case .call:
                return "Call"
            case .message:
                return "Message"
            case .ping:
                if !contact.isDependent {
                    return "Can't Ping"
                }
                return contact.hasOutgoingPing ? "Pinged" : "Ping"
            }
        }
    }

    private func handleAction(_ type: ActionButtonType) {
        switch type {
        case .call: callContact()
        case .message: messageContact()
        case .ping: activeAlert = .ping
        }
    }

    private func callContact() {
        guard let currentContact = contact else { return }
        if let url = URL(string: "tel://\(currentContact.phone)") {
            UIApplication.shared.open(url)
        }
    }

    private func messageContact() {
        guard let currentContact = contact else { return }
        if let url = URL(string: "sms://\(currentContact.phone)") {
            UIApplication.shared.open(url)
        }
    }

    private func pingContact() {
        guard let currentContact = contact, currentContact.isDependent else { return }

        // Use the UserViewModel's handlePingOperation method which handles all ping operations
        let operation = currentContact.hasOutgoingPing ? UserViewModel.PingOperation.clear : UserViewModel.PingOperation.send

        userViewModel.handlePingOperation(operation: operation, for: currentContact) { success, error in
            if let error = error {
                print("Error handling ping operation: \(error.localizedDescription)")
                return
            }

            if success {
                // Force refresh the view
                DispatchQueue.main.async {
                    self.refreshID = UUID()
                }
            }
        }
    }

    private enum RoleChanged { case dependent, responder }

    private func validateRoles(changed: RoleChanged) {
        // Validate that at least one role is selected
        if !isResponder && !isDependent {
            pendingToggleRevert = changed
            activeAlert = .role
            return
        }

        activeAlert = nil

        guard let currentContact = contact else {
            print("Cannot validate roles: contact not found")
            return
        }

        // Store the previous roles before updating
        let wasResponder = currentContact.isResponder
        let wasDependent = currentContact.isDependent

        // If the roles haven't actually changed, do nothing
        if wasResponder == isResponder && wasDependent == isDependent {
            return
        }

        // Update the local state
        lastValidRoles = (isResponder, isDependent)

        // Create a mutable copy for the view model update
        var updatedContact = currentContact
        updatedContact.isResponder = isResponder
        updatedContact.isDependent = isDependent

        // Update the contact's position in the lists based on role changes
        userViewModel.updateContactRole(contact: updatedContact, wasResponder: wasResponder, wasDependent: wasDependent) { success, error in
            if let error = error {
                print("Error updating contact role: \(error.localizedDescription)")
                // Revert local state on error
                DispatchQueue.main.async {
                    self.isResponder = wasResponder
                    self.isDependent = wasDependent
                    self.lastValidRoles = (wasResponder, wasDependent)
                    self.refreshID = UUID() // Force refresh
                }
                return
            }

            if success {
                // Force refresh the view
                DispatchQueue.main.async {
                    self.refreshID = UUID()
                }
            }
        }
    }

    private func deleteContact() {
        guard let currentContact = contact else {
            print("Cannot delete contact: contact not found")
            return
        }

        // Remove the contact using the UserViewModel
        userViewModel.removeContact(currentContact) { success, error in
            if let error = error {
                print("Error removing contact: \(error.localizedDescription)")
                return
            }

            if success {
                // Dismiss the sheet after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatTimeAgo(_ date: Date) -> String {
        return TimeManager.shared.formatTimeAgo(date)
    }

    private func formatInterval(_ interval: TimeInterval) -> String {
        let days = Int(interval / (24 * 60 * 60))
        let hours = Int((interval.truncatingRemainder(dividingBy: 24 * 60 * 60)) / (60 * 60))
        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s")"
        } else {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }
    }

    private func isNotResponsive(_ contact: Contact?) -> Bool {
        guard let contact = contact else { return false }
        // Always check if countdown is expired, regardless of manual alert status
        let interval = contact.interval ?? 24 * 60 * 60
        if let last = contact.lastCheckIn {
            return last.addingTimeInterval(interval) < Date()
        } else {
            return true
        }
    }
}

enum ContactAlertType: Identifiable {
    case role, delete, ping, pingConfirmation, pingDisabled
    var id: Int { hashValue }
}
