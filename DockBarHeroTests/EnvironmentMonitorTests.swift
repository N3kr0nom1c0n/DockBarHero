import XCTest
@testable import DockBarHero

@MainActor
final class EnvironmentMonitorTests: XCTestCase {
    func testBurstOfChangesProducesOneEvaluation() {
        let evaluator = FakeEnvironmentEvaluator(result: .fullscreen)
        let scheduler = ManualEnvironmentScheduler()
        let monitor = EnvironmentMonitor(evaluator: evaluator, scheduler: scheduler)
        var received: [EnvironmentVisibility] = []
        monitor.onVisibilityChange = { received.append($0) }

        monitor.environmentDidChange()
        monitor.environmentDidChange()
        monitor.environmentDidChange()
        scheduler.fire()

        XCTAssertEqual(evaluator.callCount, 1)
        XCTAssertEqual(received, [.fullscreen])
    }

    func testBurstOfGeometryChangesProducesOneCallback() {
        let evaluator = FakeEnvironmentEvaluator(result: .normalSpace)
        let scheduler = ManualEnvironmentScheduler()
        let monitor = EnvironmentMonitor(evaluator: evaluator, scheduler: scheduler)
        var geometryChangeCount = 0
        monitor.onGeometryChange = { geometryChangeCount += 1 }

        monitor.geometryDidChange()
        monitor.geometryDidChange()
        monitor.geometryDidChange()
        scheduler.fire()

        XCTAssertEqual(geometryChangeCount, 1)
        XCTAssertEqual(evaluator.callCount, 1)
    }
}

@MainActor
private final class FakeEnvironmentEvaluator: EnvironmentEvaluating {
    let result: EnvironmentVisibility?
    private(set) var callCount = 0

    init(result: EnvironmentVisibility?) {
        self.result = result
    }

    func currentVisibility() -> EnvironmentVisibility? {
        callCount += 1
        return result
    }
}

@MainActor
private final class ManualEnvironmentScheduler: EnvironmentScheduling {
    private var operation: (@MainActor @Sendable () -> Void)?

    func schedule(_ operation: @escaping @MainActor @Sendable () -> Void) {
        self.operation = operation
    }

    func cancel() {
        operation = nil
    }

    func fire() {
        let pending = operation
        operation = nil
        pending?()
    }
}
