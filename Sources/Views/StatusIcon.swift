import AppKit

/// Manages the menu bar status icon, updating the image
/// whenever session state counts or icon style changes.
final class StatusIcon {
    private let statusItem: NSStatusItem
    private let settings: AppSettings

    init(statusItem: NSStatusItem, settings: AppSettings = .shared) {
        self.statusItem = statusItem
        self.settings = settings
        update(counts: StateCounts())
    }

    func update(counts: StateCounts) {
        let image = NSImage.icon(style: settings.iconStyle, counts: counts)
        statusItem.button?.image = image
        statusItem.button?.imagePosition = .imageOnly

        // Accessibility description
        let total = counts.totalCount
        if total == 0 {
            statusItem.button?.toolTip = "claude-runner: No active sessions"
        } else {
            var parts: [String] = []
            if counts.permissionCount > 0 { parts.append("\(counts.permissionCount) permission") }
            if counts.waitingCount > 0 { parts.append("\(counts.waitingCount) waiting") }
            if counts.activeCount > 0 { parts.append("\(counts.activeCount) active") }
            statusItem.button?.toolTip = "claude-runner: \(parts.joined(separator: ", "))"
        }
    }
}
