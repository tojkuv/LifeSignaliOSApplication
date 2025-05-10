import Foundation
import FirebaseFirestore
import FirebaseAuth
import ComposableArchitecture

/// Protocol defining session management operations
protocol SessionClientProtocol {
    /// Get the current session ID
    func getCurrentSessionId() -> String?
    
    /// Update the session ID in Firestore and UserDefaults
    func updateSession(userId: String) async throws
    
    /// Validate the current session against Firestore
    func validateSession(userId: String) async throws -> Bool
    
    /// Set up a listener for session changes
    func watchSession(userId: String) -> AsyncStream<Void>
    
    /// Clear the session ID
    func clearSessionId()
}

/// Live implementation of SessionClient
struct SessionLiveClient: SessionClientProtocol {
    private let sessionIdKey = "user_session_id"
    private let db = Firestore.firestore()
    
    func getCurrentSessionId() -> String? {
        return UserDefaults.standard.string(forKey: sessionIdKey)
    }
    
    private func generateSessionId() -> String {
        return UUID().uuidString
    }
    
    private func saveSessionId(_ sessionId: String) {
        UserDefaults.standard.set(sessionId, forKey: sessionIdKey)
    }
    
    func clearSessionId() {
        UserDefaults.standard.removeObject(forKey: sessionIdKey)
    }
    
    func updateSession(userId: String) async throws {
        let sessionId = generateSessionId()
        
        // Save locally first
        saveSessionId(sessionId)
        
        // Reference to the user document
        let userDocRef = db.collection(FirestoreConstants.Collections.users).document(userId)
        
        // First check if the document exists
        let document = try await userDocRef.getDocument()
        
        // Session data to update or create
        let sessionData: [String: Any] = [
            FirestoreConstants.UserFields.sessionId: sessionId,
            FirestoreConstants.UserFields.lastSignInTime: FieldValue.serverTimestamp()
        ]
        
        if document.exists {
            // Document exists, update it
            // For test users, use setData with merge to ensure all fields are preserved
            if let phoneNumber = Auth.auth().currentUser?.phoneNumber,
               phoneNumber == "+11234567890" || phoneNumber == "+16505553434" {
                try await userDocRef.setData(sessionData, merge: true)
            } else {
                // Regular user, use updateData
                try await userDocRef.updateData(sessionData)
            }
        } else {
            // Document doesn't exist, create it with basic user data
            var userData = sessionData
            
            // Add additional required fields for a new user
            userData[FirestoreConstants.UserFields.uid] = userId
            userData[FirestoreConstants.UserFields.createdAt] = FieldValue.serverTimestamp()
            userData[FirestoreConstants.UserFields.profileComplete] = false
            
            // Generate a QR code ID for the new user - CRITICAL FIELD
            let qrCodeId = UUID().uuidString
            userData[FirestoreConstants.UserFields.qrCodeId] = qrCodeId
            
            // Add phone number if available
            if let phoneNumber = Auth.auth().currentUser?.phoneNumber {
                userData[FirestoreConstants.UserFields.phoneNumber] = phoneNumber
            } else {
                userData[FirestoreConstants.UserFields.phoneNumber] = "" // Required field
            }
            
            // Add required fields according to Firestore rules
            userData[FirestoreConstants.UserFields.name] = "New User" // Required field
            userData[FirestoreConstants.UserFields.note] = "" // Required field
            userData[FirestoreConstants.UserFields.checkInInterval] = 24 * 60 * 60 // 24 hours in seconds
            userData[FirestoreConstants.UserFields.lastCheckedIn] = FieldValue.serverTimestamp()
            
            // Initialize other fields with default values
            userData[FirestoreConstants.UserFields.notificationEnabled] = true
            userData[FirestoreConstants.UserFields.notify30MinBefore] = false
            userData[FirestoreConstants.UserFields.notify2HoursBefore] = false
            userData[FirestoreConstants.UserFields.manualAlertActive] = false
            userData[FirestoreConstants.UserFields.contacts] = []
            
            // Create the document
            try await userDocRef.setData(userData)
        }
    }
    
    func validateSession(userId: String) async throws -> Bool {
        guard let localSessionId = getCurrentSessionId() else {
            throw SessionError.noLocalSessionId
        }
        
        let document = try await db.collection(FirestoreConstants.Collections.users).document(userId).getDocument()
        
        guard document.exists else {
            throw SessionError.userDocumentNotFound
        }
        
        if let remoteSessionId = document.data()?[FirestoreConstants.UserFields.sessionId] as? String {
            return remoteSessionId == localSessionId
        } else {
            throw SessionError.noRemoteSessionId
        }
    }
    
    func watchSession(userId: String) -> AsyncStream<Void> {
        AsyncStream { continuation in
            let listener = db.collection(FirestoreConstants.Collections.users).document(userId).addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot, snapshot.exists else {
                    return
                }
                
                if let remoteSessionId = snapshot.data()?[FirestoreConstants.UserFields.sessionId] as? String,
                   let localSessionId = getCurrentSessionId(),
                   remoteSessionId != localSessionId {
                    // Session is invalid
                    continuation.yield()
                }
            }
            
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }
}

/// Mock implementation for testing
struct SessionMockClient: SessionClientProtocol {
    private var sessionId: String? = "mock-session-id"
    
    func getCurrentSessionId() -> String? {
        return sessionId
    }
    
    func updateSession(userId: String) async throws {
        sessionId = "updated-mock-session-id"
    }
    
    func validateSession(userId: String) async throws -> Bool {
        return true
    }
    
    func watchSession(userId: String) -> AsyncStream<Void> {
        AsyncStream { continuation in
            // No-op for testing
        }
    }
    
    func clearSessionId() {
        sessionId = nil
    }
}

/// Session-related errors
enum SessionError: Error, LocalizedError {
    case noLocalSessionId
    case userDocumentNotFound
    case noRemoteSessionId
    
    var errorDescription: String? {
        switch self {
        case .noLocalSessionId:
            return "No local session ID"
        case .userDocumentNotFound:
            return "User document not found"
        case .noRemoteSessionId:
            return "No remote session ID"
        }
    }
}

// TCA dependency registration
extension DependencyValues {
    var sessionClient: SessionClientProtocol {
        get { self[SessionClientKey.self] }
        set { self[SessionClientKey.self] = newValue }
    }
    
    private enum SessionClientKey: DependencyKey {
        static let liveValue: SessionClientProtocol = SessionLiveClient()
        static let testValue: SessionClientProtocol = SessionMockClient()
    }
}
