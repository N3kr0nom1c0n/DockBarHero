import XCTest
@testable import DockBarHero

final class ManagementViewTests: XCTestCase {
    func testInventoryRowsAreNewestFirstWithIDTieBreak() {
        let items = [
            Item(id: ItemID(rawValue: 2), level: 3, slot: .armor, primaryStat: 7, creationSequence: 4),
            Item(id: ItemID(rawValue: 1), level: 2, slot: .weapon, primaryStat: 5, creationSequence: 4),
            Item(id: ItemID(rawValue: 3), level: 1, slot: .weapon, primaryStat: 3, creationSequence: 5)
        ]
        var state = GameSimulation().state
        state.inventory = items

        let rows = InventoryRow.rows(for: state)

        XCTAssertEqual(rows.map(\.id.rawValue), [3, 2, 1])
    }

    func testInventoryRowsDeriveEquippedStateByID() {
        let weapon = Item(id: ItemID(rawValue: 10), level: 2, slot: .weapon, primaryStat: 8, creationSequence: 1)
        let armor = Item(id: ItemID(rawValue: 11), level: 2, slot: .armor, primaryStat: 6, creationSequence: 2)
        var state = GameSimulation().state
        state.inventory = [weapon, armor]
        state.equipment = EquipmentState(weaponID: weapon.id, armorID: nil)

        let rows = InventoryRow.rows(for: state)

        XCTAssertTrue(rows.first(where: { $0.id == weapon.id })?.isEquipped == true)
        XCTAssertFalse(rows.first(where: { $0.id == armor.id })?.isEquipped == true)
    }

    func testDPSUsesOneDecimalPlace() {
        XCTAssertEqual(ManagementFormat.dps(12.34), "12.3")
    }

    func testSaveStatusLabelsIncludeUnsupportedVersion() {
        XCTAssertEqual(ManagementFormat.saveStatus(.notLoaded), "Loading")
        XCTAssertEqual(ManagementFormat.saveStatus(.saving), "Saving")
        XCTAssertEqual(ManagementFormat.saveStatus(.saved(Date(timeIntervalSince1970: 0))), "Saved")
        XCTAssertEqual(ManagementFormat.saveStatus(.recovered), "Recovered from backup")
        XCTAssertEqual(ManagementFormat.saveStatus(.unsupportedVersion(7)), "Unsupported save version: 7")
        XCTAssertEqual(ManagementFormat.saveStatus(.failed("disk full")), "Save error: disk full")
    }

    func testAutoEquipBindingCreatesSetAutoEquipIntent() {
        XCTAssertEqual(ManagementIntent.autoEquip(false), .setAutoEquip(false))
    }

    func testSelectedItemCreatesManualEquipIntent() {
        let itemID = ItemID(rawValue: 12)

        XCTAssertEqual(ManagementIntent.equip(itemID), .equip(itemID))
        XCTAssertNil(ManagementIntent.equip(nil))
    }
}
