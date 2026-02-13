import XCTest
@testable import ClaudeRunnerLib

final class AppSettingsTests: XCTestCase {

    // MARK: - IconStyle Enum

    func testIconStyleRawValues() {
        XCTAssertEqual(IconStyle.trafficLight.rawValue, "trafficLight")
        XCTAssertEqual(IconStyle.singleDot.rawValue, "singleDot")
        XCTAssertEqual(IconStyle.compactBar.rawValue, "compactBar")
        XCTAssertEqual(IconStyle.textCounter.rawValue, "textCounter")
    }

    func testIconStyleRoundTrip() {
        for style in IconStyle.allCases {
            let raw = style.rawValue
            let decoded = IconStyle(rawValue: raw)
            XCTAssertEqual(decoded, style)
        }
    }

    func testIconStyleCaseIterable() {
        XCTAssertEqual(IconStyle.allCases.count, 4)
    }

    // MARK: - SessionDisplayFormat Enum

    func testSessionDisplayFormatRawValues() {
        XCTAssertEqual(SessionDisplayFormat.fullPath.rawValue, "fullPath")
        XCTAssertEqual(SessionDisplayFormat.directoryOnly.rawValue, "directoryOnly")
        XCTAssertEqual(SessionDisplayFormat.lastTwoDirs.rawValue, "lastTwoDirs")
    }

    func testSessionDisplayFormatRoundTrip() {
        for format in SessionDisplayFormat.allCases {
            let raw = format.rawValue
            let decoded = SessionDisplayFormat(rawValue: raw)
            XCTAssertEqual(decoded, format)
        }
    }

    func testSessionDisplayFormatCaseIterable() {
        XCTAssertEqual(SessionDisplayFormat.allCases.count, 3)
    }

    // MARK: - AppSettings Defaults (using isolated UserDefaults)

    func testDefaultValues() {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // Verify default raw values match expected
        XCTAssertNil(defaults.object(forKey: "launchAtLogin"))
        XCTAssertNil(defaults.object(forKey: "iconStyle"))
        XCTAssertNil(defaults.object(forKey: "sessionDisplayFormat"))
        XCTAssertNil(defaults.object(forKey: "staleTimeout"))
    }

    func testIconStylePersistence() {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(IconStyle.singleDot.rawValue, forKey: "iconStyle")
        let stored = defaults.string(forKey: "iconStyle")
        XCTAssertEqual(stored, "singleDot")
        XCTAssertEqual(IconStyle(rawValue: stored!), .singleDot)
    }

    func testSessionDisplayFormatPersistence() {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(SessionDisplayFormat.lastTwoDirs.rawValue, forKey: "sessionDisplayFormat")
        let stored = defaults.string(forKey: "sessionDisplayFormat")
        XCTAssertEqual(stored, "lastTwoDirs")
        XCTAssertEqual(SessionDisplayFormat(rawValue: stored!), .lastTwoDirs)
    }

    func testStaleTimeoutPersistence() {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(15, forKey: "staleTimeout")
        XCTAssertEqual(defaults.integer(forKey: "staleTimeout"), 15)
    }
}
