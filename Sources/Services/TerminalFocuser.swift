import AppKit
import Foundation

/// A strategy for focusing a specific terminal app's window.
protocol TerminalFocusStrategy {
    /// Bundle IDs this strategy handles.
    static var supportedBundleIds: Set<String> { get }
    /// Focus the terminal window for the given session.
    static func focus(session: SessionEntry)
}

/// Dispatches focus requests to the appropriate terminal-specific strategy.
///
/// Registered strategies are checked in order; the first whose `supportedBundleIds`
/// contains the session's terminal bundle ID wins. If none match, `DefaultFocuser` is used.
enum TerminalFocuser {

    /// Registered strategies (checked in order).
    private static let strategies: [any TerminalFocusStrategy.Type] = [
        ITermFocuser.self,
        TerminalAppFocuser.self,
        JetBrainsFocuser.self,
        WarpFocuser.self,
    ]

    /// Bring the terminal window for this session to the foreground.
    static func focus(session: SessionEntry) {
        let bundleId = session.terminalBundleId ?? ""
        guard !bundleId.isEmpty else { return }

        for strategy in strategies {
            if strategy.supportedBundleIds.contains(bundleId) {
                strategy.focus(session: session)
                return
            }
        }
        DefaultFocuser.focus(session: session)
    }

    // MARK: - Shared Helpers

    /// Activate an app by bundle ID using NSRunningApplication.
    @discardableResult
    static func activateApp(bundleID: String) -> Bool {
        guard let app = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleID
        ).first else {
            return false
        }
        app.activate(options: .activateIgnoringOtherApps)
        return true
    }

    /// Run an AppleScript asynchronously on a background queue.
    static func runAppleScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = NSAppleScript(source: source)
            var error: NSDictionary?
            script?.executeAndReturnError(&error)
        }
    }

    /// Escape a string for safe use inside AppleScript double-quoted strings.
    static func escapedForAppleScript(_ str: String) -> String {
        str.replacingOccurrences(of: "\\", with: "\\\\")
           .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
