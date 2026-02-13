import XCTest
@testable import ClaudeRunnerLib

final class StateStoreTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("claude-runner-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func writeSession(
        id: String,
        cwd: String = "/tmp/project",
        state: String,
        updatedAt: Date = Date(),
        startedAt: Date? = nil,
        terminalBundleId: String? = nil
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
        if let term = terminalBundleId {
            dict["terminal_bundle_id"] = term
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

    // MARK: - Empty Directory

    func testReloadEmptyDirectory() {
        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.sessions.count, 0)
        XCTAssertEqual(store.counts.totalCount, 0)
        XCTAssertNil(store.counts.dominantState)
    }

    // MARK: - Loading Sessions

    func testReloadWithSessions() {
        writeSession(id: "s1", cwd: "/tmp/project-a", state: "active")
        writeSession(id: "s2", cwd: "/tmp/project-b", state: "waiting")
        writeSession(id: "s3", cwd: "/tmp/project-c", state: "permission")

        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.sessions.count, 3)
        XCTAssertEqual(store.counts.activeCount, 1)
        XCTAssertEqual(store.counts.waitingCount, 1)
        XCTAssertEqual(store.counts.permissionCount, 1)
    }

    func testReloadWithTerminalBundleId() {
        writeSession(id: "s1", state: "active", terminalBundleId: "com.googlecode.iterm2")

        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.sessions.first?.terminalBundleId, "com.googlecode.iterm2")
    }

    // MARK: - Sorting

    func testSortingByPriority() {
        writeSession(id: "s1", state: "active")
        writeSession(id: "s2", state: "permission")
        writeSession(id: "s3", state: "waiting")

        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.sessions[0].state, .permission)
        XCTAssertEqual(store.sessions[1].state, .waiting)
        XCTAssertEqual(store.sessions[2].state, .active)
    }

    func testSortingWithinSamePriority() {
        // Within same state, most recently updated first
        let now = Date()
        writeSession(id: "s1", state: "active", updatedAt: now.addingTimeInterval(-60))
        writeSession(id: "s2", state: "active", updatedAt: now)

        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.sessions[0].sessionId, "s2") // more recent
        XCTAssertEqual(store.sessions[1].sessionId, "s1")
    }

    // MARK: - Stale Pruning

    func testStalePruningWaitingSession() {
        // Only waiting sessions are pruned when stale
        writeSession(id: "stale", state: "waiting",
                     updatedAt: Date().addingTimeInterval(-1200)) // 20 min old
        writeSession(id: "fresh", state: "waiting")

        let store = StateStore(sessionsDirectory: tempDir, staleThreshold: 600, autoReload: false)
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions.first?.sessionId, "fresh")

        // Stale file should be deleted from disk
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent("stale.json").path))
    }

    func testStalePruningPreservesActiveSession() {
        // Active sessions are NOT pruned even if old
        writeSession(id: "old-active", state: "active",
                     updatedAt: Date().addingTimeInterval(-1200)) // 20 min old

        let store = StateStore(sessionsDirectory: tempDir, staleThreshold: 600, autoReload: false)
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions.first?.sessionId, "old-active")
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent("old-active.json").path))
    }

    func testStalePruningPreservesPermissionSession() {
        // Permission sessions are NOT pruned even if old
        writeSession(id: "old-perm", state: "permission",
                     updatedAt: Date().addingTimeInterval(-1200)) // 20 min old

        let store = StateStore(sessionsDirectory: tempDir, staleThreshold: 600, autoReload: false)
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions.first?.sessionId, "old-perm")
    }

    func testFreshSessionNotPruned() {
        writeSession(id: "fresh", state: "waiting",
                     updatedAt: Date().addingTimeInterval(-300)) // 5 min old

        let store = StateStore(sessionsDirectory: tempDir, staleThreshold: 600, autoReload: false)
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.sessions.count, 1)
    }

    // MARK: - File Filtering

    func testIgnoresNonJsonFiles() {
        writeSession(id: "valid", state: "active")
        try! "not json".data(using: .utf8)!.write(
            to: tempDir.appendingPathComponent("readme.txt"))

        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.sessions.count, 1)
    }

    func testIgnoresMalformedJson() {
        writeSession(id: "valid", state: "active")
        try! "{ broken }".data(using: .utf8)!.write(
            to: tempDir.appendingPathComponent("bad.json"))

        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.sessions.count, 1)
    }

    // MARK: - Auto Reload

    func testAutoReloadOnInit() {
        writeSession(id: "s1", state: "active")

        let store = StateStore(sessionsDirectory: tempDir, autoReload: true)
        waitForMainQueue()

        XCTAssertEqual(store.sessions.count, 1)
    }

    // MARK: - Multiple States Count

    func testMultipleSessionsSameState() {
        writeSession(id: "s1", state: "waiting")
        writeSession(id: "s2", state: "waiting")
        writeSession(id: "s3", state: "waiting")

        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.counts.waitingCount, 3)
        XCTAssertEqual(store.counts.totalCount, 3)
        XCTAssertEqual(store.counts.dominantState, .waiting)
    }
}
