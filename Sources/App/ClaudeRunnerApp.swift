import AppKit

// MARK: - Main Entry Point

@main
struct ClaudeRunnerApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
