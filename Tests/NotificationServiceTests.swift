import XCTest
@testable import ClaudeRunnerLib

final class NotificationServiceTests: XCTestCase {

    // MARK: - Notification Trigger Conditions

    func testNotifyWhenPermissionIncreasesFromZero() {
        let recorder = MockNotificationService()
        var oldCounts = StateCounts()
        oldCounts.activeCount = 1

        var newCounts = StateCounts()
        newCounts.activeCount = 1
        newCounts.permissionCount = 1

        recorder.notify(oldCounts: oldCounts, newCounts: newCounts, sessions: [])
        XCTAssertEqual(recorder.notifyCallCount, 1)
    }

    func testNotifyWhenWaitingIncreasesFromZero() {
        let recorder = MockNotificationService()
        var oldCounts = StateCounts()
        oldCounts.activeCount = 1

        var newCounts = StateCounts()
        newCounts.activeCount = 1
        newCounts.waitingCount = 1

        recorder.notify(oldCounts: oldCounts, newCounts: newCounts, sessions: [])
        XCTAssertEqual(recorder.notifyCallCount, 1)
    }

    func testNoNotifyWhenOnlyActiveChanges() {
        let recorder = MockNotificationService()
        var oldCounts = StateCounts()
        oldCounts.activeCount = 1

        var newCounts = StateCounts()
        newCounts.activeCount = 2

        recorder.notify(oldCounts: oldCounts, newCounts: newCounts, sessions: [])
        XCTAssertEqual(recorder.notifyCallCount, 0)
    }

    func testNoNotifyWhenCountsUnchanged() {
        let recorder = MockNotificationService()
        var counts = StateCounts()
        counts.activeCount = 1

        recorder.notify(oldCounts: counts, newCounts: counts, sessions: [])
        XCTAssertEqual(recorder.notifyCallCount, 0)
    }

    func testNoNotifyWhenPermissionAlreadyPresent() {
        let recorder = MockNotificationService()
        var oldCounts = StateCounts()
        oldCounts.permissionCount = 1

        var newCounts = StateCounts()
        newCounts.permissionCount = 2

        recorder.notify(oldCounts: oldCounts, newCounts: newCounts, sessions: [])
        XCTAssertEqual(recorder.notifyCallCount, 0)
    }

    func testNoNotifyWhenWaitingAlreadyPresent() {
        let recorder = MockNotificationService()
        var oldCounts = StateCounts()
        oldCounts.waitingCount = 1

        var newCounts = StateCounts()
        newCounts.waitingCount = 2

        recorder.notify(oldCounts: oldCounts, newCounts: newCounts, sessions: [])
        XCTAssertEqual(recorder.notifyCallCount, 0)
    }

    func testNoNotifyWhenSettingDisabled() {
        let recorder = MockNotificationService(notifyEnabled: false)
        var newCounts = StateCounts()
        newCounts.permissionCount = 1

        recorder.notify(oldCounts: StateCounts(), newCounts: newCounts, sessions: [])
        XCTAssertEqual(recorder.notifyCallCount, 0)
    }

    func testPermissionTakesPriorityOverWaiting() {
        let recorder = MockNotificationService()
        var newCounts = StateCounts()
        newCounts.permissionCount = 1
        newCounts.waitingCount = 1

        recorder.notify(oldCounts: StateCounts(), newCounts: newCounts, sessions: [])
        XCTAssertEqual(recorder.notifyCallCount, 1)
        XCTAssertEqual(recorder.lastTitle, "Needs Approval")
    }

    func testWaitingNotificationTitle() {
        let recorder = MockNotificationService()
        var newCounts = StateCounts()
        newCounts.waitingCount = 1

        recorder.notify(oldCounts: StateCounts(), newCounts: newCounts, sessions: [])
        XCTAssertEqual(recorder.lastTitle, "Waiting for Input")
    }

    func testPermissionPluralBody() {
        let recorder = MockNotificationService()
        var newCounts = StateCounts()
        newCounts.permissionCount = 3

        recorder.notify(oldCounts: StateCounts(), newCounts: newCounts, sessions: [])
        XCTAssertEqual(recorder.lastBody, "3 sessions need approval")
    }

    func testWaitingPluralBody() {
        let recorder = MockNotificationService()
        var newCounts = StateCounts()
        newCounts.waitingCount = 2

        recorder.notify(oldCounts: StateCounts(), newCounts: newCounts, sessions: [])
        XCTAssertEqual(recorder.lastBody, "2 sessions waiting for input")
    }
}

// MARK: - Mock

/// Mock that replicates NotificationService logic without UNUserNotificationCenter.
private final class MockNotificationService: NotificationSending {
    var notifyCallCount = 0
    var lastTitle: String?
    var lastBody: String?
    let notifyEnabled: Bool

    init(notifyEnabled: Bool = true) {
        self.notifyEnabled = notifyEnabled
    }

    func notify(oldCounts: StateCounts, newCounts: StateCounts, sessions: [SessionEntry]) {
        guard notifyEnabled else { return }
        guard oldCounts != newCounts else { return }

        if oldCounts.permissionCount == 0 && newCounts.permissionCount > 0 {
            let body = newCounts.permissionCount == 1
                ? "1 session needs approval"
                : "\(newCounts.permissionCount) sessions need approval"
            record(title: "Needs Approval", body: body)
            return
        }

        if oldCounts.waitingCount == 0 && newCounts.waitingCount > 0 {
            let body = newCounts.waitingCount == 1
                ? "1 session is waiting for input"
                : "\(newCounts.waitingCount) sessions waiting for input"
            record(title: "Waiting for Input", body: body)
            return
        }
    }

    private func record(title: String, body: String) {
        notifyCallCount += 1
        lastTitle = title
        lastBody = body
    }
}
