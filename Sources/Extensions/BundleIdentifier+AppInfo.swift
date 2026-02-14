import AppKit

/// Resolves bundle identifiers to human-readable app names and icons.
enum AppInfo {
    private static var nameCache: [String: String] = [:]
    private static var iconCache: [String: NSImage] = [:]

    /// Known bundle ID → short display name fallbacks.
    private static let knownNames: [String: String] = [
        "com.apple.Terminal": "Terminal",
        "com.googlecode.iterm2": "iTerm2",
        "net.kovidgoyal.kitty": "Kitty",
        "com.github.wez.wezterm": "WezTerm",
        "dev.warp.Warp-Stable": "Warp",
        "com.microsoft.VSCode": "VS Code",
        "com.microsoft.VSCodeInsiders": "VS Code Insiders",
        "dev.zed.Zed": "Zed",
        "com.sublimetext.4": "Sublime Text",
        "com.jetbrains.intellij": "IntelliJ",
        "com.jetbrains.intellij.ce": "IntelliJ CE",
        "com.jetbrains.WebStorm": "WebStorm",
        "com.jetbrains.pycharm": "PyCharm",
        "com.jetbrains.pycharm.ce": "PyCharm CE",
        "com.jetbrains.CLion": "CLion",
        "com.jetbrains.goland": "GoLand",
        "com.jetbrains.rider": "Rider",
        "com.jetbrains.rubymine": "RubyMine",
        "com.jetbrains.PhpStorm": "PhpStorm",
        "com.jetbrains.datagrip": "DataGrip",
        "com.todesktop.230313mzl4w4u92": "Cursor",
    ]

    /// Returns a human-readable app name for the given bundle identifier.
    static func appName(for bundleId: String) -> String {
        if let cached = nameCache[bundleId] { return cached }

        let name: String
        if let known = knownNames[bundleId] {
            name = known
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
                  let bundle = Bundle(url: url),
                  let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
            name = bundleName
        } else {
            // Fallback: last component of bundle ID
            name = bundleId.components(separatedBy: ".").last ?? bundleId
        }

        nameCache[bundleId] = name
        return name
    }

    /// Returns the app icon (sized to 16x16) for the given bundle identifier.
    static func appIcon(for bundleId: String) -> NSImage? {
        if let cached = iconCache[bundleId] { return cached }

        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 16, height: 16)
        iconCache[bundleId] = icon
        return icon
    }
}
