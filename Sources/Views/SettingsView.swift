import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var store = StateStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                generalSection
                Divider()
                statusGuideSection
                Divider()
                menuBarIconSection
                Divider()
                sessionDisplaySection
                Divider()
                advancedSection
            }
            .padding(20)
        }
        .frame(width: 360, height: 520)
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("General")
                .font(.system(size: 13, weight: .semibold))

            Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                .font(.system(size: 12))
                .onChange(of: settings.launchAtLogin) { newValue in
                    do {
                        if newValue {
                            try LoginItemManager.shared.register()
                        } else {
                            try LoginItemManager.shared.unregister()
                        }
                    } catch {
                        // Revert on failure
                        settings.launchAtLogin = !newValue
                    }
                }

            Toggle("Notify on State Change", isOn: $settings.notifyOnStateChange)
                .font(.system(size: 12))
        }
    }

    // MARK: - Status Guide

    private var statusGuideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status Guide")
                .font(.system(size: 13, weight: .semibold))

            VStack(alignment: .leading, spacing: 8) {
                statusGuideRow(color: DesignTokens.redSwiftUI, title: "Needs Approval",
                               description: "Permission or response required")
                statusGuideRow(color: DesignTokens.yellowSwiftUI, title: "Waiting",
                               description: "Ready for your input")
                statusGuideRow(color: DesignTokens.greenSwiftUI, title: "Working",
                               description: "Claude is active")
            }
        }
    }

    private func statusGuideRow(color: Color, title: String, description: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.system(size: 12, weight: .medium))

            Text("— \(description)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Menu Bar Icon

    private var menuBarIconSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Menu Bar Icon")
                .font(.system(size: 13, weight: .semibold))

            // Preview strip
            iconPreviewStrip

            // 2x2 grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                iconCard(style: .trafficLight, name: "Traffic Light")
                iconCard(style: .pieChart, name: "Pie Chart")
                iconCard(style: .domino, name: "Domino")
                iconCard(style: .textCounter, name: "Text Counter")
            }
        }
    }

    private var iconPreviewStrip: some View {
        HStack {
            Spacer()
            IconPreview(style: settings.iconStyle, counts: store.counts)
                .frame(height: 24)
            Spacer()
        }
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(6)
    }

    private func iconCard(style: IconStyle, name: String) -> some View {
        Button {
            settings.iconStyle = style
        } label: {
            VStack(spacing: 6) {
                IconPreview(style: style, counts: previewCounts)
                    .frame(height: 24)
                Text(name)
                    .font(.system(size: 10))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(settings.iconStyle == style ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    /// Sample counts for icon style preview cards
    private var previewCounts: StateCounts {
        var c = StateCounts()
        c.permissionCount = 1
        c.waitingCount = 2
        c.activeCount = 1
        return c
    }

    // MARK: - Session Display

    private var sessionDisplaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Display")
                .font(.system(size: 13, weight: .semibold))

            Picker("Path Format", selection: $settings.sessionDisplayFormat) {
                Text("Full Path").tag(SessionDisplayFormat.fullPath)
                Text("Directory Only").tag(SessionDisplayFormat.directoryOnly)
                Text("Last Two Dirs").tag(SessionDisplayFormat.lastTwoDirs)
            }
            .pickerStyle(.segmented)

            // Preview
            Text(previewPath)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(4)
        }
    }

    private var previewPath: String {
        switch settings.sessionDisplayFormat {
        case .fullPath:
            return "~/projects/my-app"
        case .directoryOnly:
            return "my-app"
        case .lastTwoDirs:
            return "projects/my-app"
        }
    }

    // MARK: - Advanced

    @State private var showUninstallConfirm = false

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Advanced")
                .font(.system(size: 13, weight: .semibold))

            HStack {
                Text("Stale Session Timeout")
                    .font(.system(size: 12))
                Spacer()
                Stepper(
                    "\(settings.staleTimeoutMinutes) min",
                    value: $settings.staleTimeoutMinutes,
                    in: 1...60
                )
                .font(.system(size: 12))
            }

            Text("Waiting sessions older than this are automatically removed.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Divider()
                .padding(.top, 4)

            Button(role: .destructive) {
                showUninstallConfirm = true
            } label: {
                Text("Uninstall claude-runner…")
                    .font(.system(size: 12))
            }
            .alert("Uninstall claude-runner?", isPresented: $showUninstallConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Uninstall", role: .destructive) {
                    performUninstall()
                }
            } message: {
                Text("Hooks will be removed from ~/.claude/settings.json and session data will be deleted. The app will quit afterwards — delete it from /Applications manually.")
            }
        }
    }

    private func performUninstall() {
        // 1. Unregister hooks from ~/.claude/settings.json
        HookRegistrar.unregisterHooks()

        // 2. Remove ~/Library/Application Support/claude-runner/
        let appSupport = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/claude-runner")
        try? FileManager.default.removeItem(at: appSupport)

        // 3. Spawn background script to delete .app bundle after quit
        if let bundlePath = Bundle.main.bundlePath as String? {
            let script = "sleep 1 && rm -rf \"\(bundlePath)\""
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", script]
            try? process.run()
        }

        // 4. Quit the app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApplication.shared.terminate(nil)
        }
    }
}

// MARK: - Icon Preview (NSImage → SwiftUI)

struct IconPreview: NSViewRepresentable {
    let style: IconStyle
    let counts: StateCounts

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleNone
        return imageView
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.image = NSImage.icon(style: style, counts: counts)
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
    static let closePopover = Notification.Name("closePopover")
}
