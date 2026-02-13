#!/bin/bash
# verify-hooks.sh
# Verifies that ~/.claude/settings.json has all required hook events registered
# for claude-runner to work correctly.

set -euo pipefail

SETTINGS_FILE="$HOME/.claude/settings.json"
HOOK_SCRIPT_PATH="\$HOME/Library/Application Support/claude-runner/hooks/claude-runner-hook.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "=== claude-runner hook 설정 검증 ==="
echo ""

if [ ! -f "$SETTINGS_FILE" ]; then
    echo -e "${RED}[FAIL]${NC} $SETTINGS_FILE 파일이 없습니다."
    exit 1
fi

echo "설정 파일: $SETTINGS_FILE"
echo ""

# Required hook events
REQUIRED_EVENTS=("SessionStart" "UserPromptSubmit" "PreToolUse" "Stop" "SessionEnd")
REQUIRED_NOTIFICATIONS=("permission_prompt" "idle_prompt")

PASS=0
FAIL=0

# Check each required hook event
for event in "${REQUIRED_EVENTS[@]}"; do
    if jq -e ".hooks[\"$event\"]" "$SETTINGS_FILE" > /dev/null 2>&1; then
        # Check if hook command contains claude-runner
        if jq -e ".hooks[\"$event\"][] | .hooks[] | select(.command | contains(\"claude-runner\"))" "$SETTINGS_FILE" > /dev/null 2>&1; then
            echo -e "  ${GREEN}[OK]${NC}   $event"
            PASS=$((PASS + 1))
        else
            echo -e "  ${RED}[FAIL]${NC} $event - claude-runner hook 명령어 없음"
            FAIL=$((FAIL + 1))
        fi
    else
        echo -e "  ${RED}[FAIL]${NC} $event - 미등록"
        FAIL=$((FAIL + 1))
    fi
done

# Check notification matchers
echo ""
echo "Notification matchers:"
for ntype in "${REQUIRED_NOTIFICATIONS[@]}"; do
    if jq -e ".hooks.Notification[] | select(.matcher == \"$ntype\")" "$SETTINGS_FILE" > /dev/null 2>&1; then
        echo -e "  ${GREEN}[OK]${NC}   Notification/$ntype"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} Notification/$ntype - 미등록"
        FAIL=$((FAIL + 1))
    fi
done

# Check installed hook script
echo ""
echo "Hook 스크립트:"
INSTALLED_HOOK="$HOME/Library/Application Support/claude-runner/hooks/claude-runner-hook.sh"
if [ -f "$INSTALLED_HOOK" ]; then
    if [ -x "$INSTALLED_HOOK" ]; then
        echo -e "  ${GREEN}[OK]${NC}   $INSTALLED_HOOK (실행 가능)"
    else
        echo -e "  ${YELLOW}[WARN]${NC} $INSTALLED_HOOK (실행 권한 없음)"
        FAIL=$((FAIL + 1))
    fi

    # Check if installed script handles PreToolUse
    if grep -q "PreToolUse" "$INSTALLED_HOOK"; then
        echo -e "  ${GREEN}[OK]${NC}   PreToolUse 핸들러 포함"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} PreToolUse 핸들러 없음 - hook 스크립트 재설치 필요"
        FAIL=$((FAIL + 1))
    fi
else
    echo -e "  ${RED}[FAIL]${NC} Hook 스크립트 미설치: $INSTALLED_HOOK"
    FAIL=$((FAIL + 1))
fi

# Check debug log
echo ""
echo "디버그 로그:"
DEBUG_LOG="$HOME/Library/Application Support/claude-runner/debug.log"
if [ -f "$DEBUG_LOG" ]; then
    LINES=$(wc -l < "$DEBUG_LOG" | tr -d ' ')
    LAST_ENTRY=$(tail -1 "$DEBUG_LOG")
    echo -e "  ${GREEN}[OK]${NC}   $DEBUG_LOG ($LINES 줄)"
    echo -e "  마지막 이벤트: $LAST_ENTRY"
else
    echo -e "  ${YELLOW}[INFO]${NC} 디버그 로그 아직 없음 (이벤트 발생 시 생성됨)"
fi

# Summary
echo ""
echo "---"
echo -e "결과: ${GREEN}$PASS 통과${NC}, ${RED}$FAIL 실패${NC}"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}수정이 필요합니다. hook 스크립트를 재설치하세요.${NC}"
    exit 1
else
    echo -e "${GREEN}모든 설정이 올바릅니다.${NC}"
fi
