import Foundation

/// Centralized UI strings with Korean + English support.
///
/// All computed properties reference `AppSettings.shared.appLanguage`
/// so SwiftUI views re-render automatically when the language changes.
enum Strings {
    private static var lang: AppLanguage { AppSettings.shared.appLanguage }

    // MARK: - SessionListView

    static var noActiveSessions: String {
        lang == .korean ? "활성 세션 없음" : "No active sessions"
    }
    static var settings: String {
        lang == .korean ? "설정" : "Settings"
    }
    static var recover: String {
        lang == .korean ? "복구" : "Recover"
    }
    static var quit: String {
        lang == .korean ? "종료" : "Quit"
    }

    // MARK: - SettingsView — General

    static var general: String {
        lang == .korean ? "일반" : "General"
    }
    static var launchAtLogin: String {
        lang == .korean ? "로그인 시 실행" : "Launch at Login"
    }
    static var notifyOnStateChange: String {
        lang == .korean ? "상태 변경 시 알림" : "Notify on State Change"
    }
    static var language: String {
        lang == .korean ? "언어" : "Language"
    }

    // MARK: - SettingsView — Status Guide

    static var statusGuide: String {
        lang == .korean ? "상태 안내" : "Status Guide"
    }
    static var needsApproval: String {
        lang == .korean ? "승인 필요" : "Needs Approval"
    }
    static var needsApprovalDesc: String {
        lang == .korean ? "도구 권한 또는 사용자 응답 필요" : "Tool permission or user response required"
    }
    static var waiting: String {
        lang == .korean ? "대기 중" : "Waiting"
    }
    static var waitingDesc: String {
        lang == .korean ? "작업 완료, 다음 프롬프트 대기 중" : "Task complete, waiting for your next prompt"
    }
    static var running: String {
        lang == .korean ? "실행 중" : "Running"
    }
    static var runningDesc: String {
        lang == .korean ? "Claude가 작업을 수행하고 있습니다" : "Claude is working on your task"
    }

    // MARK: - SettingsView — Menu Bar Icon

    static var menuBarIcon: String {
        lang == .korean ? "메뉴 바 아이콘" : "Menu Bar Icon"
    }
    static var trafficLight: String {
        lang == .korean ? "신호등" : "Traffic Light"
    }
    static var pieChart: String {
        lang == .korean ? "파이 차트" : "Pie Chart"
    }
    static var domino: String {
        lang == .korean ? "도미노" : "Domino"
    }
    static var textCounter: String {
        lang == .korean ? "텍스트 카운터" : "Text Counter"
    }

    // MARK: - SettingsView — Session Display

    static var sessionDisplay: String {
        lang == .korean ? "세션 표시" : "Session Display"
    }
    static var showTaskMessage: String {
        lang == .korean ? "작업 메시지 표시" : "Show Task Message"
    }
    static var pathFormat: String {
        lang == .korean ? "경로 형식" : "Path Format"
    }
    static var full: String {
        lang == .korean ? "전체" : "Full"
    }
    static var dirOnly: String {
        lang == .korean ? "디렉토리만" : "Dir Only"
    }
    static var lastTwoDirs: String {
        lang == .korean ? "마지막 2단계" : "Last 2 Dirs"
    }

    // MARK: - SettingsView — Advanced

    static var advanced: String {
        lang == .korean ? "고급" : "Advanced"
    }
    static var staleSessionTimeout: String {
        lang == .korean ? "세션 만료 시간" : "Stale Session Timeout"
    }
    static var staleTimeoutDesc: String {
        lang == .korean ? "🟡 이 시간이 지난 대기 세션은 자동으로 제거됩니다." : "🟡 Waiting sessions older than this are automatically removed."
    }
    static var recoverTitle: String {
        lang == .korean ? "복구" : "Recover"
    }
    static var recoverDesc: String {
        lang == .korean ? "타임아웃 또는 앱 재시작으로 사라진 세션을 터미널 스캔으로 복원합니다." : "Scan running terminals to restore sessions lost by timeout or app restart."
    }
    static var uninstall: String {
        lang == .korean ? "claude-runner 삭제…" : "Uninstall claude-runner…"
    }
    static var uninstallConfirmTitle: String {
        lang == .korean ? "claude-runner를 삭제할까요?" : "Uninstall claude-runner?"
    }
    static var cancel: String {
        lang == .korean ? "취소" : "Cancel"
    }
    static var uninstallConfirmMessage: String {
        lang == .korean
            ? "~/.claude/settings.json에서 훅이 제거되고 세션 데이터가 삭제됩니다. 이후 앱이 종료되며, /Applications에서 직접 삭제해주세요."
            : "Hooks will be removed from ~/.claude/settings.json and session data will be deleted. The app will quit afterwards — delete it from /Applications manually."
    }
    static var min: String {
        lang == .korean ? "분" : "min"
    }

    // MARK: - StatusIcon

    static var noActiveSessionsTooltip: String {
        lang == .korean ? "claude-runner: 활성 세션 없음" : "claude-runner: No active sessions"
    }
    static var permission: String {
        lang == .korean ? "승인 필요" : "permission"
    }
    static var waitingTooltip: String {
        lang == .korean ? "대기" : "waiting"
    }
    static var active: String {
        lang == .korean ? "활성" : "active"
    }

    // MARK: - NotificationService

    static var notifPermissionSingle: String {
        lang == .korean ? "1개 세션이 도구 권한을 요청합니다" : "1 session needs tool permission"
    }
    static func notifPermissionPlural(_ count: Int) -> String {
        lang == .korean ? "\(count)개 세션이 도구 권한을 요청합니다" : "\(count) sessions need tool permission"
    }
    static var notifPermissionTitle: String {
        lang == .korean ? "승인 필요" : "Needs Approval"
    }
    static var notifWaitingSingle: String {
        lang == .korean ? "1개 세션 완료, 다음 프롬프트 대기 중" : "1 session finished, waiting for your next prompt"
    }
    static func notifWaitingPlural(_ count: Int) -> String {
        lang == .korean ? "\(count)개 세션 완료, 프롬프트 대기 중" : "\(count) sessions finished, waiting for prompts"
    }
    static var notifWaitingTitle: String {
        lang == .korean ? "입력 대기" : "Waiting for Input"
    }

    // MARK: - AppDelegate

    static var jqAlertTitle: String {
        lang == .korean ? "jq가 설치되어 있지 않습니다" : "jq is not installed"
    }
    static var jqAlertMessage: String {
        lang == .korean
            ? "claude-runner의 hook 스크립트가 jq를 필요로 합니다. jq 없이는 세션 상태를 추적할 수 없습니다.\n\nbrew install jq 로 설치해주세요."
            : "claude-runner's hook script requires jq. Without jq, session state cannot be tracked.\n\nInstall with: brew install jq"
    }
    static var ok: String {
        lang == .korean ? "확인" : "OK"
    }
    static var settingsWindowTitle: String {
        lang == .korean ? "claude-runner 설정" : "claude-runner Settings"
    }

    // MARK: - SettingsView — About

    static var version: String {
        lang == .korean ? "버전" : "Version"
    }
    static var checkForUpdates: String {
        lang == .korean ? "업데이트 확인" : "Check for Updates"
    }
    static var updateAvailable: String {
        lang == .korean ? "새 버전 사용 가능" : "Update Available"
    }
    static var upToDate: String {
        lang == .korean ? "최신 버전입니다" : "Up to date"
    }
    static var checking: String {
        lang == .korean ? "확인 중…" : "Checking…"
    }
    static var download: String {
        lang == .korean ? "다운로드" : "Download"
    }
    static var copyCommand: String {
        lang == .korean ? "명령어 복사" : "Copy Command"
    }
    static var copied: String {
        lang == .korean ? "복사됨" : "Copied!"
    }
    static var updateHint: String {
        lang == .korean ? "앱을 종료한 후 터미널에서 실행해주세요" : "Quit the app first, then run in terminal"
    }

    // MARK: - SessionState

    static func using(_ tool: String) -> String {
        lang == .korean ? "\(tool) 사용 중" : "Using \(tool)"
    }
}
