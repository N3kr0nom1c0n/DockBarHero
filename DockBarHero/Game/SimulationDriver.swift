import Foundation

@MainActor
protocol SimulationDriving: AnyObject {
    var onPresentation: ((GamePresentation) -> Void)? { get set }
    var onEvents: (([GameEvent]) -> Void)? { get set }
    var currentState: GameState { get }
    func start()
    func stop()
    func replaceState(_ state: GameState)
    func send(_ intent: GameIntent) throws
}

@MainActor
final class SimulationDriver: SimulationDriving {
    var onPresentation: ((GamePresentation) -> Void)?
    var onEvents: (([GameEvent]) -> Void)?

    private var simulation: GameSimulation
    private let now: @MainActor () -> UInt64
    private var lastTick: UInt64 = 0
    private var lastPublish: UInt64 = 0
    private var loopTask: Task<Void, Never>?
    private var isStarted = false

    var currentState: GameState {
        simulation.state
    }

    init(
        simulation: GameSimulation = GameSimulation(),
        now: @escaping @MainActor () -> UInt64 = { DispatchTime.now().uptimeNanoseconds }
    ) {
        self.simulation = simulation
        self.now = now
    }

    func start() {
        start(startLoop: true)
    }

    func start(startLoop: Bool) {
        guard !isStarted else { return }

        isStarted = true
        let timestamp = now()
        lastTick = timestamp
        lastPublish = timestamp
        onPresentation?(simulation.presentation)

        guard startLoop else { return }
        loopTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                guard let self else { return }
                self.step(at: self.now())
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        isStarted = false
    }

    func step(at timestamp: UInt64) {
        guard isStarted, timestamp >= lastTick else { return }

        let rawDelta = timestamp - lastTick
        let elapsed = SimulationDuration.nanoseconds(
            Int64(min(rawDelta, 1_000_000_000))
        )

        do {
            let events = try simulation.advance(by: elapsed)
            if !events.isEmpty {
                onEvents?(events)
            }
            if timestamp - lastPublish >= 250_000_000 {
                lastPublish = timestamp
                onPresentation?(simulation.presentation)
            }
            lastTick = timestamp
        } catch {
            assertionFailure("Simulation driver failed to advance: \(error)")
        }
    }

    func replaceState(_ state: GameState) {
        simulation = GameSimulation(state: state)
        let timestamp = now()
        lastTick = timestamp
        lastPublish = timestamp
        onPresentation?(simulation.presentation)
    }

    func send(_ intent: GameIntent) throws {
        let events = try simulation.apply(intent)
        if !events.isEmpty {
            onEvents?(events)
        }
        onPresentation?(simulation.presentation)
    }
}
