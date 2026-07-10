import AppKit

@MainActor
protocol EnvironmentScheduling: AnyObject {
    func schedule(_ operation: @escaping @MainActor @Sendable () -> Void)
    func cancel()
}

@MainActor
final class MainQueueEnvironmentScheduler: EnvironmentScheduling {
    private var task: Task<Void, Never>?

    func schedule(_ operation: @escaping @MainActor @Sendable () -> Void) {
        task?.cancel()
        task = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            operation()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

@MainActor
protocol EnvironmentMonitoring: AnyObject {
    var onVisibilityChange: (@MainActor (EnvironmentVisibility) -> Void)? { get set }
    var onGeometryChange: (@MainActor () -> Void)? { get set }
    func start()
    func stop()
}

@MainActor
final class EnvironmentMonitor: NSObject, EnvironmentMonitoring {
    var onVisibilityChange: (@MainActor (EnvironmentVisibility) -> Void)?
    var onGeometryChange: (@MainActor () -> Void)?

    private let evaluator: EnvironmentEvaluating
    private let scheduler: EnvironmentScheduling
    private var started = false
    private var geometryDirty = false

    init(
        evaluator: EnvironmentEvaluating,
        scheduler: EnvironmentScheduling = MainQueueEnvironmentScheduler()
    ) {
        self.evaluator = evaluator
        self.scheduler = scheduler
    }

    func start() {
        guard !started else { return }
        started = true
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(self, selector: #selector(handleEnvironmentNotification), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        workspaceCenter.addObserver(self, selector: #selector(handleEnvironmentNotification), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        workspaceCenter.addObserver(self, selector: #selector(handleWakeNotification), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleGeometryNotification), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        environmentDidChange()
    }

    func stop() {
        guard started else { return }
        started = false
        scheduler.cancel()
        geometryDirty = false
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    func environmentDidChange() {
        scheduler.schedule { [weak self] in
            guard let self else { return }
            if self.geometryDirty {
                self.geometryDirty = false
                self.onGeometryChange?()
            }
            if let visibility = self.evaluator.currentVisibility() {
                AppLog.environment.debug("Environment visibility changed")
                self.onVisibilityChange?(visibility)
            }
        }
    }

    func geometryDidChange() {
        geometryDirty = true
        environmentDidChange()
    }

    @objc private func handleEnvironmentNotification(_ notification: Notification) {
        environmentDidChange()
    }

    @objc private func handleWakeNotification(_ notification: Notification) {
        geometryDidChange()
    }

    @objc private func handleGeometryNotification(_ notification: Notification) {
        geometryDidChange()
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }
}
