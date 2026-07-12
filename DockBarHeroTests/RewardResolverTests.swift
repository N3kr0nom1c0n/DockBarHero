import XCTest
@testable import DockBarHero

final class RewardResolverTests: XCTestCase {
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
        XCTAssertEqual(result.events.count, 1)
        XCTAssertEqual(result.events.first, .loot(Item(id: ItemID(rawValue: 1), level: 1, slot: .weapon, primaryStat: 1, creationSequence: 1)))
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
}
