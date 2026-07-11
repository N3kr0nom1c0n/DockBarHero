import XCTest
@testable import DockBarHero

final class DamageMetricsTests: XCTestCase {
    func testNewMetricsHaveZeroDPS() {
        let metrics = DamageMetrics()

        XCTAssertEqual(metrics.rollingDPS(at: .zero, encounterElapsed: .zero), 0)
        XCTAssertEqual(DamageMetrics.encounterAverage(totalDamage: 0, elapsed: .zero), 0)
    }

    func testRollingDPSUsesPartialWindowThenEvictsOldDamage() {
        var metrics = DamageMetrics()
        metrics.record(damage: 10, at: .seconds(1)!)
        metrics.record(damage: 20, at: .seconds(4)!)

        XCTAssertEqual(metrics.rollingDPS(at: .seconds(4)!, encounterElapsed: .seconds(4)!), 7.5, accuracy: 0.001)
        XCTAssertEqual(metrics.rollingDPS(at: .milliseconds(6_100)!, encounterElapsed: .milliseconds(6_100)!), 4.0, accuracy: 0.001)
    }

    func testEncounterAverageExcludesZeroDuration() {
        XCTAssertEqual(DamageMetrics.encounterAverage(totalDamage: 30, elapsed: .zero), 0)
        XCTAssertEqual(DamageMetrics.encounterAverage(totalDamage: 30, elapsed: .seconds(3)!), 10)
    }

    func testResetRemovesRollingDamage() {
        var metrics = DamageMetrics()
        metrics.record(damage: 10, at: .seconds(1)!)

        metrics.reset()

        XCTAssertEqual(metrics.rollingDPS(at: .seconds(1)!, encounterElapsed: .seconds(1)!), 0)
    }
}
