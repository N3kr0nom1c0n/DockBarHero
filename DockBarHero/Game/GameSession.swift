import Foundation

@MainActor
protocol GameSessionControlling: AnyObject {
    var onPresentation: ((GamePresentation) -> Void)? { get set }
    var onEvents: (([GameEvent]) -> Void)? { get set }
    var onSaveStatus: ((SaveStatus) -> Void)? { get set }
    func start()
    func send(_ intent: GameIntent) throws
    func stopAndSave() async
}

@MainActor
final class GameSession: GameSessionControlling {
    var onPresentation: ((GamePresentation) -> Void)?
    var onEvents: (([GameEvent]) -> Void)?
    var onSaveStatus: ((SaveStatus) -> Void)?

    private let driver: any SimulationDriving
    private let store: any SaveStoring
    private let coordinator: any SaveCoordinating
    private let statusObserver: (any SaveStatusObserving)?
    private let newGame: GameState
    private let autosaveInterval: Duration
    private let sleep: @Sendable (Duration) async throws -> Void

    private var hasStarted = false
    private var isRunning = false
    private var isStopping = false
    private var hasStopped = false
    private var generation: UInt64 = 0
    private var startupTask: Task<Void, Never>?
    private var autosaveTask: Task<Void, Never>?
    private(set) var outstandingSaveSubmissionCount = 0
    private var saveSubmissionWaiters: [CheckedContinuation<Void, Never>] = []
    private var stopWaiters: [CheckedContinuation<Void, Never>] = []
    private var intentEventRequestedSave = false

    init(
        driver: any SimulationDriving,
        store: any SaveStoring,
        coordinator: any SaveCoordinating,
        newGame: GameState = .newGame(balance: .standard),
        autosaveInterval: Duration = .seconds(30),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { duration in
            try await Task.sleep(for: duration)
        }
    ) {
        self.driver = driver
        self.store = store
        self.coordinator = coordinator
        self.statusObserver = coordinator as? any SaveStatusObserving
        self.newGame = newGame
        self.autosaveInterval = autosaveInterval
        self.sleep = sleep
    }

    func start() {
        guard !hasStarted, !isStopping, !hasStopped else { return }

        hasStarted = true
        generation &+= 1
        let startGeneration = generation
        startupTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard self.canContinueStartup(startGeneration) else { return }
            if let statusObserver = self.statusObserver {
                await statusObserver.setStatusHandler { @MainActor [weak self] status in
                    self?.receive(status, generation: startGeneration)
                }
            }
            guard self.canContinueStartup(startGeneration) else { return }
            let result = await self.store.load(newGame: self.newGame)
            self.finishStart(result, generation: startGeneration)
        }
    }

    func send(_ intent: GameIntent) throws {
        guard isRunning, !isStopping, !hasStopped else { return }

        let previousState = driver.currentState
        intentEventRequestedSave = false
        defer { intentEventRequestedSave = false }
        try driver.send(intent)

        guard previousState != driver.currentState,
              !intentEventRequestedSave else { return }
        requestSave()
    }

    func stopAndSave() async {
        guard !hasStopped else { return }
        if isStopping {
            await withCheckedContinuation { continuation in
                stopWaiters.append(continuation)
            }
            return
        }

        isStopping = true
        hasStarted = false
        isRunning = false
        generation &+= 1
        startupTask?.cancel()
        startupTask = nil
        autosaveTask?.cancel()
        autosaveTask = nil
        driver.stop()

        await waitForSaveSubmissions()
        let finalState = driver.currentState
        await coordinator.flush(finalState)
        await statusObserver?.setStatusHandler(nil)

        hasStopped = true
        isStopping = false
        let waiters = stopWaiters
        stopWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    private func finishStart(_ result: SaveLoadResult, generation startGeneration: UInt64) {
        guard canContinueStartup(startGeneration) else { return }

        driver.onPresentation = { @MainActor [weak self] presentation in
            self?.receive(presentation, generation: startGeneration)
        }
        driver.onEvents = { @MainActor [weak self] events in
            self?.receive(events, generation: startGeneration)
        }
        driver.replaceState(result.state)
        if case let .unsupportedVersion(version) = result.issue {
            receive(.unsupportedVersion(version), generation: startGeneration)
        }
        if result.source == .backup {
            receive(.recovered, generation: startGeneration)
        }
        isRunning = true
        driver.start()
        startupTask = nil
        autosaveTask = Task { @MainActor [weak self] in
            await self?.runAutosave(generation: startGeneration)
        }
    }

    private func receive(_ presentation: GamePresentation, generation callbackGeneration: UInt64) {
        guard isActive(callbackGeneration) else { return }
        onPresentation?(presentation)
    }

    private func receive(_ events: [GameEvent], generation callbackGeneration: UInt64) {
        guard isActive(callbackGeneration) else { return }
        onEvents?(events)
        guard events.contains(where: shouldSave(for:)) else { return }
        intentEventRequestedSave = true
        requestSave()
    }

    private func receive(_ status: SaveStatus, generation callbackGeneration: UInt64) {
        guard callbackGeneration == generation,
              hasStarted,
              !isStopping,
              !hasStopped else { return }
        onSaveStatus?(status)
    }

    private func shouldSave(for event: GameEvent) -> Bool {
        switch event {
        case .victory, .loot, .equipped, .autoEquipChanged:
            return true
        case .attack, .defeat, .revived:
            return false
        }
    }

    private func requestSave() {
        guard isRunning, !isStopping, !hasStopped else { return }

        let state = driver.currentState
        let coordinator = coordinator
        outstandingSaveSubmissionCount += 1
        Task { @MainActor [weak self] in
            await coordinator.request(state)
            self?.saveSubmissionCompleted()
        }
    }

    private func saveSubmissionCompleted() {
        precondition(outstandingSaveSubmissionCount > 0)
        outstandingSaveSubmissionCount -= 1
        guard outstandingSaveSubmissionCount == 0 else { return }

        let waiters = saveSubmissionWaiters
        saveSubmissionWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    private func waitForSaveSubmissions() async {
        guard outstandingSaveSubmissionCount > 0 else { return }
        await withCheckedContinuation { continuation in
            saveSubmissionWaiters.append(continuation)
        }
    }

    private func runAutosave(generation autosaveGeneration: UInt64) async {
        while !Task.isCancelled {
            do {
                try await sleep(autosaveInterval)
            } catch {
                return
            }

            guard !Task.isCancelled, isActive(autosaveGeneration) else { return }
            requestSave()
        }
    }

    private func isActive(_ callbackGeneration: UInt64) -> Bool {
        callbackGeneration == generation && isRunning && !isStopping && !hasStopped
    }

    private func canContinueStartup(_ startupGeneration: UInt64) -> Bool {
        !Task.isCancelled
            && startupGeneration == generation
            && hasStarted
            && !isStopping
            && !hasStopped
    }
}
