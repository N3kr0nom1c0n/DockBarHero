import AppKit
import SwiftUI

enum ManagementWindowSizing {
    static let initialContentSize = NSSize(width: 1_100, height: 720)
    static let minimumSize = NSSize(width: 720, height: 520)
}

struct InitialManagementWindowSizingGate {
    private var hasAppliedInitialSize = false

    mutating func shouldApplyInitialSize() -> Bool {
        guard !hasAppliedInitialSize else { return false }
        hasAppliedInitialSize = true
        return true
    }
}

enum AppLaunchOptions {
    static func managementRoute(arguments: [String]) -> ManagementRoute? {
        arguments.contains("--open-book") ? .book : nil
    }
}

@MainActor
protocol ApplicationActivationControlling: AnyObject {
    @discardableResult
    func setActivationPolicy(_ activationPolicy: NSApplication.ActivationPolicy) -> Bool
    func activate()
}

extension NSApplication: ApplicationActivationControlling {}

@MainActor
final class ManagementDockPresenceController {
    private let application: ApplicationActivationControlling

    init(application: ApplicationActivationControlling = NSApplication.shared) {
        self.application = application
    }

    func configureForLaunch() {
        application.setActivationPolicy(.accessory)
    }

    func managementWindowWillOpen() {
        application.setActivationPolicy(.regular)
        application.activate()
    }

    func managementWindowDidClose() {
        application.setActivationPolicy(.accessory)
    }

    func handleDockReopen(openManagementWindow: () -> Void) -> Bool {
        openManagementWindow()
        return true
    }
}

@MainActor
final class ManagementWindowController: NSWindowController, NSWindowDelegate {
    private let onOpen: () -> Void
    private let onClose: () -> Void
    private var initialSizingGate = InitialManagementWindowSizingGate()

    init(
        model: AppModel,
        dockPresence: ManagementDockPresenceController = ManagementDockPresenceController()
    ) {
        onOpen = { dockPresence.managementWindowWillOpen() }
        onClose = { [weak model, dockPresence] in
            model?.managementWindowDidClose()
            dockPresence.managementWindowDidClose()
        }
        let content = NSHostingController(rootView: ManagementRootView(model: model))
        content.sizingOptions = [.minSize]
        let window = NSWindow(contentViewController: content)
        window.title = "DockBarHero"
        window.setContentSize(ManagementWindowSizing.initialContentSize)
        window.minSize = ManagementWindowSizing.minimumSize
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func open() {
        onOpen()
        showWindow(nil)
        if initialSizingGate.shouldApplyInitialSize() {
            window?.setContentSize(ManagementWindowSizing.initialContentSize)
        }
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

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
    private let dockPresence = ManagementDockPresenceController()
    private let managementWindowController: ManagementWindowController
    private var terminationGate = TerminationRequestGate()

    override init() {
        let store = SaveStore(urls: .applicationSupport)
        let coordinator = SaveCoordinator(store: store)
        let driver = SimulationDriver()
        let session = GameSession(driver: driver, store: store, coordinator: coordinator)
        let settingsSession = SettingsSession(store: SettingsStore())
        let loreCatalog: LoreCatalog?
        let loreReader: any LoreReaderControlling
        do {
            let loadedLore = try LoreCatalog.bundled()
            let dialogue = try SpokenDialogueCatalog.bundled(loreCatalog: loadedLore)
            loreCatalog = loadedLore
            let loreSpeech: LoreSpeechControlling
            do {
                loreSpeech = try RecordedLoreSpeechService(bundle: .main, dialogue: dialogue)
            } catch {
                loreSpeech = SystemLoreSpeechService()
            }
            loreReader = LoreReaderController(dialogue: dialogue, speech: loreSpeech)
        } catch {
            loreCatalog = nil
            loreReader = SilentLoreReaderController()
            AppLog.lifecycle.error("Lore bootstrap failed: \(String(describing: error), privacy: .public)")
        }
        let model = AppModel(
            gameSession: session, settingsController: settingsSession,
            loreCatalog: loreCatalog, loreReader: loreReader
        )
        self.model = model
        managementWindowController = ManagementWindowController(model: model, dockPresence: dockPresence)
        super.init()
        model.onManagementWindowRequest = { [weak managementWindowController] in
            managementWindowController?.open()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        dockPresence.configureForLaunch()
        model.start()
        do {
            let scene = try PrototypeSceneHost()
            let window = OverlayWindowController(contentView: scene.view)
            let screen = AppKitScreenProvider()
            let monitor = EnvironmentMonitor(evaluator: WorkspaceEnvironmentEvaluator())
            model.connect(window: window, scene: scene, screen: screen, monitor: monitor)
            model.start()
            if let route = AppLaunchOptions.managementRoute(arguments: ProcessInfo.processInfo.arguments) {
                model.selectManagementRoute(route)
                managementWindowController.open()
            }
            AppLog.lifecycle.info("DockBarHero launched")
        } catch {
            AppLog.scene.error("Scene bootstrap failed: \(error.localizedDescription)")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        model.loreReader.applicationBecameActive()
    }

    func applicationDidResignActive(_ notification: Notification) {
        model.loreReader.applicationBecameInactive()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        dockPresence.handleDockReopen { managementWindowController.open() }
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

    func openManagementWindow() {
        managementWindowController.open()
    }
}
