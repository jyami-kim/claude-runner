import AppKit
import Foundation

/// Focuses a JetBrains IDE project window using the Toolbox CLI launcher.
struct JetBrainsFocuser: TerminalFocusStrategy {

    /// Bundle ID → Toolbox CLI tool name mapping.
    static let jetBrainsTools: [String: String] = [
        "com.jetbrains.intellij": "idea",
        "com.jetbrains.intellij.ce": "idea",
        "com.jetbrains.WebStorm": "webstorm",
        "com.jetbrains.pycharm": "pycharm",
        "com.jetbrains.pycharm.ce": "pycharm",
        "com.jetbrains.CLion": "clion",
        "com.jetbrains.goland": "goland",
        "com.jetbrains.rider": "rider",
        "com.jetbrains.rubymine": "rubymine",
        "com.jetbrains.PhpStorm": "phpstorm",
        "com.jetbrains.datagrip": "datagrip",
        "com.jetbrains.AppCode": "appcode",
        "com.google.android.studio": "studio",
    ]

    static let supportedBundleIds: Set<String> = Set(jetBrainsTools.keys)

    static func focus(session: SessionEntry) {
        let bundleId = session.terminalBundleId ?? ""
        guard let toolName = jetBrainsTools[bundleId] else {
            TerminalFocuser.activateApp(bundleID: bundleId)
            return
        }

        let toolboxScripts = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/JetBrains/Toolbox/scripts")
            .appendingPathComponent(toolName)

        guard FileManager.default.isExecutableFile(atPath: toolboxScripts.path) else {
            TerminalFocuser.activateApp(bundleID: bundleId)
            return
        }

        let projectPath = resolveWorktreeRoot(cwd: session.cwd)

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = toolboxScripts
            process.arguments = [projectPath]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
        }
    }

    // MARK: - Worktree Resolution

    /// Resolves a git worktree `cwd` to the original project root.
    ///
    /// Git worktrees have a `.git` **file** (not directory) containing a `gitdir:` pointer
    /// back to the main repository's `.git/worktrees/<name>` directory. This method reads
    /// that pointer and derives the original project root.
    ///
    /// Returns the original `cwd` if it's not a worktree or resolution fails.
    static func resolveWorktreeRoot(cwd: String) -> String {
        let gitPath = (cwd as NSString).appendingPathComponent(".git")
        let fm = FileManager.default

        // Check if .git is a file (worktree) rather than a directory
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: gitPath, isDirectory: &isDir), !isDir.boolValue else {
            return cwd
        }

        // Read the .git file content: "gitdir: /original/.git/worktrees/<name>"
        guard let content = try? String(contentsOfFile: gitPath, encoding: .utf8) else {
            return cwd
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("gitdir: ") else {
            return cwd
        }

        let gitdir = String(trimmed.dropFirst("gitdir: ".count))

        // Expected pattern: .../worktrees/<name>
        // Remove /worktrees/<name> suffix to get the main .git directory
        guard let range = gitdir.range(of: "/worktrees/", options: .backwards) else {
            return cwd
        }

        let mainGitDir = String(gitdir[gitdir.startIndex..<range.lowerBound])

        // The project root is the parent of the .git directory
        return (mainGitDir as NSString).deletingLastPathComponent
    }
}
