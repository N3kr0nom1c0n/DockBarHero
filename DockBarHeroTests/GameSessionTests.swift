import XCTest
@testable import DockBarHero

@MainActor
final class GameSessionTests: XCTestCase {
    func testLoadFinishesBeforeDriverStartsAndDuplicateStartsAreIgnored() async {
        let loaded = state(autoEquip: false)
        let store = SessionStoreFake(result: SaveLoadResult(state: loaded, source: .primary), blockLoad: true)
        let driver = SessionDriverFake()
        let coordinator = SessionSaveCoordinatorFake()
        let session = makeSession(store: store, driver: driver, coordinator: coordinator)

        session.start()
        session.start()
        await store.waitForLoadStart()
        XCTAssertEqual(driver.startCount, 0)

        await store.finishLoad()
        await waitUntil { driver.startCount == 1 }

        XCTAssertEqual(driver.replacedStates, [loaded])
        XCTAssertEqual(driver.actions, ["replace", "start"])
    }

    func testProductionDriverPublishesLoadedStateInitialPresentationDuringStartup() async {
        let loaded = state(autoEquip: false)
        let store = SessionStoreFake(result: SaveLoadResult(state: loaded, source: .primary))
        let driver = SimulationDriver(now: { 1_000 })
        let coordinator = SessionSaveCoordinatorFake()
        let session = GameSession(
            driver: driver,
            store: store,
            coordinator: coordinator,
            newGame: state(autoEquip: true)
        )
        var presentations: [GamePresentation] = []
        session.onPresentation = { presentations.append($0) }

        session.start()
        await waitUntil { driver.currentState == loaded }

        XCTAssertEqual(presentations, [GameSimulation(state: loaded).presentation])
        await session.stopAndSave()
    }

    func testBackupLoadPublishesRecoveredStatusAndDoesNotAdvanceLoadedState() async {
        let loaded = state(autoEquip: false)
        let store = SessionStoreFake(result: SaveLoadResult(state: loaded, source: .backup))
        let driver = SessionDriverFake()
        let coordinator = SessionSaveCoordinatorFake()
        let session = makeSession(store: store, driver: driver, coordinator: coordinator)
        let statuses = GameStatusRecorder()
        session.onSaveStatus = { statuses.values.append($0) }

        session.start()
        await waitUntil { driver.startCount == 1 }

        XCTAssertEqual(driver.currentState, loaded)
        XCTAssertEqual(statuses.values, [SaveStatus.recovered])
    }

    func testUnsupportedVersionStatusRemainsVisibleAfterBackupRecovery() async {
        let loaded = state(autoEquip: false)
        let store = SessionStoreFake(result: SaveLoadResult(
            state: loaded,
            source: .backup,
            issue: .unsupportedVersion(99)
        ))
        let driver = SessionDriverFake()
        let coordinator = SessionSaveCoordinatorFake()
        let session = makeSession(store: store, driver: driver, coordinator: coordinator)
        let statuses = GameStatusRecorder()
        session.onSaveStatus = { statuses.values.append($0) }

        session.start()
        await waitUntil { driver.startCount == 1 }

        XCTAssertEqual(driver.currentState, loaded)
        XCTAssertEqual(statuses.values, [.unsupportedVersion(99)])
    }

    func testUnsupportedVersionStatusPublishesWhenLoadStartsNewGame() async {
        let newGame = state(autoEquip: true)
        let store = SessionStoreFake(result: SaveLoadResult(
            state: newGame,
            source: .newGame,
            issue: .unsupportedVersion(99)
        ))
        let driver = SessionDriverFake()
        let coordinator = SessionSaveCoordinatorFake()
        let session = makeSession(store: store, driver: driver, coordinator: coordinator)
        let statuses = GameStatusRecorder()
        session.onSaveStatus = { statuses.values.append($0) }

        session.start()
        await waitUntil { driver.startCount == 1 }

        XCTAssertEqual(statuses.values, [.unsupportedVersion(99)])
    }

    func testProductionCoordinatorStatusesReachSessionAndStopClearsObservation() async {
        let loaded = state(autoEquip: false)
        let store = SessionStatusStore(
            loadResult: SaveLoadResult(state: loaded, source: .backup),
            failingSaveAttempt: 2
        )
        let driver = SessionDriverFake()
        let savedAt = Date(timeIntervalSince1970: 456)
        let coordinator = SaveCoordinator(store: store, now: { savedAt })
        let session = GameSession(
            driver: driver,
            store: store,
            coordinator: coordinator,
            newGame: state(autoEquip: true)
        )
        let statuses = GameStatusRecorder()
        session.onSaveStatus = { statuses.values.append($0) }

        session.start()
        await waitUntil { driver.startCount == 1 }
        driver.emit([.victory(defeatedLevel: 1)])
        await waitUntil { statuses.values.count == 3 }
        driver.emit([.loot(Item(
            id: ItemID(rawValue: 1),
            level: 1,
            slot: .weapon,
            primaryStat: 1,
            creationSequence: 1
        ))])
        await waitUntil { statuses.values.count == 5 }

        XCTAssertEqual(statuses.values, [
            .recovered,
            .saving,
            .saved(savedAt),
            .saving,
            .failed("controlled status failure")
        ])

        await session.stopAndSave()
        await coordinator.flush(driver.currentState)
        XCTAssertEqual(statuses.values.count, 5)
    }

    func testOnlyDurableEventsRequestEventSaves() async {
        let store = SessionStoreFake(result: SaveLoadResult(state: state(autoEquip: true), source: .newGame))
        let driver = SessionDriverFake()
        let coordinator = SessionSaveCoordinatorFake()
        let session = makeSession(store: store, driver: driver, coordinator: coordinator)
        session.start()
        await waitUntil { driver.startCount == 1 }

        let durableEvents: [GameEvent] = [
            .victory(defeatedLevel: 1),
            .loot(Item(id: ItemID(rawValue: 1), level: 1, slot: .weapon, primaryStat: 1, creationSequence: 1)),
            .equipped(slot: .weapon, itemID: ItemID(rawValue: 1)),
            .autoEquipChanged(false)
        ]
        for event in durableEvents {
            driver.emit([event])
        }
        driver.emit([.attack(attacker: .hero, defender: .enemy, damage: 10)])
        await waitForSaveRequests(count: durableEvents.count, coordinator: coordinator)

        let requestedStates = await coordinator.requestedStates()
        XCTAssertEqual(requestedStates.count, durableEvents.count)
    }

    func testSuccessfulIntentRequestsLatestStateSave() async throws {
        let store = SessionStoreFake(result: SaveLoadResult(state: state(autoEquip: true), source: .newGame))
        let driver = SessionDriverFake()
        let coordinator = SessionSaveCoordinatorFake()
        let session = makeSession(store: store, driver: driver, coordinator: coordinator)
        session.start()
        await waitUntil { driver.startCount == 1 }

        try session.send(.setAutoEquip(false))
        await waitForSaveRequests(count: 1, coordinator: coordinator)

        let requestedStates = await coordinator.requestedStates()
        XCTAssertEqual(requestedStates.last?.autoEquipEnabled, false)
    }

    func testInjectedThirtySecondAutosaveRequestsCurrentState() async {
        let store = SessionStoreFake(result: SaveLoadResult(state: state(autoEquip: true), source: .newGame))
        let driver = SessionDriverFake()
        let coordinator = SessionSaveCoordinatorFake()
        let sleeper = AutosaveSleeper()
        let session = makeSession(
            store: store,
            driver: driver,
            coordinator: coordinator,
            autosaveInterval: .seconds(30),
            sleep: { duration in try await sleeper.sleep(for: duration) }
        )
        session.start()
        await waitUntil { driver.startCount == 1 }
        await sleeper.waitForDuration()
        let requestedDurations = await sleeper.requestedDurations()
        XCTAssertEqual(requestedDurations, [.seconds(30)])

        driver.currentState.autoEquipEnabled = false
        await sleeper.fireNext()
        await waitForSaveRequests(count: 1, coordinator: coordinator)

        let requestedStates = await coordinator.requestedStates()
        XCTAssertEqual(requestedStates.last?.autoEquipEnabled, false)
    }

    func testStopAndSaveStopsCancelsAndFlushesExactlyOnce() async {
        let store = SessionStoreFake(result: SaveLoadResult(state: state(autoEquip: true), source: .newGame))
        let driver = SessionDriverFake()
        let coordinator = SessionSaveCoordinatorFake()
        let sleeper = AutosaveSleeper()
        let session = makeSession(
            store: store,
            driver: driver,
            coordinator: coordinator,
            sleep: { duration in try await sleeper.sleep(for: duration) }
        )
        session.start()
        await waitUntil { driver.startCount == 1 }
        await sleeper.waitForDuration()

        await session.stopAndSave()
        await session.stopAndSave()

        XCTAssertEqual(driver.stopCount, 1)
        let flushedStates = await coordinator.flushedStates()
        XCTAssertEqual(flushedStates.count, 1)
        XCTAssertEqual(flushedStates.first, driver.currentState)
        let wasCancelled = await sleeper.wasCancelled()
        XCTAssertTrue(wasCancelled)
    }

    func testStopWaitsForBlockedRequestSubmissionBeforeFinalFlush() async {
        let store = SessionStoreFake(result: SaveLoadResult(state: state(autoEquip: true), source: .newGame))
        let driver = SessionDriverFake()
        let coordinator = BlockingSessionSaveCoordinator()
        let session = makeSession(store: store, driver: driver, coordinator: coordinator)
        session.start()
        await waitUntil { driver.startCount == 1 }

        driver.emit([.victory(defeatedLevel: 1)])
        await coordinator.waitForRequestStart()
        let completion = SessionCompletionRecorder()
        let stopTask = Task {
            await session.stopAndSave()
            await completion.markComplete()
        }
        await Task.yield()

        let didFlushBeforeRelease = await coordinator.didFlush()
        let didCompleteBeforeRelease = await completion.isComplete()
        XCTAssertFalse(didFlushBeforeRelease)
        XCTAssertFalse(didCompleteBeforeRelease)

        await coordinator.releaseRequest()
        await stopTask.value

        let events = await coordinator.events()
        XCTAssertEqual(events, ["request-start", "request-finish", "flush"])
    }

    func testCompletedSaveSubmissionsAreReleasedDuringHighVolumeSteadyState() async {
        let store = SessionStoreFake(result: SaveLoadResult(state: state(autoEquip: true), source: .newGame))
        let driver = SessionDriverFake()
        let coordinator = SessionSaveCoordinatorFake()
        let session = makeSession(store: store, driver: driver, coordinator: coordinator)
        session.start()
        await waitUntil { driver.startCount == 1 }

        for level in 1...500 {
            driver.emit([.victory(defeatedLevel: level)])
        }
        await waitUntil { session.outstandingSaveSubmissionCount == 0 }

        let requestedStates = await coordinator.requestedStates()
        XCTAssertEqual(requestedStates.count, 500)
        XCTAssertEqual(session.outstandingSaveSubmissionCount, 0)
    }

    func testStopDuringLoadFlushesLoadedStateWithoutStartingDriver() async {
        let loaded = state(autoEquip: false)
        let store = SessionStoreFake(result: SaveLoadResult(state: loaded, source: .primary), blockLoad: true)
        let driver = SessionDriverFake()
        let coordinator = SessionSaveCoordinatorFake()
        let session = makeSession(store: store, driver: driver, coordinator: coordinator)

        session.start()
        await store.waitForLoadStart()
        let stopTask = Task { await session.stopAndSave() }
        await Task.yield()
        await store.finishLoad()
        await stopTask.value

        XCTAssertEqual(driver.startCount, 0)
        XCTAssertEqual(driver.replacedStates, [])
        let flushedStates = await coordinator.flushedStates()
        XCTAssertEqual(flushedStates, [loaded])
    }

    private func makeSession(
        store: SessionStoreFake,
        driver: SessionDriverFake,
        coordinator: any SaveCoordinating,
        autosaveInterval: Duration = .seconds(30),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { duration in
            try await Task.sleep(for: duration)
        }
    ) -> GameSession {
        GameSession(
            driver: driver,
            store: store,
            coordinator: coordinator,
            newGame: state(autoEquip: true),
            autosaveInterval: autosaveInterval,
            sleep: sleep
        )
    }

    private func state(autoEquip: Bool) -> GameState {
        var state = GameState.newGame(balance: .standard)
        state.autoEquipEnabled = autoEquip
        return state
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<1_000 {
            if condition() { return }
            await Task.yield()
        }
        XCTFail("Condition did not become true", file: file, line: line)
    }

    private func waitForSaveRequests(count: Int, coordinator: SessionSaveCoordinatorFake) async {
        for _ in 0..<100 {
            if await coordinator.requestedStates().count >= count { return }
            await Task.yield()
        }
        XCTFail("Expected at least \(count) save requests")
    }
}

@MainActor
private final class GameStatusRecorder {
    var values: [SaveStatus] = []
}

actor SessionCompletionRecorder {
    private var complete = false

    func markComplete() {
        complete = true
    }

    func isComplete() -> Bool {
        complete
    }
}

@MainActor
private final class SessionDriverFake: SimulationDriving {
    var onPresentation: ((GamePresentation) -> Void)?
    var onEvents: (([GameEvent]) -> Void)?
    var currentState: GameState
    var actions: [String] = []
    var replacedStates: [GameState] = []
    var startCount = 0
    var stopCount = 0

    init(state: GameState = .newGame(balance: .standard)) {
        currentState = state
    }

    func start() {
        actions.append("start")
        startCount += 1
    }

    func stop() {
        actions.append("stop")
        stopCount += 1
    }

    func replaceState(_ state: GameState) {
        actions.append("replace")
        currentState = state
        replacedStates.append(state)
    }

    func send(_ intent: GameIntent) throws {
        switch intent {
        case .setAutoEquip(let enabled):
            currentState.autoEquipEnabled = enabled
            onEvents?([.autoEquipChanged(enabled)])
        case .equip:
            break
        }
        onPresentation?(GameSimulation(state: currentState).presentation)
    }

    func emit(_ events: [GameEvent]) {
        onEvents?(events)
    }
}

actor SessionStoreFake: SaveStoring {
    private let result: SaveLoadResult
    private let blockLoad: Bool
    private var loadStarted = false
    private var loadContinuation: CheckedContinuation<SaveLoadResult, Never>?
    private var loadWaiters: [CheckedContinuation<Void, Never>] = []

    init(result: SaveLoadResult, blockLoad: Bool = false) {
        self.result = result
        self.blockLoad = blockLoad
    }

    func load(newGame: GameState) async -> SaveLoadResult {
        loadStarted = true
        let waiters = loadWaiters
        loadWaiters.removeAll()
        waiters.forEach { $0.resume() }
        guard blockLoad else { return result }
        return await withCheckedContinuation { continuation in
            loadContinuation = continuation
        }
    }

    func save(_ state: GameState) async throws {}

    func waitForLoadStart() async {
        if loadStarted { return }
        await withCheckedContinuation { continuation in
            loadWaiters.append(continuation)
        }
    }

    func finishLoad() {
        loadContinuation?.resume(returning: result)
        loadContinuation = nil
    }
}

actor SessionStatusStore: SaveStoring {
    private let loadResult: SaveLoadResult
    private let failingSaveAttempt: Int
    private var saveAttempt = 0

    init(loadResult: SaveLoadResult, failingSaveAttempt: Int) {
        self.loadResult = loadResult
        self.failingSaveAttempt = failingSaveAttempt
    }

    func load(newGame: GameState) async -> SaveLoadResult {
        loadResult
    }

    func save(_ state: GameState) async throws {
        saveAttempt += 1
        if saveAttempt == failingSaveAttempt {
            throw SessionStatusError.failure
        }
    }
}

private enum SessionStatusError: Error, CustomStringConvertible {
    case failure

    var description: String { "controlled status failure" }
}

actor SessionSaveCoordinatorFake: SaveCoordinating {
    private var requests: [GameState] = []
    private var flushes: [GameState] = []

    func request(_ state: GameState) async {
        requests.append(state)
    }

    func flush(_ state: GameState) async {
        flushes.append(state)
    }

    func requestedStates() -> [GameState] { requests }
    func flushedStates() -> [GameState] { flushes }
}

actor BlockingSessionSaveCoordinator: SaveCoordinating {
    private var recordedEvents: [String] = []
    private var requestContinuation: CheckedContinuation<Void, Never>?
    private var requestStarted = false
    private var requestStartWaiters: [CheckedContinuation<Void, Never>] = []

    func request(_ state: GameState) async {
        recordedEvents.append("request-start")
        requestStarted = true
        let waiters = requestStartWaiters
        requestStartWaiters.removeAll()
        waiters.forEach { $0.resume() }
        await withCheckedContinuation { continuation in
            requestContinuation = continuation
        }
        recordedEvents.append("request-finish")
    }

    func flush(_ state: GameState) async {
        recordedEvents.append("flush")
    }

    func waitForRequestStart() async {
        if requestStarted { return }
        await withCheckedContinuation { continuation in
            requestStartWaiters.append(continuation)
        }
    }

    func releaseRequest() {
        requestContinuation?.resume()
        requestContinuation = nil
    }

    func didFlush() -> Bool {
        recordedEvents.contains("flush")
    }

    func events() -> [String] {
        recordedEvents
    }
}

actor AutosaveSleeper {
    private var durations: [Duration] = []
    private var continuation: CheckedContinuation<Void, Error>?
    private var durationWaiters: [CheckedContinuation<Void, Never>] = []
    private var cancelled = false

    func sleep(for duration: Duration) async throws {
        durations.append(duration)
        let waiters = durationWaiters
        durationWaiters.removeAll()
        waiters.forEach { $0.resume() }
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
            }
        }, onCancel: {
            Task { await self.cancel() }
        })
    }

    func waitForDuration() async {
        if !durations.isEmpty { return }
        await withCheckedContinuation { continuation in
            durationWaiters.append(continuation)
        }
    }

    func requestedDurations() -> [Duration] { durations }

    func fireNext() {
        continuation?.resume()
        continuation = nil
    }

    func wasCancelled() -> Bool { cancelled }

    private func cancel() {
        cancelled = true
        continuation?.resume(throwing: CancellationError())
        continuation = nil
    }
}
