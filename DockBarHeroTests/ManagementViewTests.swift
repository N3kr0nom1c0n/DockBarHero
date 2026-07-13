import XCTest
@testable import DockBarHero

final class ManagementViewTests: XCTestCase {
    func testLevelLabelsAreExplicit() {
        XCTAssertEqual(ManagementFormat.heroLevel(12), "Hero Lv. 12")
        XCTAssertEqual(ManagementFormat.enemyLevel(34), "Enemy Lv. 34")
        XCTAssertEqual(ManagementFormat.itemLevel(56), "Item Lv. 56")
    }

    func testCampaignIntentFactories() {
        XCTAssertEqual(ManagementIntent.selectLevel(24), .selectLevel(24))
        XCTAssertEqual(ManagementIntent.returnToFrontier, .returnToFrontier)
    }

    func testResetPhraseIsExact() {
        XCTAssertTrue(ManagementFormat.isNewGameConfirmationValid("GAME OVER MAN!"))
        XCTAssertFalse(ManagementFormat.isNewGameConfirmationValid("Game Over Man!"))
    }

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
        XCTAssertEqual(rows.map(\.creationSequence), [5, 4, 4])
    }

    func testInventoryRowsHonorAlternateTableSortOrder() {
        var state = GameSimulation().state
        state.inventory = [
            Item(id: ItemID(rawValue: 1), level: 3, slot: .weapon, primaryStat: 8, creationSequence: 1),
            Item(id: ItemID(rawValue: 2), level: 1, slot: .armor, primaryStat: 4, creationSequence: 2)
        ]
        let rows = InventoryRow.rows(for: state)

        let sorted = InventoryRow.sorted(
            rows,
            using: [KeyPathComparator(\InventoryRow.level, order: .forward)]
        )

        XCTAssertEqual(sorted.map(\.level), [1, 3])
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

    func testSelectedHeroCreatesHeroTargetedEquipIntent() {
        let itemID = ItemID(rawValue: 12)

        XCTAssertEqual(
            ManagementIntent.equip(heroSlot: 1, selection: itemID),
            .equipHero(slot: 1, itemID: itemID)
        )
        XCTAssertNil(ManagementIntent.equip(heroSlot: 1, selection: nil))
    }

    func testInventoryRowsIdentifyEquippedHero() {
        let weapon = Item(id: ItemID(rawValue: 10), level: 2, slot: .weapon, primaryStat: 8, creationSequence: 1)
        var state = GameState.newGame(classID: .tank, balance: .standard, progression: .standard)
        var second = GameState.newGame(classID: .dps, balance: .standard, progression: .standard).party.heroes[0]
        second.equipment.weaponID = weapon.id
        state.party = PartyState(heroes: [state.party.heroes[0], second], unlocks: .secondUnlocked)
        state.inventory = [weapon]

        let row = InventoryRow.rows(for: state)[0]

        XCTAssertEqual(row.equippedHeroSlot, 1)
        XCTAssertEqual(row.equippedLabel, "Hero 2 · DPS")
    }

    func testInventoryQueryFiltersRarityAndSortsByLevel() {
        var state = GameState.newGame(balance: .standard)
        state.inventory = [
            Item(id: ItemID(rawValue: 1), level: 4, slot: .weapon, primaryStat: 4, creationSequence: 1),
            Item(id: ItemID(rawValue: 2), level: 9, slot: .armor, primaryStat: 9, creationSequence: 2, rarity: .rare),
            Item(id: ItemID(rawValue: 3), level: 6, slot: .weapon, primaryStat: 6, creationSequence: 3, rarity: .rare),
        ]

        let rows = InventoryQuery(
            rarity: .rare,
            slot: nil,
            upgradeOnly: false,
            sort: .level
        ).apply(to: InventoryRow.rows(for: state))

        XCTAssertEqual(rows.map(\.id.rawValue), [2, 3])
    }

    func testInventoryQueryAcceptsMultipleRarities() {
        var state = GameState.newGame(balance: .standard)
        state.inventory = [
            Item(id: ItemID(rawValue: 1), level: 1, slot: .weapon, primaryStat: 1, creationSequence: 1),
            Item(id: ItemID(rawValue: 2), level: 2, slot: .weapon, primaryStat: 2, creationSequence: 2, rarity: .uncommon, affixes: [.init(id: .might, magnitude: 1)]),
            Item(id: ItemID(rawValue: 3), level: 3, slot: .weapon, primaryStat: 3, creationSequence: 3, rarity: .rare, affixes: [.init(id: .haste, magnitude: 1), .init(id: .might, magnitude: 1)]),
        ]

        let rows = InventoryQuery(
            rarities: [.common, .rare],
            slot: nil,
            upgradeOnly: false,
            sort: .newest
        ).apply(to: InventoryRow.rows(for: state))

        XCTAssertEqual(rows.map(\.id.rawValue), [3, 1])
    }

    func testInventoryRowsIncludeOverflowLocationAndStackQuantity() {
        var state = GameState.newGame(balance: .standard)
        state.overflowInventory = [
            Item(
                id: ItemID(rawValue: 7),
                level: 2,
                slot: .armor,
                primaryStat: 3,
                creationSequence: 7,
                quantity: 12
            ),
        ]

        let row = InventoryRow.rows(for: state).first { $0.id.rawValue == 7 }

        XCTAssertEqual(row?.location, .overflow)
        XCTAssertEqual(row?.quantity, 12)
    }

    func testInventoryQueryFiltersLockEquipmentAndLocation() {
        var state = GameState.newGame(balance: .standard)
        var equipped = Item(id: ItemID(rawValue: 1), level: 2, slot: .weapon, primaryStat: 2, creationSequence: 1)
        equipped.isLocked = true
        state.inventory = [equipped]
        state.party.heroes[0].equipment.weaponID = equipped.id
        state.overflowInventory = [
            Item(id: ItemID(rawValue: 2), level: 3, slot: .armor, primaryStat: 3, creationSequence: 2),
        ]

        let rows = InventoryQuery(
            rarity: nil,
            slot: nil,
            upgradeOnly: false,
            sort: .newest,
            locked: true,
            equipped: true,
            location: .inventory
        ).apply(to: InventoryRow.rows(for: state))

        XCTAssertEqual(rows.map(\.id), [equipped.id])
    }

    func testSalvagePreviewReportsExactUnitsStacksAndGold() throws {
        var state = GameState.newGame(balance: .standard)
        state.inventory = [
            Item(id: ItemID(rawValue: 1), level: 10, slot: .weapon, primaryStat: 2, creationSequence: 1, quantity: 3),
            Item(id: ItemID(rawValue: 2), level: 5, slot: .armor, primaryStat: 2, creationSequence: 2, rarity: .rare, affixes: [
                ItemAffix(id: .vitality, magnitude: 1),
                ItemAffix(id: .ward, magnitude: 1),
            ], quantity: 2),
        ]
        let rows = InventoryRow.rows(for: state)

        let preview = try SalvagePreview(
            selections: [
                SalvageSelection(location: .inventory, itemID: ItemID(rawValue: 1), quantity: 2),
                SalvageSelection(location: .inventory, itemID: ItemID(rawValue: 2), quantity: 1),
            ],
            rows: rows
        )

        XCTAssertEqual(preview.units, 3)
        XCTAssertEqual(preview.entries, 2)
        XCTAssertEqual(preview.gold, 40)
    }

    func testGamePresentationContainsEffectiveStatsForEveryHero() {
        var state = GameState.newGame(classID: .tank, balance: .standard, progression: .standard)
        let second = GameState.newGame(classID: .dps, balance: .standard, progression: .standard).party.heroes[0]
        state.party = PartyState(heroes: [state.party.heroes[0], second], unlocks: .secondUnlocked)

        let presentation = GameSimulation(state: state).presentation

        XCTAssertEqual(presentation.heroes.map(\.slot), [0, 1])
        XCTAssertEqual(presentation.heroes.map(\.attack), [8, 12])
        XCTAssertEqual(presentation.heroes.map(\.defense), [2, 0])
    }
}
