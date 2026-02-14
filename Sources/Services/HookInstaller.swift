import Foundation

/// Installs the hook script to Application Support and creates necessary directories.
/// Does NOT modify ~/.claude/settings.json (hooks are already configured by the user).
enum HookInstaller {

    private static let appSupportDir: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("claude-runner", isDirectory: true)
    }()

    private static let hooksDir: URL = appSupportDir.appendingPathComponent("hooks", isDirectory: true)
    private static let sessionsDir: URL = appSupportDir.appendingPathComponent("sessions", isDirectory: true)
    private static let scriptName = "claude-runner-hook.sh"

    /// Copies the hook script and creates required directories.
    @discardableResult
    static func install() -> Bool {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: hooksDir, withIntermediateDirectories: true)
            try fm.createDirectory(at: sessionsDir, withIntermediateDirectories: true)

            // Find hook script source relative to executable or project root
            let scriptSource = findScriptSource()
            let dest = hooksDir.appendingPathComponent(scriptName)

            if let src = scriptSource {
                if fm.fileExists(atPath: dest.path) {
                    try fm.removeItem(at: dest)
                }
                try fm.copyItem(at: src, to: dest)
            }

            // Ensure executable permission
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dest.path)

            return true
        } catch {
            return false
        }
    }

    private static func findScriptSource() -> URL? {
        let execDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        var candidates = [
            // Development: project root
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Scripts/\(scriptName)"),
            // Relative to binary
            execDir.appendingPathComponent("../../Scripts/\(scriptName)"),
            execDir.appendingPathComponent("../Resources/\(scriptName)"),
        ]
        // Inside .app bundle (distributed via Homebrew or GitHub Release)
        if let bundled = Bundle.main.url(forResource: "claude-runner-hook", withExtension: "sh") {
            candidates.append(bundled)
        }

        for candidate in candidates {
            let resolved = candidate.standardized
            if FileManager.default.fileExists(atPath: resolved.path) {
                return resolved
            }
        }
        return nil
    }
}
