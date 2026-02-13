import XCTest
@testable import ClaudeRunnerLib

/// Tests hook-driven state transitions for permission-requiring events.
///
/// Flows under test:
/// 1. AskUserQuestion  → Notification/elicitation_dialog → state = "permission" (RED)
/// 2. User responds    → UserPromptSubmit or PreToolUse  → state = "active"   (GREEN)
/// 3. PermissionRequest (Bash, Write, …) → state = "permission" (RED)
/// 4. User approves    → PreToolUse                      → state = "active"   (GREEN)
final class HookStateTransitionTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("claude-runner-hook-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Helpers

    private func writeSession(
        id: String,
        cwd: String = "/tmp/project",
        state: String,
        updatedAt: Date = Date(),
        startedAt: Date? = nil
    ) {
        var dict: [String: Any] = [
            "session_id": id,
            "cwd": cwd,
            "state": state,
            "updated_at": ISO8601DateFormatter().string(from: updatedAt)
        ]
        if let started = startedAt {
            dict["started_at"] = ISO8601DateFormatter().string(from: started)
        }
        let data = try! JSONSerialization.data(withJSONObject: dict)
        try! data.write(to: tempDir.appendingPathComponent("\(id).json"))
    }

    private func waitForMainQueue() {
        let expectation = expectation(description: "main queue")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Elicitation Dialog → RED (permission)

    /// Notification/elicitation_dialog sets state to "permission" (RED icon).
    func testElicitationDialogTransitionsToPermission() {
        writeSession(id: "session-elicit", state: "permission")

        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions.first?.state, .permission)
        XCTAssertEqual(store.counts.permissionCount, 1)
        XCTAssertEqual(store.counts.dominantState, .permission)
    }

    // MARK: - User Response → GREEN (active)

    /// After elicitation, UserPromptSubmit transitions state to "active" (GREEN).
    func testUserPromptSubmitAfterElicitationTransitionsToActive() {
        // Step 1: elicitation_dialog → permission
        writeSession(id: "session-elicit", state: "permission")

        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.sessions.first?.state, .permission,
                       "Should be RED after elicitation_dialog")

        // Step 2: user answers → UserPromptSubmit → active
        writeSession(id: "session-elicit", state: "active")
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions.first?.state, .active,
                       "Should be GREEN after UserPromptSubmit")
        XCTAssertEqual(store.counts.activeCount, 1)
        XCTAssertEqual(store.counts.permissionCount, 0)
    }

    /// After elicitation, PreToolUse (non-AskUserQuestion) transitions state to "active" (GREEN).
    func testPreToolUseAfterElicitationTransitionsToActive() {
        // Step 1: elicitation_dialog → permission
        writeSession(id: "session-elicit", state: "permission")

        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.sessions.first?.state, .permission)

        // Step 2: Claude resumes → PreToolUse (e.g. Read) → active
        writeSession(id: "session-elicit", state: "active")
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.sessions.first?.state, .active,
                       "Should be GREEN after PreToolUse resumes work")
        XCTAssertEqual(store.counts.activeCount, 1)
        XCTAssertEqual(store.counts.permissionCount, 0)
    }

    // MARK: - PreToolUse/AskUserQuestion → permission (RED)

    /// PreToolUse with tool_name=AskUserQuestion also sets state to "permission".
    func testPreToolUseAskUserQuestionTransitionsToPermission() {
        // Initially active
        writeSession(id: "session-ask", state: "active")

        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.sessions.first?.state, .active)

        // PreToolUse/AskUserQuestion → permission
        writeSession(id: "session-ask", state: "permission")
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.sessions.first?.state, .permission,
                       "AskUserQuestion via PreToolUse should set RED state")
    }

    // MARK: - Multiple Sessions with Elicitation

    /// Elicitation in one session dominates the menu bar icon.
    func testElicitationDominatesOtherStates() {
        writeSession(id: "s1", state: "active")
        writeSession(id: "s2", state: "permission") // elicitation_dialog
        writeSession(id: "s3", state: "waiting")

        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.counts.dominantState, .permission,
                       "Permission (RED) should dominate when any session has elicitation")
        XCTAssertEqual(store.counts.permissionCount, 1)
        XCTAssertEqual(store.counts.activeCount, 1)
        XCTAssertEqual(store.counts.waitingCount, 1)
    }

    /// Once all elicitation sessions are resolved, dominant state changes.
    func testAllElicitationsResolvedClearsDominantPermission() {
        writeSession(id: "s1", state: "permission")
        writeSession(id: "s2", state: "permission")

        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.counts.permissionCount, 2)
        XCTAssertEqual(store.counts.dominantState, .permission)

        // Both sessions answered
        writeSession(id: "s1", state: "active")
        writeSession(id: "s2", state: "active")
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.counts.permissionCount, 0)
        XCTAssertEqual(store.counts.activeCount, 2)
        XCTAssertEqual(store.counts.dominantState, .active,
                       "Should no longer show RED after all elicitations resolved")
    }

    // MARK: - PermissionRequest → RED (permission)

    /// PermissionRequest for Bash → permission (RED). User must approve "tail -f" etc.
    func testPermissionRequestBashTransitionsToPermission() {
        writeSession(id: "session-perm", state: "active")

        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.sessions.first?.state, .active)

        // PermissionRequest/Bash → permission
        writeSession(id: "session-perm", state: "permission")
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.sessions.first?.state, .permission,
                       "Bash permission request should set RED state")
    }

    /// PermissionRequest for Write → permission (RED).
    func testPermissionRequestWriteTransitionsToPermission() {
        writeSession(id: "session-perm", state: "active")

        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)
        store.reload()
        waitForMainQueue()

        // PermissionRequest/Write → permission
        writeSession(id: "session-perm", state: "permission")
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.sessions.first?.state, .permission,
                       "Write permission request should set RED state")
    }

    /// User approves PermissionRequest → PreToolUse fires → active (GREEN).
    func testPermissionRequestApprovedTransitionsToActive() {
        // Step 1: PermissionRequest → permission
        writeSession(id: "session-perm", state: "permission")

        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.sessions.first?.state, .permission,
                       "Should be RED while awaiting user approval")

        // Step 2: user approves → PreToolUse fires → active
        writeSession(id: "session-perm", state: "active")
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.sessions.first?.state, .active,
                       "Should be GREEN after user approves permission")
        XCTAssertEqual(store.counts.permissionCount, 0)
    }

    /// Full cycle: active → PermissionRequest(Bash) → approved → active → elicitation → answered
    func testPermissionThenElicitationFullCycle() {
        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)

        // 1. active (Claude is working)
        writeSession(id: "s1", state: "active")
        store.reload()
        waitForMainQueue()
        XCTAssertEqual(store.sessions.first?.state, .active)

        // 2. PermissionRequest/Bash → RED
        writeSession(id: "s1", state: "permission")
        store.reload()
        waitForMainQueue()
        XCTAssertEqual(store.sessions.first?.state, .permission)

        // 3. User approves → active (GREEN)
        writeSession(id: "s1", state: "active")
        store.reload()
        waitForMainQueue()
        XCTAssertEqual(store.sessions.first?.state, .active)

        // 4. AskUserQuestion → elicitation_dialog → RED
        writeSession(id: "s1", state: "permission")
        store.reload()
        waitForMainQueue()
        XCTAssertEqual(store.sessions.first?.state, .permission)

        // 5. User answers → active (GREEN)
        writeSession(id: "s1", state: "active")
        store.reload()
        waitForMainQueue()
        XCTAssertEqual(store.sessions.first?.state, .active)
        XCTAssertEqual(store.counts.permissionCount, 0)
    }

    // MARK: - Notification/permission_prompt → RED

    /// Notification/permission_prompt (tool approval popup) → permission (RED).
    func testNotificationPermissionPromptTransitionsToPermission() {
        writeSession(id: "session-notify", state: "active")

        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)
        store.reload()
        waitForMainQueue()

        // Notification/permission_prompt → permission
        writeSession(id: "session-notify", state: "permission")
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.sessions.first?.state, .permission,
                       "permission_prompt notification should set RED state")
    }

    // MARK: - Sorting: permission sessions appear first

    /// Permission sessions from elicitation_dialog sort before active/waiting.
    func testElicitationSessionsSortFirst() {
        let now = Date()
        writeSession(id: "s-active", state: "active", updatedAt: now)
        writeSession(id: "s-elicit", state: "permission",
                     updatedAt: now.addingTimeInterval(-10)) // older but higher priority

        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.sessions.count, 2)
        XCTAssertEqual(store.sessions[0].sessionId, "s-elicit",
                       "Permission session should sort first regardless of time")
        XCTAssertEqual(store.sessions[1].sessionId, "s-active")
    }
}
