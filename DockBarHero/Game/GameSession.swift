import Foundation

enum RunPresentation: Equatable, Sendable {
    case classSelection
    case active(GamePresentation)
}

@MainActor
protocol GameSessionControlling: AnyObject {
    var onPresentation: ((GamePresentation) -> Void)? { get set }
    var onRunState: ((RunPresentation) -> Void)? { get set }
    var onEvents: (([GameEvent]) -> Void)? { get set }
    var onSaveStatus: ((SaveStatus) -> Void)? { get set }
    func start()
    func send(_ intent: GameIntent) throws
    func chooseStartingClass(_ classID: HeroClassID) async throws
    func startNewGame() async throws
    func stopAndSave() async
}

extension GameSessionControlling {
    var onRunState: ((RunPresentation) -> Void)? {
        get { nil }
        set { }
    }

    func chooseStartingClass(_ classID: HeroClassID) async throws { }
    func startNewGame() async throws { }
}

@MainActor
final class GameSession: GameSessionControlling {
    var onPresentation: ((GamePresentation) -> Void)?
    var onRunState: ((RunPresentation) -> Void)?
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
    private var startupTask: Task<SaveLoadResult?, Never>?
    private var autosaveTask: Task<Void, Never>?
    private(set) var outstandingSaveSubmissionCount = 0
    private var saveSubmissionWaiters: [CheckedContinuation<Void, Never>] = []
    private var stopWaiters: [CheckedContinuation<Void, Never>] = []
    private var intentEventRequestedSave = false
    private var currentRunState: RunState = .classSelection

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
            guard let self else { return nil }
            guard self.canContinueStartup(startGeneration) else { return nil }
            if let statusObserver = self.statusObserver {
                await statusObserver.setStatusHandler { @MainActor [weak self] status in
                    self?.receive(status, generation: startGeneration)
                }
            }
            guard self.canContinueStartup(startGeneration) else { return nil }
            let result = await self.store.load()
            self.finishStart(result, generation: startGeneration)
            return result
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

    func chooseStartingClass(_ classID: HeroClassID) async throws {
        guard hasStarted, !isStopping, !hasStopped, currentRunState == .classSelection else { return }
        let state = GameState.newGame(
            classID: classID,
            balance: .standard,
            progression: .standard
        )
        do {
            try await store.replaceRun(with: .active(state))
            currentRunState = .active(state)
            startActive(state, generation: generation)
        } catch {
            receive(.failed(String(describing: error)), generation: generation)
            throw error
        }
    }

    func startNewGame() async throws {
        guard hasStarted, !isStopping, !hasStopped else { return }
        let oldState = currentRunState
        autosaveTask?.cancel()
        autosaveTask = nil
        isRunning = false
        driver.stop()
        await waitForSaveSubmissions()

        do {
            try await store.replaceRun(with: .classSelection)
            currentRunState = .classSelection
            onRunState?(.classSelection)
        } catch {
            if case let .active(state) = oldState {
                currentRunState = oldState
                startActive(state, generation: generation)
            }
            receive(.failed(String(describing: error)), generation: generation)
            throw error
        }
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
        let pendingStartupTask = startupTask
        pendingStartupTask?.cancel()
        startupTask = nil
        autosaveTask?.cancel()
        autosaveTask = nil
        driver.stop()

        let startupResult = await pendingStartupTask?.value
        await waitForSaveSubmissions()
        let finalRunState = startupResult?.runState ?? currentRunState
        await coordinator.flush(finalRunState)
        await statusObserver?.setStatusHandler(nil)

        hasStopped = true
        isStopping = false
        let waiters = stopWaiters
        stopWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    private func finishStart(_ result: SaveLoadResult, generation startGeneration: UInt64) {
        guard canContinueStartup(startGeneration) else { return }

        if case let .unsupportedVersion(version) = result.issue {
            receive(.unsupportedVersion(version), generation: startGeneration)
        } else if result.source == .backup {
            receive(.recovered, generation: startGeneration)
        }
        currentRunState = result.runState
        switch result.runState {
        case .classSelection:
            isRunning = false
            onRunState?(.classSelection)
        case let .active(state):
            startActive(state, generation: startGeneration)
        }
        startupTask = nil
    }

    private func startActive(_ state: GameState, generation activeGeneration: UInt64) {
        driver.onPresentation = { @MainActor [weak self] presentation in
            self?.receive(presentation, generation: activeGeneration)
        }
        driver.onEvents = { @MainActor [weak self] events in
            self?.receive(events, generation: activeGeneration)
        }
        driver.replaceState(state)
        isRunning = true
        driver.start()
        autosaveTask?.cancel()
        autosaveTask = Task { @MainActor [weak self] in
            await self?.runAutosave(generation: activeGeneration)
        }
    }

    private func receive(_ presentation: GamePresentation, generation callbackGeneration: UInt64) {
        guard isActive(callbackGeneration) else { return }
        onPresentation?(presentation)
        onRunState?(.active(presentation))
        currentRunState = .active(presentation.state)
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
        case .victory, .loot, .xpGained, .heroLeveled, .goldGained, .equipped,
             .autoEquipChanged, .destinationQueued, .farmingStarted, .returnedToFrontier:
            return true
        case .attack, .defeat, .revived:
            return false
        }
    }

    private func requestSave() {
        guard isRunning, !isStopping, !hasStopped else { return }

        let runState = RunState.active(driver.currentState)
        let coordinator = coordinator
        outstandingSaveSubmissionCount += 1
        Task { @MainActor [weak self] in
            await coordinator.request(runState)
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
