import XCTest
@testable import DockBarHero

final class GameSimulationTests: XCTestCase {
    func testGamePresentationCarriesAuthoredIdentityWithoutSavingIt() throws {
        let state = try authoredState(level: 15)

        let campaign = try XCTUnwrap(GameSimulation(state: state).presentation.campaign)

        XCTAssertEqual(campaign.areaID, .forgottenShallowDepths)
        XCTAssertEqual(campaign.areaFullName, "The Forgotten Shallow Depths That Were Remembered")
        XCTAssertEqual(campaign.areaShortName, "Shallow Depths")
        XCTAssertEqual(campaign.enemyID, .poisonNagaQueen)
        XCTAssertEqual(campaign.enemyName, "Poison Naga Queen")
        XCTAssertEqual(campaign.enemySpriteID, .poisonNagaQueen)
        XCTAssertEqual(campaign.tier, .elite)
        XCTAssertEqual(campaign.level, 15)
        let json = String(data: try JSONEncoder().encode(state), encoding: .utf8)!
        XCTAssertFalse(json.contains("Poison Naga Queen"))
    }

    func testGamePresentationOmitsCampaignIdentityForProceduralLevels() throws {
        let state = try authoredState(level: 26)

        XCTAssertNil(GameSimulation(state: state).presentation.campaign)
    }

    func testEmptyInMemoryPartyIsRejectedBeforeCompatibilityAccess() throws {
        var state = GameState.newGame(balance: .standard)
        state.party.heroes = []
        var simulation = GameSimulation(state: state)

        XCTAssertEqual(simulation.presentation.heroAttack, 0)
        XCTAssertThrowsError(try simulation.advance(by: .zero)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidState)
        }
    }

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
            .xpGained(classID: .dps, amount: 25),
            .goldGained(amount: 24),
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
        state.campaign.highestUnlockedLevel = .max
        state.campaign.selectedLevel = .max
        state.encounter.tier = .normal
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

    func testWrongAuthoredTierIsRejectedBeforeMutation() throws {
        let resolved = try CampaignResolver().resolve(level: 9)
        var state = GameState.newGame(balance: .standard)
        state.campaign.highestUnlockedLevel = 9
        state.campaign.selectedLevel = 9
        state.encounter.enemyLevel = 9
        state.encounter.tier = .elite
        state.enemy = try EnemyFactory().makeEnemy(
            for: resolved,
            balance: .standard,
            progression: .standard
        )
        var simulation = GameSimulation(state: state)
        let original = simulation.state

        XCTAssertThrowsError(try simulation.advance(by: .zero)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidState)
        }
        XCTAssertEqual(simulation.state, original)
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
            .xpGained(classID: .dps, amount: 25),
            .goldGained(amount: 24),
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
            .xpGained(classID: .dps, amount: 25),
            .goldGained(amount: 24),
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

    func testManualEquipTargetsOneHeroAndRejectsItemOwnedByAnother() throws {
        var state = twoHeroState()
        let firstWeapon = Item(id: ItemID(rawValue: 1), level: 1, slot: .weapon, primaryStat: 2, creationSequence: 1)
        let secondWeapon = Item(id: ItemID(rawValue: 2), level: 1, slot: .weapon, primaryStat: 3, creationSequence: 2)
        state.inventory = [firstWeapon, secondWeapon]
        state.party.heroes[0].equipment.weaponID = firstWeapon.id
        var simulation = GameSimulation(state: state)

        XCTAssertEqual(
            try simulation.apply(.equipHero(slot: 1, itemID: secondWeapon.id)),
            [.equippedHero(heroSlot: 1, slot: .weapon, itemID: secondWeapon.id)]
        )
        XCTAssertThrowsError(try simulation.apply(.equipHero(slot: 1, itemID: firstWeapon.id))) { error in
            XCTAssertEqual(error as? GameIntentError, .itemInUse)
        }
        XCTAssertEqual(simulation.state.party.heroes[0].equipment.weaponID, firstWeapon.id)
        XCTAssertEqual(simulation.state.party.heroes[1].equipment.weaponID, secondWeapon.id)
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

    func testBoss25VictoryCommitsRewardsThenPausesForSecondHero() throws {
        var state = GameState.newGame(classID: .tank, balance: .standard, progression: .standard)
        state.campaign.highestUnlockedLevel = 25
        state.campaign.selectedLevel = 25
        state.encounter.enemyLevel = 25
        state.encounter.tier = .boss
        state.encounter.activeElapsed = try duration(seconds: 1)
        state.party.heroes[0].encounterAliveDuration = try duration(seconds: 1)
        state.enemy = try XCTUnwrap(BalanceConfiguration.standard.enemy(level: 25, tier: .boss, progression: .standard))
        state.enemy.currentHealth = 1
        state.hero.timeUntilNextAttack = .zero
        var simulation = GameSimulation(state: state)

        let events = try simulation.advance(by: .zero)

        XCTAssertTrue(events.contains(.partyUnlockPending(.boss25)))
        XCTAssertEqual(simulation.state.encounter.phase, .awaitingPartyChoice)
        XCTAssertEqual(simulation.state.party.unlocks.pendingUnlock?.choices, [.dps, .healer])
        XCTAssertGreaterThan(simulation.state.economy.gold, 0)
        XCTAssertEqual(simulation.state.encounter.enemyLevel, 25)
        XCTAssertEqual(try simulation.advance(by: try duration(seconds: 1)), [])
        XCTAssertEqual(simulation.state.encounter.enemyLevel, 25)
    }

    func testPartyHeroActionsResolveByAscendingSlotBeforeEnemy() throws {
        var state = twoHeroState()
        state.party.heroes[0].combat.timeUntilNextAttack = .zero
        state.party.heroes[1].combat.timeUntilNextAttack = .zero
        state.enemy.timeUntilNextAttack = .zero
        var simulation = GameSimulation(state: state)

        let events = try simulation.advance(by: .zero)

        XCTAssertEqual(events.prefix(3), [
            .heroAttack(slot: 0, damage: 8),
            .heroAttack(slot: 1, damage: 12),
            .enemyAttack(targetSlot: 0, damage: 1),
        ])
    }

    func testEnemyTargetsLowestLivingHeroAndDoesNotDefeatLivingParty() throws {
        var state = twoHeroState()
        state.party.heroes[0].combat.currentHealth = 0
        state.party.heroes[0].wasDownThisEncounter = true
        state.enemy.timeUntilNextAttack = .zero
        var simulation = GameSimulation(state: state)

        let events = try simulation.advance(by: .zero)

        XCTAssertEqual(events, [.enemyAttack(targetSlot: 1, damage: 3)])
        XCTAssertEqual(simulation.state.party.heroes[0].combat.currentHealth, 0)
        XCTAssertGreaterThan(simulation.state.party.heroes[1].combat.currentHealth, 0)
        XCTAssertEqual(simulation.state.encounter.phase, .active)
    }

    func testPartyDefeatBeginsOnlyAfterEveryHeroIsDown() throws {
        var state = twoHeroState()
        state.party.heroes[0].combat.currentHealth = 1
        state.party.heroes[1].combat.currentHealth = 1
        state.party.heroes[0].combat.timeUntilNextAttack = try duration(seconds: 2)
        state.party.heroes[1].combat.timeUntilNextAttack = try duration(seconds: 2)
        state.enemy = CombatantState(
            id: .enemy,
            currentHealth: 1_000,
            maxHealth: 1_000,
            baseAttack: 3,
            baseDefense: 0,
            attackInterval: try duration(seconds: 1),
            timeUntilNextAttack: .zero
        )
        var simulation = GameSimulation(state: state)

        XCTAssertEqual(try simulation.advance(by: .zero), [
            .enemyAttack(targetSlot: 0, damage: 1),
            .heroDown(slot: 0),
        ])
        XCTAssertEqual(simulation.state.encounter.phase, .active)

        let events = try simulation.advance(by: try duration(seconds: 1))
        XCTAssertEqual(events, [
            .enemyAttack(targetSlot: 1, damage: 3),
            .heroDown(slot: 1),
            .defeat(enemyLevel: 1),
        ])
        XCTAssertEqual(simulation.state.encounter.phase, .reviving)
    }

    func testVictoryRewardsCommitBeforeHeroDeathStreakRetreat() throws {
        var state = twoHeroState()
        state.campaign.highestUnlockedLevel = 50
        state.campaign.selectedLevel = 50
        state.encounter.enemyLevel = 50
        state.encounter.tier = .boss
        state.encounter.activeElapsed = try duration(seconds: 1)
        state.party.heroes[0].encounterAliveDuration = try duration(seconds: 1)
        state.party.heroes[0].combat.timeUntilNextAttack = .zero
        state.party.heroes[1].combat.currentHealth = 0
        state.party.heroes[1].wasDownThisEncounter = true
        state.party.heroes[1].consecutiveDeaths = 2
        state.enemy = try XCTUnwrap(BalanceConfiguration.standard.enemy(level: 50, tier: .boss, progression: .standard))
        state.enemy.currentHealth = 1
        var simulation = GameSimulation(state: state)

        let events = try simulation.advance(by: .zero)

        XCTAssertTrue(events.contains(.victory(defeatedLevel: 50)))
        XCTAssertTrue(events.contains(where: { if case .loot = $0 { return true }; return false }))
        XCTAssertGreaterThan(simulation.state.economy.gold, 0)
        XCTAssertEqual(simulation.state.campaign.selectedLevel, 24)
        XCTAssertEqual(simulation.state.campaign.mode, .farming)
        XCTAssertEqual(simulation.state.party.heroes.map(\.consecutiveDeaths), [0, 0])
    }

    func testQueuedDestinationStillPrecedesHeroDeathStreakRetreat() throws {
        var state = twoHeroState()
        state.campaign.highestUnlockedLevel = 50
        state.campaign.selectedLevel = 50
        state.campaign.queuedLevel = 10
        state.encounter.enemyLevel = 50
        state.encounter.tier = .boss
        state.encounter.activeElapsed = try duration(seconds: 1)
        state.party.heroes[0].encounterAliveDuration = try duration(seconds: 1)
        state.party.heroes[0].combat.timeUntilNextAttack = .zero
        state.party.heroes[1].combat.currentHealth = 0
        state.party.heroes[1].wasDownThisEncounter = true
        state.party.heroes[1].consecutiveDeaths = 2
        state.enemy = try XCTUnwrap(BalanceConfiguration.standard.enemy(level: 50, tier: .boss, progression: .standard))
        state.enemy.currentHealth = 1
        var simulation = GameSimulation(state: state)

        _ = try simulation.advance(by: .zero)

        XCTAssertEqual(simulation.state.campaign.selectedLevel, 10)
        XCTAssertEqual(simulation.state.party.heroes.map(\.consecutiveDeaths), [0, 0])
    }

    private func twoHeroState() -> GameState {
        var state = GameState.newGame(classID: .tank, balance: .standard, progression: .standard)
        let second = GameState.newGame(classID: .dps, balance: .standard, progression: .standard).party.heroes[0]
        state.party = PartyState(heroes: [state.party.heroes[0], second], unlocks: .secondUnlocked)
        return state
    }

    private func authoredState(level: Int) throws -> GameState {
        var state = GameState.newGame(balance: .standard)
        let resolved = try CampaignResolver().resolve(level: level)
        state.campaign = CampaignState(
            highestUnlockedLevel: level,
            selectedLevel: level,
            queuedLevel: nil,
            mode: .push,
            consecutiveDefeats: 0
        )
        state.encounter.enemyLevel = level
        state.encounter.tier = resolved.tier
        state.enemy = try EnemyFactory().makeEnemy(
            for: resolved,
            balance: .standard,
            progression: .standard
        )
        return state
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
