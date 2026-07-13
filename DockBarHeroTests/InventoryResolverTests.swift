import XCTest
@testable import DockBarHero

final class InventoryResolverTests: XCTestCase {
    func testCapacityIncludesMilestonesAndPurchases() throws {
        var state = GameState.newGame(balance: .standard)
        XCTAssertEqual(try InventoryResolver().capacity(for: state), 40)
        state.party.unlocks = .pendingSecond(.init(milestone: .boss25, choices: [.tank, .healer]))
        XCTAssertEqual(try InventoryResolver().capacity(for: state), 50)
        state.party.unlocks = .complete
        state.inventoryExpansionPurchases = 2
        XCTAssertEqual(try InventoryResolver().capacity(for: state), 90)
    }

    func testFullInventoryMergesExactStackOtherwiseUsesOverflow() throws {
        var state = GameState.newGame(balance: .standard)
        state.inventory = (1...40).map { id in
            item(id: UInt64(id), level: id, quantity: 1)
        }
        state.lootSequence = 40
        let matching = item(id: 41, level: 1, quantity: 1)

        let merged = try InventoryResolver().insertDrop(matching, into: state)
        XCTAssertEqual(merged.state.inventory.first(where: { $0.level == 1 })?.quantity, 2)
        XCTAssertTrue(merged.state.overflowInventory.isEmpty)

        let different = item(id: 41, level: 99, quantity: 1)
        let overflowed = try InventoryResolver().insertDrop(different, into: state)
        XCTAssertEqual(overflowed.state.inventory.count, 40)
        XCTAssertEqual(overflowed.state.overflowInventory, [different])
    }

    func testLockedAndUnlockedDescriptorsDoNotStack() {
        var unlocked = item(id: 1, level: 1, quantity: 1)
        var locked = item(id: 2, level: 1, quantity: 1)
        locked.isLocked = true

        XCTAssertFalse(InventoryResolver().canStack(unlocked, with: locked))
        unlocked.isLocked = true
        XCTAssertTrue(InventoryResolver().canStack(unlocked, with: locked))
    }

    func testCapacityPurchaseDeductsDoublingPriceAndAddsSlots() throws {
        var state = GameState.newGame(balance: .standard)
        state.economy.gold = 2_000
        var simulation = GameSimulation(state: state)

        _ = try simulation.apply(.purchaseInventoryCapacity)
        XCTAssertEqual(simulation.state.economy.gold, 1_500)
        XCTAssertEqual(simulation.state.inventoryExpansionPurchases, 1)
        XCTAssertEqual(try InventoryResolver().capacity(for: simulation.state), 50)

        _ = try simulation.apply(.purchaseInventoryCapacity)
        XCTAssertEqual(simulation.state.economy.gold, 500)
        XCTAssertEqual(simulation.state.inventoryExpansionPurchases, 2)
        XCTAssertEqual(try InventoryResolver().capacity(for: simulation.state), 60)
    }

    func testOverflowMoveMergesAtFullCapacity() throws {
        var state = GameState.newGame(balance: .standard)
        state.inventory = (1...40).map { item(id: UInt64($0), level: $0, quantity: 1) }
        let overflow = item(id: 41, level: 1, quantity: 3)
        state.overflowInventory = [overflow]
        state.lootSequence = 41
        var simulation = GameSimulation(state: state)

        _ = try simulation.apply(.moveOverflow(itemID: overflow.id, quantity: 2))

        XCTAssertEqual(simulation.state.inventory.first(where: { $0.level == 1 })?.quantity, 3)
        XCTAssertEqual(simulation.state.overflowInventory.first?.quantity, 1)
    }

    func testEquippingFromStackExtractsExclusiveItemIdentity() throws {
        var state = GameState.newGame(balance: .standard)
        state.inventory = [item(id: 1, level: 3, quantity: 2)]
        state.lootSequence = 1
        var simulation = GameSimulation(state: state)

        _ = try simulation.apply(.equip(ItemID(rawValue: 1)))

        XCTAssertEqual(simulation.state.inventory.count, 2)
        XCTAssertEqual(simulation.state.inventory.first(where: { $0.id.rawValue == 1 })?.quantity, 1)
        XCTAssertEqual(simulation.state.party.heroes[0].equipment[.weapon], ItemID(rawValue: 2))
        XCTAssertEqual(simulation.state.inventory.first(where: { $0.id.rawValue == 2 })?.quantity, 1)
        XCTAssertEqual(simulation.state.lootSequence, 2)
        XCTAssertNoThrow(try SaveCodec().encode(
            state: simulation.state,
            savedAt: Date(timeIntervalSince1970: 0)
        ))
    }

    private func item(id: UInt64, level: Int, quantity: UInt64) -> Item {
        Item(
            id: ItemID(rawValue: id),
            level: level,
            slot: .weapon,
            primaryStat: max(1, level),
            creationSequence: id,
            quantity: quantity
        )
    }
}
