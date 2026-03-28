import Foundation

/// Scans running processes to discover orphaned Claude Code sessions
/// that no longer have corresponding session files.
enum SessionScanner {

    struct DiscoveredSession {
        let pid: Int
        let tty: String
        let cwd: String
        let terminalBundleId: String
    }

    /// Returns TTYs where a Claude process is actually running.
    static func findActiveClaudeTTYs() -> Set<String> {
        let claudePids = findClaudePids()
        var ttys = Set<String>()
        for pid in claudePids {
            guard let info = getProcessInfo(pid: pid) else { continue }
            let tty = resolveTmuxClientTTY(paneTTY: info.tty) ?? info.tty
            if !tty.isEmpty { ttys.insert(tty) }
        }
        return ttys
    }

    /// Scans for running Claude processes not represented in the existing session TTYs.
    ///
    /// - Parameter existingTTYs: TTYs of currently tracked sessions.
    /// - Returns: Discovered sessions that have no matching existing TTY.
    static func scanForOrphanedSessions(existingTTYs: Set<String>) -> [DiscoveredSession] {
        let claudePids = findClaudePids()
        guard !claudePids.isEmpty else { return [] }

        var results: [DiscoveredSession] = []

        for pid in claudePids {
            guard let info = getProcessInfo(pid: pid) else { continue }
            // Resolve tmux pane TTY → real terminal client TTY
            let tty = resolveTmuxClientTTY(paneTTY: info.tty) ?? info.tty
            guard !tty.isEmpty, !existingTTYs.contains(tty) else { continue }

            let cwd = getCwd(pid: pid)
            guard !cwd.isEmpty else { continue }

            let bundleId = detectBundleId(pid: pid)

            results.append(DiscoveredSession(
                pid: pid,
                tty: tty,
                cwd: cwd,
                terminalBundleId: bundleId
            ))
        }

        return results
    }

    // MARK: - Internal (visible for testing)

    struct ProcessInfo {
        let pid: Int
        let tty: String
    }

    /// Find PIDs of running `claude` processes.
    static func findClaudePids() -> [Int] {
        return parseClaudePids(from: runShell("pgrep -f 'claude'"))
    }

    /// Parse PID list from pgrep output.
    static func parseClaudePids(from output: String) -> [Int] {
        output.split(separator: "\n")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    /// Get TTY for a process.
    static func getProcessInfo(pid: Int) -> ProcessInfo? {
        let output = runShell("ps -p \(pid) -o tty= 2>/dev/null")
        let tty = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tty.isEmpty, !tty.contains("?") else { return nil }
        return ProcessInfo(pid: pid, tty: "/dev/\(tty)")
    }

    /// Get current working directory for a process via lsof.
    static func getCwd(pid: Int) -> String {
        let output = runShell("lsof -a -d cwd -Fn -p \(pid) 2>/dev/null")
        return parseCwdFromLsof(output)
    }

    /// Parse cwd from lsof output (lines starting with "n").
    static func parseCwdFromLsof(_ output: String) -> String {
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("n") && trimmed.count > 1 {
                let path = String(trimmed.dropFirst())
                // Skip non-path entries
                if path.hasPrefix("/") {
                    return path
                }
            }
        }
        return ""
    }

    /// Detect terminal bundle ID by walking the PPID chain.
    ///
    /// Tries `lsappinfo` first (fast), then falls back to resolving the executable
    /// path to an `.app` bundle and reading `CFBundleIdentifier` from its Info.plist.
    /// For tmux processes (PPID chain hits tmux-server daemon), falls back to
    /// `tmux list-clients` to find the real terminal app.
    static func detectBundleId(pid: Int) -> String {
        let bundle = detectBundleIdFromPidChain(pid)
        if !bundle.isEmpty { return bundle }

        // Tmux fallback: PPID chain ended at daemon. Try tmux client PIDs.
        for clientPid in tmuxClientPids() {
            let bundle = detectBundleIdFromPidChain(clientPid)
            if !bundle.isEmpty { return bundle }
        }

        return ""
    }

    /// Walk the PPID chain from a given PID to find a terminal app bundle ID.
    private static func detectBundleIdFromPidChain(_ startPid: Int) -> String {
        var currentPid = startPid
        while currentPid > 1 {
            let ppidOutput = runShell("ps -p \(currentPid) -o ppid= 2>/dev/null")
            guard let ppid = Int(ppidOutput.trimmingCharacters(in: .whitespacesAndNewlines)),
                  ppid > 1 else { break }
            currentPid = ppid

            // Try lsappinfo first
            let bundleOutput = runShell(
                "lsappinfo info -only bundleid -app \"pid=\(currentPid)\" 2>/dev/null"
            )
            let bundle = parseBundleId(from: bundleOutput)
            if !bundle.isEmpty {
                return bundle
            }

            // Fallback: resolve executable path → .app bundle → Info.plist
            let exe = runShell("ps -p \(currentPid) -o comm= 2>/dev/null")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if exe.contains(".app/") {
                let appPath = exe.components(separatedBy: ".app/").first.map { $0 + ".app" } ?? ""
                let plist = appPath + "/Contents/Info.plist"
                let bid = runShell(
                    "/usr/libexec/PlistBuddy -c \"Print :CFBundleIdentifier\" \"\(plist)\" 2>/dev/null"
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                if !bid.isEmpty {
                    return bid
                }
            }
        }
        return ""
    }

    /// Get tmux client PIDs (empty if tmux is not running).
    static func tmuxClientPids() -> [Int] {
        let output = runShell("tmux list-clients -F '#{client_pid}' 2>/dev/null")
        return output.split(separator: "\n")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    /// Resolve a tmux pane TTY to the real terminal client TTY.
    ///
    /// Maps pane TTY → tmux session → client TTY via `tmux list-panes` and `list-clients`.
    /// Returns `nil` if not a tmux pane or resolution fails.
    static func resolveTmuxClientTTY(paneTTY: String) -> String? {
        // pane TTY → session name
        let panesOutput = runShell(
            "tmux list-panes -a -F '#{pane_tty} #{session_name}' 2>/dev/null"
        )
        var sessionName: String?
        for line in panesOutput.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1)
            if parts.count == 2, String(parts[0]) == paneTTY {
                sessionName = String(parts[1])
                break
            }
        }
        guard let session = sessionName else { return nil }

        // session name → client TTY
        let clientsOutput = runShell(
            "tmux list-clients -F '#{client_tty} #{client_session}' 2>/dev/null"
        )
        for line in clientsOutput.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1)
            if parts.count == 2, String(parts[1]) == session {
                return String(parts[0])
            }
        }
        return nil
    }

    /// Parse bundle ID from lsappinfo output.
    static func parseBundleId(from output: String) -> String {
        // lsappinfo output format: "bundleid" = "com.example.App"
        guard let start = output.range(of: "\"", options: .backwards) else { return "" }
        let beforeLast = output[..<start.lowerBound]
        guard let secondStart = beforeLast.range(of: "\"", options: .backwards) else { return "" }
        let bundleId = String(output[secondStart.upperBound..<start.lowerBound])
        return bundleId.isEmpty ? "" : bundleId
    }

    /// Run a shell command and return stdout.
    private static func runShell(_ command: String) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}
