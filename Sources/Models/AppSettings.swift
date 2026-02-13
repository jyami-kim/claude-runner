import SwiftUI

// MARK: - Icon Style

/// Menu bar icon rendering style
enum IconStyle: String, CaseIterable {
    case trafficLight
    case singleDot
    case compactBar
    case textCounter
}

// MARK: - Session Display Format

/// How session paths are displayed in the popover
enum SessionDisplayFormat: String, CaseIterable {
    case fullPath       // ~/jyami-private/claude-runner
    case directoryOnly  // claude-runner
    case lastTwoDirs    // jyami-private/claude-runner
}

// MARK: - App Settings

/// Centralized app settings backed by UserDefaults via @AppStorage.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("launchAtLogin") var launchAtLogin = false
    @AppStorage("iconStyle") var iconStyle: IconStyle = .trafficLight
    @AppStorage("sessionDisplayFormat") var sessionDisplayFormat: SessionDisplayFormat = .fullPath
    @AppStorage("staleTimeoutSeconds") var staleTimeoutSeconds: Int = 600 // seconds (session file deletion, user-configurable)
}
