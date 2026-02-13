import SwiftUI

struct SessionListView: View {
    @ObservedObject var store: StateStore
    @Environment(\.colorScheme) private var colorScheme

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
                        Text("⌘")
                            .font(.system(size: 10))
                        Text("Quit")
                            .font(.system(size: 11))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 260)
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

    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)

            Text(session.projectName)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text(elapsedText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }

    private var stateColor: Color {
        switch session.state {
        case .active: return Color(red: 0.3, green: 0.85, blue: 0.4)
        case .waiting: return Color(red: 1.0, green: 0.8, blue: 0.0)
        case .permission: return Color(red: 1.0, green: 0.27, blue: 0.23)
        }
    }

    private var elapsedText: String {
        let seconds = Int(currentTime.timeIntervalSince(session.updatedAt))
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        return "\(hours)h"
    }
}
