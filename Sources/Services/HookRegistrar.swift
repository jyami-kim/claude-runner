import Foundation

/// Manages hook registration in `~/.claude/settings.json`.
///
/// Reads the existing file, idempotently merges claude-runner hook entries,
/// and writes back preserving all other settings. Uses `JSONSerialization`
/// so no external dependency (like jq) is required.
enum HookRegistrar {

    /// Marker string used to identify our hook entries.
    static let hookScriptName = "claude-runner-hook.sh"

    /// Hook events that use a simple command entry (no matcher).
    static let simpleHookEvents = [
        "SessionStart", "UserPromptSubmit", "Stop", "SessionEnd",
        "PreToolUse", "PostToolUse", "PostToolUseFailure", "PermissionRequest",
    ]

    /// Notification matchers.
    static let notificationMatchers = [
        "permission_prompt", "idle_prompt", "elicitation_dialog",
    ]

    // MARK: - Public API

    /// Register hooks idempotently. Safe to call on every launch.
    /// Returns `true` on success.
    @discardableResult
    static func registerHooks(settingsURL: URL? = nil) -> Bool {
        let url = settingsURL ?? defaultSettingsURL
        do {
            var root = try readSettings(at: url)

            var hooks = root["hooks"] as? [String: Any] ?? [:]

            // Register simple hook events
            for event in simpleHookEvents {
                hooks[event] = mergeSimpleEvent(
                    existing: hooks[event] as? [[String: Any]] ?? [],
                    command: hookCommand
                )
            }

            // Register notification matchers
            hooks["Notification"] = mergeNotificationEvent(
                existing: hooks["Notification"] as? [[String: Any]] ?? [],
                command: hookCommand
            )

            root["hooks"] = hooks

            try writeSettings(root, to: url)
            return true
        } catch {
            return false
        }
    }

    /// Remove all claude-runner hooks. Returns `true` on success.
    @discardableResult
    static func unregisterHooks(settingsURL: URL? = nil) -> Bool {
        let url = settingsURL ?? defaultSettingsURL
        do {
            var root = try readSettings(at: url)
            guard var hooks = root["hooks"] as? [String: Any] else {
                return true  // nothing to remove
            }

            let allEvents = simpleHookEvents + ["Notification"]
            for event in allEvents {
                guard var entries = hooks[event] as? [[String: Any]] else { continue }
                entries = entries.filter { entry in
                    !entryContainsOurHook(entry)
                }
                if entries.isEmpty {
                    hooks.removeValue(forKey: event)
                } else {
                    hooks[event] = entries
                }
            }

            if hooks.isEmpty {
                root.removeValue(forKey: "hooks")
            } else {
                root["hooks"] = hooks
            }

            try writeSettings(root, to: url)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Internal

    /// The command string pointing to the installed hook script.
    static var hookCommand: String {
        let home = NSHomeDirectory()
        return "\"\(home)/Library/Application Support/claude-runner/hooks/\(hookScriptName)\""
    }

    static let defaultSettingsURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")
    }()

    // MARK: - Private Helpers

    /// Build a single hook entry: `{"type":"command","command":"...","async":true}`
    private static func makeHookEntry(command: String) -> [String: Any] {
        return [
            "type": "command",
            "command": command,
            "async": true,
        ]
    }

    /// Build a simple event array entry: `[{"hooks":[<hookEntry>]}]`
    private static func makeSimpleEntry(command: String) -> [String: Any] {
        return ["hooks": [makeHookEntry(command: command)]]
    }

    /// Build a notification entry with matcher: `{"matcher":"...","hooks":[<hookEntry>]}`
    private static func makeNotificationEntry(matcher: String, command: String) -> [String: Any] {
        return [
            "matcher": matcher,
            "hooks": [makeHookEntry(command: command)],
        ]
    }

    /// Check if an entry's nested hooks contain our script name.
    private static func entryContainsOurHook(_ entry: [String: Any]) -> Bool {
        guard let hooks = entry["hooks"] as? [[String: Any]] else { return false }
        return hooks.contains { hook in
            guard let cmd = hook["command"] as? String else { return false }
            return cmd.contains(hookScriptName)
        }
    }

    /// Merge our entry into a simple event array, only if not already present.
    private static func mergeSimpleEvent(
        existing: [[String: Any]],
        command: String
    ) -> [[String: Any]] {
        let alreadyRegistered = existing.contains { entryContainsOurHook($0) }
        if alreadyRegistered { return existing }
        return existing + [makeSimpleEntry(command: command)]
    }

    /// Merge notification matchers, adding only missing ones.
    private static func mergeNotificationEvent(
        existing: [[String: Any]],
        command: String
    ) -> [[String: Any]] {
        var result = existing
        for matcher in notificationMatchers {
            let alreadyRegistered = result.contains { entry in
                guard let m = entry["matcher"] as? String else { return false }
                return m == matcher && entryContainsOurHook(entry)
            }
            if !alreadyRegistered {
                result.append(makeNotificationEntry(matcher: matcher, command: command))
            }
        }
        return result
    }

    /// Read settings.json, returning empty dict if file doesn't exist.
    private static func readSettings(at url: URL) throws -> [String: Any] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            return [:]
        }
        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "HookRegistrar", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "settings.json is not a JSON object"
            ])
        }
        return json
    }

    /// Write settings.json atomically with backup.
    private static func writeSettings(_ root: [String: Any], to url: URL) throws {
        let fm = FileManager.default

        // Ensure parent directory exists
        let parent = url.deletingLastPathComponent()
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)

        // Backup existing file
        if fm.fileExists(atPath: url.path) {
            let backup = url.appendingPathExtension("bak")
            try? fm.removeItem(at: backup)
            try? fm.copyItem(at: url, to: backup)
        }

        // Write with sorted keys for consistency
        let data = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        )

        // Atomic write via temp file
        let tempURL = url.deletingLastPathComponent()
            .appendingPathComponent(".settings.json.\(UUID().uuidString).tmp")
        try data.write(to: tempURL)
        _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
    }
}
