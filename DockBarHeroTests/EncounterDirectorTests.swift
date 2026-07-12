import XCTest
@testable import DockBarHero

final class EncounterDirectorTests: XCTestCase {
    func testBeginNextEncounterCreatesNextLevelAndResetsHeroAndTimers() throws {
        var state = GameState.newGame(balance: .standard)
        state.hero.currentHealth = 1
        state.hero.timeUntilNextAttack = .zero
        state.enemy.timeUntilNextAttack = .zero
        state.encounter.activeElapsed = .nanoseconds(4)
        state.encounter.heroDamage = 12

        let result = try EncounterDirector().beginNextEncounter(in: state, balance: .standard)

        XCTAssertEqual(result.encounter.enemyLevel, 2)
        XCTAssertEqual(result.hero.currentHealth, result.hero.maxHealth)
        XCTAssertEqual(result.enemy, BalanceConfiguration.standard.enemy(level: 2))
        XCTAssertEqual(result.encounter.phase, .active)
        XCTAssertEqual(result.encounter.activeElapsed, .zero)
        XCTAssertEqual(result.encounter.heroDamage, 0)
        XCTAssertEqual(result.encounter.reviveRemaining, .zero)
        XCTAssertEqual(result.hero.timeUntilNextAttack, result.hero.attackInterval)
        XCTAssertEqual(result.enemy.timeUntilNextAttack, result.enemy.attackInterval)
    }

    func testBeginReviveResetsEncounterMetricsAndUsesBalanceDelay() throws {
        var state = GameState.newGame(balance: .standard)
        state.hero.currentHealth = 0
        state.hero.timeUntilNextAttack = .nanoseconds(111)
        state.enemy.timeUntilNextAttack = .nanoseconds(222)
        state.encounter.activeElapsed = .nanoseconds(4)
        state.encounter.heroDamage = 12

        let result = try EncounterDirector().beginRevive(in: state, balance: .standard)

        XCTAssertEqual(result.encounter.phase, .reviving)
        XCTAssertEqual(result.encounter.activeElapsed, .zero)
        XCTAssertEqual(result.encounter.heroDamage, 0)
        XCTAssertEqual(result.encounter.reviveRemaining, BalanceConfiguration.standard.reviveDelay)
        XCTAssertEqual(result.hero.timeUntilNextAttack, .nanoseconds(111))
        XCTAssertEqual(result.enemy.timeUntilNextAttack, .nanoseconds(222))
    }

    func testFinishReviveRestoresSameEnemyAndTimers() throws {
        var state = GameState.newGame(balance: .standard)
        state.hero.currentHealth = 0
        state.encounter.phase = .reviving
        state.encounter.reviveRemaining = .zero

        let result = try EncounterDirector().finishRevive(in: state, balance: .standard)

        XCTAssertEqual(result.encounter.enemyLevel, 1)
        XCTAssertEqual(result.hero.currentHealth, result.hero.maxHealth)
        XCTAssertEqual(result.enemy.currentHealth, result.enemy.maxHealth)
        XCTAssertEqual(result.encounter.phase, .active)
        XCTAssertEqual(result.encounter.activeElapsed, .zero)
        XCTAssertEqual(result.encounter.heroDamage, 0)
        XCTAssertEqual(result.encounter.reviveRemaining, .zero)
        XCTAssertEqual(result.hero.timeUntilNextAttack, result.hero.attackInterval)
        XCTAssertEqual(result.enemy.timeUntilNextAttack, result.enemy.attackInterval)
    }

    func testBeginNextEncounterRejectsEnemyLevelOverflow() {
        var state = GameState.newGame(balance: .standard)
        state.encounter.enemyLevel = .max
        let original = state

        XCTAssertThrowsError(try EncounterDirector().beginNextEncounter(in: state, balance: .standard)) { error in
            XCTAssertEqual(error as? SimulationError, .arithmeticOverflow)
        }
        XCTAssertEqual(state, original)
    }

    func testBeginReviveRejectsInvalidBalance() {
        let invalidBalance = BalanceConfiguration(
            heroMaxHealth: 100,
            heroBaseAttack: 10,
            heroBaseDefense: 0,
            heroAttackInterval: .nanoseconds(1_000_000_000),
            enemyBaseHealth: 30,
            enemyBaseAttack: 3,
            enemyBaseDefense: 0,
            enemyAttackInterval: .nanoseconds(1_500_000_000),
            reviveDelay: .nanoseconds(-1)
        )
        let state = GameState.newGame(balance: .standard)

        XCTAssertThrowsError(try EncounterDirector().beginRevive(in: state, balance: invalidBalance)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidBalance)
        }
    }
}
