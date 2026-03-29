#!/bin/bash
set -euo pipefail

# claude-runner hook script
# Receives JSON from Claude Code hooks via stdin
# Writes per-session state files to sessions/ directory

SESSIONS_DIR="$HOME/Library/Application Support/claude-runner/sessions"
mkdir -p "$SESSIONS_DIR"

# Read JSON from stdin (must read before PPID chain check, as async hooks may lose parent)
INPUT=$(cat)

# Parse fields using jq
HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

# For SessionEnd, skip caller validation — the claude process may already be gone
# when this async hook runs. Worst case: a stale session file gets deleted.
if [ "$HOOK_EVENT" != "SessionEnd" ]; then
    # Verify this hook is being called from Claude Code (not other tools like opencode)
    # Walk up the PPID chain looking for the 'claude' binary
    is_claude_code_caller() {
        local pid=$$
        for _ in 1 2 3 4 5; do
            pid=$(ps -p "$pid" -o ppid= 2>/dev/null | tr -d ' ')
            [ -z "$pid" ] || [ "$pid" -le 1 ] 2>/dev/null && return 1
            local cmd
            cmd=$(basename "$(ps -p "$pid" -o comm= 2>/dev/null)" 2>/dev/null)
            [ "$cmd" = "claude" ] && return 0
        done
        return 1
    }

    if ! is_claude_code_caller; then
        exit 0
    fi
fi
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Detect parent terminal/IDE bundle ID by walking the PPID chain from a given PID
detect_bundle_id_from_pid() {
    local pid="${1:-$$}"
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
        exe=$(ps -p "$pid" -o comm= 2>/dev/null | sed 's/^ *//;s/ *$//')
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

# Detect bundle ID: try direct PPID chain first, then tmux client fallback
TERMINAL_BUNDLE_ID=$(detect_bundle_id_from_pid $$)

# tmux fallback: if no bundle ID found and $TMUX is set, try tmux client PID
if [ -z "$TERMINAL_BUNDLE_ID" ] && [ -n "${TMUX:-}" ]; then
    TMUX_CLIENT_PID=$(tmux display-message -p '#{client_pid}' 2>/dev/null || echo "")
    if [ -n "$TMUX_CLIENT_PID" ]; then
        TERMINAL_BUNDLE_ID=$(detect_bundle_id_from_pid "$TMUX_CLIENT_PID")
    fi
fi

# Capture TTY for terminal tab matching (e.g., /dev/ttys016)
# In tmux, always prefer the client TTY (the real terminal tab's TTY)
if [ -n "${TMUX:-}" ]; then
    TMUX_CLIENT_TTY=$(tmux display-message -p '#{client_tty}' 2>/dev/null || echo "")
    if [ -n "$TMUX_CLIENT_TTY" ]; then
        SESSION_TTY="$TMUX_CLIENT_TTY"
    else
        SESSION_TTY=""
    fi
else
    SESSION_TTY=$(ps -p $PPID -o tty= 2>/dev/null | sed 's/^ *//;s/ *$//' || echo "")
    if [ -n "$SESSION_TTY" ] && [[ "$SESSION_TTY" != *"?"* ]]; then
        SESSION_TTY="/dev/$SESSION_TTY"
    else
        SESSION_TTY=""
    fi
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

# Preserve existing activity fields from the session file
EXISTING_LAST_MESSAGE=""
EXISTING_ACTIVITY=""
if [ -f "$SESSION_FILE" ]; then
    EXISTING_LAST_MESSAGE=$(jq -r '.last_message // empty' "$SESSION_FILE" 2>/dev/null)
    EXISTING_ACTIVITY=$(jq -r '.current_activity // empty' "$SESSION_FILE" 2>/dev/null)
fi

# Activity tracking variables (will be set based on hook event)
LAST_MESSAGE="${EXISTING_LAST_MESSAGE}"
CURRENT_ACTIVITY="${EXISTING_ACTIVITY}"

# Determine state based on hook event
case "$HOOK_EVENT" in
    SessionStart)
        STATE="waiting"
        LAST_MESSAGE=""
        CURRENT_ACTIVITY=""
        ;;
    UserPromptSubmit)
        STATE="active"
        CURRENT_ACTIVITY=""
        ;;
    PreToolUse)
        # AskUserQuestion requires user response → treat as permission
        TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
        if [ "$TOOL_NAME" = "AskUserQuestion" ]; then
            STATE="permission"
            CURRENT_ACTIVITY=""
        else
            STATE="active"
            CURRENT_ACTIVITY="$TOOL_NAME"
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
                CURRENT_ACTIVITY=""
                ;;
        esac
        ;;
    PostToolUse)
        # Tool completed successfully → back to active (GREEN)
        STATE="active"
        TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
        CURRENT_ACTIVITY="$TOOL_NAME"
        ;;
    PostToolUseFailure)
        # is_interrupt: true means user pressed ESC during tool execution
        IS_INTERRUPT=$(echo "$INPUT" | jq -r '.is_interrupt // false')
        if [ "$IS_INTERRUPT" = "true" ]; then
            STATE="waiting"
            CURRENT_ACTIVITY=""
        else
            STATE="active"
        fi
        ;;
    Stop)
        STATE="waiting"
        CURRENT_ACTIVITY=""
        # Capture last assistant message (truncated to 200 chars)
        STOP_MESSAGE=$(echo "$INPUT" | jq -r '.last_assistant_message // empty' | head -c 200)
        if [ -n "$STOP_MESSAGE" ]; then
            LAST_MESSAGE="$STOP_MESSAGE"
        fi
        ;;
    Notification)
        # notification_type is a top-level field in the hook input
        NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type // empty')
        case "$NOTIFICATION_TYPE" in
            permission_prompt)
                STATE="permission"
                CURRENT_ACTIVITY=""
                ;;
            idle_prompt)
                STATE="waiting"
                CURRENT_ACTIVITY=""
                ;;
            elicitation_dialog)
                STATE="permission"
                CURRENT_ACTIVITY=""
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

# Clean up other session files on the same TTY (handles revived sessions + resume)
if [ -n "$SESSION_TTY" ]; then
    for f in "$SESSIONS_DIR"/*.json; do
        [ -f "$f" ] || continue
        OLD_SID=$(jq -r '.session_id // empty' "$f" 2>/dev/null)
        OLD_TTY=$(jq -r '.tty // empty' "$f" 2>/dev/null)
        if [ "$OLD_TTY" = "$SESSION_TTY" ] && [ "$OLD_SID" != "$SESSION_ID" ]; then
            rm -f "$f"
        fi
    done
fi

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
    --arg lm "$LAST_MESSAGE" \
    --arg ca "$CURRENT_ACTIVITY" \
    '{"session_id":$sid,"cwd":$cwd,"state":$state,"updated_at":$ts,"started_at":$started,"terminal_bundle_id":$bid,"tty":$tty,"last_message":$lm,"current_activity":$ca}' > "$TEMP_FILE"
mv "$TEMP_FILE" "$SESSION_FILE"

exit 0
