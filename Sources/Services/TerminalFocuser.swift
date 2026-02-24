import AppKit
import ApplicationServices
import Foundation

/// Focuses the terminal window associated with a Claude Code session.
///
/// Strategy:
/// - iTerm2: AppleScript to switch to the specific tab by matching TTY
/// - Terminal.app: AppleScript to switch to the window by matching TTY
/// - Ghostty / Warp: lsof + Accessibility API to find window by TTY ownership
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
        case "com.mitchellh.ghostty":
            focusViaTTY(session: session, bundleId: bundleId)
        case "dev.warp.Warp-Stable":
            focusViaTTY(session: session, bundleId: bundleId)
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

    // MARK: - TTY-based Window Focusing (Ghostty, Warp)

    /// Focus a terminal window by finding the window that owns the TTY.
    /// Uses lsof to find the terminal PID, then CGWindowList + Accessibility API to focus.
    /// Falls back to simple app activation if TTY matching fails.
    private static func focusViaTTY(session: SessionEntry, bundleId: String) {
        guard let tty = session.tty, !tty.isEmpty else {
            activateApp(bundleID: bundleId)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            // Step 1: Find terminal PID from TTY using lsof
            guard let terminalPid = findTerminalPid(forTTY: tty, bundleId: bundleId) else {
                DispatchQueue.main.async { activateApp(bundleID: bundleId) }
                return
            }

            // Step 2: Find and focus the window owned by this PID
            if !focusWindowByPid(terminalPid) {
                DispatchQueue.main.async { activateApp(bundleID: bundleId) }
            }
        }
    }

    /// Find the terminal application's PID that owns the given TTY.
    /// Returns nil if not found.
    private static func findTerminalPid(forTTY tty: String, bundleId: String) -> pid_t? {
        // Get all running instances of this terminal app
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        guard !apps.isEmpty else { return nil }

        let terminalPids = Set(apps.map { $0.processIdentifier })

        // Use lsof to find processes with this TTY open
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-t", tty]  // -t: terse output (PIDs only)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        // Parse PIDs from lsof output and find one that matches our terminal
        let pids = output.split(separator: "\n").compactMap { pid_t($0) }

        // Walk up the process tree to find a terminal PID
        for pid in pids {
            if let terminalPid = findAncestorPid(of: pid, in: terminalPids) {
                return terminalPid
            }
        }

        // Fallback: return the first running terminal app's PID
        return apps.first?.processIdentifier
    }

    /// Walk up the process tree to find an ancestor PID that's in the target set.
    private static func findAncestorPid(of pid: pid_t, in targetPids: Set<pid_t>) -> pid_t? {
        var currentPid = pid
        var visited = Set<pid_t>()

        while currentPid > 1 && !visited.contains(currentPid) {
            if targetPids.contains(currentPid) {
                return currentPid
            }
            visited.insert(currentPid)

            // Get parent PID using ps
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/ps")
            process.arguments = ["-o", "ppid=", "-p", "\(currentPid)"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                break
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let ppid = pid_t(output) else {
                break
            }
            currentPid = ppid
        }

        return nil
    }

    /// Focus a window owned by the given PID using Accessibility API.
    /// Returns true if successful.
    @discardableResult
    private static func focusWindowByPid(_ pid: pid_t) -> Bool {
        // Get the app and activate it
        guard let app = NSRunningApplication(processIdentifier: pid) else {
            return false
        }

        // Use Accessibility API to raise the window
        let axApp = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?

        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement],
              let firstWindow = windows.first else {
            // Fallback: just activate the app
            app.activate(options: .activateIgnoringOtherApps)
            return true
        }

        // Raise the first window
        AXUIElementSetAttributeValue(firstWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(firstWindow, kAXRaiseAction as CFString)

        // Activate the app
        app.activate(options: .activateIgnoringOtherApps)
        return true
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
