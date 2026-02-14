import XCTest
@testable import ClaudeRunnerLib

final class AppInfoTests: XCTestCase {

    // MARK: - Known Bundle IDs

    func testKnownTerminalNames() {
        XCTAssertEqual(AppInfo.appName(for: "com.apple.Terminal"), "Terminal")
        XCTAssertEqual(AppInfo.appName(for: "com.googlecode.iterm2"), "iTerm2")
        XCTAssertEqual(AppInfo.appName(for: "com.microsoft.VSCode"), "VS Code")
    }

    func testKnownJetBrainsNames() {
        XCTAssertEqual(AppInfo.appName(for: "com.jetbrains.intellij"), "IntelliJ")
        XCTAssertEqual(AppInfo.appName(for: "com.jetbrains.intellij.ce"), "IntelliJ CE")
        XCTAssertEqual(AppInfo.appName(for: "com.jetbrains.WebStorm"), "WebStorm")
        XCTAssertEqual(AppInfo.appName(for: "com.jetbrains.pycharm"), "PyCharm")
    }

    func testKnownOtherNames() {
        XCTAssertEqual(AppInfo.appName(for: "dev.zed.Zed"), "Zed")
        XCTAssertEqual(AppInfo.appName(for: "dev.warp.Warp-Stable"), "Warp")
        XCTAssertEqual(AppInfo.appName(for: "com.todesktop.230313mzl4w4u92"), "Cursor")
    }

    // MARK: - Unknown Bundle IDs

    func testUnknownBundleIdFallsBackToLastComponent() {
        XCTAssertEqual(AppInfo.appName(for: "com.example.MyTerminal"), "MyTerminal")
    }

    func testSingleComponentBundleId() {
        XCTAssertEqual(AppInfo.appName(for: "SomeApp"), "SomeApp")
    }

    // MARK: - Icon

    func testIconForInstalledApp() {
        // Terminal.app is always installed on macOS
        let icon = AppInfo.appIcon(for: "com.apple.Terminal")
        XCTAssertNotNil(icon)
        XCTAssertEqual(icon?.size.width, 16)
        XCTAssertEqual(icon?.size.height, 16)
    }

    func testIconForUnknownAppReturnsNil() {
        let icon = AppInfo.appIcon(for: "com.nonexistent.fakeapp.xyz")
        XCTAssertNil(icon)
    }

    // MARK: - Caching

    func testNameIsCached() {
        let name1 = AppInfo.appName(for: "com.apple.Terminal")
        let name2 = AppInfo.appName(for: "com.apple.Terminal")
        XCTAssertEqual(name1, name2)
    }
}
