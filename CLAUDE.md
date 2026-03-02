# claude-runner

macOS menu bar app that monitors active Claude Code sessions via hook scripts. Displays a traffic-light style status icon and a popover listing all sessions with their state, app icon, elapsed time, and activity text. Clicking a session row focuses the corresponding terminal/IDE window.

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
│   │   ├── AppSettings.swift       # @AppStorage settings, IconStyle, SessionDisplayFormat, AppLanguage enums
│   │   └── Strings.swift           # Centralized UI strings (Korean + English)
│   ├── Views/
│   │   ├── SessionListView.swift   # Panel content: session list + session row + Revive button
│   │   ├── SettingsView.swift      # Settings window UI (5 sections)
│   │   └── StatusIcon.swift        # Menu bar icon updater
│   ├── Services/
│   │   ├── HookInstaller.swift     # Installs hook script to Application Support
│   │   ├── HookRegistrar.swift     # Registers hooks in ~/.claude/settings.json (no jq needed)
│   │   ├── SessionDirectoryWatcher.swift  # kqueue-based directory watcher
│   │   ├── SessionScanner.swift    # Scans running processes for orphaned Claude sessions
│   │   ├── LoginItemManager.swift  # SMAppService wrapper for launch-at-login
│   │   ├── NotificationService.swift  # UNUserNotificationCenter wrapper + click-to-focus
│   │   ├── TerminalFocuser.swift   # Protocol + dispatcher + shared helpers
│   │   └── Focusers/
│   │       ├── ITermFocuser.swift         # iTerm2 AppleScript TTY matching
│   │       ├── TerminalAppFocuser.swift   # Terminal.app AppleScript TTY matching
│   │       ├── JetBrainsFocuser.swift     # Toolbox CLI + worktree resolution
│   │       └── DefaultFocuser.swift       # NSRunningApplication fallback
│   └── Extensions/
│       ├── BundleIdentifier+AppInfo.swift  # Bundle ID → app name/icon resolver
│       ├── DesignTokens.swift      # Colors, dimensions, spacing constants
│       └── NSImage+TrafficLight.swift  # Menu bar icon renderers (4 styles)
├── Scripts/
│   └── claude-runner-hook.sh       # Claude Code hook → writes session JSON (tmux-aware)
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
│   ├── AppInfoTests.swift
│   ├── WorktreeResolutionTests.swift
│   └── SessionScannerTests.swift
└── Package.swift
```

## Architecture

1. **Hook script** (`claude-runner-hook.sh`) receives Claude Code hook events via stdin JSON, writes per-session `.json` files to `~/Library/Application Support/claude-runner/sessions/`. Captures `terminal_bundle_id` and `tty` from the parent process chain. Supports tmux environments via `#{client_pid}` and `#{client_tty}` fallbacks. Captures `last_message` (from Stop events) and `current_activity` (from tool use events).
2. **HookInstaller** copies the hook script from the .app bundle (`Contents/Resources/`) to `~/Library/Application Support/claude-runner/hooks/` on every launch.
3. **HookRegistrar** idempotently registers hooks in `~/.claude/settings.json` using `JSONSerialization` (no jq dependency). Adds 8 hook events + 3 notification matchers.
4. **SessionDirectoryWatcher** monitors the sessions directory via kqueue (DispatchSource) and triggers `StateStore.reload()`.
5. **StateStore** reads JSON files, prunes stale sessions, publishes `sessions` + `counts`, and supports `reviveSessions()` for orphaned process recovery.
6. **StatusIcon** renders the menu bar icon using `NSImage.icon(style:counts:)`.
7. **PopoverPanel** (NSPanel subclass) displays the session list. Uses `.regularMaterial` background with rounded corners.
8. **SessionListView** shows session rows with state dot, app icon, project path, app name, activity text, and elapsed time. Clicking a row focuses the terminal/IDE window via `TerminalFocuser`. Footer includes Settings, Revive, and Quit buttons.
9. **TerminalFocuser** uses a protocol-based strategy pattern (`TerminalFocusStrategy`) to dispatch focus requests:
   - **ITermFocuser**: iTerm2 AppleScript TTY matching
   - **TerminalAppFocuser**: Terminal.app AppleScript TTY matching
   - **JetBrainsFocuser**: Toolbox CLI launcher with git worktree resolution
   - **DefaultFocuser**: `NSRunningApplication.activate()` fallback (Ghostty, Warp, etc.)
10. **NotificationService** sends alerts for permission/waiting state changes with activity context. Clicking a notification focuses the session's terminal app.
11. **SettingsView** provides a settings window with General (launch at login, notifications, language selector), Status Guide, Menu Bar Icon, Session Display, and Advanced sections.
12. **SessionScanner** scans running `claude` processes via `pgrep`/`ps`/`lsof` to discover orphaned sessions not tracked by session files. Used by `StateStore.reviveSessions()`.

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
- **Notifications:** `notifyOnStateChange` setting controls whether state change notifications are shown. Notifications fire when permission or waiting count increases (not just 0→1). Notifications include activity context. Clicking a notification focuses the session's terminal app.
- **Task messages:** `showTaskMessage` setting controls whether activity text (current tool, last message) is shown in session rows. Enabled by default.
- **Terminal focus:** Uses `TerminalFocusStrategy` protocol. Each terminal type has its own focuser struct in `Sources/Services/Focusers/`. To add a new terminal, create a new struct conforming to the protocol and register it in `TerminalFocuser.strategies`.
- **JetBrains focus:** Uses `~/Library/Application Support/JetBrains/Toolbox/scripts/` CLI launchers. Bundle ID → tool name mapping in `JetBrainsFocuser.jetBrainsTools`. Supports git worktree resolution via `.git` file parsing.
- **tmux support:** Hook script detects tmux via `$TMUX` env var and falls back to `tmux display-message` for client PID/TTY.
- **Session revive:** `SessionScanner` discovers orphaned Claude processes and creates synthetic session files (prefixed `revived-`). These are naturally replaced when real hook events arrive. Scanner detects bundle IDs via PPID chain with Info.plist fallback, and resolves tmux pane TTYs to real terminal client TTYs.
- **Hook TTY cleanup:** Every hook event (not just SessionStart) cleans up other session files sharing the same TTY. This ensures revived sessions are replaced when real hook events arrive.
- **Localization:** All UI strings are managed via the `Strings` enum (`Sources/Models/Strings.swift`). Supports Korean and English, selectable in Settings → General → Language. Uses `AppLanguage` enum stored in `@AppStorage("appLanguage")`. To add a new string: add a computed property to `Strings` with both language variants. No `.lproj` files — intentionally app-level control independent of system language.
