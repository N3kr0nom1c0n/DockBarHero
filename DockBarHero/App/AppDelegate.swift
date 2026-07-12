import AppKit

struct TerminationRequestGate {
    enum Decision: Equatable {
        case startAndWait
        case wait
        case terminateNow
    }

    private enum State {
        case ready
        case pending
        case replied
    }

    private var state: State = .ready

    mutating func request() -> Decision {
        switch state {
        case .ready:
            state = .pending
            return .startAndWait
        case .pending:
            return .wait
        case .replied:
            return .terminateNow
        }
    }

    mutating func markReplyIssued() -> Bool {
        guard state == .pending else { return false }
        state = .replied
        return true
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model: AppModel
    private var terminationGate = TerminationRequestGate()

    override init() {
        let store = SaveStore(urls: .applicationSupport)
        let coordinator = SaveCoordinator(store: store)
        let driver = SimulationDriver()
        let session = GameSession(driver: driver, store: store, coordinator: coordinator)
        let settingsSession = SettingsSession(store: SettingsStore())
        model = AppModel(gameSession: session, settingsController: settingsSession)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        model.start()
        do {
            let scene = try PrototypeSceneHost()
            let window = OverlayWindowController(contentView: scene.view)
            let screen = AppKitScreenProvider()
            let monitor = EnvironmentMonitor(evaluator: WorkspaceEnvironmentEvaluator())
            model.connect(window: window, scene: scene, screen: screen, monitor: monitor)
            model.start()
            AppLog.lifecycle.info("DockBarHero launched")
        } catch {
            AppLog.scene.error("Scene bootstrap failed: \(error.localizedDescription)")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        switch terminationGate.request() {
        case .startAndWait:
            Task { @MainActor in
                let outcome = await Self.waitForSaveOrTimeout {
                    await self.model.stopAndSave()
                }
                switch outcome {
                case .completed:
                    AppLog.lifecycle.info("Clean termination save completed")
                case .timedOut:
                    AppLog.lifecycle.error("Clean termination save timed out")
                }
                sender.reply(toApplicationShouldTerminate: true)
                precondition(self.terminationGate.markReplyIssued())
            }
            return .terminateLater
        case .wait:
            return .terminateLater
        case .terminateNow:
            return .terminateNow
        }
    }

    enum TerminationOutcome: Equatable {
        case completed
        case timedOut
    }

    static func waitForSaveOrTimeout(
        timeout: Duration = .seconds(5),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { duration in
            try await Task.sleep(for: duration)
        },
        save: @escaping @MainActor () async -> Void
    ) async -> TerminationOutcome {
        let race = TerminationRace()
        let saveTask = Task { @MainActor in
            await save()
            race.finish(.completed)
        }
        let timeoutTask = Task {
            do {
                try await sleep(timeout)
                race.finish(.timedOut)
            } catch {
                // The losing timeout task is canceled after the save completes.
            }
        }
        let outcome = await withCheckedContinuation { continuation in
            race.install(continuation)
        }
        saveTask.cancel()
        timeoutTask.cancel()
        return outcome
    }

    private final class TerminationRace: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<TerminationOutcome, Never>?
        private var outcome: TerminationOutcome?

        func install(_ continuation: CheckedContinuation<TerminationOutcome, Never>) {
            lock.lock()
            if let outcome {
                lock.unlock()
                continuation.resume(returning: outcome)
            } else {
                self.continuation = continuation
                lock.unlock()
            }
        }

        func finish(_ outcome: TerminationOutcome) {
            lock.lock()
            guard self.outcome == nil else {
                lock.unlock()
                return
            }
            self.outcome = outcome
            let continuation = self.continuation
            self.continuation = nil
            lock.unlock()
            continuation?.resume(returning: outcome)
        }
    }

    func send(_ action: OverlayAction) {
        model.send(action)
    }
}
