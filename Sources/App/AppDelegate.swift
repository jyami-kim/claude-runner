import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var statusIcon: StatusIcon!
    private var popover: NSPopover!
    private var watcher: SessionDirectoryWatcher!
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Install hook script on first launch
        HookInstaller.install()

        let store = StateStore.shared

        // Setup status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusIcon = StatusIcon(statusItem: statusItem)

        // Setup popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 260, height: 300)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: SessionListView(store: store)
        )

        // Setup click handler
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self

        // Observe state changes
        store.$counts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] counts in
                self?.statusIcon.update(counts: counts)
            }
            .store(in: &cancellables)

        // Start watching sessions directory
        watcher = SessionDirectoryWatcher()
        watcher.start { [weak store] in
            store?.reload()
        }

        // Close popover when clicking outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
        }

        // Listen for settings open request
        NotificationCenter.default.addObserver(
            self, selector: #selector(showSettings),
            name: .openSettings, object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        watcher?.stop()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            StateStore.shared.reload()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc private func showSettings() {
        // Close popover first
        if popover.isShown {
            popover.performClose(nil)
        }

        if let window = settingsWindow {
            window.level = .floating
            window.makeKeyAndOrderFront(nil)
            window.level = .normal
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "claude-runner Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 360, height: 520))
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        window.level = .normal
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }
}
