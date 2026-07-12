import XCTest
@testable import DockBarHero

final class CombatResolverTests: XCTestCase {
    func testDPSLevelGrowthScalesEquippedAttack() throws {
        var state = try GameState.newGame(
            classID: .dps,
            balance: .standard,
            progression: .standard
        )
        state.party.heroes[0].level = 10
        let weapon = Item(
            id: ItemID(rawValue: 1),
            level: 1,
            slot: .weapon,
            primaryStat: 88,
            creationSequence: 1
        )
        state.inventory = [weapon]
        state.party.heroes[0].equipment.weaponID = weapon.id

        XCTAssertEqual(
            try CombatResolver().effectiveAttack(forHeroAt: 0, in: state),
            111
        )
    }

    func testDamageUsesBaseStatsAndMinimumOne() throws {
        let state = GameState.newGame(balance: .standard)
        let resolver = CombatResolver()

        XCTAssertEqual(try resolver.effectiveAttack(for: .hero, in: state), 10)
        XCTAssertEqual(try resolver.effectiveDefense(for: .hero, in: state), 0)
        XCTAssertEqual(try resolver.damage(attacker: .hero, defender: .enemy, in: state), 10)
        XCTAssertEqual(try resolver.damage(attacker: .enemy, defender: .hero, in: state), 3)
    }

    func testDamageUsesOwnedEquipmentAndMinimumOne() throws {
        var state = GameState.newGame(balance: .standard)
        let weapon = Item(id: ItemID(rawValue: 1), level: 1, slot: .weapon, primaryStat: 5, creationSequence: 1)
        let armor = Item(id: ItemID(rawValue: 2), level: 1, slot: .armor, primaryStat: 20, creationSequence: 2)
        state.inventory = [weapon, armor]
        state.equipment = EquipmentState(weaponID: weapon.id, armorID: armor.id)
        let resolver = CombatResolver()

        XCTAssertEqual(try resolver.damage(attacker: .hero, defender: .enemy, in: state), 15)
        XCTAssertEqual(try resolver.damage(attacker: .enemy, defender: .hero, in: state), 1)
    }

    func testMissingOrWrongSlotEquipmentIsIgnoredOrRejected() throws {
        var state = GameState.newGame(balance: .standard)
        let armor = Item(id: ItemID(rawValue: 1), level: 1, slot: .armor, primaryStat: 2, creationSequence: 1)
        state.inventory = [armor]
        let resolver = CombatResolver()
        XCTAssertEqual(try resolver.effectiveAttack(for: .hero, in: state), 10)

        state.equipment.weaponID = armor.id
        XCTAssertThrowsError(try resolver.effectiveAttack(for: .hero, in: state)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidState)
        }
    }

    func testMissingEquippedItemIsRejected() {
        var state = GameState.newGame(balance: .standard)
        state.equipment.weaponID = ItemID(rawValue: 99)

        XCTAssertThrowsError(try CombatResolver().effectiveAttack(for: .hero, in: state)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidState)
        }
    }

    func testDuplicateEquipmentIDsAreRejected() throws {
        var state = GameState.newGame(balance: .standard)
        let first = Item(id: ItemID(rawValue: 1), level: 1, slot: .weapon, primaryStat: 5, creationSequence: 1)
        let duplicate = Item(id: first.id, level: 1, slot: .weapon, primaryStat: 6, creationSequence: 2)
        state.inventory = [first, duplicate]
        state.equipment.weaponID = first.id

        XCTAssertThrowsError(try CombatResolver().effectiveAttack(for: .hero, in: state)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidState)
        }
    }

    func testInvalidEquipmentValuesAreRejected() throws {
        var state = GameState.newGame(balance: .standard)
        let invalid = Item(id: ItemID(rawValue: 1), level: 0, slot: .weapon, primaryStat: 5, creationSequence: 1)
        state.inventory = [invalid]
        state.equipment.weaponID = invalid.id

        XCTAssertThrowsError(try CombatResolver().effectiveAttack(for: .hero, in: state)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidState)
        }
    }

    func testStatOverflowIsReported() throws {
        var state = GameState.newGame(balance: .standard)
        let weapon = Item(id: ItemID(rawValue: 1), level: 1, slot: .weapon, primaryStat: 1, creationSequence: 1)
        state.hero = CombatantState(id: .hero, currentHealth: 100, maxHealth: 100, baseAttack: .max, baseDefense: 0,
                                    attackInterval: .nanoseconds(1_000_000_000), timeUntilNextAttack: .nanoseconds(1_000_000_000))
        state.inventory = [weapon]
        state.equipment.weaponID = weapon.id

        XCTAssertThrowsError(try CombatResolver().effectiveAttack(for: .hero, in: state)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidState)
        }
    }

    func testHealthClampsAtZero() throws {
        XCTAssertEqual(try CombatResolver().health(afterTaking: 40, from: 30), 0)
        XCTAssertEqual(try CombatResolver().health(afterTaking: 10, from: 30), 20)
    }
}
