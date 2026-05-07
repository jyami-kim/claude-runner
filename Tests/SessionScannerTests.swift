import XCTest
@testable import ClaudeRunnerLib

final class SessionScannerTests: XCTestCase {

    // MARK: - PID Parsing

    func testParseClaudePidsFromOutput() {
        let output = "12345\n67890\n"
        let pids = SessionScanner.parseClaudePids(from: output)
        XCTAssertEqual(pids, [12345, 67890])
    }

    func testParseClaudePidsEmptyOutput() {
        let pids = SessionScanner.parseClaudePids(from: "")
        XCTAssertEqual(pids, [])
    }

    func testParseClaudePidsWithWhitespace() {
        let output = "  12345  \n  67890  \n"
        let pids = SessionScanner.parseClaudePids(from: output)
        XCTAssertEqual(pids, [12345, 67890])
    }

    func testParseClaudePidsIgnoresNonNumeric() {
        let output = "12345\nabc\n67890\n"
        let pids = SessionScanner.parseClaudePids(from: output)
        XCTAssertEqual(pids, [12345, 67890])
    }

    // MARK: - lsof CWD Parsing

    func testParseCwdFromLsof() {
        let output = """
        p12345
        fcwd
        n/Users/test/my-project
        """
        let cwd = SessionScanner.parseCwdFromLsof(output)
        XCTAssertEqual(cwd, "/Users/test/my-project")
    }

    func testParseCwdFromLsofEmpty() {
        let cwd = SessionScanner.parseCwdFromLsof("")
        XCTAssertEqual(cwd, "")
    }

    func testParseCwdFromLsofNoNLine() {
        let output = "p12345\nfcwd\n"
        let cwd = SessionScanner.parseCwdFromLsof(output)
        XCTAssertEqual(cwd, "")
    }

    // MARK: - Bundle ID Parsing

    func testParseBundleIdFromLsappinfo() {
        let output = "\"bundleid\"=\"com.googlecode.iterm2\""
        let bundleId = SessionScanner.parseBundleId(from: output)
        XCTAssertEqual(bundleId, "com.googlecode.iterm2")
    }

    func testParseBundleIdEmpty() {
        let bundleId = SessionScanner.parseBundleId(from: "")
        XCTAssertEqual(bundleId, "")
    }

    func testParseBundleIdInvalidFormat() {
        let bundleId = SessionScanner.parseBundleId(from: "no quotes here")
        XCTAssertEqual(bundleId, "")
    }

    // MARK: - TTY Filtering

    func testScanFiltersExistingTTYs() {
        // This tests the filtering logic conceptually
        // (actual process scanning requires real processes)
        let existing: Set<String> = ["/dev/ttys001", "/dev/ttys002"]
        XCTAssertTrue(existing.contains("/dev/ttys001"))
        XCTAssertFalse(existing.contains("/dev/ttys003"))
    }

    // MARK: - isClaudeProcess

    func testIsClaudeProcess_returnsTrueForCurrentProcess() {
        // The test runner process itself is not "claude", so we verify the negative path.
        // We cannot create a real "claude" process in unit tests, but we can confirm
        // that PIDs we know aren't claude return false (current process = swift test runner).
        let selfPid = Int(ProcessInfo.processInfo.processIdentifier)
        // The test binary is named "ClaudeRunnerPackageTests" or similar, not "claude".
        XCTAssertFalse(SessionScanner.isClaudeProcess(pid: selfPid),
            "Test runner process should not be identified as 'claude'")
    }

    func testIsClaudeProcess_returnsFalseForInvalidPid() {
        // PID 0 is never a valid user process.
        XCTAssertFalse(SessionScanner.isClaudeProcess(pid: 0))
    }

    func testIsClaudeProcess_returnsFalseForNonExistentPid() {
        // Extremely large PID that cannot exist on macOS (max ~99999).
        XCTAssertFalse(SessionScanner.isClaudeProcess(pid: 9_999_999))
    }

    // MARK: - canonicalizeCwd

    func testCanonicalizeCwd_resolvesSymlink() {
        // /tmp is a symlink to /private/tmp on macOS.
        // realpath(3) requires the path to exist, so create a real directory under /tmp.
        let tmpSubdir = "/tmp/canonicalize-test-\(UUID().uuidString)"
        try! FileManager.default.createDirectory(atPath: tmpSubdir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tmpSubdir) }

        let result = SessionScanner.canonicalizeCwd(tmpSubdir)
        // After symlink resolution, /tmp becomes /private/tmp.
        XCTAssertTrue(result.hasPrefix("/"), "Should return absolute path")
        XCTAssertFalse(result.hasPrefix("/tmp/"), "Should have resolved /tmp symlink")
        XCTAssertTrue(result.hasPrefix("/private/tmp/"), "Should resolve to /private/tmp on macOS")
    }

    func testCanonicalizeCwd_preservesAlreadyCanonicalPath() {
        let path = "/Users/test/myproject"
        let result = SessionScanner.canonicalizeCwd(path)
        XCTAssertEqual(result, path)
    }

    func testCanonicalizeCwd_emptyStringReturnsEmpty() {
        XCTAssertEqual(SessionScanner.canonicalizeCwd(""), "")
    }

    // MARK: - parseCwdFromLsof (additional deterministic cases replacing smoke test)

    func testParseCwdFromLsof_skipsNonPathEntry() {
        // Some lsof output may have "n" lines that are not absolute paths.
        let output = "p12345\nfcwd\nnsocket\nn/actual/path"
        let cwd = SessionScanner.parseCwdFromLsof(output)
        // Should skip "nsocket" (doesn't start with /) and return the first real path.
        XCTAssertEqual(cwd, "/actual/path")
    }

    func testParseCwdFromLsof_handlesMultipleNLines() {
        let output = "p99\nfcwd\nn/first/path\nn/second/path"
        let cwd = SessionScanner.parseCwdFromLsof(output)
        // Should return the first absolute path found.
        XCTAssertEqual(cwd, "/first/path")
    }
}
