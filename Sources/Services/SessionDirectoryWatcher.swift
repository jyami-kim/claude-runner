import Foundation

/// Watches the sessions/ directory for file changes using kqueue (DispatchSource).
/// Falls back to polling if kqueue fails.
final class SessionDirectoryWatcher {
    private let sessionsURL: URL
    private var source: DispatchSourceFileSystemObject?
    private var debounceWork: DispatchWorkItem?
    private var pollingTimer: Timer?
    private let debounceInterval: TimeInterval = 0.1
    private var onChange: (() -> Void)?

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        sessionsURL = appSupport.appendingPathComponent("claude-runner/sessions", isDirectory: true)
        try? FileManager.default.createDirectory(at: sessionsURL, withIntermediateDirectories: true)
    }

    func start(onChange: @escaping () -> Void) {
        self.onChange = onChange

        let fd = open(sessionsURL.path, O_EVTONLY)
        guard fd >= 0 else {
            startPolling()
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .attrib],
            queue: .global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            self?.scheduleReload()
        }

        source.setCancelHandler {
            close(fd)
        }

        self.source = source
        source.resume()

    }

    func stop() {
        source?.cancel()
        source = nil
        debounceWork?.cancel()
        debounceWork = nil
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func scheduleReload() {
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.onChange?()
        }
        debounceWork = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    private func startPolling() {
        DispatchQueue.main.async { [weak self] in
            self?.pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.onChange?()
            }
        }
    }
}
