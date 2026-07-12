import XCTest
@testable import DockBarHero

final class ProgressionConfigurationTests: XCTestCase {
    func testApprovedXPFormulasAndLevelGapPenalty() throws {
        let config = ProgressionConfiguration.standard

        XCTAssertEqual(try config.xpRequired(for: 10), 10_000)
        XCTAssertEqual(
            try config.xpReward(enemyLevel: 10, heroLevel: 10, tier: .normal),
            2_500
        )
        XCTAssertEqual(
            try config.xpReward(enemyLevel: 10, heroLevel: 16, tier: .normal),
            2_125
        )
        XCTAssertEqual(
            try config.xpReward(enemyLevel: 10, heroLevel: 99, tier: .normal),
            625
        )
    }

    func testApprovedGoldFormulas() throws {
        let config = ProgressionConfiguration.standard

        XCTAssertEqual(try config.goldReward(enemyLevel: 100, tier: .normal), 670)
        XCTAssertEqual(try config.goldReward(enemyLevel: 100, tier: .elite), 1_005)
        XCTAssertEqual(try config.goldReward(enemyLevel: 100, tier: .boss), 1_340)
    }

    func testApprovedClassDefinitions() throws {
        let config = ProgressionConfiguration.standard
        let tank = config.classDefinition(for: .tank)
        let dps = config.classDefinition(for: .dps)
        let healer = config.classDefinition(for: .healer)

        XCTAssertEqual(tank.baseHealth, 130)
        XCTAssertEqual(tank.healthGrowthBasisPoints, 150)
        XCTAssertEqual(dps.baseAttack, 12)
        XCTAssertEqual(dps.attackGrowthBasisPoints, 125)
        XCTAssertEqual(healer.baseDefense, 1)
        XCTAssertEqual(healer.defenseGrowthBasisPoints, 75)
    }

    func testInvalidLevelsRatiosAndOverflowFail() {
        let config = ProgressionConfiguration.standard

        XCTAssertThrowsError(try config.xpRequired(for: 0))
        XCTAssertThrowsError(try config.xpRequired(for: .max))
        XCTAssertThrowsError(
            try config.xpReward(enemyLevel: .max, heroLevel: 1, tier: .normal)
        )
        XCTAssertThrowsError(try config.goldReward(enemyLevel: .max, tier: .boss))
        XCTAssertThrowsError(
            try config.applying(.init(numerator: 1, denominator: 0), to: 10, rounding: .down)
        )
    }

    func testBasisPointScalingUsesCheckedIntegerFloor() throws {
        let config = ProgressionConfiguration.standard

        XCTAssertEqual(
            try config.scaledStat(raw: 100, level: 10, growthBasisPoints: 125),
            111
        )
    }
}
