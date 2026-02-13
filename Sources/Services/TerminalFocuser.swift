import AppKit
import Foundation

/// Focuses the terminal window associated with a Claude Code session.
///
/// Strategy:
/// - Tier 1: NSRunningApplication to activate the terminal app (no permission needed)
/// - Tier 2: AppleScript to switch to the specific tab by matching TTY
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
                activateApp(bundleID: bundleId)
            }
        }
    }

    // MARK: - iTerm2 (tab switching by TTY)

    private static func focusITerm(session: SessionEntry) {
        activateApp(bundleID: "com.googlecode.iterm2")

        guard let tty = session.tty, !tty.isEmpty else { return }

        let escaped = escapedForAppleScript(tty)
        let script = """
        tell application "iTerm2"
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        try
                            if tty of s is "\(escaped)" then
                                select t
                                set index of w to 1
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
        activateApp(bundleID: "com.apple.Terminal")

        guard let tty = session.tty, !tty.isEmpty else { return }

        let escaped = escapedForAppleScript(tty)
        let script = """
        tell application "Terminal"
            repeat with w in windows
                try
                    if tty of w is "\(escaped)" then
                        set index of w to 1
                        set frontmost of w to true
                        return
                    end if
                end try
            end repeat
        end tell
        """
        runAppleScript(script)
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
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", source]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
        }
    }

    private static func escapedForAppleScript(_ str: String) -> String {
        str.replacingOccurrences(of: "\\", with: "\\\\")
           .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
