import Foundation
import Combine

// MARK: - Session State Enum

enum SessionState: String, Codable, Comparable {
    case active
    case waiting
    case permission

    /// Priority for menu bar icon (higher = more urgent)
    var priority: Int {
        switch self {
        case .permission: return 3
        case .waiting: return 2
        case .active: return 1
        }
    }

    static func < (lhs: SessionState, rhs: SessionState) -> Bool {
        lhs.priority < rhs.priority
    }

}

// MARK: - Session Entry

struct SessionEntry: Codable, Identifiable {
    let sessionId: String
    let cwd: String
    var state: SessionState
    let updatedAt: Date
    let startedAt: Date?
    let terminalBundleId: String?
    let tty: String?
    let lastMessage: String?
    let currentActivity: String?

    var id: String { sessionId }

    /// Project name derived from cwd (last path component)
    var projectName: String {
        (cwd as NSString).lastPathComponent
    }

    /// Display path based on the given format setting.
    func formattedPath(format: SessionDisplayFormat) -> String {
        switch format {
        case .fullPath:
            let home = NSHomeDirectory()
            if cwd.hasPrefix(home) {
                return "~" + cwd.dropFirst(home.count)
            }
            return cwd
        case .directoryOnly:
            return (cwd as NSString).lastPathComponent
        case .lastTwoDirs:
            let components = cwd.split(separator: "/", omittingEmptySubsequences: true)
            if components.count >= 2 {
                return components.suffix(2).joined(separator: "/")
            }
            return (cwd as NSString).lastPathComponent
        }
    }

    /// Default display path using fullPath format
    var displayPath: String {
        formattedPath(format: .fullPath)
    }

    /// Reference date for elapsed time: startedAt if available, otherwise updatedAt
    var referenceDate: Date {
        startedAt ?? updatedAt
    }

    /// Formatted elapsed time string (e.g. "< 1m", "3m", "1h 23m")
    var elapsedText: String {
        let seconds = Int(Date().timeIntervalSince(referenceDate))
        if seconds < 60 { return "< 1m" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 { return "\(hours)h" }
        return "\(hours)h \(remainingMinutes)m"
    }

    /// Activity text for display in the session list and notifications.
    ///
    /// - active + tool → "Using {tool}"
    /// - waiting/permission + lastMessage → first line, truncated to 80 chars
    /// - no data → nil
    var activityText: String? {
        if state == .active, let activity = currentActivity, !activity.isEmpty {
            return Strings.using(activity)
        }
        if (state == .waiting || state == .permission),
           let message = lastMessage, !message.isEmpty {
            let firstLine = message.components(separatedBy: .newlines).first ?? message
            if firstLine.count > 80 {
                return String(firstLine.prefix(80)) + "…"
            }
            return firstLine
        }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case cwd
        case state
        case updatedAt = "updated_at"
        case startedAt = "started_at"
        case terminalBundleId = "terminal_bundle_id"
        case tty
        case lastMessage = "last_message"
        case currentActivity = "current_activity"
    }
}

// MARK: - State Counts

struct StateCounts: Equatable {
    var activeCount: Int = 0
    var waitingCount: Int = 0
    var permissionCount: Int = 0

    var totalCount: Int {
        activeCount + waitingCount + permissionCount
    }

    /// Highest priority state present, or nil if no sessions
    var dominantState: SessionState? {
        if permissionCount > 0 { return .permission }
        if waitingCount > 0 { return .waiting }
        if activeCount > 0 { return .active }
        return nil
    }
}

// MARK: - State Store

final class StateStore: ObservableObject {
    @Published var sessions: [SessionEntry] = []
    @Published var counts = StateCounts()

    static let shared = StateStore()

    private let sessionsDirectory: URL
    private let decoder: JSONDecoder
    private var _staleThresholdOverride: TimeInterval?
    var staleThreshold: TimeInterval {
        _staleThresholdOverride ?? TimeInterval(AppSettings.shared.staleTimeoutMinutes * 60)
    }
    private var stalenessTimer: Timer?

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        sessionsDirectory = appSupport.appendingPathComponent("claude-runner/sessions", isDirectory: true)

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)

        // Initial load
        reload()

        // Periodic timer to re-evaluate staleness (catches ESC interrupts with no hook event)
        startStalenessTimer()
    }

    /// Testable initializer with custom directory
    init(sessionsDirectory: URL, staleThreshold: TimeInterval = 600, autoReload: Bool = true) {
        self.sessionsDirectory = sessionsDirectory
        self._staleThresholdOverride = staleThreshold

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        try? FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)

        if autoReload { reload() }
    }

    func reload() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: sessionsDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            DispatchQueue.main.async {
                self.sessions = []
                self.counts = StateCounts()
            }
            return
        }

        var loaded: [SessionEntry] = []
        let now = Date()

        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let entry = try? decoder.decode(SessionEntry.self, from: data) else {
                continue
            }

            // Prune stale sessions (only waiting sessions; active/permission are preserved)
            if entry.state == .waiting &&
               now.timeIntervalSince(entry.updatedAt) > staleThreshold {
                try? fm.removeItem(at: file)
                continue
            }

            loaded.append(entry)
        }

        // Sort by priority (highest first), then by updated time (most recent first)
        loaded.sort { a, b in
            if a.state != b.state { return a.state > b.state }
            return a.updatedAt > b.updatedAt
        }

        var newCounts = StateCounts()
        for entry in loaded {
            switch entry.state {
            case .active: newCounts.activeCount += 1
            case .waiting: newCounts.waitingCount += 1
            case .permission: newCounts.permissionCount += 1
            }
        }

        DispatchQueue.main.async {
            self.sessions = loaded
            self.counts = newCounts
        }
    }

    /// Scan for orphaned Claude processes and create synthetic session files.
    /// Also cleans up dead sessions (active/permission state but no running process).
    func reviveSessions() {
        let existingSessions = sessions
        let existingTTYs = Set(existingSessions.compactMap { $0.tty })
        let dir = sessionsDirectory

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let activeTTYs = SessionScanner.findActiveClaudeTTYs()

            // Clean up dead sessions: active/permission state but no running claude process
            let fm = FileManager.default
            for session in existingSessions where session.state != .waiting {
                guard let tty = session.tty, !tty.isEmpty else { continue }
                if !activeTTYs.contains(tty) {
                    let file = dir.appendingPathComponent("\(session.sessionId).json")
                    try? fm.removeItem(at: file)
                }
            }

            // Discover orphaned processes not tracked by session files
            let orphaned = SessionScanner.scanForOrphanedSessions(existingTTYs: existingTTYs)

            let formatter = ISO8601DateFormatter()
            let now = formatter.string(from: Date())

            for session in orphaned {
                let sessionId = "revived-\(session.tty.replacingOccurrences(of: "/", with: "-"))"
                let dict: [String: Any] = [
                    "session_id": sessionId,
                    "cwd": session.cwd,
                    "state": "waiting",
                    "updated_at": now,
                    "started_at": now,
                    "terminal_bundle_id": session.terminalBundleId,
                    "tty": session.tty,
                    "last_message": "",
                    "current_activity": "",
                ]

                guard let data = try? JSONSerialization.data(withJSONObject: dict) else { continue }
                let file = dir.appendingPathComponent("\(sessionId).json")
                try? data.write(to: file, options: .atomic)
            }

            DispatchQueue.main.async {
                self?.reload()
            }
        }
    }

    private func startStalenessTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.stalenessTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                self?.reload()
            }
        }
    }
}
