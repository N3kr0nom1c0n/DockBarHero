import Foundation

enum SaveStatus: Equatable, Sendable {
    case notLoaded
    case saving
    case saved(Date)
    case recovered
    case failed(String)
}

protocol SaveCoordinating: Sendable {
    func request(_ state: GameState) async
    func flush(_ state: GameState) async
}

actor SaveCoordinator: SaveCoordinating {
    private let store: any SaveStoring
    private let now: @Sendable () -> Date
    private let onStatus: (@MainActor @Sendable (SaveStatus) -> Void)?

    private var pendingState: GameState?
    private var isDraining = false
    private var flushWaiters: [CheckedContinuation<Void, Never>] = []

    init(
        store: any SaveStoring,
        now: @escaping @Sendable () -> Date = Date.init,
        onStatus: (@MainActor @Sendable (SaveStatus) -> Void)? = nil
    ) {
        self.store = store
        self.now = now
        self.onStatus = onStatus
    }

    func request(_ state: GameState) async {
        pendingState = state
        startDrainIfNeeded()
    }

    func flush(_ state: GameState) async {
        pendingState = state
        startDrainIfNeeded()

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
        while let state = pendingState {
            pendingState = nil
            await publish(.saving)

            do {
                try await store.save(state)
                await publish(.saved(now()))
            } catch {
                await publish(.failed(String(describing: error)))
            }
        }

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
