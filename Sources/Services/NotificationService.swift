import AppKit
import UserNotifications

/// Protocol for notification sending, enabling test mocking.
protocol NotificationSending {
    func notify(oldCounts: StateCounts, newCounts: StateCounts, sessions: [SessionEntry])
}

/// Manages macOS user notifications for session state changes.
///
/// Sends alerts when:
/// - permission count increases from 0 (needs approval)
/// - waiting count increases from 0 (ready for input)
/// Active-only changes are silent.
/// Clicking a notification focuses the corresponding terminal app.
final class NotificationService: NSObject, UNUserNotificationCenterDelegate, NotificationSending {
    static let shared = NotificationService()

    private var center: UNUserNotificationCenter?
    private let settings: AppSettings
    private var isAvailable = false

    init(settings: AppSettings = .shared) {
        self.settings = settings
        super.init()
    }

    /// Sets up notification delegate and requests permission. Call once at app launch.
    func setup() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let unc = UNUserNotificationCenter.current()
        unc.delegate = self
        unc.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            self?.isAvailable = granted
        }
        center = unc
    }

    /// Compares old and new counts, sending a notification if a notable state change occurred.
    func notify(oldCounts: StateCounts, newCounts: StateCounts, sessions: [SessionEntry]) {
        guard settings.notifyOnStateChange else { return }
        guard oldCounts != newCounts else { return }

        // Permission: count increased (most urgent)
        if newCounts.permissionCount > 0 && newCounts.permissionCount > oldCounts.permissionCount {
            let session = sessions.first(where: { $0.state == .permission })
            var body = newCounts.permissionCount == 1
                ? Strings.notifPermissionSingle
                : Strings.notifPermissionPlural(newCounts.permissionCount)
            if let activity = session?.activityText {
                body += "\n\(activity)"
            }
            send(title: Strings.notifPermissionTitle, body: body,
                 sessionId: session?.sessionId, bundleId: session?.terminalBundleId)
            return
        }

        // Waiting: count increased (a session finished and needs input)
        if newCounts.waitingCount > 0 && newCounts.waitingCount > oldCounts.waitingCount {
            let session = sessions.first(where: { $0.state == .waiting })
            var body = newCounts.waitingCount == 1
                ? Strings.notifWaitingSingle
                : Strings.notifWaitingPlural(newCounts.waitingCount)
            if let activity = session?.activityText {
                body += "\n\(activity)"
            }
            send(title: Strings.notifWaitingTitle, body: body,
                 sessionId: session?.sessionId, bundleId: session?.terminalBundleId)
            return
        }
    }

    private func send(title: String, body: String, sessionId: String?, bundleId: String? = nil) {
        // System notification (if available)
        if let center = center, isAvailable {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            var userInfo: [String: String] = [:]
            if let sessionId = sessionId {
                userInfo["sessionId"] = sessionId
            }
            if let bundleId = bundleId {
                userInfo["terminalBundleId"] = bundleId
            }
            if !userInfo.isEmpty {
                content.userInfo = userInfo
            }

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            center.add(request)
        } else {
            // Fallback: system sound only
            NSSound.beep()
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show notifications even when the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// Handle notification click → focus the terminal app for the session.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let sessionId = userInfo["sessionId"] as? String,
           let session = StateStore.shared.sessions.first(where: { $0.sessionId == sessionId }) {
            DispatchQueue.main.async {
                TerminalFocuser.focus(session: session)
            }
        } else if let bundleId = userInfo["terminalBundleId"] as? String {
            // Fallback: session may have been removed, but we still know the terminal app
            DispatchQueue.main.async {
                TerminalFocuser.activateApp(bundleID: bundleId)
            }
        }
        completionHandler()
    }
}
