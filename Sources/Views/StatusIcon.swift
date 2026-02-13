import AppKit

/// Manages the menu bar status icon, updating the traffic light image
/// whenever session state counts change.
final class StatusIcon {
    private let statusItem: NSStatusItem

    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
        update(counts: StateCounts())
    }

    func update(counts: StateCounts) {
        let image = NSImage.trafficLight(counts: counts)
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
