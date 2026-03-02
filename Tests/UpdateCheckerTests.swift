import XCTest
@testable import ClaudeRunnerLib

final class UpdateCheckerTests: XCTestCase {

    // MARK: - compareVersions

    func testCompareVersions_same() {
        XCTAssertEqual(
            UpdateChecker.compareVersions(current: "0.2.0", latest: "0.2.0"),
            .orderedSame
        )
    }

    func testCompareVersions_latestIsNewer() {
        XCTAssertEqual(
            UpdateChecker.compareVersions(current: "0.2.0", latest: "0.3.0"),
            .orderedAscending
        )
    }

    func testCompareVersions_currentIsNewer() {
        XCTAssertEqual(
            UpdateChecker.compareVersions(current: "1.0.0", latest: "0.9.9"),
            .orderedDescending
        )
    }

    func testCompareVersions_majorDifference() {
        XCTAssertEqual(
            UpdateChecker.compareVersions(current: "0.9.9", latest: "1.0.0"),
            .orderedAscending
        )
    }

    func testCompareVersions_patchDifference() {
        XCTAssertEqual(
            UpdateChecker.compareVersions(current: "0.2.0", latest: "0.2.1"),
            .orderedAscending
        )
    }

    func testCompareVersions_differentComponentCounts() {
        XCTAssertEqual(
            UpdateChecker.compareVersions(current: "1.0", latest: "1.0.0"),
            .orderedSame
        )
        XCTAssertEqual(
            UpdateChecker.compareVersions(current: "1.0", latest: "1.0.1"),
            .orderedAscending
        )
    }

    // MARK: - parseTagName

    func testParseTagName_withPrefix() {
        XCTAssertEqual(UpdateChecker.parseTagName("v0.2.0"), "0.2.0")
    }

    func testParseTagName_withoutPrefix() {
        XCTAssertEqual(UpdateChecker.parseTagName("0.2.0"), "0.2.0")
    }

    func testParseTagName_vOnly() {
        XCTAssertEqual(UpdateChecker.parseTagName("v1.0.0"), "1.0.0")
    }

    // MARK: - isUpdateAvailable

    func testIsUpdateAvailable_whenLatestIsNewer() {
        let checker = UpdateChecker()
        checker.latestVersion = "99.0.0"
        XCTAssertTrue(checker.isUpdateAvailable)
    }

    func testIsUpdateAvailable_whenUpToDate() {
        let checker = UpdateChecker()
        // In tests, currentVersion is "0.0.0" (no bundle)
        checker.latestVersion = "0.0.0"
        XCTAssertFalse(checker.isUpdateAvailable)
    }

    func testIsUpdateAvailable_whenNoLatestVersion() {
        let checker = UpdateChecker()
        XCTAssertFalse(checker.isUpdateAvailable)
    }
}
