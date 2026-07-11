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

        XCTAssertTrue(events.contains(.victory(defeatedLevel: 1)))
        XCTAssertEqual(simulation.state.encounter.enemyLevel, 2)
        XCTAssertEqual(simulation.state.hero.currentHealth, 100)
    }

    func testEquivalentElapsedChunksProduceIdenticalStateAndEvents() throws {
        var singleAdvance = GameSimulation()
        var chunkedAdvance = GameSimulation()

        let singleEvents = try singleAdvance.advance(by: 2.1)
        var chunkedEvents: [GameEvent] = []
        chunkedEvents += try chunkedAdvance.advance(by: 0.7)
        chunkedEvents += try chunkedAdvance.advance(by: 0.7)
        chunkedEvents += try chunkedAdvance.advance(by: 0.7)

        XCTAssertEqual(singleAdvance.state, chunkedAdvance.state)
        XCTAssertEqual(singleEvents, chunkedEvents)
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

private extension GameEvent {
    var isAttack: Bool {
        if case .attack = self { return true }
        return false
    }
}
