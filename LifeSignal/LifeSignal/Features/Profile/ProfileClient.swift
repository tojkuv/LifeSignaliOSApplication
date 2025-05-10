import Foundation
import ComposableArchitecture
import FirebaseFirestore
import FirebaseAuth

/// Client for interacting with profile functionality
struct ProfileClient {
    /// Load profile data from Firestore
    var loadProfile: () async throws -> (name: String, phoneNumber: String, phoneRegion: String, note: String, qrCodeId: String, notificationEnabled: Bool, profileComplete: Bool)

    /// Update profile data in Firestore
    var updateProfile: (name: String, note: String) async throws -> Bool

    /// Update notification settings in Firestore
    var updateNotificationSettings: (enabled: Bool) async throws -> Bool

    /// Load settings from Firestore
    var loadSettings: () async throws -> Bool

    /// Sign out the current user
    var signOut: () async throws -> Bool
}

extension ProfileClient: DependencyKey {
    /// Live implementation of the profile client
    static var liveValue: Self {
        return Self(
            loadProfile: {
                guard let userId = AuthenticationService.shared.getCurrentUserID() else {
                    throw NSError(domain: "ProfileClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

                let db = Firestore.firestore()
                let userRef = db.collection(FirestoreConstants.Collections.users).document(userId)

                let document = try await userRef.getDocument()

                guard let data = document.data() else {
                    throw NSError(domain: "ProfileClient", code: 404, userInfo: [NSLocalizedDescriptionKey: "User document not found"])
                }

                let name = data[FirestoreConstants.UserFields.name] as? String ?? ""
                let phoneNumber = data[FirestoreConstants.UserFields.phoneNumber] as? String ?? ""
                let phoneRegion = data[FirestoreConstants.UserFields.phoneRegion] as? String ?? "US"
                let note = data[FirestoreConstants.UserFields.note] as? String ?? ""
                let qrCodeId = data[FirestoreConstants.UserFields.qrCodeId] as? String ?? ""
                let notificationEnabled = data[FirestoreConstants.UserFields.notificationEnabled] as? Bool ?? true
                let profileComplete = data[FirestoreConstants.UserFields.profileComplete] as? Bool ?? false

                return (
                    name: name,
                    phoneNumber: phoneNumber,
                    phoneRegion: phoneRegion,
                    note: note,
                    qrCodeId: qrCodeId,
                    notificationEnabled: notificationEnabled,
                    profileComplete: profileComplete
                )
            },

            updateProfile: { name, note in
                guard let userId = AuthenticationService.shared.getCurrentUserID() else {
                    throw NSError(domain: "ProfileClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

                let db = Firestore.firestore()
                let userRef = db.collection(FirestoreConstants.Collections.users).document(userId)

                let updateData: [String: Any] = [
                    FirestoreConstants.UserFields.name: name,
                    FirestoreConstants.UserFields.note: note,
                    FirestoreConstants.UserFields.profileComplete: true,
                    FirestoreConstants.UserFields.lastUpdated: Timestamp(date: Date())
                ]

                try await userRef.updateData(updateData)
                return true
            },

            updateNotificationSettings: { enabled in
                guard let userId = AuthenticationService.shared.getCurrentUserID() else {
                    throw NSError(domain: "ProfileClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

                let db = Firestore.firestore()
                let userRef = db.collection(FirestoreConstants.Collections.users).document(userId)

                let updateData: [String: Any] = [
                    FirestoreConstants.UserFields.notificationEnabled: enabled,
                    FirestoreConstants.UserFields.lastUpdated: Timestamp(date: Date())
                ]

                try await userRef.updateData(updateData)
                return true
            },

            loadSettings: {
                guard let userId = AuthenticationService.shared.getCurrentUserID() else {
                    throw NSError(domain: "ProfileClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

                let db = Firestore.firestore()
                let userRef = db.collection(FirestoreConstants.Collections.users).document(userId)

                let document = try await userRef.getDocument()

                guard let data = document.data() else {
                    throw NSError(domain: "ProfileClient", code: 404, userInfo: [NSLocalizedDescriptionKey: "User document not found"])
                }

                let notificationsEnabled = data[FirestoreConstants.UserFields.notificationEnabled] as? Bool ?? true

                return notificationsEnabled
            },

            signOut: {
                do {
                    try Auth.auth().signOut()
                    return true
                } catch {
                    throw error
                }
            }
        )
    }

    /// Test implementation of the profile client
    static var testValue: Self {
        return Self(
            loadProfile: {
                return (
                    name: "Test User",
                    phoneNumber: "+15551234567",
                    phoneRegion: "US",
                    note: "Test note",
                    qrCodeId: "test-qr-code",
                    notificationEnabled: true,
                    profileComplete: true
                )
            },

            updateProfile: { _, _ in
                return true
            },

            updateNotificationSettings: { _ in
                return true
            },

            loadSettings: {
                return true
            },

            signOut: {
                return true
            }
        )
    }
}

extension DependencyValues {
    var profileClient: ProfileClient {
        get { self[ProfileClient.self] }
        set { self[ProfileClient.self] = newValue }
    }
}
