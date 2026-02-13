#!/bin/bash
set -euo pipefail

# claude-runner hook script
# Receives JSON from Claude Code hooks via stdin
# Writes per-session state files to sessions/ directory

SESSIONS_DIR="$HOME/Library/Application Support/claude-runner/sessions"
mkdir -p "$SESSIONS_DIR"

# Read JSON from stdin
INPUT=$(cat)

# Parse fields using jq
HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Exit if no session ID
if [ -z "$SESSION_ID" ]; then
    exit 0
fi

SESSION_FILE="$SESSIONS_DIR/${SESSION_ID}.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Determine state based on hook event
case "$HOOK_EVENT" in
    SessionStart|UserPromptSubmit)
        STATE="active"
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
    '{"session_id":$sid,"cwd":$cwd,"state":$state,"updated_at":$ts}' > "$TEMP_FILE"
mv "$TEMP_FILE" "$SESSION_FILE"

exit 0
