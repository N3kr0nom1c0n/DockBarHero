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

    private func activeState(level: Int, classes: [HeroClassID]) throws -> GameState {
        let balance = BalanceConfiguration.standard
        let progression = ProgressionConfiguration.standard
        let tier = try XCTUnwrap(EncounterSchedule.standard.tier(for: level))
        var heroes: [HeroState] = []
        for classID in classes {
            let definition = progression.classDefinition(for: classID)
            let maximumHealth = try progression.scaledStat(
                raw: definition.baseHealth,
                level: level,
                growthBasisPoints: definition.healthGrowthBasisPoints
            )
            heroes.append(HeroState(
                classID: classID,
                level: level,
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
                equipment: EquipmentState(weaponID: nil, armorID: nil)
            ))
        }
        let unlocks: PartyUnlockState = switch heroes.count {
        case 1: .locked
        case 2: .secondUnlocked
        default: .complete
        }
        return GameState(
            party: PartyState(heroes: heroes, unlocks: unlocks),
            enemy: try XCTUnwrap(balance.enemy(level: level, tier: tier, progression: progression)),
            encounter: EncounterState(
                enemyLevel: level,
                tier: tier,
                phase: .active,
                activeElapsed: .zero,
                heroDamage: 0,
                reviveRemaining: .zero
            ),
            campaign: CampaignState(
                highestUnlockedLevel: level,
                selectedLevel: level,
                queuedLevel: nil,
                mode: .push,
                consecutiveDefeats: 0
            ),
            economy: EconomyState(gold: 0),
            inventory: [],
            autoEquipEnabled: true,
            lootSequence: 0
        )
    }
}
