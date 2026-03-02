import Foundation

/// Focuses a Terminal.app window by matching the session's TTY via AppleScript.
struct TerminalAppFocuser: TerminalFocusStrategy {

    static let supportedBundleIds: Set<String> = [
        "com.apple.Terminal",
    ]

    static func focus(session: SessionEntry) {
        guard let tty = session.tty, !tty.isEmpty else {
            TerminalFocuser.activateApp(bundleID: "com.apple.Terminal")
            return
        }

        let escaped = TerminalFocuser.escapedForAppleScript(tty)
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
        TerminalFocuser.runAppleScript(script)
    }
}
