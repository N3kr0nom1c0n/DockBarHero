import XCTest
@testable import DockBarHero

final class BalanceConfigurationTests: XCTestCase {
    func testEliteEnemyHealthUsesTierRatioWithCeiling() throws {
        let enemy = try XCTUnwrap(
            BalanceConfiguration.standard.enemy(
                level: 5,
                tier: .elite,
                progression: .standard
            )
        )

        XCTAssertEqual(enemy.maxHealth, 54)
        XCTAssertEqual(enemy.baseAttack, 4)
    }

    func testPartyStateRejectsDecodedEmptyHeroArray() throws {
        let data = Data(#"{"heroes":[]}"#.utf8)

        XCTAssertThrowsError(try JSONDecoder().decode(PartyState.self, from: data))
    }

    func testExplicitTankNewGameUsesSchemaV2ProgressionState() throws {
        let state = try GameState.newGame(
            classID: .tank,
            balance: .standard,
            progression: .standard
        )

        XCTAssertEqual(state.party.heroes.count, 1)
        XCTAssertEqual(state.party.heroes[0].classID, .tank)
        XCTAssertEqual(state.party.heroes[0].level, 1)
        XCTAssertEqual(state.party.heroes[0].currentXP, 0)
        XCTAssertEqual(state.party.heroes[0].combat.maxHealth, 130)
        XCTAssertEqual(state.campaign.highestUnlockedLevel, 1)
        XCTAssertEqual(state.campaign.selectedLevel, 1)
        XCTAssertNil(state.campaign.queuedLevel)
        XCTAssertEqual(state.campaign.mode, .push)
        XCTAssertEqual(state.campaign.consecutiveDefeats, 0)
        XCTAssertEqual(state.economy.gold, 0)
    }

    func testStandardNewGameStartsAtEnemyOneWithAutoEquip() {
        let state = GameState.newGame(balance: .standard)

        XCTAssertEqual(state.hero.maxHealth, 100)
        XCTAssertEqual(state.hero.baseAttack, 10)
        XCTAssertEqual(state.enemy.maxHealth, 30)
        XCTAssertEqual(state.hero.attackInterval, try! XCTUnwrap(SimulationDuration.seconds(1)))
        XCTAssertEqual(state.enemy.attackInterval, try! XCTUnwrap(SimulationDuration.milliseconds(1_500)))
        XCTAssertEqual(state.encounter.enemyLevel, 1)
        XCTAssertEqual(state.encounter.phase, .active)
        XCTAssertTrue(state.autoEquipEnabled)
        XCTAssertTrue(state.inventory.isEmpty)
        XCTAssertEqual(state.lootSequence, 0)
    }

    func testStandardScalingMatchesApprovedFormulas() {
        let balance = BalanceConfiguration.standard

        XCTAssertEqual(balance.enemy(level: 1)?.maxHealth, 30)
        XCTAssertEqual(balance.enemy(level: 2)?.maxHealth, 32)
        XCTAssertEqual(balance.itemPrimaryStat(level: 1, slot: .weapon), 1)
        XCTAssertEqual(balance.itemPrimaryStat(level: 2, slot: .armor), 1)
    }

    func testLevelOneExtremeBalanceConstructsAndIsRejectedDuringAdvance() {
        let balance = BalanceConfiguration(
            heroMaxHealth: 100,
            heroBaseAttack: 10,
            heroBaseDefense: 0,
            heroAttackInterval: .nanoseconds(1_000_000_000),
            enemyBaseHealth: .max,
            enemyBaseAttack: 3,
            enemyBaseDefense: 0,
            enemyAttackInterval: .nanoseconds(1_500_000_000),
            reviveDelay: .nanoseconds(3_000_000_000)
        )
        var simulation = GameSimulation(balance: balance)
        let stateBeforeAdvance = simulation.state

        XCTAssertThrowsError(try simulation.advance(by: .zero)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidBalance)
        }
        XCTAssertEqual(simulation.state, stateBeforeAdvance)
    }
}
