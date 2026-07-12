import XCTest
@testable import DockBarHero

final class LootSystemTests: XCTestCase {
    func testBossItemMultiplierUsesCheckedCeiling() throws {
        var state = GameState.newGame(balance: .standard)
        var loot = LootSystem(balance: .standard)

        let item = try loot.drop(defeatedLevel: 1, tier: .boss, state: &state)

        XCTAssertEqual(item.primaryStat, 2)
    }

    func testDropsAlternateSlotsAndUseStableSequenceIDs() throws {
        var state = GameState.newGame(balance: .standard)
        var loot = LootSystem(balance: .standard)

        let first = try loot.drop(defeatedLevel: 1, state: &state)
        let second = try loot.drop(defeatedLevel: 2, state: &state)

        XCTAssertEqual(first.id, ItemID(rawValue: 1))
        XCTAssertEqual(first.slot, .weapon)
        XCTAssertEqual(second.id, ItemID(rawValue: 2))
        XCTAssertEqual(second.slot, .armor)
        XCTAssertEqual(first.primaryStat, 1)
        XCTAssertEqual(second.primaryStat, 1)
        XCTAssertEqual(state.lootSequence, 2)
        XCTAssertEqual(state.inventory, [first, second])
    }

    func testNilPrimaryStatRollsBackStateAndThrowsInvalidBalance() {
        let balance = BalanceConfiguration(
            heroMaxHealth: 100,
            heroBaseAttack: 10,
            heroBaseDefense: 0,
            heroAttackInterval: .nanoseconds(1_000_000_000),
            enemyBaseHealth: 30,
            enemyBaseAttack: 3,
            enemyBaseDefense: 0,
            enemyAttackInterval: .nanoseconds(1_500_000_000),
            reviveDelay: .nanoseconds(3_000_000_000)
        )
        var state = GameState.newGame(balance: balance)
        let original = state
        var loot = LootSystem(balance: balance)

        XCTAssertThrowsError(try loot.drop(defeatedLevel: 0, state: &state)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidBalance)
        }
        XCTAssertEqual(state, original)
    }

    func testReplayProducesIdenticalItemsAndState() throws {
        var firstState = GameState.newGame(balance: .standard)
        var secondState = firstState
        var firstLoot = LootSystem(balance: .standard)
        var secondLoot = LootSystem(balance: .standard)

        for level in 1...6 {
            XCTAssertEqual(
                try firstLoot.drop(defeatedLevel: level, state: &firstState),
                try secondLoot.drop(defeatedLevel: level, state: &secondState)
            )
        }
        XCTAssertEqual(firstState, secondState)
    }

    func testNextItemIDCollisionThrowsBeforeMutation() {
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
        let original = state
        var loot = LootSystem(balance: .standard)

        XCTAssertThrowsError(try loot.drop(defeatedLevel: 1, state: &state)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidState)
        }
        XCTAssertEqual(state, original)
    }

    func testNextCreationSequenceCollisionThrowsBeforeMutation() {
        var state = GameState.newGame(balance: .standard)
        state.inventory = [
            Item(
                id: ItemID(rawValue: 99),
                level: 1,
                slot: .armor,
                primaryStat: 1,
                creationSequence: 1
            )
        ]
        let original = state
        var loot = LootSystem(balance: .standard)

        XCTAssertThrowsError(try loot.drop(defeatedLevel: 1, state: &state)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidState)
        }
        XCTAssertEqual(state, original)
    }
}
