import XCTest
@testable import DockBarHero

@MainActor
final class SaveCoordinatorTests: XCTestCase {
    func testRequestsDuringAnInFlightSavePersistFirstAndLatestOnly() async {
        let first = state(autoEquip: true)
        let middle = state(autoEquip: false)
        let latest = state(autoEquip: true)
        let store = ControlledSaveStore(blockFirstSave: true)
        let statuses = StatusRecorder()
        let coordinator = SaveCoordinator(
            store: store,
            now: { Date(timeIntervalSince1970: 123) },
            onStatus: { statuses.values.append($0) }
        )

        await coordinator.request(first)
        await store.waitForFirstSave()
        await coordinator.request(middle)
        await coordinator.request(latest)

        let completion = CompletionRecorder()
        let flushTask = Task {
            await coordinator.flush(latest)
            await completion.markComplete()
        }
        await Task.yield()
        let isCompleteBeforeRelease = await completion.isComplete()
        XCTAssertFalse(isCompleteBeforeRelease)
        await store.releaseFirstSave()
        await flushTask.value

        let savedStates = await store.savedStates()
        XCTAssertEqual(savedStates, [first, latest])
        XCTAssertEqual(statuses.values, [
            .saving,
            .saved(Date(timeIntervalSince1970: 123)),
            .saving,
            .saved(Date(timeIntervalSince1970: 123))
        ])
        XCTAssertFalse(savedStates.contains(middle))
    }

    func testFailedSaveReportsFailureAndALaterRequestStillDrains() async {
        let first = state(autoEquip: true)
        let second = state(autoEquip: false)
        let store = FailOnceSaveStore()
        let statuses = StatusRecorder()
        let coordinator = SaveCoordinator(
            store: store,
            onStatus: { statuses.values.append($0) }
        )

        await coordinator.request(first)
        await coordinator.flush(first)
        await coordinator.request(second)
        await coordinator.flush(second)

        let savedStates = await store.savedStates()
        XCTAssertEqual(savedStates, [first, second])
        XCTAssertEqual(statuses.values.count, 4)
        XCTAssertEqual(statuses.values[0], .saving)
        XCTAssertEqual(statuses.values[1], .failed("controlled failure"))
        XCTAssertEqual(statuses.values[2], .saving)
        if case .saved = statuses.values[3] {
            // The exact completion timestamp is intentionally not part of this assertion.
        } else {
            XCTFail("The recovered request should report saved status")
        }
    }

    private func state(autoEquip: Bool) -> GameState {
        var state = GameState.newGame(balance: .standard)
        state.autoEquipEnabled = autoEquip
        return state
    }
}

@MainActor
private final class StatusRecorder {
    var values: [SaveStatus] = []
}

actor CompletionRecorder {
    private var complete = false

    func markComplete() {
        complete = true
    }

    func isComplete() -> Bool {
        complete
    }
}

actor ControlledSaveStore: SaveStoring {
    private let blockFirstSave: Bool
    private var hasStartedFirstSave = false
    private var firstSaveContinuation: CheckedContinuation<Void, Never>?
    private var firstSaveWaiters: [CheckedContinuation<Void, Never>] = []
    private var states: [GameState] = []

    init(blockFirstSave: Bool) {
        self.blockFirstSave = blockFirstSave
    }

    func load(newGame: GameState) async -> SaveLoadResult {
        SaveLoadResult(state: newGame, source: .newGame)
    }

    func save(_ state: GameState) async throws {
        states.append(state)
        guard blockFirstSave, !hasStartedFirstSave else { return }
        hasStartedFirstSave = true
        await withCheckedContinuation { continuation in
            firstSaveContinuation = continuation
            let waiters = firstSaveWaiters
            firstSaveWaiters.removeAll()
            waiters.forEach { $0.resume() }
        }
    }

    func waitForFirstSave() async {
        if hasStartedFirstSave { return }
        await withCheckedContinuation { continuation in
            firstSaveWaiters.append(continuation)
        }
    }

    func releaseFirstSave() {
        firstSaveContinuation?.resume()
        firstSaveContinuation = nil
    }

    func savedStates() -> [GameState] {
        states
    }
}

actor FailOnceSaveStore: SaveStoring {
    private var shouldFail = true
    private var states: [GameState] = []

    func load(newGame: GameState) async -> SaveLoadResult {
        SaveLoadResult(state: newGame, source: .newGame)
    }

    func save(_ state: GameState) async throws {
        states.append(state)
        if shouldFail {
            shouldFail = false
            throw ControlledSaveError.failure
        }
    }

    func savedStates() -> [GameState] {
        states
    }
}

enum ControlledSaveError: Error, CustomStringConvertible {
    case failure

    var description: String { "controlled failure" }
}
