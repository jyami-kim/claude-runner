#!/bin/bash
set -euo pipefail

APP_NAME="claude-runner"
APP_SUPPORT_DIR="$HOME/Library/Application Support/$APP_NAME"
APP_DIR="/Applications/$APP_NAME.app"
HOOKS_DIR="$APP_SUPPORT_DIR/hooks"
SESSIONS_DIR="$APP_SUPPORT_DIR/sessions"
SETTINGS_FILE="$HOME/.claude/settings.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_CMD="\"$HOME/Library/Application Support/$APP_NAME/hooks/claude-runner-hook.sh\""

# ─── Helpers ─────────────────────────────────────────────────

print_usage() {
    echo "Usage: $0 [install|uninstall]"
    echo ""
    echo "  install    Build and install $APP_NAME (default)"
    echo "  uninstall  Remove $APP_NAME, hooks, and session data"
}

merge_hooks() {
    # Merge claude-runner hooks into ~/.claude/settings.json
    # Preserves all existing settings, only adds hooks if missing
    if ! command -v jq &>/dev/null; then
        echo "  WARNING: jq not found, skipping settings.json hook registration"
        echo "  Install jq: brew install jq"
        echo "  Then manually add hooks to $SETTINGS_FILE"
        return
    fi

    mkdir -p "$(dirname "$SETTINGS_FILE")"

    if [ ! -f "$SETTINGS_FILE" ]; then
        echo '{}' > "$SETTINGS_FILE"
    fi

    # Backup
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak"

    local HOOK_ENTRY
    HOOK_ENTRY=$(jq -n --arg cmd "$HOOK_CMD" '[{"hooks":[{"type":"command","command":$cmd,"async":true}]}]')

    local NOTIF_ENTRY
    NOTIF_ENTRY=$(jq -n --arg cmd "$HOOK_CMD" '[
        {"matcher":"permission_prompt","hooks":[{"type":"command","command":$cmd,"async":true}]},
        {"matcher":"idle_prompt","hooks":[{"type":"command","command":$cmd,"async":true}]},
        {"matcher":"elicitation_dialog","hooks":[{"type":"command","command":$cmd,"async":true}]}
    ]')

    # Only add hooks that don't already exist
    local UPDATED
    UPDATED=$(cat "$SETTINGS_FILE")

    for hook in SessionStart UserPromptSubmit Stop SessionEnd \
                PreToolUse PostToolUse PostToolUseFailure PermissionRequest; do
        HAS_HOOK=$(echo "$UPDATED" | jq --arg h "$hook" '.hooks[$h] // empty | length')
        if [ "$HAS_HOOK" = "" ] || [ "$HAS_HOOK" = "0" ]; then
            UPDATED=$(echo "$UPDATED" | jq --arg h "$hook" --argjson entry "$HOOK_ENTRY" '.hooks[$h] = $entry')
        fi
    done

    HAS_NOTIF=$(echo "$UPDATED" | jq '.hooks.Notification // empty | length')
    if [ "$HAS_NOTIF" = "" ] || [ "$HAS_NOTIF" = "0" ]; then
        UPDATED=$(echo "$UPDATED" | jq --argjson entry "$NOTIF_ENTRY" '.hooks.Notification = $entry')
    fi

    echo "$UPDATED" | jq --sort-keys . > "$SETTINGS_FILE"
    echo "  Hooks registered in $SETTINGS_FILE"
    echo "  Backup saved to $SETTINGS_FILE.bak"
}

remove_hooks() {
    if [ ! -f "$SETTINGS_FILE" ] || ! command -v jq &>/dev/null; then
        return
    fi

    cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak"

    # Remove hook entries whose command contains "claude-runner-hook.sh"
    # This matches regardless of $HOME expansion or quoting differences
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

    # Clean up empty hooks object
    UPDATED=$(echo "$UPDATED" | jq 'if .hooks | length == 0 then del(.hooks) else . end')

    echo "$UPDATED" | jq --sort-keys . > "$SETTINGS_FILE"
    echo "  Hooks removed from $SETTINGS_FILE"
}

# ─── Install ─────────────────────────────────────────────────

do_install() {
    echo "=== Installing $APP_NAME ==="
    echo ""

    # 1. Build
    echo "[1/5] Building release binary..."
    cd "$SCRIPT_DIR"
    swift build -c release 2>&1 | tail -1

    BINARY_PATH="$SCRIPT_DIR/.build/release/$APP_NAME"
    if [ ! -f "$BINARY_PATH" ]; then
        echo "ERROR: Build failed - binary not found"
        exit 1
    fi

    # 2. Create .app bundle
    echo "[2/5] Creating app bundle..."
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

    # 3. Code sign
    echo "[3/5] Code signing..."
    codesign --force --sign - "$APP_DIR" 2>/dev/null && echo "  Signed (ad-hoc)" || echo "  (code signing skipped)"

    # 4. Install hook script
    echo "[4/5] Installing hook script..."
    mkdir -p "$HOOKS_DIR"
    mkdir -p "$SESSIONS_DIR"
    cp "$SCRIPT_DIR/Scripts/claude-runner-hook.sh" "$HOOKS_DIR/"
    chmod +x "$HOOKS_DIR/claude-runner-hook.sh"

    # 5. Register hooks in settings.json
    echo "[5/5] Registering hooks..."
    merge_hooks

    echo ""
    echo "=== Installation Complete ==="
    echo ""
    echo "  App:     $APP_DIR"
    echo "  Hooks:   $HOOKS_DIR/claude-runner-hook.sh"
    echo "  Data:    $SESSIONS_DIR/"
    echo "  Config:  $SETTINGS_FILE"
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

    # Remove app
    if [ -d "$APP_DIR" ]; then
        rm -rf "$APP_DIR"
        echo "  Removed $APP_DIR"
    fi

    # Remove hooks from settings.json
    echo "  Removing hooks from settings.json..."
    remove_hooks

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
