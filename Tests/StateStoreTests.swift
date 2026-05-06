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

    // MARK: - Revive Sessions (synthetic file creation)

    func testReviveSessionsCreatesFile() {
        // Manually create a synthetic revived session file (simulating what reviveSessions does)
        let sessionId = "revived--dev-ttys099"
        let now = ISO8601DateFormatter().string(from: Date())
        let dict: [String: Any] = [
            "session_id": sessionId,
            "cwd": "/tmp/test-project",
            "state": "waiting",
            "updated_at": now,
            "started_at": now,
            "terminal_bundle_id": "com.googlecode.iterm2",
            "tty": "/dev/ttys099",
            "last_message": "",
            "current_activity": "",
        ]
        let data = try! JSONSerialization.data(withJSONObject: dict)
        try! data.write(to: tempDir.appendingPathComponent("\(sessionId).json"))

        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions.first?.sessionId, sessionId)
        XCTAssertEqual(store.sessions.first?.tty, "/dev/ttys099")
        XCTAssertEqual(store.sessions.first?.state, .waiting)
    }

    // MARK: - performRevive — TTY-based dead session cleanup

    private func writeSessionWithTTY(
        id: String,
        cwd: String = "/tmp/project",
        state: String,
        tty: String? = nil,
        updatedAt: Date = Date()
    ) {
        var dict: [String: Any] = [
            "session_id": id,
            "cwd": cwd,
            "state": state,
            "updated_at": ISO8601DateFormatter().string(from: updatedAt),
        ]
        if let tty = tty {
            dict["tty"] = tty
        }
        let data = try! JSONSerialization.data(withJSONObject: dict)
        try! data.write(to: tempDir.appendingPathComponent("\(id).json"))
    }

    func testRevive_keepsSession_whenTTYMatchesActiveTTYs() {
        writeSessionWithTTY(id: "alive", cwd: "/tmp/proj", state: "active", tty: "/dev/ttys001")

        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)
        store.reload()
        waitForMainQueue()

        store._performRevive(existingSessions: store.sessions,
            activeTTYs: ["/dev/ttys001"],
            activeCwds: [],
            orphaned: [],
            dir: tempDir
        )
        waitForMainQueue()

        XCTAssertTrue(FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent("alive.json").path))
    }

    func testRevive_deletesSession_whenTTYNotInActiveTTYs() {
        writeSessionWithTTY(id: "dead", cwd: "/tmp/proj", state: "active", tty: "/dev/ttys099")

        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)
        store.reload()
        waitForMainQueue()

        store._performRevive(existingSessions: store.sessions,
            activeTTYs: [],
            activeCwds: [],
            orphaned: [],
            dir: tempDir
        )
        waitForMainQueue()

        XCTAssertFalse(FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent("dead.json").path))
    }

    func testRevive_keepsEmptyTTYSession_whenCwdMatchesActiveCwds() {
        writeSessionWithTTY(id: "ghost-alive", cwd: "/tmp/live-proj", state: "active", tty: nil)

        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)
        store.reload()
        waitForMainQueue()

        // activeCwds must contain the canonicalized form of the session's cwd,
        // because _performRevive canonicalizes session.cwd before comparing.
        // On macOS, /tmp is a symlink to /private/tmp.
        let canonicalLiveCwd = SessionScanner.canonicalizeCwd("/tmp/live-proj")
        store._performRevive(existingSessions: store.sessions,
            activeTTYs: [],
            activeCwds: [canonicalLiveCwd],
            orphaned: [],
            dir: tempDir
        )
        waitForMainQueue()

        XCTAssertTrue(FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent("ghost-alive.json").path))
    }

    func testRevive_deletesEmptyTTYSession_whenCwdNotInActiveCwds() {
        writeSessionWithTTY(id: "ghost-dead", cwd: "/tmp/dead-proj", state: "permission", tty: nil)

        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)
        store.reload()
        waitForMainQueue()

        store._performRevive(existingSessions: store.sessions,
            activeTTYs: [],
            activeCwds: [],
            orphaned: [],
            dir: tempDir
        )
        waitForMainQueue()

        XCTAssertFalse(FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent("ghost-dead.json").path))
    }

    func testRevive_deletesOldTmpFiles() {
        // Create a .tmp.* file with mtime > 24h ago
        let tmpFile = tempDir.appendingPathComponent(".tmp.staleXYZ")
        try! "leftover".data(using: .utf8)!.write(to: tmpFile)
        // Back-date the file by setting mtime to 25 hours ago
        let oldDate = Date().addingTimeInterval(-90000)
        try! FileManager.default.setAttributes(
            [.modificationDate: oldDate],
            ofItemAtPath: tmpFile.path
        )

        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)
        store.reload()
        waitForMainQueue()

        store._performRevive(existingSessions: store.sessions,
            activeTTYs: [],
            activeCwds: [],
            orphaned: [],
            dir: tempDir
        )
        waitForMainQueue()

        XCTAssertFalse(FileManager.default.fileExists(atPath: tmpFile.path),
            "Stale .tmp.* file should have been deleted")
    }

    func testRevive_keepsRecentTmpFiles() {
        // Create a .tmp.* file with mtime < 24h ago
        let tmpFile = tempDir.appendingPathComponent(".tmp.recentABC")
        try! "leftover".data(using: .utf8)!.write(to: tmpFile)
        // mtime is effectively now (just written)

        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)
        store.reload()
        waitForMainQueue()

        store._performRevive(existingSessions: store.sessions,
            activeTTYs: [],
            activeCwds: [],
            orphaned: [],
            dir: tempDir
        )
        waitForMainQueue()

        XCTAssertTrue(FileManager.default.fileExists(atPath: tmpFile.path),
            "Recent .tmp.* file should be kept (not old enough to delete)")
    }

    // MARK: - Activity Fields in Session Files

    func testReloadWithActivityFields() {
        let now = Date()
        let dict: [String: Any] = [
            "session_id": "s1",
            "cwd": "/tmp/project",
            "state": "active",
            "updated_at": ISO8601DateFormatter().string(from: now),
            "last_message": "Build done",
            "current_activity": "Bash",
        ]
        let data = try! JSONSerialization.data(withJSONObject: dict)
        try! data.write(to: tempDir.appendingPathComponent("s1.json"))

        let store = StateStore(sessionsDirectory: tempDir, autoReload: false)
        store.reload()
        waitForMainQueue()

        XCTAssertEqual(store.sessions.first?.lastMessage, "Build done")
        XCTAssertEqual(store.sessions.first?.currentActivity, "Bash")
    }

    // MARK: - reviveSessions() public entry point regression

    func testReviveSessions_dispatchesAndReloads() {
        // Ghost session with a cwd no real process will ever have.
        // When reviveSessions() runs, findActiveClaudeCwds() won't return this cwd,
        // so _performRevive will delete the file and trigger reload().
        let ghostCwd = "/nonexistent/path/that/no/process/has/\(UUID().uuidString)"
        writeSessionWithTTY(id: "ghost-revive", cwd: ghostCwd, state: "active", tty: nil)

        // Normal session with a TTY that is also definitely not active.
        writeSessionWithTTY(id: "normal-revive", cwd: "/tmp/proj", state: "active", tty: "/dev/ttys999")

        let store = StateStore(sessionsDirectory: tempDir, autoReload: true)
        waitForMainQueue()
        // Both sessions are present before revive.
        XCTAssertEqual(store.sessions.count, 2)

        let expectation = self.expectation(description: "reviveSessions background dispatch completes")
        // Allow enough time for the background queue + main-queue reload round-trip.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            expectation.fulfill()
        }

        store.reviveSessions()
        wait(for: [expectation], timeout: 5.0)

        // After revive: both dead sessions should have been cleaned up.
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("ghost-revive.json").path),
            "Ghost session with inactive cwd should be deleted by reviveSessions"
        )
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("normal-revive.json").path),
            "Session with inactive TTY should be deleted by reviveSessions"
        )
        // sessions should have been reloaded (empty or smaller count)
        XCTAssertLessThan(store.sessions.count, 2,
            "store.sessions should reflect reload after reviveSessions")
    }
}
