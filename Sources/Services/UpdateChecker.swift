import Foundation

/// Checks for app updates via GitHub Releases API.
///
/// Fetches the latest release tag from the GitHub repository and compares it
/// against the current app version using semantic versioning.
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var latestVersion: String?
    @Published var isChecking = false

    private let repoOwner = "jyami-kim"
    private let repoName = "claude-runner"

    /// The current app version from the bundle, or "0.0.0" as fallback.
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// Whether a newer version is available on GitHub.
    var isUpdateAvailable: Bool {
        guard let latest = latestVersion else { return false }
        return Self.compareVersions(current: currentVersion, latest: latest) == .orderedAscending
    }

    /// Fetches the latest release from GitHub and updates published properties.
    func checkForUpdates() {
        guard !isChecking else { return }
        isChecking = true

        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: urlString) else {
            isChecking = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                defer { self?.isChecking = false }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    return
                }
                self?.latestVersion = Self.parseTagName(tagName)
            }
        }.resume()
    }

    /// Whether the app was installed via Homebrew Cask.
    ///
    /// Checks if the app bundle resides under a Homebrew Caskroom path.
    static var isHomebrewInstall: Bool {
        guard let bundlePath = Bundle.main.bundlePath as String? else { return false }
        return bundlePath.contains("/Homebrew/") || bundlePath.contains("/Caskroom/")
    }

    /// Strips a leading "v" from a tag name (e.g. "v0.2.0" → "0.2.0").
    static func parseTagName(_ tag: String) -> String {
        tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }

    /// Compares two semantic version strings component by component.
    ///
    /// Returns `.orderedAscending` if `current < latest`,
    /// `.orderedDescending` if `current > latest`,
    /// `.orderedSame` if equal.
    static func compareVersions(current: String, latest: String) -> ComparisonResult {
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        let latestParts = latest.split(separator: ".").compactMap { Int($0) }

        let maxCount = max(currentParts.count, latestParts.count)
        for i in 0..<maxCount {
            let c = i < currentParts.count ? currentParts[i] : 0
            let l = i < latestParts.count ? latestParts[i] : 0
            if c < l { return .orderedAscending }
            if c > l { return .orderedDescending }
        }
        return .orderedSame
    }
}
