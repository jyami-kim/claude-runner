import XCTest
@testable import ClaudeRunnerLib

final class HookRegistrarTests: XCTestCase {

    private var tempDir: URL!
    private var settingsURL: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("claude-runner-registrar-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        settingsURL = tempDir.appendingPathComponent("settings.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Register

    func testRegisterCreatesFileWhenMissing() {
        XCTAssertFalse(FileManager.default.fileExists(atPath: settingsURL.path))

        let result = HookRegistrar.registerHooks(settingsURL: settingsURL)
        XCTAssertTrue(result)
        XCTAssertTrue(FileManager.default.fileExists(atPath: settingsURL.path))

        let root = readJSON()
        let hooks = root["hooks"] as? [String: Any]
        XCTAssertNotNil(hooks)
    }

    func testRegisterAddsAllSimpleEvents() {
        let result = HookRegistrar.registerHooks(settingsURL: settingsURL)
        XCTAssertTrue(result)

        let hooks = readHooks()
        for event in HookRegistrar.simpleHookEvents {
            let entries = hooks[event] as? [[String: Any]]
            XCTAssertNotNil(entries, "Missing event: \(event)")
            XCTAssertEqual(entries?.count, 1, "Event \(event) should have 1 entry")
        }
    }

    func testRegisterAddsAllNotificationMatchers() {
        let result = HookRegistrar.registerHooks(settingsURL: settingsURL)
        XCTAssertTrue(result)

        let hooks = readHooks()
        let notifications = hooks["Notification"] as? [[String: Any]]
        XCTAssertNotNil(notifications)
        XCTAssertEqual(notifications?.count, 3)

        let matchers = notifications?.compactMap { $0["matcher"] as? String } ?? []
        for matcher in HookRegistrar.notificationMatchers {
            XCTAssertTrue(matchers.contains(matcher), "Missing matcher: \(matcher)")
        }
    }

    func testRegisterPreservesExistingSettings() {
        // Write initial settings with custom key
        let initial: [String: Any] = [
            "alwaysThinkingEnabled": true,
            "customKey": "customValue",
        ]
        writeJSON(initial)

        HookRegistrar.registerHooks(settingsURL: settingsURL)

        let root = readJSON()
        XCTAssertEqual(root["alwaysThinkingEnabled"] as? Bool, true)
        XCTAssertEqual(root["customKey"] as? String, "customValue")
        XCTAssertNotNil(root["hooks"])
    }

    func testRegisterPreservesExistingHooks() {
        // Write settings with an existing hook from another tool
        let initial: [String: Any] = [
            "hooks": [
                "SessionStart": [
                    ["hooks": [["type": "command", "command": "other-tool.sh", "async": true]]]
                ]
            ]
        ]
        writeJSON(initial)

        HookRegistrar.registerHooks(settingsURL: settingsURL)

        let hooks = readHooks()
        let sessionStart = hooks["SessionStart"] as? [[String: Any]]
        // Should have 2 entries: the existing one + ours
        XCTAssertEqual(sessionStart?.count, 2)
    }

    func testRegisterIsIdempotent() {
        HookRegistrar.registerHooks(settingsURL: settingsURL)
        HookRegistrar.registerHooks(settingsURL: settingsURL)

        let hooks = readHooks()
        for event in HookRegistrar.simpleHookEvents {
            let entries = hooks[event] as? [[String: Any]]
            XCTAssertEqual(entries?.count, 1, "Event \(event) duplicated")
        }

        let notifications = hooks["Notification"] as? [[String: Any]]
        XCTAssertEqual(notifications?.count, 3, "Notification matchers duplicated")
    }

    func testRegisterCreatesBackup() {
        // Create initial file
        writeJSON(["initial": true])

        HookRegistrar.registerHooks(settingsURL: settingsURL)

        let backupURL = settingsURL.appendingPathExtension("bak")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))
    }

    func testRegisterReturnsFalseForMalformedJSON() {
        // Write invalid JSON
        try? "not json at all".data(using: .utf8)?.write(to: settingsURL)

        let result = HookRegistrar.registerHooks(settingsURL: settingsURL)
        XCTAssertFalse(result)
    }

    func testHookCommandContainsScriptName() {
        XCTAssertTrue(HookRegistrar.hookCommand.contains(HookRegistrar.hookScriptName))
    }

    func testHookEntryStructure() {
        HookRegistrar.registerHooks(settingsURL: settingsURL)

        let hooks = readHooks()
        let entries = hooks["SessionStart"] as? [[String: Any]]
        let entry = entries?.first
        let hooksList = entry?["hooks"] as? [[String: Any]]
        let hook = hooksList?.first

        XCTAssertEqual(hook?["type"] as? String, "command")
        XCTAssertEqual(hook?["async"] as? Bool, true)
        XCTAssertTrue((hook?["command"] as? String)?.contains(HookRegistrar.hookScriptName) == true)
    }

    // MARK: - Unregister

    func testUnregisterRemovesOurEntries() {
        HookRegistrar.registerHooks(settingsURL: settingsURL)
        let result = HookRegistrar.unregisterHooks(settingsURL: settingsURL)
        XCTAssertTrue(result)

        let root = readJSON()
        // hooks key should be removed entirely (was only our entries)
        XCTAssertNil(root["hooks"])
    }

    func testUnregisterPreservesOtherHooks() {
        // Register our hooks first
        HookRegistrar.registerHooks(settingsURL: settingsURL)

        // Manually add another tool's hook
        var root = readJSON()
        var hooks = root["hooks"] as! [String: Any]
        var sessionStart = hooks["SessionStart"] as! [[String: Any]]
        sessionStart.append(["hooks": [["type": "command", "command": "other-tool.sh", "async": true]]])
        hooks["SessionStart"] = sessionStart
        root["hooks"] = hooks
        writeJSON(root)

        HookRegistrar.unregisterHooks(settingsURL: settingsURL)

        let updatedHooks = readHooks()
        let remaining = updatedHooks["SessionStart"] as? [[String: Any]]
        XCTAssertEqual(remaining?.count, 1)

        let cmd = (remaining?.first?["hooks"] as? [[String: Any]])?.first?["command"] as? String
        XCTAssertEqual(cmd, "other-tool.sh")
    }

    func testUnregisterOnEmptyFile() {
        // Should succeed even without a file
        let result = HookRegistrar.unregisterHooks(settingsURL: settingsURL)
        XCTAssertTrue(result)
    }

    func testUnregisterPreservesNonHookSettings() {
        let initial: [String: Any] = [
            "alwaysThinkingEnabled": true,
            "hooks": [
                "SessionStart": [
                    ["hooks": [["type": "command", "command": HookRegistrar.hookCommand, "async": true]]]
                ]
            ],
        ]
        writeJSON(initial)

        HookRegistrar.unregisterHooks(settingsURL: settingsURL)

        let root = readJSON()
        XCTAssertEqual(root["alwaysThinkingEnabled"] as? Bool, true)
        XCTAssertNil(root["hooks"])
    }

    // MARK: - Helpers

    private func readJSON() -> [String: Any] {
        guard let data = try? Data(contentsOf: settingsURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    private func readHooks() -> [String: Any] {
        let root = readJSON()
        return root["hooks"] as? [String: Any] ?? [:]
    }

    private func writeJSON(_ dict: [String: Any]) {
        let data = try! JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
        try! data.write(to: settingsURL)
    }
}
