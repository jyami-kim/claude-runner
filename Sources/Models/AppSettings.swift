import SwiftUI

// MARK: - Icon Style

/// Menu bar icon rendering style
enum IconStyle: String, CaseIterable {
    case trafficLight
    case pieChart
    case domino
    case textCounter
}

// MARK: - App Language

/// In-app language selection (independent of system language)
enum AppLanguage: String, CaseIterable {
    case english = "en"
    case korean = "ko"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .korean: return "한국어"
        }
    }
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
    @AppStorage("showTaskMessage") var showTaskMessage: Bool = true
    @AppStorage("staleTimeoutMinutes") var staleTimeoutMinutes: Int = 10
    @AppStorage("appLanguage") var appLanguage: AppLanguage = .english
}
