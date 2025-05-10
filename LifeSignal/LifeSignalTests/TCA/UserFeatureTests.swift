import XCTest
import ComposableArchitecture
@testable import LifeSignal

/// Tests for the UserFeature
final class UserFeatureTests: XCTestCase {
    
    /// Test loading user data
    func testLoadUserData() async {
        let testProfileData: ProfileData = (
            name: "Test User",
            phoneNumber: "+15551234567",
            phoneRegion: "US",
            note: "Test note",
            qrCodeId: "test-qr-code",
            notificationEnabled: true,
            profileComplete: true
        )
        
        let testCheckInData = CheckInFeature.CheckInData(
            lastCheckedIn: Date().addingTimeInterval(-3600), // 1 hour ago
            checkInInterval: 24 * 60 * 60, // 24 hours
            notify30MinBefore: true,
            notify2HoursBefore: false,
            sendAlertActive: false,
            manualAlertTimestamp: nil
        )
        
        let store = TestStore(initialState: UserFeature.State()) {
            UserFeature()
        } withDependencies: {
            $0.userClient.loadProfile = { testProfileData }
            $0.userClient.loadCheckInData = { testCheckInData }
        }
        
        await store.send(.loadUserData) {
            $0.isLoading = true
        }
        
        await store.receive(.loadUserDataResponse(.success((profile: testProfileData, checkIn: testCheckInData)))) {
            $0.isLoading = false
            $0.name = testProfileData.name
            $0.phoneNumber = testProfileData.phoneNumber
            $0.phoneRegion = testProfileData.phoneRegion
            $0.note = testProfileData.note
            $0.qrCodeId = testProfileData.qrCodeId
            $0.notificationEnabled = testProfileData.notificationEnabled
            $0.profileComplete = testProfileData.profileComplete
            $0.lastCheckedIn = testCheckInData.lastCheckedIn
            $0.checkInInterval = testCheckInData.checkInInterval
            $0.notify30MinBefore = testCheckInData.notify30MinBefore
            $0.notify2HoursBefore = testCheckInData.notify2HoursBefore
            $0.sendAlertActive = testCheckInData.sendAlertActive
            $0.manualAlertTimestamp = testCheckInData.manualAlertTimestamp
        }
    }
    
    /// Test updating profile
    func testUpdateProfile() async {
        let store = TestStore(initialState: UserFeature.State()) {
            UserFeature()
        } withDependencies: {
            $0.userClient.updateUserFields = { _ in true }
        }
        
        let newName = "Updated Name"
        let newNote = "Updated note"
        
        await store.send(.updateProfile(name: newName, note: newNote)) {
            $0.isLoading = true
        }
        
        await store.receive(.updateProfileResponse(.success(true))) {
            $0.isLoading = false
        }
    }
    
    /// Test checking in
    func testCheckIn() async {
        let store = TestStore(initialState: UserFeature.State()) {
            UserFeature()
        } withDependencies: {
            $0.userClient.updateUserFields = { _ in true }
        }
        
        let initialDate = store.state.lastCheckedIn
        
        await store.send(.checkIn) {
            $0.isLoading = true
        }
        
        await store.receive(.checkInResponse(.success(true))) {
            $0.isLoading = false
            $0.lastCheckedIn = $0.lastCheckedIn
        }
        
        // Verify that the lastCheckedIn date was updated
        XCTAssertNotEqual(store.state.lastCheckedIn, initialDate)
    }
    
    /// Test updating check-in interval
    func testUpdateCheckInInterval() async {
        let store = TestStore(initialState: UserFeature.State()) {
            UserFeature()
        } withDependencies: {
            $0.userClient.updateUserFields = { _ in true }
        }
        
        let newInterval: TimeInterval = 48 * 60 * 60 // 48 hours
        
        await store.send(.updateCheckInInterval(newInterval)) {
            $0.isLoading = true
        }
        
        await store.receive(.updateCheckInIntervalResponse(.success(true))) {
            $0.isLoading = false
        }
    }
    
    /// Test updating notification preferences
    func testUpdateNotificationPreferences() async {
        let store = TestStore(initialState: UserFeature.State()) {
            UserFeature()
        } withDependencies: {
            $0.userClient.updateUserFields = { _ in true }
        }
        
        await store.send(.updateNotificationPreferences(notify30Min: false, notify2Hours: true)) {
            $0.isLoading = true
        }
        
        await store.receive(.updateNotificationPreferencesResponse(.success(true))) {
            $0.isLoading = false
        }
    }
    
    /// Test signing out
    func testSignOut() async {
        let store = TestStore(initialState: UserFeature.State()) {
            UserFeature()
        } withDependencies: {
            $0.userClient.signOut = { true }
        }
        
        await store.send(.signOut) {
            $0.isLoading = true
        }
        
        await store.receive(.signOutResponse(.success(true))) {
            $0.isLoading = false
        }
    }
    
    /// Test error handling
    func testErrorHandling() async {
        let testError = NSError(domain: "UserFeatureTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        let store = TestStore(initialState: UserFeature.State()) {
            UserFeature()
        } withDependencies: {
            $0.userClient.loadProfile = { throw testError }
            $0.userClient.loadCheckInData = { throw testError }
        }
        
        await store.send(.loadUserData) {
            $0.isLoading = true
        }
        
        await store.receive(.loadUserDataResponse(.failure(testError))) {
            $0.isLoading = false
            $0.error = testError
        }
    }
}
