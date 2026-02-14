# claude-runner

macOS menu bar app that monitors active Claude Code sessions via hook scripts. Displays a traffic-light style status icon and a popover listing all sessions with their state and elapsed time.

## Tech Stack

- **Language:** Swift 5.9
- **UI:** SwiftUI (popover) + AppKit (menu bar, NSImage rendering)
- **Build:** Swift Package Manager (`Package.swift`)
- **Platform:** macOS 13+

## Project Structure

```
claude-runner/
├── Entry/                          # Executable target entry point
├── Sources/                        # ClaudeRunnerLib target
│   ├── App/
│   │   ├── ClaudeRunnerApp.swift   # App bootstrap
│   │   └── AppDelegate.swift       # NSStatusItem, popover, watcher setup
│   ├── Models/
│   │   ├── SessionState.swift      # SessionState enum, SessionEntry, StateCounts, StateStore
│   │   └── AppSettings.swift       # @AppStorage settings, IconStyle, SessionDisplayFormat enums
│   ├── Views/
│   │   ├── SessionListView.swift   # Popover content: session list + session row
│   │   ├── SettingsView.swift      # Settings window UI (5 sections)
│   │   └── StatusIcon.swift        # Menu bar icon updater
│   ├── Services/
│   │   ├── HookInstaller.swift     # Installs hook script to ~/.claude/
│   │   ├── SessionDirectoryWatcher.swift  # FSEvent-based directory watcher
│   │   ├── LoginItemManager.swift  # SMAppService wrapper for launch-at-login
│   │   ├── NotificationService.swift  # UNUserNotificationCenter wrapper for state alerts
│   │   └── TerminalFocuser.swift   # Focuses terminal tab for a session
│   └── Extensions/
│       ├── BundleIdentifier+AppInfo.swift  # Bundle ID → app name/icon resolver
│       ├── DesignTokens.swift      # Colors, dimensions, spacing constants
│       └── NSImage+TrafficLight.swift  # Menu bar icon renderers (4 styles)
├── Scripts/
│   └── claude-runner-hook.sh       # Claude Code hook → writes session JSON
├── Resources/
│   ├── AppIcon.icns / .svg
│   └── Info.plist
├── Tests/                          # ClaudeRunnerTests target
│   ├── SessionStateTests.swift
│   ├── StateStoreTests.swift
│   ├── DesignTokensTests.swift
│   ├── TrafficLightTests.swift
│   ├── AppSettingsTests.swift
│   ├── LoginItemManagerTests.swift
│   ├── NotificationServiceTests.swift
│   └── AppInfoTests.swift
└── Package.swift
```

## Architecture

1. **Hook script** (`claude-runner-hook.sh`) receives Claude Code hook events via stdin JSON, writes per-session `.json` files to `~/Library/Application Support/claude-runner/sessions/`.
2. **SessionDirectoryWatcher** monitors that directory via FSEvents and triggers `StateStore.reload()`.
3. **StateStore** reads JSON files, prunes stale sessions, and publishes `sessions` + `counts`.
4. **StatusIcon** renders the menu bar icon using `NSImage.icon(style:counts:)`.
5. **SessionListView** displays the popover with session rows showing state dot, path, and elapsed time.
6. **SettingsView** provides a settings window (NSWindow) with General, Status Guide, Menu Bar Icon, Session Display, and Advanced sections.

## Build & Test

```bash
swift build
swift test
```

## Development Guidelines

- **Tests required:** Every feature or behavior change must have corresponding tests in `Tests/`.
- **Update this file:** When adding files, changing architecture, or modifying the project structure, update this CLAUDE.md.
- **Doc comments:** New public APIs should have `///` documentation comments.
- **Settings:** App settings are managed via `AppSettings` with `@AppStorage`. Icon style and display format are enum-based.
- **Icon styles:** 4 styles available: Traffic Light, Pie Chart, Domino, Text Counter. All render at `DesignTokens.iconWidth x iconHeight`.
- **Session display formats:** fullPath (`~/path/to/project`), directoryOnly (`project`), lastTwoDirs (`to/project`).
- **Stale threshold:** Configurable via `AppSettings.staleTimeoutMinutes` (minutes), used by `StateStore` to prune old sessions.
- **Notifications:** `notifyOnStateChange` setting controls whether state change notifications are shown.
