#!/bin/bash
set -euo pipefail

# claude-runner hook script
# Receives JSON from Claude Code hooks via stdin
# Writes per-session state files to sessions/ directory

SESSIONS_DIR="$HOME/Library/Application Support/claude-runner/sessions"
mkdir -p "$SESSIONS_DIR"

# Debug logging (temporary - remove after diagnosis)
DEBUG_LOG="$HOME/Library/Application Support/claude-runner/debug.log"
log_debug() {
    echo "$(date '+%H:%M:%S') EVENT=$HOOK_EVENT SID=${SESSION_ID:-?} STATE=${STATE:-?}" >> "$DEBUG_LOG"
}

# Read JSON from stdin
INPUT=$(cat)

# Parse fields using jq
HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
# Detect parent terminal/IDE bundle ID by walking the PPID chain
detect_bundle_id() {
    local pid=$$
    while [ "$pid" -gt 1 ] 2>/dev/null; do
        pid=$(ps -p "$pid" -o ppid= 2>/dev/null | tr -d ' ')
        [ -z "$pid" ] || [ "$pid" -le 1 ] 2>/dev/null && break

        # Try lsappinfo first (fast, no disk I/O)
        local bundle
        bundle=$(lsappinfo info -only bundleid -app "pid=$pid" 2>/dev/null | grep -o '"[^"]*"' | tr -d '"')
        if [ -n "$bundle" ]; then
            echo "$bundle"
            return
        fi

        # Fallback: resolve executable → .app bundle → read Info.plist
        local exe
        exe=$(ps -p "$pid" -o comm= 2>/dev/null | tr -d ' ')
        if [ -n "$exe" ] && [[ "$exe" == *".app/"* ]]; then
            local app_path="${exe%%\.app/*}.app"
            local plist="$app_path/Contents/Info.plist"
            if [ -f "$plist" ]; then
                local fb
                fb=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$plist" 2>/dev/null)
                if [ -n "$fb" ]; then
                    echo "$fb"
                    return
                fi
            fi
        fi
    done
    echo ""
}

TERMINAL_BUNDLE_ID=$(detect_bundle_id)

# Capture TTY for terminal tab matching (e.g., /dev/ttys016)
SESSION_TTY=$(ps -p $PPID -o tty= 2>/dev/null || echo "")
if [ -n "$SESSION_TTY" ] && [[ "$SESSION_TTY" != *"?"* ]]; then
    SESSION_TTY="/dev/$SESSION_TTY"
else
    SESSION_TTY=""
fi

# Exit if no session ID
if [ -z "$SESSION_ID" ]; then
    exit 0
fi

SESSION_FILE="$SESSIONS_DIR/${SESSION_ID}.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Determine started_at: capture on SessionStart, preserve from existing file otherwise
if [ "$HOOK_EVENT" = "SessionStart" ]; then
    STARTED_AT="$TIMESTAMP"
elif [ -f "$SESSION_FILE" ]; then
    STARTED_AT=$(jq -r '.started_at // empty' "$SESSION_FILE")
fi
STARTED_AT="${STARTED_AT:-$TIMESTAMP}"

# Determine state based on hook event
case "$HOOK_EVENT" in
    SessionStart)
        STATE="waiting"
        ;;
    UserPromptSubmit)
        STATE="active"
        ;;
    PreToolUse)
        # AskUserQuestion requires user response → treat as permission
        TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
        if [ "$TOOL_NAME" = "AskUserQuestion" ]; then
            STATE="permission"
        else
            STATE="active"
        fi
        ;;
    PermissionRequest)
        # Only set RED for tools that actually require user approval
        # Skip read-only tools that are typically auto-approved
        TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
        case "$TOOL_NAME" in
            Read|Glob|Grep|LSP|WebSearch|WebFetch|TaskList|TaskGet)
                exit 0
                ;;
            *)
                STATE="permission"
                ;;
        esac
        ;;
    PostToolUse)
        # Tool completed successfully → back to active (GREEN)
        STATE="active"
        ;;
    PostToolUseFailure)
        # is_interrupt: true means user pressed ESC during tool execution
        IS_INTERRUPT=$(echo "$INPUT" | jq -r '.is_interrupt // false')
        if [ "$IS_INTERRUPT" = "true" ]; then
            STATE="waiting"
        else
            STATE="active"
        fi
        ;;
    Stop)
        STATE="waiting"
        ;;
    Notification)
        # notification_type is a top-level field in the hook input
        NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type // empty')
        case "$NOTIFICATION_TYPE" in
            permission_prompt)
                STATE="permission"
                ;;
            idle_prompt)
                STATE="waiting"
                ;;
            elicitation_dialog)
                STATE="permission"
                ;;
            *)
                exit 0
                ;;
        esac
        ;;
    SessionEnd)
        rm -f "$SESSION_FILE"
        exit 0
        ;;
    *)
        exit 0
        ;;
esac

# Atomic write: temp file then mv
TEMP_FILE=$(mktemp "$SESSIONS_DIR/.tmp.XXXXXX")
jq -n \
    --arg sid "$SESSION_ID" \
    --arg cwd "$CWD" \
    --arg state "$STATE" \
    --arg ts "$TIMESTAMP" \
    --arg bid "$TERMINAL_BUNDLE_ID" \
    --arg tty "$SESSION_TTY" \
    --arg started "$STARTED_AT" \
    '{"session_id":$sid,"cwd":$cwd,"state":$state,"updated_at":$ts,"started_at":$started,"terminal_bundle_id":$bid,"tty":$tty}' > "$TEMP_FILE"
mv "$TEMP_FILE" "$SESSION_FILE"

# Debug: log state transition + verify file was written
FILE_STATE=$(jq -r '.state // "READ_FAIL"' "$SESSION_FILE" 2>/dev/null)
echo "$(date '+%H:%M:%S') EVENT=$HOOK_EVENT SID=${SESSION_ID:-?} STATE=$STATE FILE=$FILE_STATE" >> "$DEBUG_LOG"

exit 0
