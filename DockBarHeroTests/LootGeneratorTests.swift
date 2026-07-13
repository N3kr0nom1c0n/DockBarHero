import XCTest
@testable import DockBarHero

final class LootGeneratorTests: XCTestCase {
    func testIdenticalInputsProduceIdenticalCanonicalItem() throws {
        let generator = LootGenerator(configuration: .standard, balance: .standard)
        let a = try generator.generate(defeatedLevel: 25, tier: .boss, sequence: 41, slot: .weapon)
        let b = try generator.generate(defeatedLevel: 25, tier: .boss, sequence: 41, slot: .weapon)

        XCTAssertEqual(a, b)
        XCTAssertEqual(a.affixes, a.affixes.sorted { $0.id < $1.id })
        XCTAssertEqual(a.affixes.count, LootConfiguration.standard.affixCount(for: a.rarity))
        XCTAssertFalse(a.rarity == .common)
    }

    func testGeneratedAffixesAreUniqueLegalAndPositiveAcrossSequence() throws {
        let generator = LootGenerator(configuration: .standard, balance: .standard)
        for sequence in UInt64(0)..<200 {
            let slot: EquipmentSlot = sequence.isMultiple(of: 2) ? .weapon : .armor
            let item = try generator.generate(
                defeatedLevel: 30,
                tier: .elite,
                sequence: sequence,
                slot: slot
            )
            XCTAssertEqual(Set(item.affixes.map(\.id)).count, item.affixes.count)
            XCTAssertTrue(Set(item.affixes.map(\.id)).isSubset(of: Set(LootConfiguration.standard.affixPool(for: slot))))
            XCTAssertTrue(item.affixes.allSatisfy { $0.magnitude > 0 })
        }
    }
}
