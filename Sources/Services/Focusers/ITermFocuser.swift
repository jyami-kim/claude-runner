import Foundation

/// Focuses an iTerm2 tab by matching the session's TTY via AppleScript.
struct ITermFocuser: TerminalFocusStrategy {

    static let supportedBundleIds: Set<String> = [
        "com.googlecode.iterm2",
    ]

    static func focus(session: SessionEntry) {
        guard let tty = session.tty, !tty.isEmpty else {
            TerminalFocuser.activateApp(bundleID: "com.googlecode.iterm2")
            return
        }

        let escaped = TerminalFocuser.escapedForAppleScript(tty)
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
        TerminalFocuser.runAppleScript(script)
    }
}
