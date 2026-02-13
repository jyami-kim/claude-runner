import SwiftUI

struct SessionListView: View {
    @ObservedObject var store: StateStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("claude-runner")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

            Divider()

            if store.sessions.isEmpty {
                Text("No active sessions")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(store.sessions) { session in
                            SessionRow(session: session)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }

            Divider()

            // Footer
            HStack {
                Button(action: openSettings) {
                    Label("Settings", systemImage: "gear")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Button(action: quitApp) {
                    HStack(spacing: 2) {
                        Text("\u{2318}")
                            .font(.system(size: 10))
                        Text("Quit")
                            .font(.system(size: 11))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .keyboardShortcut("q", modifiers: .command)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: DesignTokens.popoverWidth)
    }

    private func openSettings() {
        // Phase 2: settings panel
    }

    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: SessionEntry
    @ObservedObject private var settings = AppSettings.shared

    @State private var isHovered = false
    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        Button {
            TerminalFocuser.focus(session: session)
        } label: {
            HStack(spacing: DesignTokens.dotTextGap) {
                Circle()
                    .fill(DesignTokens.color(for: session.state))
                    .frame(width: DesignTokens.dotSize, height: DesignTokens.dotSize)

                Text(session.formattedPath(format: settings.sessionDisplayFormat))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.head)

                Spacer()

                Text(elapsedText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovered ? Color.primary.opacity(0.06) : Color.clear)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .accessibilityLabel("\(session.state.rawValue): \(session.projectName), \(elapsedText)")
    }

    private var elapsedText: String {
        let seconds = Int(currentTime.timeIntervalSince(session.referenceDate))
        if seconds < 60 { return "< 1m" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 { return "\(hours)h" }
        return "\(hours)h \(remainingMinutes)m"
    }
}
