import Foundation

/// Focuses a terminal window by matching the window title via System Events AppleScript.
///
/// Used for terminals that lack AppleScript dictionaries (Ghostty, Warp, etc.) but set
/// the window title to include the current working directory or project name.
/// Requires Accessibility permission (System Settings > Privacy > Accessibility).
struct WindowTitleFocuser: TerminalFocusStrategy {

    static let supportedBundleIds: Set<String> = [
        "com.mitchellh.ghostty",
        "dev.warp.Warp-Stable",
    ]

    static func focus(session: SessionEntry) {
        let bundleId = session.terminalBundleId ?? ""
        let escapedBundleId = TerminalFocuser.escapedForAppleScript(bundleId)
        let projectName = TerminalFocuser.escapedForAppleScript(session.projectName)
        let cwd = TerminalFocuser.escapedForAppleScript(session.cwd)

        // Try window title matching via System Events (requires Accessibility permission).
        // If that fails (no permission, no match), fall back to just activating the app.
        let script = """
        try
            tell application "System Events"
                set targetApp to first process whose bundle identifier is "\(escapedBundleId)"
                repeat with w in windows of targetApp
                    set wTitle to name of w
                    if wTitle contains "\(projectName)" or wTitle contains "\(cwd)" then
                        perform action "AXRaise" of w
                        exit repeat
                    end if
                end repeat
            end tell
        end try
        tell application id "\(escapedBundleId)" to activate
        """
        TerminalFocuser.runAppleScript(script)
    }
}
