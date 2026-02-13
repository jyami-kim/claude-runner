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
    let state: SessionState
    let updatedAt: Date

    var id: String { sessionId }

    /// Project name derived from cwd (last path component)
    var projectName: String {
        (cwd as NSString).lastPathComponent
    }

    /// Time elapsed since last update
    var elapsed: TimeInterval {
        Date().timeIntervalSince(updatedAt)
    }

    /// Formatted elapsed time string
    var elapsedText: String {
        let seconds = Int(elapsed)
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        return "\(hours)h"
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case cwd
        case state
        case updatedAt = "updated_at"
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
    private let staleThreshold: TimeInterval = 600 // 10 minutes

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        sessionsDirectory = appSupport.appendingPathComponent("claude-runner/sessions", isDirectory: true)

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)

        // Initial load
        reload()
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

            // Prune stale sessions
            if now.timeIntervalSince(entry.updatedAt) > staleThreshold {
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
}
