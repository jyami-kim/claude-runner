# Claude Code Hook 통합 로드맵

## 현재 상태 (Phase 1 완료)

### 앱 상태 모델

| 상태 | 색상 | 의미 |
|------|------|------|
| `active` | GREEN | Claude가 작업 중 |
| `waiting` | YELLOW | 사용자 입력 대기 |
| `permission` | RED | 사용자 승인/응답 대기 |

### 등록된 Hook 이벤트 (9개)

| Hook 이벤트 | 매핑 상태 | 비고 |
|------------|----------|------|
| `SessionStart` | `waiting` | 세션 시작 |
| `UserPromptSubmit` | `active` | 프롬프트 제출 → 작업 시작 |
| `PreToolUse` | `active` / `permission` | `AskUserQuestion` → `permission`, 그 외 → `active` |
| `PostToolUse` | `active` | 도구 완료 → 작업 재개 (승인 후 GREEN 복귀) |
| `PermissionRequest` | `permission` | 권한 다이얼로그 표시 직전 (읽기 전용 도구 제외) |
| `PostToolUseFailure` | 조건부 | `is_interrupt:true` → `waiting` (ESC), 그 외 → `active` |
| `Stop` | `waiting` | Claude 응답 완료 |
| `SessionEnd` | 삭제 | 세션 파일 제거 |
| `Notification/permission_prompt` | `permission` | 권한 승인 알림 |
| `Notification/idle_prompt` | `waiting` | 유휴 상태 알림 |
| `Notification/elicitation_dialog` | `permission` | AskUserQuestion 등 질문 다이얼로그 |

### Hook 설정

- 모든 hook은 `async: false`로 설정하여 이벤트 순서를 보장한다.
- Race condition 방지: `PreToolUse` → `PermissionRequest` 순서가 보장되어야 정확한 상태 전환이 가능.

### Stale Session Pruning

- `waiting` 상태 세션만 `staleTimeoutSeconds` (기본 600초) 경과 시 삭제
- `active` / `permission` 상태 세션은 시간에 관계없이 보존

### Known Limitations

- **ESC 인터럽트 시 hook 미발생**: 도구 실행 중 또는 권한 대기 중 ESC로 중단하면 `PostToolUseFailure`, `Stop` 등 hook 이벤트가 발생하지 않는 경우가 있음. 이 경우 상태가 `permission`(RED)에 머물 수 있으며, 다음 `UserPromptSubmit` 이벤트에서 복구됨.
- **장시간 도구 실행 중 RED 유지**: 사용자가 권한을 승인한 후에도, 도구가 완료될 때까지(`PostToolUse` 발생까지) `permission`(RED) 상태가 유지됨. 승인 완료를 알려주는 별도의 hook 이벤트가 Claude Code에 존재하지 않기 때문. 짧은 명령은 즉시 GREEN으로 전환되지만, 장시간 실행 명령(예: `sleep`, 대용량 빌드)은 완료까지 RED로 표시됨.

---

## Phase 2 - 상태 정확도 개선 (TODO)

### 목표
서브에이전트 활동과 컨텍스트 압축 등 추가 이벤트를 반영하여 상태 정확도를 높인다.

### 추가할 Hook 이벤트

#### SubagentStart → `active`
- 서브에이전트(Task tool)가 생성될 때 발생
- matcher로 에이전트 타입 필터 가능: `Bash`, `Explore`, `Plan`, 커스텀 에이전트명
- 메인 에이전트가 서브에이전트를 실행 중이므로 `active` 상태 유지
- **페이로드**: `agent_id`, `agent_type`

#### SubagentStop → `active`
- 서브에이전트가 완료될 때 발생
- 서브에이전트 종료 후에도 메인 에이전트는 계속 작업 중
- **페이로드**: `agent_id`, `agent_type`, `agent_transcript_path`, `stop_hook_active`

#### PreCompact → `active`
- 컨텍스트 압축 전 발생
- matcher: `manual` (/compact 명령) vs `auto` (컨텍스트 윈도우 초과)
- 압축 중에도 세션은 활성 상태
- **페이로드**: `trigger`, `custom_instructions`

### 구현 시 고려사항
- `settings.json`에 hook 등록 추가
- `claude-runner-hook.sh`에 case 추가
- `verify-hooks.sh`의 `REQUIRED_EVENTS` 배열 업데이트

---

## Phase 3 - 팀 모드 지원 (TODO)

### 목표
Claude Code의 Agent Team 기능을 지원하여 팀원별 상태를 추적한다.

### 아키텍처 변경 필요사항

#### 상태 모델 확장
현재 세션 1개 = 상태 1개 구조에서, 세션 1개 내에 여러 에이전트(팀원)가 동시 실행되는 모델로 확장 필요.

```
현재:     Session → State (active/waiting/permission)
확장 후:  Session → [Agent1: active, Agent2: waiting, Agent3: permission]
```

#### 추가할 Hook 이벤트

##### TeammateIdle
- 팀 모드에서 팀원이 유휴 상태로 전환될 때 발생
- **페이로드**: `teammate_name`, `team_name`
- matcher 미지원 (모든 발생에 대해 트리거)
- 차단 가능 (exit 2)

##### TaskCompleted
- 태스크가 완료 표시될 때 발생
- **페이로드**: `task_id`, `task_subject`, `task_description`, `teammate_name`, `team_name`
- matcher 미지원
- 차단 가능 (exit 2)

#### UI 확장 고려

| 항목 | 현재 | 확장 후 |
|------|------|--------|
| 메뉴바 아이콘 | 세션별 상태 (3색) | 팀원별 상태 표시 |
| 팝오버 목록 | 세션 리스트 | 세션 > 팀원 리스트 (트리 구조) |
| 상태 표시 | "작업 중" / "입력 대기" / "승인 대기" | "팀 2/3 active, 1 waiting" |

#### 데이터 모델 확장

```swift
// 현재
struct SessionEntry {
    let state: SessionState
}

// 확장 안
struct SessionEntry {
    let state: SessionState          // 세션 전체 상태 (dominant)
    let teammates: [TeammateEntry]?  // 팀원별 상태 (nil이면 단독 모드)
}

struct TeammateEntry {
    let name: String
    let state: SessionState
    let taskSubject: String?
}
```

#### 세션 파일 확장

```json
{
  "session_id": "abc123",
  "state": "active",
  "teammates": [
    { "name": "researcher", "state": "active", "task": "Find API docs" },
    { "name": "implementer", "state": "waiting", "task": null },
    { "name": "reviewer", "state": "permission", "task": "Review PR #42" }
  ]
}
```

### 구현 순서 (권장)
1. `TeammateIdle` / `TaskCompleted` hook 등록 및 스크립트 처리
2. 세션 파일에 `teammates` 필드 추가 (하위 호환 유지)
3. `SessionEntry` 모델에 `teammates` 옵셔널 배열 추가
4. UI에 팀원별 상태 표시 (팝오버 확장)
5. 메뉴바 아이콘에 팀 상태 반영

---

## 전체 Claude Code Hook 이벤트 레퍼런스

| # | 이벤트 | 발생 시점 | Phase | 차단 가능 |
|---|--------|----------|:-----:|:---------:|
| 1 | `SessionStart` | 세션 시작/재개 | 1 ✅ | No |
| 2 | `UserPromptSubmit` | 프롬프트 제출 | 1 ✅ | Yes |
| 3 | `PreToolUse` | 도구 실행 직전 | 1 ✅ | Yes |
| 4 | `PermissionRequest` | 권한 다이얼로그 직전 | 1 ✅ | Yes |
| 5 | `PostToolUse` | 도구 성공 완료 | 1 ✅ | No |
| 6 | `PostToolUseFailure` | 도구 실패 (ESC 감지) | 1 ✅ | No |
| 7 | `Notification` | 알림 발생 | 1 ✅ | No |
| 8 | `SubagentStart` | 서브에이전트 생성 | 2 | No |
| 9 | `SubagentStop` | 서브에이전트 종료 | 2 | Yes |
| 10 | `Stop` | Claude 응답 완료 | 1 ✅ | Yes |
| 11 | `TeammateIdle` | 팀원 유휴 전환 | 3 | Yes |
| 12 | `TaskCompleted` | 태스크 완료 | 3 | Yes |
| 13 | `PreCompact` | 컨텍스트 압축 전 | 2 | No |
| 14 | `SessionEnd` | 세션 종료 | 1 ✅ | No |
