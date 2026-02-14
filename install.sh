#!/bin/bash
set -euo pipefail

APP_NAME="claude-runner"
APP_SUPPORT_DIR="$HOME/Library/Application Support/$APP_NAME"
APP_DIR="/Applications/$APP_NAME.app"
SETTINGS_FILE="$HOME/.claude/settings.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ─── Helpers ─────────────────────────────────────────────────

print_usage() {
    echo "Usage: $0 [install|uninstall]"
    echo ""
    echo "  install    Build and install $APP_NAME (default)"
    echo "  uninstall  Remove $APP_NAME, hooks, and session data"
}

remove_hooks() {
    # Remove claude-runner hook entries from ~/.claude/settings.json
    if [ ! -f "$SETTINGS_FILE" ] || ! command -v jq &>/dev/null; then
        return
    fi

    cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak"

    local UPDATED
    UPDATED=$(cat "$SETTINGS_FILE")
    for hook in SessionStart UserPromptSubmit Stop SessionEnd Notification \
                PreToolUse PostToolUse PostToolUseFailure PermissionRequest; do
        UPDATED=$(echo "$UPDATED" | jq --arg h "$hook" '
            if .hooks[$h] then
                .hooks[$h] |= map(select(
                    .hooks // [] | all(.command | contains("claude-runner-hook.sh") | not)
                )) |
                if .hooks[$h] | length == 0 then del(.hooks[$h]) else . end
            else . end
        ')
    done

    UPDATED=$(echo "$UPDATED" | jq 'if .hooks | length == 0 then del(.hooks) else . end')

    echo "$UPDATED" | jq --sort-keys . > "$SETTINGS_FILE"
    echo "  Hooks removed from $SETTINGS_FILE"
}

# ─── Install ─────────────────────────────────────────────────

do_install() {
    echo "=== Installing $APP_NAME ==="
    echo ""

    # 1. Build
    echo "[1/3] Building release binary..."
    cd "$SCRIPT_DIR"
    swift build -c release 2>&1 | tail -1

    BINARY_PATH="$SCRIPT_DIR/.build/release/$APP_NAME"
    if [ ! -f "$BINARY_PATH" ]; then
        echo "ERROR: Build failed - binary not found"
        exit 1
    fi

    # 2. Create .app bundle
    echo "[2/3] Creating app bundle..."
    rm -rf "$APP_DIR"
    mkdir -p "$APP_DIR/Contents/MacOS"
    mkdir -p "$APP_DIR/Contents/Resources"

    cp "$BINARY_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
    cp "$SCRIPT_DIR/Resources/Info.plist" "$APP_DIR/Contents/"

    # PkgInfo
    echo -n "APPL????" > "$APP_DIR/Contents/PkgInfo"

    # Copy app icon if exists
    if [ -f "$SCRIPT_DIR/Resources/AppIcon.icns" ]; then
        cp "$SCRIPT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/"
    fi

    # Copy hook script into .app bundle (app copies it to Application Support on launch)
    cp "$SCRIPT_DIR/Scripts/claude-runner-hook.sh" "$APP_DIR/Contents/Resources/"

    # 3. Code sign
    echo "[3/3] Code signing..."
    codesign --force --sign - "$APP_DIR" 2>/dev/null && echo "  Signed (ad-hoc)" || echo "  (code signing skipped)"

    echo ""
    echo "=== Installation Complete ==="
    echo ""
    echo "  App:  $APP_DIR"
    echo ""
    echo "  The app automatically installs hooks and registers them"
    echo "  in ~/.claude/settings.json on first launch."
    echo ""
    echo "Start now:"
    echo "  open /Applications/$APP_NAME.app"
    echo ""
    echo "Start at login:"
    echo "  System Settings → General → Login Items → add $APP_NAME"
}

# ─── Uninstall ───────────────────────────────────────────────

do_uninstall() {
    echo "=== Uninstalling $APP_NAME ==="
    echo ""

    # Quit running app
    pkill -f "$APP_NAME.app" 2>/dev/null || true

    # Remove hooks from settings.json
    echo "  Removing hooks from settings.json..."
    remove_hooks

    # Remove app
    if [ -d "$APP_DIR" ]; then
        rm -rf "$APP_DIR"
        echo "  Removed $APP_DIR"
    fi

    # Remove hook script and sessions
    if [ -d "$APP_SUPPORT_DIR" ]; then
        rm -rf "$APP_SUPPORT_DIR"
        echo "  Removed $APP_SUPPORT_DIR"
    fi

    echo ""
    echo "=== Uninstall Complete ==="
}

# ─── Main ────────────────────────────────────────────────────

case "${1:-install}" in
    install)
        do_install
        ;;
    uninstall)
        do_uninstall
        ;;
    -h|--help)
        print_usage
        ;;
    *)
        echo "Unknown command: $1"
        print_usage
        exit 1
        ;;
esac
