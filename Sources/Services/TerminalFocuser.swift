import AppKit
import Foundation

/// Focuses the terminal window associated with a Claude Code session.
///
/// Strategy:
/// - iTerm2: AppleScript to switch to the specific tab by matching TTY
/// - Terminal.app: AppleScript to switch to the window by matching TTY
/// - JetBrains IDEs: Toolbox CLI launcher to focus the project window
/// - Other apps: NSRunningApplication to activate the app
enum TerminalFocuser {

    /// Bring the terminal window for this session to the foreground.
    static func focus(session: SessionEntry) {
        let bundleId = session.terminalBundleId ?? ""

        switch bundleId {
        case "com.googlecode.iterm2":
            focusITerm(session: session)
        case "com.apple.Terminal":
            focusTerminalApp(session: session)
        default:
            if !bundleId.isEmpty {
                if !focusJetBrains(session: session, bundleId: bundleId) {
                    activateApp(bundleID: bundleId)
                }
            }
        }
    }

    // MARK: - iTerm2 (tab switching by TTY)

    private static func focusITerm(session: SessionEntry) {
        guard let tty = session.tty, !tty.isEmpty else {
            activateApp(bundleID: "com.googlecode.iterm2")
            return
        }

        let escaped = escapedForAppleScript(tty)
        let script = """
        tell application "iTerm2"
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        try
                            if tty of s is "\(escaped)" then
                                select t
                                tell w
                                    select
                                end tell
                                activate
                                return
                            end if
                        end try
                    end repeat
                end repeat
            end repeat
        end tell
        """
        runAppleScript(script)
    }

    // MARK: - Terminal.app

    private static func focusTerminalApp(session: SessionEntry) {
        guard let tty = session.tty, !tty.isEmpty else {
            activateApp(bundleID: "com.apple.Terminal")
            return
        }

        let escaped = escapedForAppleScript(tty)
        let script = """
        tell application "Terminal"
            repeat with w in windows
                try
                    if tty of w is "\(escaped)" then
                        set frontmost of w to true
                        activate
                        return
                    end if
                end try
            end repeat
        end tell
        """
        runAppleScript(script)
    }

    // MARK: - JetBrains IDEs (Toolbox CLI launcher)

    /// Bundle ID → Toolbox CLI tool name mapping.
    private static let jetBrainsTools: [String: String] = [
        "com.jetbrains.intellij": "idea",
        "com.jetbrains.intellij.ce": "idea",
        "com.jetbrains.WebStorm": "webstorm",
        "com.jetbrains.pycharm": "pycharm",
        "com.jetbrains.pycharm.ce": "pycharm",
        "com.jetbrains.CLion": "clion",
        "com.jetbrains.goland": "goland",
        "com.jetbrains.rider": "rider",
        "com.jetbrains.rubymine": "rubymine",
        "com.jetbrains.PhpStorm": "phpstorm",
        "com.jetbrains.datagrip": "datagrip",
        "com.jetbrains.AppCode": "appcode",
        "com.google.android.studio": "studio",
    ]

    /// Focus a JetBrains IDE project window using Toolbox CLI launcher.
    /// Returns `true` if the CLI tool was found and executed.
    @discardableResult
    private static func focusJetBrains(session: SessionEntry, bundleId: String) -> Bool {
        guard let toolName = jetBrainsTools[bundleId] else { return false }

        let toolboxScripts = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/JetBrains/Toolbox/scripts")
            .appendingPathComponent(toolName)

        guard FileManager.default.isExecutableFile(atPath: toolboxScripts.path) else {
            return false
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = toolboxScripts
            process.arguments = [session.cwd]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
        }
        return true
    }

    // MARK: - Helpers

    @discardableResult
    private static func activateApp(bundleID: String) -> Bool {
        guard let app = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleID
        ).first else {
            return false
        }
        app.activate(options: .activateIgnoringOtherApps)
        return true
    }

    private static func runAppleScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = NSAppleScript(source: source)
            var error: NSDictionary?
            script?.executeAndReturnError(&error)
        }
    }

    private static func escapedForAppleScript(_ str: String) -> String {
        str.replacingOccurrences(of: "\\", with: "\\\\")
           .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
