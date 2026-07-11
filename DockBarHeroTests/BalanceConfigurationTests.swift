import XCTest
@testable import DockBarHero

final class BalanceConfigurationTests: XCTestCase {
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

        XCTAssertEqual(balance.enemy(level: 1).maxHealth, 30)
        XCTAssertEqual(balance.enemy(level: 2).maxHealth, 32)
        XCTAssertEqual(balance.itemPrimaryStat(level: 1, slot: .weapon), 1)
        XCTAssertEqual(balance.itemPrimaryStat(level: 2, slot: .armor), 1)
    }
}
