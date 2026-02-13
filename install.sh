#!/bin/bash
set -euo pipefail

APP_NAME="claude-runner"
APP_SUPPORT_DIR="$HOME/Library/Application Support/$APP_NAME"
APP_DIR="/Applications/$APP_NAME.app"
HOOKS_DIR="$APP_SUPPORT_DIR/hooks"
SESSIONS_DIR="$APP_SUPPORT_DIR/sessions"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Installing $APP_NAME ==="

# 1. Build release binary
echo "[1/5] Building release binary..."
cd "$SCRIPT_DIR"
swift build -c release 2>&1 | tail -1

BINARY_PATH="$SCRIPT_DIR/.build/release/$APP_NAME"
if [ ! -f "$BINARY_PATH" ]; then
    echo "ERROR: Build failed - binary not found at $BINARY_PATH"
    exit 1
fi

# 2. Create .app bundle
echo "[2/5] Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BINARY_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$SCRIPT_DIR/Resources/Info.plist" "$APP_DIR/Contents/"

# 3. Ad-hoc code sign
echo "[3/5] Code signing..."
codesign --force --sign - "$APP_DIR" 2>/dev/null || echo "  (code signing skipped)"

# 4. Install hook script
echo "[4/5] Installing hook script..."
mkdir -p "$HOOKS_DIR"
mkdir -p "$SESSIONS_DIR"
cp "$SCRIPT_DIR/Scripts/claude-runner-hook.sh" "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR/claude-runner-hook.sh"

# 5. Register hooks (done by the app on first launch)
echo "[5/5] Done!"
echo ""
echo "=== Installation Complete ==="
echo "  App:    $APP_DIR"
echo "  Hooks:  $HOOKS_DIR/claude-runner-hook.sh"
echo "  Data:   $SESSIONS_DIR/"
echo ""
echo "To start: open /Applications/$APP_NAME.app"
echo "The app will automatically register Claude Code hooks on first launch."
echo ""
echo "To start at login:"
echo "  System Settings → General → Login Items → add $APP_NAME"
