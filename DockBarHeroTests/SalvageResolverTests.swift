import XCTest
@testable import DockBarHero

final class SalvageResolverTests: XCTestCase {
    func testBatchSalvageRemovesExactQuantitiesAndGrantsGoldOnce() throws {
        var state = GameState.newGame(balance: .standard)
        let common = item(id: 1, level: 10, rarity: .common, quantity: 3)
        let rare = item(
            id: 2,
            level: 5,
            rarity: .rare,
            quantity: 2,
            affixes: [.init(id: .haste, magnitude: 1_000), .init(id: .might, magnitude: 1)]
        )
        state.inventory = [common]
        state.overflowInventory = [rare]
        state.lootSequence = 2

        let result = try SalvageResolver().salvage([
            .init(location: .inventory, itemID: common.id, quantity: 2),
            .init(location: .overflow, itemID: rare.id, quantity: 1),
        ], in: state)

        XCTAssertEqual(result.goldGranted, 40)
        XCTAssertEqual(result.state.economy.gold, 40)
        XCTAssertEqual(result.state.inventory[0].quantity, 1)
        XCTAssertEqual(result.state.overflowInventory[0].quantity, 1)
    }

    func testLockedSelectionRejectsWholeBatch() throws {
        var state = GameState.newGame(balance: .standard)
        var locked = item(id: 1, level: 10, rarity: .common, quantity: 2)
        locked.isLocked = true
        state.inventory = [locked]
        state.lootSequence = 1

        XCTAssertThrowsError(try SalvageResolver().salvage([
            .init(location: .inventory, itemID: locked.id, quantity: 1),
        ], in: state))
    }

    func testSameEntryCannotAppearTwiceWithDifferentQuantities() throws {
        var state = GameState.newGame(balance: .standard)
        state.inventory = [item(id: 1, level: 10, rarity: .common, quantity: 3)]

        XCTAssertThrowsError(try SalvageResolver().salvage([
            SalvageSelection(location: .inventory, itemID: ItemID(rawValue: 1), quantity: 1),
            SalvageSelection(location: .inventory, itemID: ItemID(rawValue: 1), quantity: 2),
        ], in: state))
        XCTAssertEqual(state.inventory[0].quantity, 3)
        XCTAssertEqual(state.economy.gold, 0)
    }

    func testEquippedSelectionRejectsWholeBatchWithoutMutation() {
        var state = GameState.newGame(balance: .standard)
        let good = item(id: 1, level: 2, rarity: .common, quantity: 1)
        let equipped = item(id: 2, level: 3, rarity: .common, quantity: 1)
        state.inventory = [good, equipped]
        state.party.heroes[0].equipment.weaponID = equipped.id
        state.lootSequence = 2
        let original = state

        XCTAssertThrowsError(try SalvageResolver().salvage([
            .init(location: .inventory, itemID: good.id, quantity: 1),
            .init(location: .inventory, itemID: equipped.id, quantity: 1),
        ], in: state))
        XCTAssertEqual(state, original)
    }

    func testGoldOverflowRejectsWholeBatch() {
        var state = GameState.newGame(balance: .standard)
        let item = item(id: 1, level: 1, rarity: .common, quantity: 1)
        state.inventory = [item]
        state.economy.gold = .max
        state.lootSequence = 1

        XCTAssertThrowsError(try SalvageResolver().salvage([
            .init(location: .inventory, itemID: item.id, quantity: 1),
        ], in: state)) { error in
            XCTAssertEqual(error as? SimulationError, .arithmeticOverflow)
        }
        XCTAssertEqual(state.inventory, [item])
        XCTAssertEqual(state.economy.gold, .max)
    }

    private func item(
        id: UInt64,
        level: Int,
        rarity: ItemRarity,
        quantity: UInt64,
        affixes: [ItemAffix] = []
    ) -> Item {
        Item(
            id: ItemID(rawValue: id),
            level: level,
            slot: .weapon,
            primaryStat: max(1, level),
            creationSequence: id,
            rarity: rarity,
            affixes: affixes.sorted { $0.id < $1.id },
            quantity: quantity
        )
    }
}
