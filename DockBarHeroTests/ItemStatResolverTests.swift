import XCTest
@testable import DockBarHero

final class ItemStatResolverTests: XCTestCase {
    func testAffixesApplyAttackDefenseHealthAndHaste() throws {
        var state = GameState.newGame(classID: .tank, balance: .standard, progression: .standard)
        let weapon = item(
            id: 1,
            slot: .weapon,
            primary: 5,
            rarity: .rare,
            affixes: [.init(id: .haste, magnitude: 1_500), .init(id: .might, magnitude: 4)]
        )
        let armor = item(
            id: 2,
            slot: .armor,
            primary: 3,
            rarity: .rare,
            affixes: [.init(id: .vitality, magnitude: 20), .init(id: .ward, magnitude: 2)]
        )
        state.inventory = [weapon, armor]
        state.lootSequence = 2
        state.party.heroes[0].equipment = .init(weaponID: weapon.id, armorID: armor.id)

        let stats = try ItemStatResolver().stats(heroSlot: 0, in: state)

        XCTAssertEqual(stats.attack, 17)
        XCTAssertEqual(stats.defense, 7)
        XCTAssertEqual(stats.maximumHealth, 150)
        XCTAssertEqual(stats.hasteBasisPoints, 1_500)
        XCTAssertEqual(stats.attackInterval, try XCTUnwrap(.milliseconds(850)))
    }

    func testVitalityEquipPreservesMissingHealthAndClampsTimer() throws {
        var state = GameState.newGame(classID: .dps, balance: .standard, progression: .standard)
        state.party.heroes[0].combat.currentHealth = 70
        let armor = item(
            id: 1,
            slot: .armor,
            primary: 1,
            rarity: .rare,
            affixes: [.init(id: .haste, magnitude: 1_500), .init(id: .vitality, magnitude: 40)]
        )
        state.inventory = [armor]
        state.lootSequence = 1
        var simulation = GameSimulation(state: state)

        _ = try simulation.apply(.equip(armor.id))

        XCTAssertEqual(simulation.state.hero.maxHealth, 140)
        XCTAssertEqual(simulation.state.hero.currentHealth, 110)
        XCTAssertEqual(simulation.state.hero.timeUntilNextAttack, try XCTUnwrap(.milliseconds(850)))
    }

    private func item(
        id: UInt64,
        slot: EquipmentSlot,
        primary: Int,
        rarity: ItemRarity,
        affixes: [ItemAffix]
    ) -> Item {
        Item(
            id: ItemID(rawValue: id),
            level: 1,
            slot: slot,
            primaryStat: primary,
            creationSequence: id,
            rarity: rarity,
            affixes: affixes.sorted { $0.id < $1.id }
        )
    }
}
