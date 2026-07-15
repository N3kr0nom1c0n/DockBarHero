import Foundation

enum SaveStatus: Equatable, Sendable {
    case notLoaded
    case saving
    case saved(Date)
    case recovered
    case unsupportedVersion(Int)
    case failed(String)
}

enum SaveFlushResult: Equatable, Sendable {
    case saved
    case failed(String)
}

protocol SaveCoordinating: Sendable {
    func request(_ state: GameState) async
    func flush(_ state: GameState) async
    func request(_ runState: RunState) async
    func flush(_ runState: RunState) async
    func flushResult(_ runState: RunState) async -> SaveFlushResult
    func waitUntilIdle() async
}

extension SaveCoordinating {
    func request(_ runState: RunState) async {
        guard case let .active(state) = runState else { return }
        await request(state)
    }

    func flush(_ runState: RunState) async {
        guard case let .active(state) = runState else { return }
        await flush(state)
    }

    func flushResult(_ runState: RunState) async -> SaveFlushResult {
        await flush(runState)
        return .saved
    }

    func waitUntilIdle() async { }
}

protocol SaveStatusObserving: Sendable {
    func setStatusHandler(
        _ handler: (@MainActor @Sendable (SaveStatus) -> Void)?
    ) async
}

actor SaveCoordinator: SaveCoordinating, SaveStatusObserving {
    private let store: any SaveStoring
    private let now: @Sendable () -> Date
    private var onStatus: (@MainActor @Sendable (SaveStatus) -> Void)?

    private var pendingState: RunState?
    private var isDraining = false
    private var flushWaiters: [CheckedContinuation<Void, Never>] = []
    private var lastDrainResult: SaveFlushResult = .saved

    init(
        store: any SaveStoring,
        now: @escaping @Sendable () -> Date = Date.init,
        onStatus: (@MainActor @Sendable (SaveStatus) -> Void)? = nil
    ) {
        self.store = store
        self.now = now
        self.onStatus = onStatus
    }

    func request(_ runState: RunState) async {
        pendingState = runState
        startDrainIfNeeded()
    }

    func request(_ state: GameState) async {
        await request(.active(state))
    }

    func setStatusHandler(
        _ handler: (@MainActor @Sendable (SaveStatus) -> Void)?
    ) async {
        onStatus = handler
    }

    func flush(_ runState: RunState) async {
        pendingState = runState
        startDrainIfNeeded()

        await withCheckedContinuation { continuation in
            flushWaiters.append(continuation)
        }
    }

    func flushResult(_ runState: RunState) async -> SaveFlushResult {
        await flush(runState)
        return lastDrainResult
    }

    func flush(_ state: GameState) async {
        await flush(.active(state))
    }

    func waitUntilIdle() async {
        guard isDraining || pendingState != nil else { return }
        await withCheckedContinuation { continuation in
            flushWaiters.append(continuation)
        }
    }

    private func startDrainIfNeeded() {
        guard !isDraining else { return }

        isDraining = true
        Task { await self.drain() }
    }

    private func drain() async {
        var drainResult: SaveFlushResult = .saved
        while let state = pendingState {
            pendingState = nil
            await publish(.saving)

            do {
                try await store.save(state)
                await publish(.saved(now()))
                drainResult = .saved
            } catch {
                let message = String(describing: error)
                await publish(.failed(message))
                drainResult = .failed(message)
            }
        }

        lastDrainResult = drainResult
        isDraining = false
        let waiters = flushWaiters
        flushWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    private func publish(_ status: SaveStatus) async {
        guard let onStatus else { return }
        await MainActor.run {
            onStatus(status)
        }
    }
}
