import XCTest
@testable import DockBarHero

final class EncounterScheduleTests: XCTestCase {
    func testBossPrecedesEliteAndNormalsFillRemainingLevels() {
        let schedule = EncounterSchedule.standard

        XCTAssertEqual(schedule.tier(for: 1), .normal)
        XCTAssertEqual(schedule.tier(for: 5), .elite)
        XCTAssertEqual(schedule.tier(for: 24), .normal)
        XCTAssertEqual(schedule.tier(for: 25), .boss)
        XCTAssertEqual(schedule.tier(for: 50), .boss)
    }

    func testInvalidLevelsHaveNoTier() {
        let schedule = EncounterSchedule.standard

        XCTAssertNil(schedule.tier(for: 0))
        XCTAssertNil(schedule.tier(for: -1))
    }

    func testApprovedTierDefinitions() throws {
        let config = ProgressionConfiguration.standard
        let elite = config.tierDefinition(for: .elite)
        let boss = config.tierDefinition(for: .boss)

        XCTAssertEqual(elite.healthRatio, Ratio(numerator: 7, denominator: 5))
        XCTAssertEqual(elite.xpRatio, Ratio(numerator: 7, denominator: 4))
        XCTAssertEqual(boss.healthRatio, Ratio(numerator: 5, denominator: 2))
        XCTAssertEqual(boss.damageRatio, Ratio(numerator: 9, denominator: 4))
        XCTAssertEqual(boss.goldRatio, Ratio(numerator: 2, denominator: 1))
    }
}
