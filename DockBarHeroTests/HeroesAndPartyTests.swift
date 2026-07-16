import XCTest
@testable import DockBarHero

final class HeroesAndPartyTests: XCTestCase {
    func testEveryClassDefeatsBoss25SoloWithBaselineLevel24Equipment() throws {
        for classID in HeroClassID.allCases {
            var simulation = GameSimulation(state: try boss25State(classID: classID))
            var events: [GameEvent] = []
            for _ in 0..<12 where !events.contains(where: { if case .victory = $0 { return true }; return false }) {
                events += try simulation.advance(by: .nanoseconds(1_000_000_000))
                if events.contains(where: { if case .defeat = $0 { return true }; return false }) { break }
            }

            XCTAssertTrue(
                events.contains(where: { if case .victory(defeatedLevel: 25) = $0 { return true }; return false }),
                "\(classID) must defeat Boss 25 solo"
            )
            XCTAssertFalse(events.contains(where: { if case .defeat = $0 { return true }; return false }))
        }
    }

    func testBoss25ChoicePreservesQueuedDestinationPrecedence() throws {
        var state = try boss25State(classID: .tank)
        state.campaign.queuedLevel = 10
        state.enemy.currentHealth = 1
        state.party.heroes[0].combat.timeUntilNextAttack = .zero
        state.encounter.activeElapsed = .nanoseconds(1)
        state.party.heroes[0].encounterAliveDuration = .nanoseconds(1)
        var simulation = GameSimulation(state: state)

        _ = try simulation.advance(by: .zero)
        let resumed = try PartyUnlockResolver().completeSecondUnlock(
            classID: .dps,
            in: simulation.state,
            balance: .standard
        )

        XCTAssertEqual(resumed.campaign.selectedLevel, 10)
        XCTAssertEqual(resumed.campaign.mode, .farming)
        XCTAssertEqual(resumed.party.heroes.count, 2)
    }

    func testNewHeroExtractsStrongestUnusedEquipmentFromStack() throws {
        var state = try boss25State(classID: .tank)
        let stack = Item(
            id: ItemID(rawValue: 3),
            level: 25,
            slot: .weapon,
            primaryStat: 500,
            creationSequence: 3,
            quantity: 2
        )
        state.inventory.append(stack)
        state.lootSequence = 3
        state.enemy.currentHealth = 0
        state.encounter.phase = .awaitingPartyChoice
        state.party.unlocks = .pendingSecond(.init(
            milestone: .boss25,
            choices: [.dps, .healer]
        ))

        let result = try PartyUnlockResolver().completeSecondUnlock(
            classID: .dps,
            in: state,
            balance: .standard
        )

        let equippedID = try XCTUnwrap(result.party.heroes[1].equipment.weaponID)
        XCTAssertNotEqual(equippedID, stack.id)
        XCTAssertEqual(result.inventory.first(where: { $0.id == stack.id })?.quantity, 1)
        XCTAssertEqual(result.inventory.first(where: { $0.id == equippedID })?.quantity, 1)
        XCTAssertNoThrow(try SaveCodec().encode(state: result, savedAt: Date(timeIntervalSince1970: 0)))
    }

    func testBoss100AddsFinalHeroAndBeginsLevel101WithoutPause() throws {
        var state = try activeState(level: 100, classes: [.tank, .dps])
        state.enemy.currentHealth = 1
        state.party.heroes[0].combat.timeUntilNextAttack = .zero
        state.encounter.activeElapsed = .nanoseconds(1)
        state.party.heroes[0].encounterAliveDuration = .nanoseconds(1)
        state.party.heroes[1].encounterAliveDuration = .nanoseconds(1)
        var simulation = GameSimulation(state: state)

        let events = try simulation.advance(by: .zero)

        XCTAssertTrue(events.contains(.victory(defeatedLevel: 100)))
        XCTAssertFalse(events.contains(.partyUnlockPending(.boss100)))
        XCTAssertEqual(simulation.state.party.heroes.map(\.classID), [.tank, .dps, .healer])
        XCTAssertEqual(simulation.state.party.unlocks, .complete)
        XCTAssertEqual(simulation.state.encounter.enemyLevel, 101)
        XCTAssertEqual(simulation.state.encounter.phase, .active)
    }

    func testTwoHeroSimulationIsDeterministicAcrossTimePartitions() throws {
        let state = try activeState(level: 26, classes: [.tank, .dps])
        var single = GameSimulation(state: state)
        var partitioned = GameSimulation(state: state)

        let singleEvents = try single.advance(by: .nanoseconds(3_000_000_000))
        var partitionedEvents: [GameEvent] = []
        for _ in 0..<3 {
            partitionedEvents += try partitioned.advance(by: .nanoseconds(1_000_000_000))
        }

        XCTAssertEqual(single.state, partitioned.state)
        XCTAssertEqual(singleEvents, partitionedEvents)
    }

    func testEnemyStatsDoNotScaleWithPartySize() throws {
        let one = try activeState(level: 101, classes: [.tank])
        let two = try activeState(level: 101, classes: [.tank, .dps])
        let three = try activeState(level: 101, classes: [.tank, .dps, .healer])

        XCTAssertEqual(one.enemy, two.enemy)
        XCTAssertEqual(two.enemy, three.enemy)
    }

    func testBoss100StillWipesLevel240TankAndDPSWithoutEquipment() throws {
        let simulation = try resolvedBoss100Outcome(
            heroLevel: 240,
            classes: [.tank, .dps],
            equipmentLevel: nil
        )

        XCTAssertTrue(simulation.events.contains(.heroDown(slot: 0)))
        XCTAssertTrue(simulation.events.contains(.heroDown(slot: 1)))
        XCTAssertTrue(simulation.events.contains(.defeat(enemyLevel: 100)))
        XCTAssertFalse(simulation.events.contains(.victory(defeatedLevel: 100)))
    }

    func testBoss100GivesMassivelyOverleveledUnequippedPartyAReadableFailureWindow() throws {
        let simulation = try resolvedBoss100Outcome(
            heroLevel: 240,
            classes: [.tank, .dps],
            equipmentLevel: nil
        )

        XCTAssertTrue(simulation.events.contains(.defeat(enemyLevel: 100)))
        XCTAssertFalse(simulation.events.contains(.victory(defeatedLevel: 100)))
        XCTAssertGreaterThanOrEqual(simulation.elapsedSeconds, 12)
    }

    func testBoss100AcceptsLevel240TankAndDPSWithBossLevelEquipment() throws {
        let simulation = try resolvedBoss100Outcome(
            heroLevel: 240,
            classes: [.tank, .dps],
            equipmentLevel: 100
        )

        XCTAssertTrue(simulation.events.contains(.victory(defeatedLevel: 100)))
        XCTAssertFalse(simulation.events.contains(.defeat(enemyLevel: 100)))
    }

    func testOverleveledTwoHeroPartyClearsLevel90EliteWithMidgameEquipment() throws {
        let simulation = try resolvedOutcome(
            enemyLevel: 90,
            heroLevel: 123,
            classes: [.dps, .tank],
            equipmentLevel: 50
        )

        XCTAssertTrue(simulation.events.contains(.victory(defeatedLevel: 90)))
        XCTAssertFalse(simulation.events.contains(.defeat(enemyLevel: 90)))
    }

    private func boss25State(classID: HeroClassID) throws -> GameState {
        var state = try activeState(level: 25, classes: [classID])
        let weapon = Item(
            id: ItemID(rawValue: 1),
            level: 24,
            slot: .weapon,
            primaryStat: try XCTUnwrap(BalanceConfiguration.standard.itemPrimaryStat(level: 24, slot: .weapon)),
            creationSequence: 1
        )
        let armor = Item(
            id: ItemID(rawValue: 2),
            level: 24,
            slot: .armor,
            primaryStat: try XCTUnwrap(BalanceConfiguration.standard.itemPrimaryStat(level: 24, slot: .armor)),
            creationSequence: 2
        )
        state.inventory = [weapon, armor]
        state.lootSequence = 2
        state.party.heroes[0].equipment = EquipmentState(weaponID: weapon.id, armorID: armor.id)
        return state
    }

    private func resolvedBoss100Outcome(
        heroLevel: Int,
        classes: [HeroClassID],
        equipmentLevel: Int?
    ) throws -> (events: [GameEvent], elapsedSeconds: Int) {
        var simulation = GameSimulation(state: try activeState(
            enemyLevel: 100,
            heroLevel: heroLevel,
            classes: classes,
            equipmentLevel: equipmentLevel
        ))
        var events: [GameEvent] = []
        for elapsedSeconds in 0..<600 {
            events += try simulation.advance(by: .nanoseconds(1_000_000_000))
            if events.contains(.victory(defeatedLevel: 100)) ||
                events.contains(.defeat(enemyLevel: 100)) {
                return (events, elapsedSeconds + 1)
            }
        }
        return (events, 600)
    }

    private func resolvedOutcome(
        enemyLevel: Int,
        heroLevel: Int,
        classes: [HeroClassID],
        equipmentLevel: Int?
    ) throws -> (events: [GameEvent], elapsedSeconds: Int) {
        var simulation = GameSimulation(state: try activeState(
            enemyLevel: enemyLevel,
            heroLevel: heroLevel,
            classes: classes,
            equipmentLevel: equipmentLevel
        ))
        var events: [GameEvent] = []
        for elapsedSeconds in 0..<600 {
            events += try simulation.advance(by: .nanoseconds(1_000_000_000))
            if events.contains(.victory(defeatedLevel: enemyLevel)) ||
                events.contains(.defeat(enemyLevel: enemyLevel)) {
                return (events, elapsedSeconds + 1)
            }
        }
        return (events, 600)
    }

    private func activeState(level: Int, classes: [HeroClassID]) throws -> GameState {
        try activeState(enemyLevel: level, heroLevel: level, classes: classes, equipmentLevel: nil)
    }

    private func activeState(
        enemyLevel: Int,
        heroLevel: Int,
        classes: [HeroClassID],
        equipmentLevel: Int?
    ) throws -> GameState {
        let balance = BalanceConfiguration.standard
        let progression = ProgressionConfiguration.standard
        let tier = try XCTUnwrap(EncounterSchedule.standard.tier(for: enemyLevel))
        var heroes: [HeroState] = []
        var inventory: [Item] = []
        var nextItemID: UInt64 = 1
        for (slot, classID) in classes.enumerated() {
            let definition = progression.classDefinition(for: classID)
            let maximumHealth = try progression.scaledStat(
                raw: definition.baseHealth,
                level: heroLevel,
                growthBasisPoints: definition.healthGrowthBasisPoints
            )
            let equipment = try equipmentLevel.map {
                try equipmentState(
                    level: $0,
                    heroSlot: slot,
                    nextItemID: &nextItemID,
                    inventory: &inventory
                )
            } ?? EquipmentState(weaponID: nil, armorID: nil)
            heroes.append(HeroState(
                classID: classID,
                level: heroLevel,
                currentXP: 0,
                combat: CombatantState(
                    id: .hero,
                    currentHealth: maximumHealth,
                    maxHealth: maximumHealth,
                    baseAttack: definition.baseAttack,
                    baseDefense: definition.baseDefense,
                    attackInterval: balance.heroAttackInterval,
                    timeUntilNextAttack: balance.heroAttackInterval
                ),
                equipment: equipment
            ))
        }
        let unlocks: PartyUnlockState = switch heroes.count {
        case 1: .locked
        case 2: .secondUnlocked
        default: .complete
        }
        return GameState(
            party: PartyState(heroes: heroes, unlocks: unlocks),
            enemy: try XCTUnwrap(balance.enemy(level: enemyLevel, tier: tier, progression: progression)),
            encounter: EncounterState(
                enemyLevel: enemyLevel,
                tier: tier,
                phase: .active,
                activeElapsed: .zero,
                heroDamage: 0,
                reviveRemaining: .zero
            ),
            campaign: CampaignState(
                highestUnlockedLevel: enemyLevel,
                selectedLevel: enemyLevel,
                queuedLevel: nil,
                mode: .push,
                consecutiveDefeats: 0
            ),
            economy: EconomyState(gold: 0),
            inventory: inventory,
            autoEquipEnabled: true,
            lootSequence: nextItemID - 1
        )
    }

    private func equipmentState(
        level: Int,
        heroSlot: Int,
        nextItemID: inout UInt64,
        inventory: inout [Item]
    ) throws -> EquipmentState {
        let weaponID = ItemID(rawValue: nextItemID)
        nextItemID += 1
        let armorID = ItemID(rawValue: nextItemID)
        nextItemID += 1
        let weapon = Item(
            id: weaponID,
            level: level,
            slot: .weapon,
            primaryStat: try XCTUnwrap(BalanceConfiguration.standard.itemPrimaryStat(level: level, slot: .weapon)),
            creationSequence: weaponID.rawValue
        )
        let armor = Item(
            id: armorID,
            level: level,
            slot: .armor,
            primaryStat: try XCTUnwrap(BalanceConfiguration.standard.itemPrimaryStat(level: level, slot: .armor)),
            creationSequence: armorID.rawValue
        )
        inventory.append(contentsOf: [weapon, armor])
        return EquipmentState(weaponID: weaponID, armorID: armorID)
    }
}
