# claude-runner

macOS menu bar app that monitors active Claude Code sessions via hook scripts. Displays a traffic-light style status icon and a popover listing all sessions with their state, app icon, and elapsed time. Clicking a session row focuses the corresponding terminal/IDE window.

## Tech Stack

- **Language:** Swift 5.9
- **UI:** SwiftUI (panel popover) + AppKit (menu bar, NSImage rendering)
- **Build:** Swift Package Manager (`Package.swift`)
- **Platform:** macOS 13+

## Project Structure

```
claude-runner/
├── Entry/                          # Executable target entry point
├── Sources/                        # ClaudeRunnerLib target
│   ├── App/
│   │   ├── ClaudeRunnerApp.swift   # App bootstrap
│   │   └── AppDelegate.swift       # NSStatusItem, PopoverPanel (NSPanel), watcher setup
│   ├── Models/
│   │   ├── SessionState.swift      # SessionState enum, SessionEntry, StateCounts, StateStore
│   │   └── AppSettings.swift       # @AppStorage settings, IconStyle, SessionDisplayFormat enums
│   ├── Views/
│   │   ├── SessionListView.swift   # Panel content: session list + session row (app icon, click-to-focus)
│   │   ├── SettingsView.swift      # Settings window UI (5 sections)
│   │   └── StatusIcon.swift        # Menu bar icon updater
│   ├── Services/
│   │   ├── HookInstaller.swift     # Installs hook script to Application Support
│   │   ├── HookRegistrar.swift     # Registers hooks in ~/.claude/settings.json (no jq needed)
│   │   ├── SessionDirectoryWatcher.swift  # kqueue-based directory watcher
│   │   ├── LoginItemManager.swift  # SMAppService wrapper for launch-at-login
│   │   ├── NotificationService.swift  # UNUserNotificationCenter wrapper + click-to-focus
│   │   └── TerminalFocuser.swift   # Focuses terminal/IDE window (AppleScript, JetBrains CLI)
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
│   ├── HookStateTransitionTests.swift
│   ├── DesignTokensTests.swift
│   ├── TrafficLightTests.swift
│   ├── AppSettingsTests.swift
│   ├── LoginItemManagerTests.swift
│   ├── NotificationServiceTests.swift
│   ├── HookRegistrarTests.swift
│   └── AppInfoTests.swift
└── Package.swift
```

## Architecture

1. **Hook script** (`claude-runner-hook.sh`) receives Claude Code hook events via stdin JSON, writes per-session `.json` files to `~/Library/Application Support/claude-runner/sessions/`. Captures `terminal_bundle_id` and `tty` from the parent process chain.
2. **HookInstaller** copies the hook script from the .app bundle (`Contents/Resources/`) to `~/Library/Application Support/claude-runner/hooks/` on every launch.
3. **HookRegistrar** idempotently registers hooks in `~/.claude/settings.json` using `JSONSerialization` (no jq dependency). Adds 8 hook events + 3 notification matchers.
4. **SessionDirectoryWatcher** monitors the sessions directory via kqueue (DispatchSource) and triggers `StateStore.reload()`.
5. **StateStore** reads JSON files, prunes stale sessions, and publishes `sessions` + `counts`.
6. **StatusIcon** renders the menu bar icon using `NSImage.icon(style:counts:)`.
7. **PopoverPanel** (NSPanel subclass) displays the session list. Uses `.regularMaterial` background with rounded corners.
8. **SessionListView** shows session rows with state dot, app icon, project path, app name, and elapsed time. Clicking a row focuses the terminal/IDE window via `TerminalFocuser`.
9. **TerminalFocuser** focuses the correct window:
   - **iTerm2 / Terminal.app**: NSAppleScript with TTY matching (works in full-screen Spaces)
   - **JetBrains IDEs**: Toolbox CLI launcher (`idea`, `pycharm`, etc.) with project path
   - **Other apps**: `NSRunningApplication.activate()` fallback
10. **NotificationService** sends alerts for permission/waiting state changes. Clicking a notification focuses the session's terminal app.
11. **SettingsView** provides a settings window with General, Status Guide, Menu Bar Icon, Session Display, and Advanced sections.

## Build & Test

```bash
swift build
swift test
```

## Install

```bash
./install.sh          # Build, create .app bundle
open /Applications/claude-runner.app  # Auto-installs hooks on first launch
```

The app automatically installs the hook script and registers hooks in `~/.claude/settings.json` on every launch (idempotent). No `jq` dependency required for installation.

## Development Guidelines

- **Tests required:** Every feature or behavior change must have corresponding tests in `Tests/`.
- **Update this file:** When adding files, changing architecture, or modifying the project structure, update this CLAUDE.md.
- **Doc comments:** New public APIs should have `///` documentation comments.
- **Settings:** App settings are managed via `AppSettings` with `@AppStorage`. Icon style and display format are enum-based.
- **Icon styles:** 4 styles available: Traffic Light, Pie Chart, Domino, Text Counter. All render at `DesignTokens.iconWidth x iconHeight`.
- **Session display formats:** fullPath (`~/path/to/project`), directoryOnly (`project`), lastTwoDirs (`to/project`).
- **Stale threshold:** Configurable via `AppSettings.staleTimeoutMinutes` (minutes), used by `StateStore` to prune old sessions.
- **Notifications:** `notifyOnStateChange` setting controls whether state change notifications are shown. Clicking a notification focuses the session's terminal app.
- **Terminal focus:** AppleScript runs via `NSAppleScript` (in-process, not external `osascript`). Tab/window selection must happen before `activate` to work correctly in full-screen Spaces.
- **JetBrains focus:** Uses `~/Library/Application Support/JetBrains/Toolbox/scripts/` CLI launchers. Bundle ID → tool name mapping in `TerminalFocuser.jetBrainsTools`.
