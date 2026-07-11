import XCTest
@testable import DockBarHero

final class GameSimulationTests: XCTestCase {
    func testIndependentAttackSchedulesAdvanceChronologically() throws {
        var simulation = GameSimulation()

        let events = try simulation.advance(by: 2.1)

        XCTAssertEqual(simulation.state.enemy.currentHealth, 10)
        XCTAssertEqual(simulation.state.hero.currentHealth, 97)
        XCTAssertEqual(events.filter(\.isAttack).count, 3)
    }

    func testThreeSecondVictoryTieResolvesHeroBeforeEnemy() throws {
        var simulation = GameSimulation()

        let events = try simulation.advance(by: 3.0)

        XCTAssertEqual(events, [
            .attack(attacker: .hero, defender: .enemy, damage: 10),
            .attack(attacker: .enemy, defender: .hero, damage: 3),
            .attack(attacker: .hero, defender: .enemy, damage: 10),
            .attack(attacker: .hero, defender: .enemy, damage: 10),
            .victory(defeatedLevel: 1)
        ])
        XCTAssertEqual(simulation.state.encounter.enemyLevel, 2)
        XCTAssertEqual(simulation.state.hero.currentHealth, 100)
        let victoryIndex = try XCTUnwrap(events.firstIndex { event in
            if case .victory = event { return true }
            return false
        })
        XCTAssertFalse(events.dropFirst(victoryIndex + 1).contains { event in
            if case .attack(attacker: .enemy, defender: .hero, _) = event { return true }
            return false
        })
    }

    func testEquivalentElapsedChunksProduceIdenticalStateAndEvents() throws {
        var singleAdvance = GameSimulation()
        var chunkedAdvance = GameSimulation()

        let singleEvents = try singleAdvance.advance(by: 2.1)
        var chunkedEvents: [GameEvent] = []
        chunkedEvents += try chunkedAdvance.advance(by: 0.7)
        chunkedEvents += try chunkedAdvance.advance(by: 0.7)
        chunkedEvents += try chunkedAdvance.advance(by: 0.7)

        assertEquivalentStates(singleAdvance.state, chunkedAdvance.state)
        XCTAssertEqual(singleEvents, chunkedEvents)
    }

    func testElapsedJustBelowOneSecondDoesNotFireEarly() throws {
        var simulation = GameSimulation()

        let elapsed = 0.9999999996
        let events = try simulation.advance(by: elapsed)

        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(simulation.state.encounter.activeElapsed, elapsed, accuracy: 1e-18)
        XCTAssertEqual(simulation.state.hero.timeUntilNextAttack, 1.0 - elapsed, accuracy: 1e-18)
    }

    func testVerySmallElapsedIsPreservedAndChunkEquivalent() throws {
        var singleAdvance = GameSimulation()
        var chunkedAdvance = GameSimulation()

        let singleEvents = try singleAdvance.advance(by: 1.2e-9)
        var chunkedEvents: [GameEvent] = []
        chunkedEvents += try chunkedAdvance.advance(by: 0.4e-9)
        chunkedEvents += try chunkedAdvance.advance(by: 0.4e-9)
        chunkedEvents += try chunkedAdvance.advance(by: 0.4e-9)

        XCTAssertTrue(singleEvents.isEmpty)
        XCTAssertEqual(singleEvents, chunkedEvents)
        XCTAssertEqual(singleAdvance.state.encounter.activeElapsed, 1.2e-9, accuracy: 1e-18)
        XCTAssertEqual(chunkedAdvance.state.encounter.activeElapsed, 1.2e-9, accuracy: 1e-18)
        XCTAssertEqual(singleAdvance.state.hero.timeUntilNextAttack, 1.0 - 1.2e-9, accuracy: 1e-15)
        XCTAssertEqual(chunkedAdvance.state.hero.timeUntilNextAttack, 1.0 - 1.2e-9, accuracy: 1e-15)
        assertEquivalentStates(singleAdvance.state, chunkedAdvance.state)
    }

    func testPositiveSubNanosecondAttackIntervalsTerminate() throws {
        let balance = BalanceConfiguration(
            heroMaxHealth: 100,
            heroBaseAttack: 10,
            heroBaseDefense: 0,
            heroAttackInterval: 0.4e-9,
            enemyBaseHealth: 1_000,
            enemyBaseAttack: 3,
            enemyBaseDefense: 0,
            enemyAttackInterval: 1.5,
            reviveDelay: 3.0
        )
        var simulation = GameSimulation(balance: balance)

        let events = try simulation.advance(by: 1.0e-9)

        XCTAssertEqual(events, [
            .attack(attacker: .hero, defender: .enemy, damage: 10),
            .attack(attacker: .hero, defender: .enemy, damage: 10)
        ])
        XCTAssertEqual(simulation.state.encounter.activeElapsed, 1.0e-9, accuracy: 1e-18)
        XCTAssertEqual(simulation.state.hero.timeUntilNextAttack, 0.2e-9, accuracy: 1e-18)
    }

    func testDefeatPausesThenRevivesTheSameEncounter() throws {
        var state = GameState.newGame(balance: .standard)
        state.hero.currentHealth = 1
        state.hero.timeUntilNextAttack = 1.0
        state.enemy.timeUntilNextAttack = 1.0
        var simulation = GameSimulation(state: state)

        let defeatEvents = try simulation.advance(by: 1.0)
        XCTAssertTrue(defeatEvents.contains(.defeat(enemyLevel: 1)))
        XCTAssertEqual(simulation.state.encounter.phase, .reviving)

        let waitingEvents = try simulation.advance(by: 2.9)
        XCTAssertFalse(waitingEvents.contains { event in
            if case .revived = event { return true }
            return false
        })
        XCTAssertEqual(simulation.state.encounter.enemyLevel, 1)
        XCTAssertEqual(simulation.state.encounter.activeElapsed, 1.0)

        let reviveEvents = try simulation.advance(by: 0.1)
        XCTAssertTrue(reviveEvents.contains(.revived(enemyLevel: 1)))
        XCTAssertEqual(simulation.state.encounter.phase, .active)
        XCTAssertEqual(simulation.state.hero.currentHealth, simulation.state.hero.maxHealth)
        XCTAssertEqual(simulation.state.enemy.currentHealth, simulation.state.enemy.maxHealth)
        XCTAssertEqual(simulation.state.hero.timeUntilNextAttack, simulation.state.hero.attackInterval)
        XCTAssertEqual(simulation.state.enemy.timeUntilNextAttack, simulation.state.enemy.attackInterval)
    }

    func testInvalidElapsedValuesAreRejected() {
        var simulation = GameSimulation()

        XCTAssertThrowsError(try simulation.advance(by: -0.1)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidElapsed)
        }
        XCTAssertThrowsError(try simulation.advance(by: .infinity)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidElapsed)
        }
        XCTAssertThrowsError(try simulation.advance(by: .nan)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidElapsed)
        }
    }

    func testInvalidTimerStateIsRejectedBeforeMutation() {
        let invalidBalance = BalanceConfiguration(
            heroMaxHealth: 100,
            heroBaseAttack: 10,
            heroBaseDefense: 0,
            heroAttackInterval: 0,
            enemyBaseHealth: 30,
            enemyBaseAttack: 3,
            enemyBaseDefense: 0,
            enemyAttackInterval: 1.5,
            reviveDelay: 3.0
        )
        var zeroIntervalSimulation = GameSimulation(balance: invalidBalance)
        let zeroIntervalState = zeroIntervalSimulation.state

        XCTAssertThrowsError(try zeroIntervalSimulation.advance(by: 0.1)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidTimer)
        }
        XCTAssertEqual(zeroIntervalSimulation.state, zeroIntervalState)

        var nonFiniteState = GameState.newGame(balance: .standard)
        nonFiniteState.hero.timeUntilNextAttack = .infinity
        var nonFiniteSimulation = GameSimulation(state: nonFiniteState)
        let nonFiniteStateBeforeAdvance = nonFiniteSimulation.state

        XCTAssertThrowsError(try nonFiniteSimulation.advance(by: 0.1)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidTimer)
        }
        XCTAssertEqual(nonFiniteSimulation.state, nonFiniteStateBeforeAdvance)
    }

    func testEquippedWeaponAndArmorAffectDamage() throws {
        var state = GameState.newGame(balance: .standard)
        let weapon = Item(id: ItemID(rawValue: 1), level: 1, slot: .weapon, primaryStat: 5, creationSequence: 1)
        let armor = Item(id: ItemID(rawValue: 2), level: 1, slot: .armor, primaryStat: 2, creationSequence: 2)
        state.inventory = [weapon, armor]
        state.equipment.weaponID = weapon.id
        state.equipment.armorID = armor.id
        state.enemy.timeUntilNextAttack = 1.0
        var simulation = GameSimulation(state: state)

        let events = try simulation.advance(by: 1.0)

        XCTAssertEqual(events, [
            .attack(attacker: .hero, defender: .enemy, damage: 15),
            .attack(attacker: .enemy, defender: .hero, damage: 1)
        ])
    }
}

private func assertEquivalentStates(_ lhs: GameState, _ rhs: GameState, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(lhs.hero.id, rhs.hero.id, file: file, line: line)
    XCTAssertEqual(lhs.hero.currentHealth, rhs.hero.currentHealth, file: file, line: line)
    XCTAssertEqual(lhs.hero.maxHealth, rhs.hero.maxHealth, file: file, line: line)
    XCTAssertEqual(lhs.hero.baseAttack, rhs.hero.baseAttack, file: file, line: line)
    XCTAssertEqual(lhs.hero.baseDefense, rhs.hero.baseDefense, file: file, line: line)
    XCTAssertEqual(lhs.hero.attackInterval, rhs.hero.attackInterval, file: file, line: line)
    XCTAssertEqual(lhs.enemy.id, rhs.enemy.id, file: file, line: line)
    XCTAssertEqual(lhs.enemy.currentHealth, rhs.enemy.currentHealth, file: file, line: line)
    XCTAssertEqual(lhs.enemy.maxHealth, rhs.enemy.maxHealth, file: file, line: line)
    XCTAssertEqual(lhs.enemy.baseAttack, rhs.enemy.baseAttack, file: file, line: line)
    XCTAssertEqual(lhs.enemy.baseDefense, rhs.enemy.baseDefense, file: file, line: line)
    XCTAssertEqual(lhs.enemy.attackInterval, rhs.enemy.attackInterval, accuracy: 1e-15, file: file, line: line)
    XCTAssertEqual(lhs.encounter.enemyLevel, rhs.encounter.enemyLevel, file: file, line: line)
    XCTAssertEqual(lhs.encounter.phase, rhs.encounter.phase, file: file, line: line)
    XCTAssertEqual(lhs.encounter.heroDamage, rhs.encounter.heroDamage, file: file, line: line)
    XCTAssertEqual(lhs.inventory, rhs.inventory, file: file, line: line)
    XCTAssertEqual(lhs.equipment, rhs.equipment, file: file, line: line)
    XCTAssertEqual(lhs.autoEquipEnabled, rhs.autoEquipEnabled, file: file, line: line)
    XCTAssertEqual(lhs.lootSequence, rhs.lootSequence, file: file, line: line)
    XCTAssertEqual(lhs.hero.timeUntilNextAttack, rhs.hero.timeUntilNextAttack, accuracy: 1e-15, file: file, line: line)
    XCTAssertEqual(lhs.enemy.timeUntilNextAttack, rhs.enemy.timeUntilNextAttack, accuracy: 1e-15, file: file, line: line)
    XCTAssertEqual(lhs.encounter.activeElapsed, rhs.encounter.activeElapsed, accuracy: 1e-15, file: file, line: line)
    XCTAssertEqual(lhs.encounter.reviveRemaining, rhs.encounter.reviveRemaining, accuracy: 1e-15, file: file, line: line)
}

private extension GameEvent {
    var isAttack: Bool {
        if case .attack = self { return true }
        return false
    }
}
