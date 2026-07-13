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

    func testStackSignatureUsesOnlyApprovedDescriptorFields() {
        let first = item(id: 1, level: 4, quantity: 1)
        var second = item(id: 2, level: 4, quantity: 1)
        second = Item(
            id: second.id,
            level: second.level,
            slot: .armor,
            primaryStat: 999,
            creationSequence: second.creationSequence,
            templateID: first.templateID,
            rarity: second.rarity,
            affixes: second.affixes,
            isLocked: second.isLocked,
            quantity: second.quantity
        )

        XCTAssertTrue(InventoryResolver().canStack(first, with: second))
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

    func testCapacityPurchaseRejectsAtCapWithoutMutation() throws {
        var state = GameState.newGame(balance: .standard)
        state.party.unlocks = .complete
        state.inventoryExpansionPurchases = 13
        state.economy.gold = .max
        let original = state
        var simulation = GameSimulation(state: state)

        XCTAssertEqual(try InventoryResolver().capacity(for: state), 200)
        XCTAssertThrowsError(try simulation.apply(.purchaseInventoryCapacity))
        XCTAssertEqual(simulation.state, original)
    }

    func testPurchasePricesRemainConfigurationDataAndOverflowChecked() throws {
        let configuration = InventoryConfiguration.standard
        XCTAssertEqual(try configuration.purchasePrice(after: 0), 500)
        XCTAssertEqual(try configuration.purchasePrice(after: 1), 1_000)
        XCTAssertEqual(try configuration.purchasePrice(after: 2), 2_000)
        XCTAssertThrowsError(try configuration.purchasePrice(after: 63))
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

    func testNonmatchingOverflowMoveAtFullCapacityRollsBack() throws {
        var state = GameState.newGame(balance: .standard)
        state.inventory = (1...40).map { item(id: UInt64($0), level: $0, quantity: 1) }
        state.overflowInventory = [item(id: 41, level: 99, quantity: 2)]
        state.lootSequence = 41
        let original = state
        var simulation = GameSimulation(state: state)

        XCTAssertThrowsError(try simulation.apply(.moveOverflow(
            itemID: ItemID(rawValue: 41),
            quantity: 1
        )))
        XCTAssertEqual(simulation.state, original)
    }

    func testStackQuantityOverflowRejectsInsertion() {
        var state = GameState.newGame(balance: .standard)
        state.inventory = [item(id: 1, level: 1, quantity: .max)]
        state.lootSequence = 1

        XCTAssertThrowsError(try InventoryResolver().insertDrop(
            item(id: 2, level: 1, quantity: 1),
            into: state
        )) { error in
            XCTAssertEqual(error as? SimulationError, .arithmeticOverflow)
        }
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

    func testFullInventoryEquipSucceedsWhenReplacedItemReturnsToStack() throws {
        var state = GameState.newGame(balance: .standard)
        let equipped = item(id: 1, level: 1, quantity: 1)
        let source = item(id: 2, level: 1, quantity: 2)
        state.inventory = [equipped, source] + (3...40).map {
            item(id: UInt64($0), level: $0, quantity: 1)
        }
        state.party.heroes[0].equipment.weaponID = equipped.id
        state.lootSequence = 40
        var simulation = GameSimulation(state: state)

        _ = try simulation.apply(.equip(source.id))

        XCTAssertEqual(simulation.state.inventory.count, 40)
        XCTAssertEqual(simulation.state.inventory.first(where: { $0.id == equipped.id })?.quantity, 2)
        XCTAssertEqual(simulation.state.party.heroes[0].equipment.weaponID, ItemID(rawValue: 41))
        XCTAssertNil(simulation.state.inventory.first(where: { $0.id == source.id }))
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
