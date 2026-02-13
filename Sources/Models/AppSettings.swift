import SwiftUI

// MARK: - Icon Style

/// Menu bar icon rendering style
enum IconStyle: String, CaseIterable {
    case trafficLight
    case pieChart
    case domino
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
    @AppStorage("notifyOnStateChange") var notifyOnStateChange = true
    @AppStorage("iconStyle") var iconStyle: IconStyle = .trafficLight
    @AppStorage("sessionDisplayFormat") var sessionDisplayFormat: SessionDisplayFormat = .fullPath
    @AppStorage("staleTimeoutMinutes") var staleTimeoutMinutes: Int = 10
}
