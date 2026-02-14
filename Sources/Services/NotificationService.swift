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

        // Permission: 0 → 1+ (most urgent)
        if oldCounts.permissionCount == 0 && newCounts.permissionCount > 0 {
            let body = newCounts.permissionCount == 1
                ? "1 session needs approval"
                : "\(newCounts.permissionCount) sessions need approval"
            let sessionId = sessions.first(where: { $0.state == .permission })?.sessionId
            send(title: "Needs Approval", body: body, sessionId: sessionId)
            return
        }

        // Waiting: 0 → 1+ (user input needed)
        if oldCounts.waitingCount == 0 && newCounts.waitingCount > 0 {
            let body = newCounts.waitingCount == 1
                ? "1 session is waiting for input"
                : "\(newCounts.waitingCount) sessions waiting for input"
            let sessionId = sessions.first(where: { $0.state == .waiting })?.sessionId
            send(title: "Waiting for Input", body: body, sessionId: sessionId)
            return
        }
    }

    private func send(title: String, body: String, sessionId: String?) {
        // System notification (if available)
        if let center = center, isAvailable {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            if let sessionId = sessionId {
                content.userInfo = ["sessionId": sessionId]
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
        }
        completionHandler()
    }
}
