# claude-runner

macOS 메뉴바에 **가로 신호등 아이콘**으로 Claude Code 세션 상태를 실시간 표시하는 경량 네이티브 앱.

여러 터미널에서 Claude Code를 동시에 사용할 때, 어떤 세션이 유저 입력을 기다리는지 한눈에 파악할 수 있습니다.

## 상태 표시

| 색상 | 의미 | 트리거 |
|------|------|--------|
| 🟢 초록 | Claude가 작업 중 | `SessionStart`, `UserPromptSubmit` |
| 🟡 노랑 | 유저 입력 대기 | `Stop`, `Notification(idle)` |
| 🔴 빨강 | 권한 승인 대기 | `Notification(permission)` |
| ⚪ 모두 흐림 | 활성 세션 없음 | 세션 0개 |

복수 세션 시 해당 색상 위에 숫자 배지가 표시됩니다 (2개 이상일 때).

## 설치

### 요구 사항

- macOS 13.0+
- Swift 5.9+
- [jq](https://jqlang.github.io/jq/) (`brew install jq`)

### 원클릭 설치

```bash
git clone https://github.com/jyami/claude-runner.git
cd claude-runner
./install.sh
```

이 스크립트가 자동으로:
1. Release 바이너리 빌드
2. `/Applications/claude-runner.app` 생성 (Dock에 안 나타남)
3. Hook 스크립트 설치
4. `~/.claude/settings.json`에 Hook 등록 (기존 설정 보존)

### 실행

```bash
open /Applications/claude-runner.app
```

로그인 시 자동 시작: **System Settings → General → Login Items → claude-runner 추가**

### 제거

```bash
./install.sh uninstall
```

## 작동 원리

```
Claude Code Hook (shell script)
    → ~/Library/Application Support/claude-runner/sessions/{session_id}.json
        → Swift 앱이 sessions/ 디렉토리 감시 (kqueue)
            → 메뉴바 가로 신호등 아이콘 업데이트
```

1. **Claude Code Hook**: 세션 이벤트 발생 시 개별 JSON 파일에 상태 기록
2. **디렉토리 감시**: kqueue 기반 실시간 파일 변경 감지 (CPU 사용 거의 없음)
3. **아이콘 업데이트**: 상태별 신호등 원 밝기 + 배지 숫자 렌더링

### 세션 파일 형식

```json
{
  "session_id": "abc123",
  "cwd": "/Users/you/my-project",
  "state": "waiting",
  "updated_at": "2026-02-13T12:34:56Z"
}
```

각 세션이 자기 파일만 write하므로 쓰기 경합이 없습니다.

## 프로젝트 구조

```
claude-runner/
├── Package.swift                          # SPM (외부 의존성 없음)
├── install.sh                             # 설치/제거 스크립트
├── Scripts/
│   └── claude-runner-hook.sh              # Claude Code Hook 스크립트
├── Sources/
│   ├── App/
│   │   ├── ClaudeRunnerApp.swift          # @main 진입점
│   │   └── AppDelegate.swift              # NSStatusItem + 팝오버
│   ├── Models/
│   │   └── SessionState.swift             # 상태 enum, 모델, StateStore
│   ├── Views/
│   │   ├── StatusIcon.swift               # 메뉴바 아이콘 관리
│   │   └── SessionListView.swift          # SwiftUI 팝오버 UI
│   ├── Services/
│   │   ├── SessionDirectoryWatcher.swift  # kqueue 디렉토리 감시
│   │   └── HookInstaller.swift            # Hook 스크립트 설치
│   └── Extensions/
│       ├── DesignTokens.swift             # 공유 색상/치수 상수
│       └── NSImage+TrafficLight.swift     # 신호등 아이콘 렌더링
├── Resources/
│   ├── Info.plist                         # LSUIElement=true
│   ├── AppIcon.icns                       # 앱 아이콘
│   └── AppIcon.svg                        # 아이콘 원본 SVG
└── Design/
    ├── DESIGN_SPEC.md                     # 디자인 스펙
    ├── FIGMA_PROMPTS.md                   # UI 디자인 프롬프트
    └── APP_ICON_PROMPTS.md                # 앱 아이콘 프롬프트
```

## 디자인

- **메뉴바 아이콘**: 36x18pt 가로 신호등 (빨/노/초), 배지 숫자
- **팝오버**: 260pt 너비, 세션별 상태 dot + 프로젝트명 + 경과시간
- **색상**: Apple HIG 준수 (`#FF453A`, `#FFD60A`, `#30D158`)
- **앱 아이콘**: 미니멀 네온 도트 (Concept 2)

## 기술 스택

- **Swift 5.9** + **SwiftUI** (외부 의존성 없음)
- **Swift Package Manager** 빌드
- **kqueue** (DispatchSource) 파일 감시
- **Claude Code Hooks** 연동
- **Figma MCP** 디자인 워크플로우

## 라이선스

MIT
