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
