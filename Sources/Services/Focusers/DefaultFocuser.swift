import Foundation

/// Fallback focuser that simply activates the app via NSRunningApplication.
struct DefaultFocuser: TerminalFocusStrategy {

    static let supportedBundleIds: Set<String> = []

    static func focus(session: SessionEntry) {
        let bundleId = session.terminalBundleId ?? ""
        guard !bundleId.isEmpty else { return }
        TerminalFocuser.activateApp(bundleID: bundleId)
    }
}
