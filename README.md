# claude-runner

macOS 메뉴바에서 Claude Code 세션 상태를 실시간 모니터링하는 경량 네이티브 앱.

여러 터미널/IDE에서 Claude Code를 동시에 사용할 때, 어떤 세션이 유저 입력을 기다리는지 한눈에 파악하고, 클릭 한번으로 해당 창으로 전환할 수 있습니다.

## 주요 기능

- **메뉴바 상태 아이콘**: 4가지 스타일 (신호등, 파이 차트, 도미노, 텍스트 카운터)
- **세션 목록 팝오버**: 앱 아이콘, 프로젝트명, 경과시간 표시
- **클릭-to-포커스**: 세션 클릭 시 해당 터미널/IDE 창으로 전환
  - iTerm2 / Terminal.app: 정확한 탭/창 전환 (전체화면 지원)
  - JetBrains IDEs: 프로젝트 창 전환 (Toolbox CLI 연동)
- **알림**: 권한 승인/유저 입력 대기 시 macOS 알림 (클릭 시 앱 포커스)
- **설정**: 아이콘 스타일, 경로 표시 형식, 스테일 타임아웃 등

## 상태 표시

| 색상 | 의미 | 트리거 |
|------|------|--------|
| 🟢 초록 | Claude가 작업 중 | `UserPromptSubmit`, `PostToolUse` |
| 🟡 노랑 | 유저 입력 대기 | `Stop`, `Notification(idle)` |
| 🔴 빨강 | 권한 승인 대기 | `PermissionRequest`, `Notification(permission)`, `elicitation_dialog` |
| ⚪ 모두 흐림 | 활성 세션 없음 | 세션 0개 |

복수 세션 시 해당 색상 위에 숫자 배지가 표시됩니다 (2개 이상일 때).

## 설치

### 요구 사항

- macOS 13.0+

### 다운로드 설치 (권장)

1. [최신 릴리스](https://github.com/jyami-kim/claude-runner/releases/latest)에서 `claude-runner-x.x.x.zip` 다운로드
2. 압축 해제 후 `claude-runner.app`을 `/Applications/`로 이동
3. **최초 실행 전** Gatekeeper 격리 속성 제거:
   ```bash
   xattr -cr /Applications/claude-runner.app
   ```
4. 앱 실행:
   ```bash
   open /Applications/claude-runner.app
   ```

> **macOS 보안 경고가 뜨는 경우**: 이 앱은 Apple Developer 인증서 없이 ad-hoc 서명되어 있어 "악성코드를 확인할 수 없습니다" 경고가 나타날 수 있습니다. 위의 `xattr -cr` 명령으로 해결되며, 또는 Finder에서 앱을 **우클릭 → 열기**로도 실행할 수 있습니다.

앱이 첫 실행 시 자동으로 Hook 스크립트를 설치하고 `~/.claude/settings.json`에 등록합니다.

### 소스 빌드 설치

Swift 5.9+ 환경이 있다면 소스에서 직접 빌드할 수 있습니다:

```bash
git clone https://github.com/jyami-kim/claude-runner.git
cd claude-runner
./install.sh
open /Applications/claude-runner.app
```

### 로그인 시 자동 시작

앱 설정 → General → Launch at Login 토글

### 제거

**앱 내 제거 (권장)**: Settings → Advanced → "Uninstall claude-runner…" 버튼 클릭. Hook 등록 해제 + 세션 데이터 삭제 후 자동 종료됩니다. 이후 `/Applications/claude-runner.app`만 삭제하면 완료.

**소스 빌드 설치 시**: `./install.sh uninstall`

## 작동 원리

```
Claude Code Hook (shell script)
    → ~/Library/Application Support/claude-runner/sessions/{session_id}.json
        → Swift 앱이 sessions/ 디렉토리 감시 (kqueue)
            → 메뉴바 아이콘 업데이트 + 팝오버 세션 목록
```

1. **Claude Code Hook**: 세션 이벤트 발생 시 개별 JSON 파일에 상태 기록. 부모 프로세스 체인에서 터미널/IDE 번들 ID와 TTY도 캡처.
2. **디렉토리 감시**: kqueue 기반 실시간 파일 변경 감지 (CPU 사용 거의 없음)
3. **아이콘 업데이트**: 상태별 신호등 원 밝기 + 배지 숫자 렌더링
4. **클릭-to-포커스**: iTerm2/Terminal.app은 AppleScript TTY 매칭, JetBrains는 Toolbox CLI, 기타 앱은 NSRunningApplication 활성화

### 세션 파일 형식

```json
{
  "session_id": "abc123",
  "cwd": "/Users/you/my-project",
  "state": "waiting",
  "updated_at": "2026-02-13T12:34:56Z",
  "started_at": "2026-02-13T12:30:00Z",
  "terminal_bundle_id": "com.googlecode.iterm2",
  "tty": "/dev/ttys005"
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
│   │   └── AppDelegate.swift              # NSStatusItem + PopoverPanel (NSPanel)
│   ├── Models/
│   │   ├── SessionState.swift             # 상태 enum, 모델, StateStore
│   │   └── AppSettings.swift              # @AppStorage 설정 관리
│   ├── Views/
│   │   ├── StatusIcon.swift               # 메뉴바 아이콘 관리
│   │   ├── SessionListView.swift          # 세션 목록 + 세션 행 (앱 아이콘, 클릭-to-포커스)
│   │   └── SettingsView.swift             # 설정 윈도우 (5개 섹션)
│   ├── Services/
│   │   ├── SessionDirectoryWatcher.swift  # kqueue 디렉토리 감시
│   │   ├── HookInstaller.swift            # Hook 스크립트 설치
│   │   ├── LoginItemManager.swift         # SMAppService 로그인 항목 관리
│   │   ├── NotificationService.swift      # macOS 알림 + 클릭-to-포커스
│   │   └── TerminalFocuser.swift          # 터미널/IDE 창 포커스 (AppleScript, JetBrains CLI)
│   └── Extensions/
│       ├── BundleIdentifier+AppInfo.swift # 번들 ID → 앱 이름/아이콘
│       ├── DesignTokens.swift             # 공유 색상/치수 상수
│       └── NSImage+TrafficLight.swift     # 메뉴바 아이콘 렌더링 (4 스타일)
├── Tests/
│   ├── SessionStateTests.swift
│   ├── StateStoreTests.swift
│   ├── HookStateTransitionTests.swift
│   ├── DesignTokensTests.swift
│   ├── TrafficLightTests.swift
│   ├── AppSettingsTests.swift
│   ├── LoginItemManagerTests.swift
│   ├── NotificationServiceTests.swift
│   └── AppInfoTests.swift
├── Resources/
│   ├── Info.plist                         # LSUIElement=true
│   ├── AppIcon.icns                       # 앱 아이콘
│   └── AppIcon.svg                        # 아이콘 원본 SVG
```

## 디자인

- **메뉴바 아이콘**: 4가지 스타일 (신호등, 파이 차트, 도미노, 텍스트 카운터)
- **팝오버**: 260pt 너비, 세션별 상태 dot + 앱 아이콘 + 프로젝트명 + 앱 이름 + 경과시간
- **색상**: Apple HIG 준수 (`#FF453A`, `#FFD60A`, `#30D158`)
- **앱 아이콘**: 미니멀 네온 도트 (Concept 2)

## 기술 스택

- **Swift 5.9** + **SwiftUI** (외부 의존성 없음)
- **Swift Package Manager** 빌드
- **kqueue** (DispatchSource) 파일 감시
- **NSAppleScript** 터미널 탭/창 전환
- **JetBrains Toolbox CLI** IDE 프로젝트 창 전환
- **Claude Code Hooks** 연동

## 라이선스

MIT
