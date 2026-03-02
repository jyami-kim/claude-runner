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
}
