import ServiceManagement

/// Protocol for login item management, enabling test mocking.
protocol LoginItemManaging {
    func register() throws
    func unregister() throws
    var isEnabled: Bool { get }
}

/// Manages the app's login item registration via SMAppService.
final class LoginItemManager: LoginItemManaging {
    static let shared = LoginItemManager()

    private let service = SMAppService.mainApp

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
    }

    var isEnabled: Bool {
        service.status == .enabled
    }
}
