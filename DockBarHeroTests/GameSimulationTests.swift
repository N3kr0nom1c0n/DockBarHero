import XCTest
@testable import DockBarHero

final class GameSimulationTests: XCTestCase {
    func testIndependentAttackSchedulesAdvanceChronologically() throws {
        var simulation = GameSimulation()

        let events = try simulation.advance(by: try duration(milliseconds: 2_100))

        XCTAssertEqual(simulation.state.enemy.currentHealth, 10)
        XCTAssertEqual(simulation.state.hero.currentHealth, 97)
        XCTAssertEqual(events.filter(\.isAttack).count, 3)
    }

    func testAdvanceOneNanosecondBeforeOneSecondDoesNotFireEarly() throws {
        var simulation = GameSimulation()

        let events = try simulation.advance(by: .nanoseconds(999_999_999))

        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(simulation.state.encounter.activeElapsed, .nanoseconds(999_999_999))
        XCTAssertEqual(simulation.state.hero.timeUntilNextAttack, .nanoseconds(1))
    }

    func testEnemyDueOneNanosecondBeforeHeroResolvesFirst() throws {
        var state = GameState.newGame(balance: .standard)
        state.enemy.timeUntilNextAttack = try duration(seconds: 1)
        state.hero.timeUntilNextAttack = .nanoseconds(1_000_000_001)
        var simulation = GameSimulation(state: state)

        let events = try simulation.advance(by: try duration(seconds: 1))

        XCTAssertEqual(events, [
            .attack(attacker: .enemy, defender: .hero, damage: 3)
        ])
        XCTAssertEqual(simulation.state.hero.timeUntilNextAttack, .nanoseconds(1))
    }

    func testOneMillionTwoHundredThousandNanosecondsMatchesThreeFourHundredThousandNanosecondChunks() throws {
        var singleAdvance = GameSimulation()
        var chunkedAdvance = GameSimulation()

        let singleEvents = try singleAdvance.advance(by: .nanoseconds(1_200_000))
        var chunkedEvents: [GameEvent] = []
        for _ in 0..<3 {
            chunkedEvents += try chunkedAdvance.advance(by: .nanoseconds(400_000))
        }

        XCTAssertEqual(singleAdvance.state, chunkedAdvance.state)
        XCTAssertEqual(singleEvents, chunkedEvents)
    }

    func testTwoPointOneSecondsMatchesThreePointSevenSecondChunks() throws {
        var singleAdvance = GameSimulation()
        var chunkedAdvance = GameSimulation()

        let singleEvents = try singleAdvance.advance(by: try duration(milliseconds: 2_100))
        var chunkedEvents: [GameEvent] = []
        for _ in 0..<3 {
            chunkedEvents += try chunkedAdvance.advance(by: try duration(milliseconds: 700))
        }

        XCTAssertEqual(singleAdvance.state, chunkedAdvance.state)
        XCTAssertEqual(singleEvents, chunkedEvents)
    }

    func testAttackIntervalBelowMinimumIsRejectedBeforeMutation() throws {
        let invalidBalance = BalanceConfiguration(
            heroMaxHealth: 100,
            heroBaseAttack: 10,
            heroBaseDefense: 0,
            heroAttackInterval: .nanoseconds(999_999),
            enemyBaseHealth: 30,
            enemyBaseAttack: 3,
            enemyBaseDefense: 0,
            enemyAttackInterval: try duration(milliseconds: 1_500),
            reviveDelay: try duration(seconds: 3)
        )
        var simulation = GameSimulation(balance: invalidBalance)
        let original = simulation.state

        XCTAssertThrowsError(try simulation.advance(by: .nanoseconds(1))) { error in
            XCTAssertEqual(error as? SimulationError, .invalidBalance)
        }
        XCTAssertEqual(simulation.state, original)
    }

    func testNegativeAndOverMaximumElapsedAreRejectedBeforeMutation() throws {
        var simulation = GameSimulation()
        let original = simulation.state

        XCTAssertThrowsError(try simulation.advance(by: .nanoseconds(-1))) { error in
            XCTAssertEqual(error as? SimulationError, .invalidElapsed)
        }
        XCTAssertEqual(simulation.state, original)

        XCTAssertThrowsError(try simulation.advance(by: .nanoseconds(10_000_000_001))) { error in
            XCTAssertEqual(error as? SimulationError, .invalidElapsed)
        }
        XCTAssertEqual(simulation.state, original)
    }

    func testArithmeticOverflowIsRejectedBeforeMutation() throws {
        var state = GameState.newGame(balance: .standard)
        state.encounter.activeElapsed = .nanoseconds(Int64.max)
        var simulation = GameSimulation(state: state)
        let original = simulation.state

        XCTAssertThrowsError(try simulation.advance(by: .nanoseconds(1))) { error in
            XCTAssertEqual(error as? SimulationError, .arithmeticOverflow)
        }
        XCTAssertEqual(simulation.state, original)
    }

    func testThreeSecondVictoryTieResolvesHeroBeforeEnemy() throws {
        var simulation = GameSimulation()

        let events = try simulation.advance(by: try duration(seconds: 3))

        let item = Item(id: ItemID(rawValue: 1), level: 1, slot: .weapon, primaryStat: 1, creationSequence: 1)
        XCTAssertEqual(events, [
            .attack(attacker: .hero, defender: .enemy, damage: 10),
            .attack(attacker: .enemy, defender: .hero, damage: 3),
            .attack(attacker: .hero, defender: .enemy, damage: 10),
            .attack(attacker: .hero, defender: .enemy, damage: 10),
            .victory(defeatedLevel: 1),
            .loot(item),
            .equipped(slot: .weapon, itemID: item.id)
        ])
        XCTAssertEqual(simulation.state.encounter.enemyLevel, 2)
        XCTAssertEqual(simulation.state.hero.currentHealth, 100)
    }

    func testDefeatRevivesAfterThreeSecondsAgainstSameEnemyLevel() throws {
        var state = GameState.newGame(balance: .standard)
        state.hero.currentHealth = 1
        state.hero.timeUntilNextAttack = try duration(seconds: 1)
        state.enemy.timeUntilNextAttack = try duration(seconds: 1)
        var simulation = GameSimulation(state: state)

        let defeatEvents = try simulation.advance(by: try duration(seconds: 1))
        XCTAssertEqual(defeatEvents, [
            .attack(attacker: .hero, defender: .enemy, damage: 10),
            .attack(attacker: .enemy, defender: .hero, damage: 3),
            .defeat(enemyLevel: 1)
        ])
        XCTAssertEqual(simulation.state.encounter.phase, .reviving)

        XCTAssertTrue(try simulation.advance(by: try duration(milliseconds: 2_900)).isEmpty)
        let reviveEvents = try simulation.advance(by: try duration(milliseconds: 100))

        XCTAssertEqual(reviveEvents, [.revived(enemyLevel: 1)])
        XCTAssertEqual(simulation.state.encounter.phase, .active)
        XCTAssertEqual(simulation.state.encounter.enemyLevel, 1)
        XCTAssertEqual(simulation.state.hero.currentHealth, simulation.state.hero.maxHealth)
        XCTAssertEqual(simulation.state.enemy.currentHealth, simulation.state.enemy.maxHealth)
    }

    func testPresentationDPSStartsAtZeroAndUpdatesAfterHeroAttack() throws {
        var simulation = GameSimulation()

        XCTAssertEqual(simulation.presentation.rollingDPS, 0)
        XCTAssertEqual(simulation.presentation.encounterDPS, 0)

        _ = try simulation.advance(by: try duration(seconds: 1))

        XCTAssertEqual(simulation.presentation.rollingDPS, 10, accuracy: 0.001)
        XCTAssertEqual(simulation.presentation.encounterDPS, 10, accuracy: 0.001)
    }

    func testPresentationDPSResetsAfterVictory() throws {
        var simulation = GameSimulation()

        _ = try simulation.advance(by: try duration(seconds: 3))

        XCTAssertEqual(simulation.presentation.rollingDPS, 0)
        XCTAssertEqual(simulation.presentation.encounterDPS, 0)
    }

    func testPresentationDPSResetsAfterDefeat() throws {
        var state = GameState.newGame(balance: .standard)
        state.hero.currentHealth = 1
        state.hero.timeUntilNextAttack = try duration(seconds: 1)
        state.enemy.timeUntilNextAttack = try duration(seconds: 1)
        var simulation = GameSimulation(state: state)

        _ = try simulation.advance(by: try duration(seconds: 1))

        XCTAssertEqual(simulation.presentation.rollingDPS, 0)
        XCTAssertEqual(simulation.presentation.encounterDPS, 0)
    }

    func testEquippedWeaponAndArmorAffectDamage() throws {
        var state = GameState.newGame(balance: .standard)
        let weapon = Item(id: ItemID(rawValue: 1), level: 1, slot: .weapon, primaryStat: 5, creationSequence: 1)
        let armor = Item(id: ItemID(rawValue: 2), level: 1, slot: .armor, primaryStat: 2, creationSequence: 2)
        state.inventory = [weapon, armor]
        state.equipment.weaponID = weapon.id
        state.equipment.armorID = armor.id
        state.enemy.timeUntilNextAttack = try duration(seconds: 1)
        var simulation = GameSimulation(state: state)

        let events = try simulation.advance(by: try duration(seconds: 1))

        XCTAssertEqual(events, [
            .attack(attacker: .hero, defender: .enemy, damage: 15),
            .attack(attacker: .enemy, defender: .hero, damage: 1)
        ])
    }

    func testEnemyLevelMaximumVictoryRejectsBeforeMutation() {
        var state = GameState.newGame(balance: .standard)
        state.encounter.enemyLevel = .max
        state.enemy.currentHealth = 1
        state.hero.timeUntilNextAttack = .zero
        var simulation = GameSimulation(state: state)
        let stateBeforeAdvance = simulation.state

        XCTAssertThrowsError(try simulation.advance(by: .zero)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidBalance)
        }
        XCTAssertEqual(simulation.state, stateBeforeAdvance)
    }

    func testMaximumHeroDamageAttackRejectsBeforeMutation() {
        var state = GameState.newGame(balance: .standard)
        state.encounter.heroDamage = .max
        state.hero.timeUntilNextAttack = .zero
        var simulation = GameSimulation(state: state)
        let stateBeforeAdvance = simulation.state

        XCTAssertThrowsError(try simulation.advance(by: .zero)) { error in
            XCTAssertEqual(error as? SimulationError, .arithmeticOverflow)
        }
        XCTAssertEqual(simulation.state, stateBeforeAdvance)
    }

    func testEquippedStatOverflowIsRejectedBeforeMutation() {
        var state = GameState.newGame(balance: .standard)
        let weapon = Item(id: ItemID(rawValue: 1), level: 1, slot: .weapon, primaryStat: 1, creationSequence: 1)
        state.hero = CombatantState(
            id: .hero,
            currentHealth: state.hero.currentHealth,
            maxHealth: state.hero.maxHealth,
            baseAttack: .max,
            baseDefense: state.hero.baseDefense,
            attackInterval: state.hero.attackInterval,
            timeUntilNextAttack: .zero
        )
        state.inventory = [weapon]
        state.equipment.weaponID = weapon.id
        var simulation = GameSimulation(state: state)
        let stateBeforeAdvance = simulation.state

        XCTAssertThrowsError(try simulation.advance(by: .zero)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidState)
        }
        XCTAssertEqual(simulation.state, stateBeforeAdvance)
    }

    func testMalformedCombatStateIsRejectedBeforeMutation() {
        var state = GameState.newGame(balance: .standard)
        state.hero = CombatantState(
            id: .enemy,
            currentHealth: state.hero.maxHealth + 1,
            maxHealth: state.hero.maxHealth,
            baseAttack: -1,
            baseDefense: state.hero.baseDefense,
            attackInterval: state.hero.attackInterval,
            timeUntilNextAttack: state.hero.timeUntilNextAttack
        )
        state.encounter.reviveRemaining = .nanoseconds(1)
        var simulation = GameSimulation(state: state)
        let stateBeforeAdvance = simulation.state

        XCTAssertThrowsError(try simulation.advance(by: .zero)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidState)
        }
        XCTAssertEqual(simulation.state, stateBeforeAdvance)
    }

    func testIncoherentRevivingStateIsRejectedBeforeMutation() {
        var state = GameState.newGame(balance: .standard)
        state.encounter.phase = .reviving
        state.encounter.reviveRemaining = try! duration(seconds: 1)
        var simulation = GameSimulation(state: state)
        let stateBeforeAdvance = simulation.state

        XCTAssertThrowsError(try simulation.advance(by: .zero)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidState)
        }
        XCTAssertEqual(simulation.state, stateBeforeAdvance)
    }

    func testActiveStateWithDeadHeroIsRejectedBeforeMutation() {
        var state = GameState.newGame(balance: .standard)
        state.hero.currentHealth = 0
        var simulation = GameSimulation(state: state)
        let stateBeforeAdvance = simulation.state

        XCTAssertThrowsError(try simulation.advance(by: .zero)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidState)
        }
        XCTAssertEqual(simulation.state, stateBeforeAdvance)
    }

    func testActiveStateWithDeadEnemyIsRejectedBeforeMutation() {
        var state = GameState.newGame(balance: .standard)
        state.enemy.currentHealth = 0
        var simulation = GameSimulation(state: state)
        let stateBeforeAdvance = simulation.state

        XCTAssertThrowsError(try simulation.advance(by: .zero)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidState)
        }
        XCTAssertEqual(simulation.state, stateBeforeAdvance)
    }

    func testRevivingStateWithDeadEnemyIsRejectedBeforeMutation() throws {
        var state = GameState.newGame(balance: .standard)
        state.hero.currentHealth = 0
        state.enemy.currentHealth = 0
        state.encounter.phase = .reviving
        state.encounter.reviveRemaining = try duration(seconds: 1)
        var simulation = GameSimulation(state: state)
        let stateBeforeAdvance = simulation.state

        XCTAssertThrowsError(try simulation.advance(by: .zero)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidState)
        }
        XCTAssertEqual(simulation.state, stateBeforeAdvance)
    }

    func testInvalidBalanceValuesAreRejectedBeforeMutation() {
        let balance = BalanceConfiguration(
            heroMaxHealth: 0,
            heroBaseAttack: -1,
            heroBaseDefense: -1,
            heroAttackInterval: try! duration(seconds: 1),
            enemyBaseHealth: 0,
            enemyBaseAttack: -1,
            enemyBaseDefense: -1,
            enemyAttackInterval: try! duration(milliseconds: 1_500),
            reviveDelay: try! duration(seconds: 3)
        )
        var simulation = GameSimulation(balance: balance)
        let stateBeforeAdvance = simulation.state

        XCTAssertThrowsError(try simulation.advance(by: .zero)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidBalance)
        }
        XCTAssertEqual(simulation.state, stateBeforeAdvance)
    }

    func testVictoryDropsLootBeforeEquippingAndStartsNextEncounter() throws {
        var simulation = GameSimulation()

        let events = try simulation.advance(by: try duration(seconds: 3))

        guard case let .loot(item) = events[events.count - 2] else {
            return XCTFail("Expected loot immediately before equipment")
        }
        XCTAssertEqual(events, [
            .attack(attacker: .hero, defender: .enemy, damage: 10),
            .attack(attacker: .enemy, defender: .hero, damage: 3),
            .attack(attacker: .hero, defender: .enemy, damage: 10),
            .attack(attacker: .hero, defender: .enemy, damage: 10),
            .victory(defeatedLevel: 1),
            .loot(item),
            .equipped(slot: .weapon, itemID: item.id)
        ])
        XCTAssertEqual(simulation.state.inventory, [item])
        XCTAssertEqual(simulation.state.equipment.weaponID, item.id)
        XCTAssertEqual(simulation.state.encounter.enemyLevel, 2)
    }

    func testAutoEquipTieLeavesExistingItemEquipped() throws {
        var state = GameState.newGame(balance: .standard)
        let existing = Item(id: ItemID(rawValue: 99), level: 1, slot: .weapon, primaryStat: 1, creationSequence: 99)
        state.inventory = [existing]
        state.equipment.weaponID = existing.id
        state.hero.timeUntilNextAttack = .zero
        state.enemy.currentHealth = 1
        var simulation = GameSimulation(state: state)

        let events = try simulation.advance(by: .zero)

        XCTAssertEqual(events, [
            .attack(attacker: .hero, defender: .enemy, damage: 11),
            .victory(defeatedLevel: 1),
            .loot(Item(id: ItemID(rawValue: 1), level: 1, slot: .weapon, primaryStat: 1, creationSequence: 1))
        ])
        XCTAssertEqual(simulation.state.equipment.weaponID, existing.id)
        XCTAssertEqual(simulation.state.inventory.count, 2)
    }

    func testDisabledAutoEquipLeavesDropUnequippedAndPreservesExistingItem() throws {
        var state = GameState.newGame(balance: .standard)
        let existing = Item(id: ItemID(rawValue: 99), level: 1, slot: .weapon, primaryStat: 0, creationSequence: 99)
        state.inventory = [existing]
        state.equipment.weaponID = existing.id
        state.autoEquipEnabled = false
        state.hero.timeUntilNextAttack = .zero
        state.enemy.currentHealth = 1
        var simulation = GameSimulation(state: state)

        _ = try simulation.advance(by: .zero)

        XCTAssertEqual(simulation.state.equipment.weaponID, existing.id)
        XCTAssertEqual(simulation.state.inventory.map(\.id), [existing.id, ItemID(rawValue: 1)])
    }

    func testManualEquipAndAutoEquipPreferencePreserveInventory() throws {
        var state = GameState.newGame(balance: .standard)
        let existing = Item(id: ItemID(rawValue: 7), level: 1, slot: .weapon, primaryStat: 1, creationSequence: 7)
        state.inventory = [existing]
        state.equipment.weaponID = existing.id
        var simulation = GameSimulation(state: state)

        XCTAssertEqual(try simulation.apply(.setAutoEquip(false)), [.autoEquipChanged(false)])
        XCTAssertEqual(try simulation.apply(.setAutoEquip(false)), [])
        XCTAssertEqual(try simulation.apply(.equip(existing.id)), [.equipped(slot: .weapon, itemID: existing.id)])
        XCTAssertThrowsError(try simulation.apply(.equip(ItemID(rawValue: 999)))) { error in
            XCTAssertEqual(error as? GameIntentError, .itemNotFound)
        }

        XCTAssertEqual(simulation.state.inventory, [existing])
        XCTAssertEqual(simulation.state.equipment.weaponID, existing.id)
    }

    func testManualEquipRejectsWrongSlot() throws {
        var state = GameState.newGame(balance: .standard)
        let armor = Item(id: ItemID(rawValue: 1), level: 1, slot: .armor, primaryStat: 1, creationSequence: 1)
        let duplicateWeapon = Item(id: armor.id, level: 1, slot: .weapon, primaryStat: 1, creationSequence: 1)
        state.inventory = [armor, duplicateWeapon]
        var simulation = GameSimulation(state: state)

        XCTAssertThrowsError(try simulation.apply(.equip(armor.id))) { error in
            XCTAssertEqual(error as? GameIntentError, .slotMismatch)
        }
        XCTAssertNil(simulation.state.equipment.weaponID)
        XCTAssertNil(simulation.state.equipment.armorID)
    }

    func testEnablingAutoEquipDoesNotRetroactivelyScanInventory() throws {
        var state = GameState.newGame(balance: .standard)
        let weapon = Item(id: ItemID(rawValue: 1), level: 1, slot: .weapon, primaryStat: 100, creationSequence: 1)
        state.inventory = [weapon]
        state.autoEquipEnabled = false
        var simulation = GameSimulation(state: state)

        XCTAssertEqual(try simulation.apply(.setAutoEquip(true)), [.autoEquipChanged(true)])
        XCTAssertNil(simulation.state.equipment.weaponID)
    }

    func testVictoryLootFailureRollsBackEntireCandidate() throws {
        var state = GameState.newGame(balance: .standard)
        state.enemy.currentHealth = 1
        state.hero.timeUntilNextAttack = .zero
        state.lootSequence = .max
        var simulation = GameSimulation(state: state)
        let original = simulation.state

        XCTAssertThrowsError(try simulation.advance(by: .zero)) { error in
            XCTAssertEqual(error as? SimulationError, .arithmeticOverflow)
        }
        XCTAssertEqual(simulation.state, original)
    }

    func testVictoryItemIDCollisionRollsBackEntireCandidate() {
        var state = GameState.newGame(balance: .standard)
        state.inventory = [
            Item(
                id: ItemID(rawValue: 1),
                level: 1,
                slot: .armor,
                primaryStat: 1,
                creationSequence: 99
            )
        ]
        state.enemy.currentHealth = 1
        state.hero.timeUntilNextAttack = .zero
        var simulation = GameSimulation(state: state)
        let original = simulation.state

        XCTAssertThrowsError(try simulation.advance(by: .zero)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidState)
        }
        XCTAssertEqual(simulation.state.hero, original.hero)
        XCTAssertEqual(simulation.state.inventory, original.inventory)
        XCTAssertEqual(simulation.state.encounter, original.encounter)
        XCTAssertEqual(simulation.state.lootSequence, original.lootSequence)
        XCTAssertEqual(simulation.state, original)
    }

    private func duration(milliseconds: Int64) throws -> SimulationDuration {
        try XCTUnwrap(SimulationDuration.milliseconds(milliseconds))
    }

    private func duration(seconds: Int64) throws -> SimulationDuration {
        try XCTUnwrap(SimulationDuration.seconds(seconds))
    }
}

private extension GameEvent {
    var isAttack: Bool {
        if case .attack = self { return true }
        return false
    }
}
