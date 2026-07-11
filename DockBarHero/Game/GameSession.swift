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
    private var saveRequestTasks: [Task<Void, Never>] = []
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

        let finalState = driver.currentState
        let requestTasks = saveRequestTasks
        saveRequestTasks.removeAll()
        for task in requestTasks {
            await task.value
        }
        await coordinator.flush(finalState)

        hasStopped = true
        isStopping = false
        let waiters = stopWaiters
        stopWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    private func finishStart(_ result: SaveLoadResult, generation startGeneration: UInt64) {
        guard !Task.isCancelled,
              startGeneration == generation,
              hasStarted,
              !isStopping,
              !hasStopped else { return }

        driver.onPresentation = { @MainActor [weak self] presentation in
            self?.receive(presentation, generation: startGeneration)
        }
        driver.onEvents = { @MainActor [weak self] events in
            self?.receive(events, generation: startGeneration)
        }
        driver.replaceState(result.state)
        if result.source == .backup {
            onSaveStatus?(.recovered)
        }
        driver.start()
        isRunning = true
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

    private func shouldSave(for event: GameEvent) -> Bool {
        switch event {
        case .victory, .loot, .equipped, .autoEquipChanged:
            return true
        case .attack, .defeat, .revived:
            return false
        }
    }

    private func requestSave() {
        let state = driver.currentState
        let coordinator = coordinator
        let task = Task {
            await coordinator.request(state)
        }
        saveRequestTasks.append(task)
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
}
