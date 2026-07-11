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

    func testStopBeforeLoadPreventsLateLoadFromStartingDriver() async {
        let loaded = state(autoEquip: false)
        let store = SessionStoreFake(result: SaveLoadResult(state: loaded, source: .primary), blockLoad: true)
        let driver = SessionDriverFake()
        let coordinator = SessionSaveCoordinatorFake()
        let session = makeSession(store: store, driver: driver, coordinator: coordinator)

        session.start()
        await store.waitForLoadStart()
        await session.stopAndSave()
        await store.finishLoad()
        await Task.yield()

        XCTAssertEqual(driver.startCount, 0)
        XCTAssertEqual(driver.replacedStates, [])
        let flushedStates = await coordinator.flushedStates()
        XCTAssertEqual(flushedStates.count, 1)
    }

    private func makeSession(
        store: SessionStoreFake,
        driver: SessionDriverFake,
        coordinator: SessionSaveCoordinatorFake,
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
        for _ in 0..<100 {
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
