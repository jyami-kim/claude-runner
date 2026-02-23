import AppKit
import SwiftUI
import Combine

// MARK: - Popover Panel

/// Borderless floating panel that acts as a popover from the menu bar.
final class PopoverPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    init(contentView: some View) {
        super.init(
            contentRect: .zero,
            styleMask: [.fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false

        let host = NSHostingController(rootView:
            contentView
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        )
        contentViewController = host
    }

    /// Position below the status bar button.
    func show(relativeTo button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        let buttonRect = buttonWindow.convertToScreen(
            button.convert(button.bounds, to: nil)
        )

        // Size to fit content
        contentViewController?.view.layoutSubtreeIfNeeded()
        let size = contentViewController?.view.fittingSize ?? NSSize(width: 260, height: 300)
        let panelWidth = max(size.width, 260)
        let panelHeight = min(size.height, 400)

        let x = buttonRect.midX - panelWidth / 2
        let y = buttonRect.minY - panelHeight

        setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        makeKeyAndOrderFront(nil)
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var statusIcon: StatusIcon!
    private var panel: PopoverPanel!
    private var watcher: SessionDirectoryWatcher!
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?
    private var settingsWindow: NSWindow?
    private var previousCounts = StateCounts()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Install hook script and register hooks in settings.json
        HookInstaller.install()
        HookRegistrar.registerHooks()

        // Check if jq is installed (required by hook script)
        checkJqAvailability()

        // Setup notifications
        NotificationService.shared.setup()

        let store = StateStore.shared

        // Setup status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusIcon = StatusIcon(statusItem: statusItem)

        // Setup panel
        panel = PopoverPanel(contentView: SessionListView(store: store))

        // Setup click handler
        statusItem.button?.action = #selector(togglePanel)
        statusItem.button?.target = self

        // Observe state changes
        store.$counts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] counts in
                self?.statusIcon.update(counts: counts)
                if let prev = self?.previousCounts {
                    NotificationService.shared.notify(
                        oldCounts: prev, newCounts: counts,
                        sessions: store.sessions
                    )
                }
                self?.previousCounts = counts
            }
            .store(in: &cancellables)

        // Start watching sessions directory
        watcher = SessionDirectoryWatcher()
        watcher.start { [weak store] in
            store?.reload()
        }

        // Close panel when clicking outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let panel = self?.panel, panel.isVisible else { return }

            // Check if the click is inside the panel
            let clickLocation = NSEvent.mouseLocation
            if panel.frame.contains(clickLocation) { return }

            panel.orderOut(nil)
        }

        // Listen for settings open request
        NotificationCenter.default.addObserver(
            self, selector: #selector(showSettings),
            name: .openSettings, object: nil
        )

        // Listen for panel close request
        NotificationCenter.default.addObserver(
            self, selector: #selector(closePanel),
            name: .closePopover, object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        watcher?.stop()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    @objc private func togglePanel() {
        guard let button = statusItem.button else { return }

        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            StateStore.shared.reload()
            NSApp.activate(ignoringOtherApps: true)
            panel.show(relativeTo: button)
        }
    }

    @objc private func closePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
        }
    }

    private func checkJqAvailability() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["jq"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            showJqAlert()
            return
        }
        if process.terminationStatus != 0 {
            showJqAlert()
        }
    }

    private func showJqAlert() {
        let alert = NSAlert()
        alert.messageText = "jq가 설치되어 있지 않습니다"
        alert.informativeText = "claude-runner의 hook 스크립트가 jq를 필요로 합니다. jq 없이는 세션 상태를 추적할 수 없습니다.\n\nbrew install jq 로 설치해주세요."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "확인")
        alert.runModal()
    }

    @objc private func showSettings() {
        // Close panel first
        closePanel()

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
