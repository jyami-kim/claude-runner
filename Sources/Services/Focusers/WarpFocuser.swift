import Foundation

/// Focuses a Warp terminal window by matching the session's working directory against window titles.
///
/// Warp doesn't have an AppleScript dictionary, so we use System Events to enumerate
/// windows by title and raise the one matching the session's project path.
struct WarpFocuser: TerminalFocusStrategy {

    static let supportedBundleIds: Set<String> = [
        "dev.warp.Warp-Stable",
    ]

    static func focus(session: SessionEntry) {
        let bundleId = session.terminalBundleId ?? "dev.warp.Warp-Stable"
        let projectName = session.projectName

        guard !projectName.isEmpty else {
            TerminalFocuser.activateApp(bundleID: bundleId)
            return
        }

        let escapedProject = TerminalFocuser.escapedForAppleScript(projectName)

        // Use System Events to find and raise the window whose title contains the project name.
        // Then activate Warp to bring it to the foreground.
        let script = """
        tell application "System Events"
            if not (exists process "Warp") then return
            tell process "Warp"
                repeat with w in windows
                    try
                        if name of w contains "\(escapedProject)" then
                            perform action "AXRaise" of w
                            set frontmost to true
                            return
                        end if
                    end try
                end repeat
            end tell
        end tell
        tell application "Warp" to activate
        """
        TerminalFocuser.runAppleScript(script)
    }
}
