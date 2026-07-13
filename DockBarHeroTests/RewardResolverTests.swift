import XCTest
@testable import DockBarHero

final class RewardResolverTests: XCTestCase {
    func testOneVictoryCanGrantMultipleLevels() throws {
        var state = GameState.newGame(
            classID: .dps,
            balance: .standard,
            progression: .standard
        )
        state.party.heroes[0].currentXP = 500

        let result = try RewardResolver().applyVictory(
            defeatedLevel: 2,
            tier: .normal,
            to: state,
            balance: .standard
        )

        XCTAssertEqual(result.state.party.heroes[0].level, 3)
        XCTAssertEqual(result.state.party.heroes[0].currentXP, 100)
        XCTAssertEqual(result.state.party.heroes[0].combat.maxHealth, 101)
        XCTAssertEqual(result.events.filter {
            if case .heroLeveled = $0 { return true }
            return false
        }.count, 2)
    }

    func testGoldOverflowRejectsVictoryTransaction() throws {
        var state = GameState.newGame(balance: .standard)
        state.economy.gold = .max

        XCTAssertThrowsError(
            try RewardResolver().applyVictory(
                defeatedLevel: 1,
                tier: .normal,
                to: state,
                balance: .standard
            )
        ) { error in
            XCTAssertEqual(error as? SimulationError, .arithmeticOverflow)
        }
    }

    func testEliteVictoryAwardsLevelGoldAndOneItem() throws {
        var state = GameState.newGame(
            classID: .dps,
            balance: .standard,
            progression: .standard
        )
        state.campaign = .init(
            highestUnlockedLevel: 5,
            selectedLevel: 5,
            queuedLevel: nil,
            mode: .push,
            consecutiveDefeats: 0
        )
        state.encounter.enemyLevel = 5
        state.encounter.tier = .elite
        state.party.heroes[0].level = 5
        state.party.heroes[0].currentXP = 1_407

        let result = try RewardResolver().applyVictory(
            defeatedLevel: 5,
            tier: .elite,
            to: state,
            balance: .standard
        )

        XCTAssertEqual(result.state.party.heroes[0].level, 6)
        XCTAssertEqual(result.state.party.heroes[0].currentXP, 0)
        XCTAssertEqual(result.state.party.heroes[0].combat.maxHealth, 103)
        XCTAssertEqual(result.state.economy.gold, 60)
        XCTAssertEqual(result.state.inventory.count, 1)
        XCTAssertEqual(result.events.prefix(3), [
            .xpGained(classID: .dps, amount: 1_093),
            .heroLeveled(classID: .dps, level: 6),
            .goldGained(amount: 60)
        ])
    }

    func testVictoryRewardAddsOneItemAndPreservesOwnedInventory() throws {
        var state = GameState.newGame(balance: .standard)
        let existing = Item(id: ItemID(rawValue: 9), level: 1, slot: .armor, primaryStat: 1, creationSequence: 9)
        state.inventory = [existing]
        state.lootSequence = 9

        let result = try RewardResolver().applyVictory(defeatedLevel: 1, to: state, balance: .standard)

        XCTAssertEqual(result.state.inventory.first, existing)
        XCTAssertEqual(result.state.inventory.count, 2)
        XCTAssertEqual(result.events.filter { if case .loot = $0 { true } else { false } }.count, 1)
    }

    func testVictoryRewardAutoEquipsOnlyAStrictSameSlotUpgrade() throws {
        var state = GameState.newGame(balance: .standard)
        let existing = Item(id: ItemID(rawValue: 99), level: 1, slot: .weapon, primaryStat: 0, creationSequence: 99)
        state.inventory = [existing]
        state.equipment.weaponID = existing.id

        let result = try RewardResolver().applyVictory(defeatedLevel: 1, to: state, balance: .standard)

        XCTAssertEqual(result.state.equipment.weaponID, ItemID(rawValue: 1))
        XCTAssertEqual(result.events, [
            .xpGained(classID: .dps, amount: 25),
            .goldGained(amount: 24),
            .loot(Item(id: ItemID(rawValue: 1), level: 1, slot: .weapon, primaryStat: 1, creationSequence: 1)),
            .equipped(slot: .weapon, itemID: ItemID(rawValue: 1))
        ])
    }

    func testVictoryRewardDoesNotAutoEquipWhenDisabledOrTied() throws {
        var state = GameState.newGame(balance: .standard)
        let existing = Item(id: ItemID(rawValue: 99), level: 1, slot: .weapon, primaryStat: 1, creationSequence: 99)
        state.inventory = [existing]
        state.equipment.weaponID = existing.id
        state.autoEquipEnabled = false

        let result = try RewardResolver().applyVictory(defeatedLevel: 1, to: state, balance: .standard)

        XCTAssertEqual(result.state.equipment.weaponID, existing.id)
        XCTAssertEqual(result.events, [
            .xpGained(classID: .dps, amount: 25),
            .goldGained(amount: 24),
            .loot(Item(id: ItemID(rawValue: 1), level: 1, slot: .weapon, primaryStat: 1, creationSequence: 1))
        ])
    }

    func testVictoryRewardInvalidLootRollsBackState() {
        var state = GameState.newGame(balance: .standard)
        state.lootSequence = .max
        let original = state

        XCTAssertThrowsError(try RewardResolver().applyVictory(defeatedLevel: 1, to: state, balance: .standard)) { error in
            XCTAssertEqual(error as? SimulationError, .arithmeticOverflow)
        }
        XCTAssertEqual(state, original)
    }

    func testPartyXPIsProportionalToAliveDurationAndUpdatesStreaksIndependently() throws {
        var state = GameState.newGame(classID: .tank, balance: .standard, progression: .standard)
        var second = GameState.newGame(classID: .dps, balance: .standard, progression: .standard).party.heroes[0]
        state.party.heroes[0].consecutiveDeaths = 2
        state.party.heroes[0].encounterAliveDuration = .nanoseconds(10)
        second.consecutiveDeaths = 2
        second.encounterAliveDuration = .nanoseconds(3)
        second.wasDownThisEncounter = true
        second.combat.currentHealth = 0
        state.party = PartyState(heroes: [state.party.heroes[0], second], unlocks: .secondUnlocked)
        state.encounter.activeElapsed = .nanoseconds(10)

        let result = try RewardResolver().applyVictory(
            defeatedLevel: 1,
            tier: .normal,
            to: state,
            balance: .standard
        )

        XCTAssertTrue(result.events.contains(.xpGained(classID: .tank, amount: 25)))
        XCTAssertTrue(result.events.contains(.xpGained(classID: .dps, amount: 7)))
        XCTAssertEqual(result.state.party.heroes[0].consecutiveDeaths, 0)
        XCTAssertEqual(result.state.party.heroes[1].consecutiveDeaths, 3)
    }

    func testPositiveAliveDurationAlwaysAwardsAtLeastOneXP() throws {
        var state = GameState.newGame(classID: .tank, balance: .standard, progression: .standard)
        var second = GameState.newGame(classID: .dps, balance: .standard, progression: .standard).party.heroes[0]
        state.party.heroes[0].encounterAliveDuration = .nanoseconds(100)
        second.encounterAliveDuration = .nanoseconds(1)
        state.party = PartyState(heroes: [state.party.heroes[0], second], unlocks: .secondUnlocked)
        state.encounter.activeElapsed = .nanoseconds(100)

        let result = try RewardResolver().applyVictory(defeatedLevel: 1, to: state, balance: .standard)

        XCTAssertTrue(result.events.contains(.xpGained(classID: .dps, amount: 1)))
    }
}
