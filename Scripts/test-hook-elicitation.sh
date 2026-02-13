#!/bin/bash
# test-hook-elicitation.sh
# Tests hook script state transitions for permission-requiring events.
#
# Verifies:
# 1. Notification/elicitation_dialog → state = "permission" (RED)
# 2. UserPromptSubmit after elicitation → state = "active" (GREEN)
# 3. PreToolUse (non-AskUserQuestion) → state = "active" (GREEN)
# 4. PreToolUse/AskUserQuestion → state = "permission" (RED)
# 5. PermissionRequest/Bash → state = "permission" (RED)
# 6. PermissionRequest/Write → state = "permission" (RED)
# 7. PermissionRequest for read-only tools → no state change (exit 0)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/claude-runner-hook.sh"

# Use a temp directory for test isolation
TEST_DIR=$(mktemp -d)
TEST_SESSIONS="$TEST_DIR/sessions"
mkdir -p "$TEST_SESSIONS"

PASS=0
FAIL=0
SESSION_ID="test-session-$(date +%s)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Override HOME so the hook writes to our test directory
export HOME="$TEST_DIR"
mkdir -p "$HOME/Library/Application Support/claude-runner/sessions"
SESSIONS_DIR="$HOME/Library/Application Support/claude-runner/sessions"

assert_state() {
    local test_name="$1"
    local expected_state="$2"
    local session_file="$SESSIONS_DIR/${SESSION_ID}.json"

    if [ ! -f "$session_file" ]; then
        echo -e "  ${RED}[FAIL]${NC} $test_name - session file not found"
        FAIL=$((FAIL + 1))
        return
    fi

    local actual_state
    actual_state=$(jq -r '.state' "$session_file")

    if [ "$actual_state" = "$expected_state" ]; then
        echo -e "  ${GREEN}[PASS]${NC} $test_name → state=$actual_state"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} $test_name → expected=$expected_state, actual=$actual_state"
        FAIL=$((FAIL + 1))
    fi
}

assert_deleted() {
    local test_name="$1"
    local session_file="$SESSIONS_DIR/${SESSION_ID}.json"

    if [ ! -f "$session_file" ]; then
        echo -e "  ${GREEN}[PASS]${NC} $test_name → file deleted"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} $test_name → file still exists"
        FAIL=$((FAIL + 1))
    fi
}

assert_unchanged() {
    local test_name="$1"
    local expected_state="$2"
    local session_file="$SESSIONS_DIR/${SESSION_ID}.json"

    if [ ! -f "$session_file" ]; then
        echo -e "  ${RED}[FAIL]${NC} $test_name - session file not found"
        FAIL=$((FAIL + 1))
        return
    fi

    local actual_state
    actual_state=$(jq -r '.state' "$session_file")

    if [ "$actual_state" = "$expected_state" ]; then
        echo -e "  ${GREEN}[PASS]${NC} $test_name → state unchanged ($actual_state)"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} $test_name → expected=$expected_state (unchanged), actual=$actual_state"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Hook State Transition Tests ==="
echo "Hook script: $HOOK_SCRIPT"
echo ""

# -------------------------------------------------------
# Test 1: SessionStart → waiting
# -------------------------------------------------------
echo "Test 1: SessionStart → waiting"
echo "{\"hook_event_name\":\"SessionStart\",\"session_id\":\"$SESSION_ID\",\"cwd\":\"/tmp/project\"}" \
    | bash "$HOOK_SCRIPT"
assert_state "SessionStart" "waiting"

# -------------------------------------------------------
# Test 2: UserPromptSubmit → active (user sends prompt)
# -------------------------------------------------------
echo ""
echo "Test 2: UserPromptSubmit → active"
echo "{\"hook_event_name\":\"UserPromptSubmit\",\"session_id\":\"$SESSION_ID\",\"cwd\":\"/tmp/project\"}" \
    | bash "$HOOK_SCRIPT"
assert_state "UserPromptSubmit" "active"

# -------------------------------------------------------
# Test 3: Notification/elicitation_dialog → permission (RED)
# This simulates AskUserQuestion being called in plan mode
# -------------------------------------------------------
echo ""
echo "Test 3: Notification/elicitation_dialog → permission (RED)"
echo "{\"hook_event_name\":\"Notification\",\"session_id\":\"$SESSION_ID\",\"cwd\":\"/tmp/project\",\"notification_type\":\"elicitation_dialog\"}" \
    | bash "$HOOK_SCRIPT"
assert_state "Notification/elicitation_dialog" "permission"

# -------------------------------------------------------
# Test 4: UserPromptSubmit → active (user answered the question)
# -------------------------------------------------------
echo ""
echo "Test 4: UserPromptSubmit after elicitation → active (GREEN)"
echo "{\"hook_event_name\":\"UserPromptSubmit\",\"session_id\":\"$SESSION_ID\",\"cwd\":\"/tmp/project\"}" \
    | bash "$HOOK_SCRIPT"
assert_state "UserPromptSubmit after elicitation" "active"

# -------------------------------------------------------
# Test 5: PreToolUse/AskUserQuestion → permission (RED)
# This simulates AskUserQuestion being detected via PreToolUse
# -------------------------------------------------------
echo ""
echo "Test 5: PreToolUse/AskUserQuestion → permission (RED)"
echo "{\"hook_event_name\":\"PreToolUse\",\"session_id\":\"$SESSION_ID\",\"cwd\":\"/tmp/project\",\"tool_name\":\"AskUserQuestion\"}" \
    | bash "$HOOK_SCRIPT"
assert_state "PreToolUse/AskUserQuestion" "permission"

# -------------------------------------------------------
# Test 6: PreToolUse (Read) → active (GREEN, normal tool use)
# -------------------------------------------------------
echo ""
echo "Test 6: PreToolUse/Read after AskUserQuestion → active (GREEN)"
echo "{\"hook_event_name\":\"PreToolUse\",\"session_id\":\"$SESSION_ID\",\"cwd\":\"/tmp/project\",\"tool_name\":\"Read\"}" \
    | bash "$HOOK_SCRIPT"
assert_state "PreToolUse/Read" "active"

# -------------------------------------------------------
# Test 7: Full cycle - elicitation → answer → another elicitation → answer
# -------------------------------------------------------
echo ""
echo "Test 7: Full cycle (elicitation → answer → elicitation → answer)"

echo "{\"hook_event_name\":\"Notification\",\"session_id\":\"$SESSION_ID\",\"cwd\":\"/tmp/project\",\"notification_type\":\"elicitation_dialog\"}" \
    | bash "$HOOK_SCRIPT"
assert_state "Cycle: 1st elicitation" "permission"

echo "{\"hook_event_name\":\"UserPromptSubmit\",\"session_id\":\"$SESSION_ID\",\"cwd\":\"/tmp/project\"}" \
    | bash "$HOOK_SCRIPT"
assert_state "Cycle: 1st answer" "active"

echo "{\"hook_event_name\":\"Notification\",\"session_id\":\"$SESSION_ID\",\"cwd\":\"/tmp/project\",\"notification_type\":\"elicitation_dialog\"}" \
    | bash "$HOOK_SCRIPT"
assert_state "Cycle: 2nd elicitation" "permission"

echo "{\"hook_event_name\":\"PreToolUse\",\"session_id\":\"$SESSION_ID\",\"cwd\":\"/tmp/project\",\"tool_name\":\"Edit\"}" \
    | bash "$HOOK_SCRIPT"
assert_state "Cycle: 2nd answer (PreToolUse)" "active"

# -------------------------------------------------------
# Test 8: PermissionRequest/Bash → permission (RED)
# e.g. "Allow tail -f ...?" prompt
# -------------------------------------------------------
echo ""
echo "Test 8: PermissionRequest/Bash → permission (RED)"
echo "{\"hook_event_name\":\"PermissionRequest\",\"session_id\":\"$SESSION_ID\",\"cwd\":\"/tmp/project\",\"tool_name\":\"Bash\"}" \
    | bash "$HOOK_SCRIPT"
assert_state "PermissionRequest/Bash" "permission"

# -------------------------------------------------------
# Test 9: PostToolUse after Bash → active (GREEN)
# This is the key fix: after user approves and tool runs, state goes back to GREEN
# -------------------------------------------------------
echo ""
echo "Test 9: PostToolUse after Bash → active (GREEN)"
echo "{\"hook_event_name\":\"PostToolUse\",\"session_id\":\"$SESSION_ID\",\"cwd\":\"/tmp/project\",\"tool_name\":\"Bash\"}" \
    | bash "$HOOK_SCRIPT"
assert_state "PostToolUse/Bash" "active"

# -------------------------------------------------------
# Test 10: PermissionRequest/Write → permission (RED)
# -------------------------------------------------------
echo ""
echo "Test 10: PermissionRequest/Write → permission (RED)"
echo "{\"hook_event_name\":\"PermissionRequest\",\"session_id\":\"$SESSION_ID\",\"cwd\":\"/tmp/project\",\"tool_name\":\"Write\"}" \
    | bash "$HOOK_SCRIPT"
assert_state "PermissionRequest/Write" "permission"

# -------------------------------------------------------
# Test 11: PermissionRequest/Edit → permission (RED)
# -------------------------------------------------------
echo ""
echo "Test 11: PermissionRequest/Edit → permission (RED)"
echo "{\"hook_event_name\":\"PermissionRequest\",\"session_id\":\"$SESSION_ID\",\"cwd\":\"/tmp/project\",\"tool_name\":\"Edit\"}" \
    | bash "$HOOK_SCRIPT"
assert_state "PermissionRequest/Edit" "permission"

# -------------------------------------------------------
# Test 12: PermissionRequest for read-only tools → no state change
# Read-only tools auto-approve, so hook exits early (exit 0)
# -------------------------------------------------------
echo ""
echo "Test 12: PermissionRequest for read-only tools → no state change"
# Set to active first
echo "{\"hook_event_name\":\"UserPromptSubmit\",\"session_id\":\"$SESSION_ID\",\"cwd\":\"/tmp/project\"}" \
    | bash "$HOOK_SCRIPT"

for tool in Read Glob Grep LSP WebSearch WebFetch TaskList TaskGet; do
    echo "{\"hook_event_name\":\"PermissionRequest\",\"session_id\":\"$SESSION_ID\",\"cwd\":\"/tmp/project\",\"tool_name\":\"$tool\"}" \
        | bash "$HOOK_SCRIPT"
    assert_unchanged "PermissionRequest/$tool (skipped)" "active"
done

# -------------------------------------------------------
# Test 13: Notification/permission_prompt → permission (RED)
# -------------------------------------------------------
echo ""
echo "Test 13: Notification/permission_prompt → permission (RED)"
echo "{\"hook_event_name\":\"Notification\",\"session_id\":\"$SESSION_ID\",\"cwd\":\"/tmp/project\",\"notification_type\":\"permission_prompt\"}" \
    | bash "$HOOK_SCRIPT"
assert_state "Notification/permission_prompt" "permission"

# -------------------------------------------------------
# Test 14: Full cycle - Bash permission → approve → elicitation → answer
# -------------------------------------------------------
echo ""
echo "Test 14: Full cycle (PermissionRequest → approve → elicitation → answer)"

echo "{\"hook_event_name\":\"UserPromptSubmit\",\"session_id\":\"$SESSION_ID\",\"cwd\":\"/tmp/project\"}" \
    | bash "$HOOK_SCRIPT"
assert_state "Cycle: start active" "active"

echo "{\"hook_event_name\":\"PermissionRequest\",\"session_id\":\"$SESSION_ID\",\"cwd\":\"/tmp/project\",\"tool_name\":\"Bash\"}" \
    | bash "$HOOK_SCRIPT"
assert_state "Cycle: Bash permission" "permission"

echo "{\"hook_event_name\":\"PostToolUse\",\"session_id\":\"$SESSION_ID\",\"cwd\":\"/tmp/project\",\"tool_name\":\"Bash\"}" \
    | bash "$HOOK_SCRIPT"
assert_state "Cycle: Bash completed (PostToolUse)" "active"

echo "{\"hook_event_name\":\"Notification\",\"session_id\":\"$SESSION_ID\",\"cwd\":\"/tmp/project\",\"notification_type\":\"elicitation_dialog\"}" \
    | bash "$HOOK_SCRIPT"
assert_state "Cycle: elicitation" "permission"

echo "{\"hook_event_name\":\"UserPromptSubmit\",\"session_id\":\"$SESSION_ID\",\"cwd\":\"/tmp/project\"}" \
    | bash "$HOOK_SCRIPT"
assert_state "Cycle: answered" "active"

# -------------------------------------------------------
# Test 15: SessionEnd removes the file
# -------------------------------------------------------
echo ""
echo "Test 15: SessionEnd → file deleted"
echo "{\"hook_event_name\":\"SessionEnd\",\"session_id\":\"$SESSION_ID\",\"cwd\":\"/tmp/project\"}" \
    | bash "$HOOK_SCRIPT"
assert_deleted "SessionEnd cleanup"

# -------------------------------------------------------
# Summary
# -------------------------------------------------------
echo ""
echo "---"
TOTAL=$((PASS + FAIL))
echo -e "Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC} / $TOTAL total"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
