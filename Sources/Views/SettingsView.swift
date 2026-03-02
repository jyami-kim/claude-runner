import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var store = StateStore.shared
    @ObservedObject private var updateChecker = UpdateChecker.shared
    @State private var showCopied = false

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
                Divider()
                aboutSection
            }
            .padding(20)
        }
        .frame(width: 360, height: 620)
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Strings.general)
                .font(.system(size: 13, weight: .semibold))

            Toggle(Strings.launchAtLogin, isOn: $settings.launchAtLogin)
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

            Toggle(Strings.notifyOnStateChange, isOn: $settings.notifyOnStateChange)
                .font(.system(size: 12))

            HStack {
                Text(Strings.language)
                    .font(.system(size: 12))
                Spacer()
                Picker(Strings.language, selection: $settings.appLanguage) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 160)
            }
        }
    }

    // MARK: - Status Guide

    private var statusGuideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Strings.statusGuide)
                .font(.system(size: 13, weight: .semibold))

            VStack(alignment: .leading, spacing: 8) {
                statusGuideRow(color: DesignTokens.redSwiftUI, title: Strings.needsApproval,
                               description: Strings.needsApprovalDesc)
                statusGuideRow(color: DesignTokens.yellowSwiftUI, title: Strings.waiting,
                               description: Strings.waitingDesc)
                statusGuideRow(color: DesignTokens.greenSwiftUI, title: Strings.running,
                               description: Strings.runningDesc)
            }
        }
    }

    private func statusGuideRow(color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))

                Text(description)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Menu Bar Icon

    private var menuBarIconSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Strings.menuBarIcon)
                .font(.system(size: 13, weight: .semibold))

            // Preview strip
            iconPreviewStrip

            // 2x2 grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                iconCard(style: .trafficLight, name: Strings.trafficLight)
                iconCard(style: .pieChart, name: Strings.pieChart)
                iconCard(style: .domino, name: Strings.domino)
                iconCard(style: .textCounter, name: Strings.textCounter)
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
            Text(Strings.sessionDisplay)
                .font(.system(size: 13, weight: .semibold))

            Toggle(Strings.showTaskMessage, isOn: $settings.showTaskMessage)
                .font(.system(size: 12))

            VStack(alignment: .leading, spacing: 8) {
                Text(Strings.pathFormat)
                    .font(.system(size: 12))

                Picker(Strings.pathFormat, selection: $settings.sessionDisplayFormat) {
                    Text(Strings.full).tag(SessionDisplayFormat.fullPath)
                    Text(Strings.dirOnly).tag(SessionDisplayFormat.directoryOnly)
                    Text(Strings.lastTwoDirs).tag(SessionDisplayFormat.lastTwoDirs)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text(previewPath)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.03))
                    .cornerRadius(4)
            }
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
            Text(Strings.advanced)
                .font(.system(size: 13, weight: .semibold))

            HStack {
                Text(Strings.staleSessionTimeout)
                    .font(.system(size: 12))
                Spacer()
                Stepper(
                    "\(settings.staleTimeoutMinutes) \(Strings.min)",
                    value: $settings.staleTimeoutMinutes,
                    in: 1...60
                )
                .font(.system(size: 12))
            }

            Text(Strings.staleTimeoutDesc)
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(Strings.recoverTitle)
                    .font(.system(size: 12))

                Text(Strings.recoverDesc)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 2)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(Strings.version)
                    .font(.system(size: 13, weight: .semibold))
                Text("v\(updateChecker.currentVersion)")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    updateChecker.checkForUpdates()
                } label: {
                    if updateChecker.isChecking {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(Strings.checkForUpdates)
                            .font(.system(size: 11))
                    }
                }
                .disabled(updateChecker.isChecking)
            }

            if updateChecker.isUpdateAvailable, let latest = updateChecker.latestVersion {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                    Text("\(Strings.updateAvailable): v\(latest)")
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                    Spacer()
                    if UpdateChecker.isHomebrewInstall {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("brew upgrade claude-runner", forType: .string)
                            showCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showCopied = false
                            }
                        } label: {
                            Text(showCopied ? Strings.copied : Strings.copyCommand)
                                .font(.system(size: 11))
                        }
                    } else {
                        Button {
                            if let url = URL(string: "https://github.com/jyami-kim/claude-runner/releases/latest") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Text(Strings.download)
                                .font(.system(size: 11))
                        }
                    }
                }
                .padding(8)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(6)
            } else if !updateChecker.isChecking, updateChecker.latestVersion != nil {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    Text(Strings.upToDate)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Divider()
                .padding(.top, 4)

            Button(role: .destructive) {
                showUninstallConfirm = true
            } label: {
                Text(Strings.uninstall)
                    .font(.system(size: 12))
            }
            .alert(Strings.uninstallConfirmTitle, isPresented: $showUninstallConfirm) {
                Button(Strings.cancel, role: .cancel) {}
                Button(Strings.uninstall, role: .destructive) {
                    performUninstall()
                }
            } message: {
                Text(Strings.uninstallConfirmMessage)
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
