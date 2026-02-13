import XCTest
@testable import ClaudeRunnerLib

final class SessionStateTests: XCTestCase {

    // MARK: - SessionState Priority & Comparable

    func testPriorityValues() {
        XCTAssertEqual(SessionState.active.priority, 1)
        XCTAssertEqual(SessionState.waiting.priority, 2)
        XCTAssertEqual(SessionState.permission.priority, 3)
    }

    func testComparable() {
        XCTAssertTrue(SessionState.active < SessionState.waiting)
        XCTAssertTrue(SessionState.waiting < SessionState.permission)
        XCTAssertTrue(SessionState.active < SessionState.permission)
        XCTAssertFalse(SessionState.permission < SessionState.active)
    }

    func testSorting() {
        let states: [SessionState] = [.active, .permission, .waiting]
        let sorted = states.sorted()
        XCTAssertEqual(sorted, [.active, .waiting, .permission])
    }

    // MARK: - SessionState Labels

    func testLabels() {
        XCTAssertEqual(SessionState.active.label, "active")
        XCTAssertEqual(SessionState.waiting.label, "waiting")
        XCTAssertEqual(SessionState.permission.label, "permission")
    }

    // MARK: - SessionEntry Codable

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func testSessionEntryDecoding() throws {
        let json = """
        {
            "session_id": "abc123",
            "cwd": "/Users/test/my-project",
            "state": "active",
            "updated_at": "2026-02-13T12:00:00Z"
        }
        """.data(using: .utf8)!

        let entry = try decoder.decode(SessionEntry.self, from: json)

        XCTAssertEqual(entry.sessionId, "abc123")
        XCTAssertEqual(entry.cwd, "/Users/test/my-project")
        XCTAssertEqual(entry.state, .active)
        XCTAssertNil(entry.terminalBundleId)
    }

    func testSessionEntryDecodingWithTerminalBundleId() throws {
        let json = """
        {
            "session_id": "abc123",
            "cwd": "/Users/test/my-project",
            "state": "waiting",
            "updated_at": "2026-02-13T12:00:00Z",
            "terminal_bundle_id": "com.googlecode.iterm2"
        }
        """.data(using: .utf8)!

        let entry = try decoder.decode(SessionEntry.self, from: json)
        XCTAssertEqual(entry.state, .waiting)
        XCTAssertEqual(entry.terminalBundleId, "com.googlecode.iterm2")
    }

    func testAllStatesDecodable() throws {
        for state in ["active", "waiting", "permission"] {
            let json = """
            {"session_id":"x","cwd":"/tmp","state":"\(state)","updated_at":"2026-02-13T12:00:00Z"}
            """.data(using: .utf8)!
            let entry = try decoder.decode(SessionEntry.self, from: json)
            XCTAssertEqual(entry.state.rawValue, state)
        }
    }

    func testProjectName() throws {
        let json = """
        {"session_id":"x","cwd":"/Users/test/deep/nested/my-project","state":"active","updated_at":"2026-02-13T12:00:00Z"}
        """.data(using: .utf8)!

        let entry = try decoder.decode(SessionEntry.self, from: json)
        XCTAssertEqual(entry.projectName, "my-project")
    }

    func testProjectNameRootPath() throws {
        let json = """
        {"session_id":"x","cwd":"/","state":"active","updated_at":"2026-02-13T12:00:00Z"}
        """.data(using: .utf8)!

        let entry = try decoder.decode(SessionEntry.self, from: json)
        XCTAssertEqual(entry.projectName, "/")
    }

    func testElapsedText() throws {
        // 90 seconds ago → "1m"
        let ts = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-90))
        let json = """
        {"session_id":"x","cwd":"/tmp","state":"active","updated_at":"\(ts)"}
        """.data(using: .utf8)!

        let entry = try decoder.decode(SessionEntry.self, from: json)
        XCTAssertEqual(entry.elapsedText, "1m")
    }

    func testElapsedTextUnderOneMinute() throws {
        let ts = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-30))
        let json = """
        {"session_id":"x","cwd":"/tmp","state":"active","updated_at":"\(ts)"}
        """.data(using: .utf8)!

        let entry = try decoder.decode(SessionEntry.self, from: json)
        XCTAssertEqual(entry.elapsedText, "< 1m")
    }

    func testElapsedTextHours() throws {
        let ts = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-7200))
        let json = """
        {"session_id":"x","cwd":"/tmp","state":"active","updated_at":"\(ts)"}
        """.data(using: .utf8)!

        let entry = try decoder.decode(SessionEntry.self, from: json)
        XCTAssertEqual(entry.elapsedText, "2h")
    }

    func testElapsedTextHoursAndMinutes() throws {
        // 1h 23m = 4980 seconds
        let ts = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-4980))
        let json = """
        {"session_id":"x","cwd":"/tmp","state":"active","updated_at":"\(ts)"}
        """.data(using: .utf8)!

        let entry = try decoder.decode(SessionEntry.self, from: json)
        XCTAssertEqual(entry.elapsedText, "1h 23m")
    }

    // MARK: - startedAt

    func testStartedAtDecoding() throws {
        let json = """
        {"session_id":"x","cwd":"/tmp","state":"active","updated_at":"2026-02-13T12:00:00Z","started_at":"2026-02-13T11:00:00Z"}
        """.data(using: .utf8)!

        let entry = try decoder.decode(SessionEntry.self, from: json)
        XCTAssertNotNil(entry.startedAt)
    }

    func testStartedAtNilWhenMissing() throws {
        let json = """
        {"session_id":"x","cwd":"/tmp","state":"active","updated_at":"2026-02-13T12:00:00Z"}
        """.data(using: .utf8)!

        let entry = try decoder.decode(SessionEntry.self, from: json)
        XCTAssertNil(entry.startedAt)
    }

    func testReferenceDateUsesStartedAt() throws {
        let json = """
        {"session_id":"x","cwd":"/tmp","state":"active","updated_at":"2026-02-13T12:00:00Z","started_at":"2026-02-13T11:00:00Z"}
        """.data(using: .utf8)!

        let entry = try decoder.decode(SessionEntry.self, from: json)
        XCTAssertEqual(entry.referenceDate, entry.startedAt)
    }

    func testReferenceDateFallsBackToUpdatedAt() throws {
        let json = """
        {"session_id":"x","cwd":"/tmp","state":"active","updated_at":"2026-02-13T12:00:00Z"}
        """.data(using: .utf8)!

        let entry = try decoder.decode(SessionEntry.self, from: json)
        XCTAssertEqual(entry.referenceDate, entry.updatedAt)
    }

    func testElapsedUsesStartedAt() throws {
        let fmt = ISO8601DateFormatter()
        let startedAt = fmt.string(from: Date().addingTimeInterval(-300)) // 5 min ago
        let updatedAt = fmt.string(from: Date().addingTimeInterval(-10))  // 10 sec ago
        let json = """
        {"session_id":"x","cwd":"/tmp","state":"active","updated_at":"\(updatedAt)","started_at":"\(startedAt)"}
        """.data(using: .utf8)!

        let entry = try decoder.decode(SessionEntry.self, from: json)
        XCTAssertEqual(entry.elapsedText, "5m")
    }

    // MARK: - formattedPath (SessionDisplayFormat)

    func testFormattedPathFullPath() throws {
        let home = NSHomeDirectory()
        let json = """
        {"session_id":"x","cwd":"\(home)/projects/my-app","state":"active","updated_at":"2026-02-13T12:00:00Z"}
        """.data(using: .utf8)!

        let entry = try decoder.decode(SessionEntry.self, from: json)
        XCTAssertEqual(entry.formattedPath(format: .fullPath), "~/projects/my-app")
    }

    func testFormattedPathDirectoryOnly() throws {
        let json = """
        {"session_id":"x","cwd":"/Users/test/deep/nested/my-project","state":"active","updated_at":"2026-02-13T12:00:00Z"}
        """.data(using: .utf8)!

        let entry = try decoder.decode(SessionEntry.self, from: json)
        XCTAssertEqual(entry.formattedPath(format: .directoryOnly), "my-project")
    }

    func testFormattedPathLastTwoDirs() throws {
        let json = """
        {"session_id":"x","cwd":"/Users/test/deep/nested/my-project","state":"active","updated_at":"2026-02-13T12:00:00Z"}
        """.data(using: .utf8)!

        let entry = try decoder.decode(SessionEntry.self, from: json)
        XCTAssertEqual(entry.formattedPath(format: .lastTwoDirs), "nested/my-project")
    }

    func testFormattedPathLastTwoDirsShortPath() throws {
        let json = """
        {"session_id":"x","cwd":"/project","state":"active","updated_at":"2026-02-13T12:00:00Z"}
        """.data(using: .utf8)!

        let entry = try decoder.decode(SessionEntry.self, from: json)
        // Only one component, should fallback to lastPathComponent
        XCTAssertEqual(entry.formattedPath(format: .lastTwoDirs), "project")
    }

    func testDisplayPathDefaultIsFullPath() throws {
        let home = NSHomeDirectory()
        let json = """
        {"session_id":"x","cwd":"\(home)/projects/my-app","state":"active","updated_at":"2026-02-13T12:00:00Z"}
        """.data(using: .utf8)!

        let entry = try decoder.decode(SessionEntry.self, from: json)
        XCTAssertEqual(entry.displayPath, entry.formattedPath(format: .fullPath))
    }

    func testIdentifiable() throws {
        let json = """
        {"session_id":"unique-id","cwd":"/tmp","state":"active","updated_at":"2026-02-13T12:00:00Z"}
        """.data(using: .utf8)!

        let entry = try decoder.decode(SessionEntry.self, from: json)
        XCTAssertEqual(entry.id, "unique-id")
    }

    // MARK: - StateCounts

    func testStateCountsTotalCount() {
        var counts = StateCounts()
        XCTAssertEqual(counts.totalCount, 0)

        counts.activeCount = 2
        counts.waitingCount = 1
        counts.permissionCount = 3
        XCTAssertEqual(counts.totalCount, 6)
    }

    func testDominantStateNil() {
        let counts = StateCounts()
        XCTAssertNil(counts.dominantState)
    }

    func testDominantStateActive() {
        var counts = StateCounts()
        counts.activeCount = 1
        XCTAssertEqual(counts.dominantState, .active)
    }

    func testDominantStateWaiting() {
        var counts = StateCounts()
        counts.activeCount = 1
        counts.waitingCount = 1
        XCTAssertEqual(counts.dominantState, .waiting)
    }

    func testDominantStatePermission() {
        var counts = StateCounts()
        counts.activeCount = 5
        counts.waitingCount = 3
        counts.permissionCount = 1
        XCTAssertEqual(counts.dominantState, .permission)
    }

    func testStateCountsEquatable() {
        var a = StateCounts()
        a.activeCount = 1
        var b = StateCounts()
        b.activeCount = 1
        XCTAssertEqual(a, b)

        b.waitingCount = 1
        XCTAssertNotEqual(a, b)
    }
}
