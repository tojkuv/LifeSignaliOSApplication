import XCTest
import ComposableArchitecture
@testable import LifeSignal
@testable import LifeSignal.Features.CheckIn

/// Tests for the CheckInFeature
final class CheckInFeatureTests: XCTestCase {

    /// Test the check-in action
    func testCheckIn() async {
        let store = TestStore(initialState: CheckInFeature.State()) {
            CheckInFeature()
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

    /// Test updating the check-in interval
    func testUpdateInterval() async {
        let store = TestStore(initialState: CheckInFeature.State()) {
            CheckInFeature()
        } withDependencies: {
            $0.userClient.updateUserFields = { _ in true }
        }

        let newInterval: TimeInterval = 48 * 60 * 60 // 48 hours

        await store.send(.updateInterval(newInterval)) {
            $0.isLoading = true
        }

        await store.receive(.updateIntervalResponse(.success(true))) {
            $0.isLoading = false
        }
    }

    /// Test updating notification preferences
    func testUpdateNotificationPreferences() async {
        let store = TestStore(initialState: CheckInFeature.State()) {
            CheckInFeature()
        } withDependencies: {
            $0.userClient.updateUserFields = { _ in true }
        }

        await store.send(.updateNotificationPreferences(notify30Min: false, notify2Hours: true)) {
            $0.isLoading = true
            $0.notify30MinBefore = false
            $0.notify2HoursBefore = true
            $0.notificationLeadTime = 120
        }

        await store.receive(.updateNotificationPreferencesResponse(.success(true))) {
            $0.isLoading = false
        }
    }

    /// Test loading check-in data
    func testLoadCheckInData() async {
        let testData = CheckInData(
            lastCheckedIn: Date().addingTimeInterval(-3600), // 1 hour ago
            checkInInterval: 24 * 60 * 60, // 24 hours
            notify30MinBefore: false,
            notify2HoursBefore: true,
            sendAlertActive: false,
            manualAlertTimestamp: nil
        )

        let store = TestStore(initialState: CheckInFeature.State()) {
            CheckInFeature()
        } withDependencies: {
            $0.userClient.loadCheckInData = { testData }
        }

        await store.send(.loadCheckInData) {
            $0.isLoading = true
        }

        await store.receive(.loadCheckInDataResponse(.success(testData))) {
            $0.isLoading = false
            $0.lastCheckedIn = testData.lastCheckedIn
            $0.checkInInterval = testData.checkInInterval
            $0.notify30MinBefore = testData.notify30MinBefore
            $0.notify2HoursBefore = testData.notify2HoursBefore
            $0.notificationLeadTime = 120
            $0.sendAlertActive = testData.sendAlertActive
            $0.manualAlertTimestamp = testData.manualAlertTimestamp
        }
    }

    /// Test error handling
    func testErrorHandling() async {
        let testError = NSError(domain: "CheckInFeatureTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])

        let store = TestStore(initialState: CheckInFeature.State()) {
            CheckInFeature()
        } withDependencies: {
            $0.userClient.updateUserFields = { _ in throw testError }
        }

        await store.send(.checkIn) {
            $0.isLoading = true
        }

        await store.receive(.checkInResponse(.failure(testError))) {
            $0.isLoading = false
            $0.error = testError
        }
    }
}
