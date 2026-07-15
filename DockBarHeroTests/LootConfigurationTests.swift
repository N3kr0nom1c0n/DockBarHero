import XCTest
@testable import DockBarHero

final class LootConfigurationTests: XCTestCase {
    func testRarityOrderAndAffixCountsAreStable() {
        XCTAssertEqual(ItemRarity.allCases, [.common, .uncommon, .rare, .epic, .unique])
        XCTAssertEqual(LootConfiguration.standard.affixCount(for: .common), 0)
        XCTAssertEqual(LootConfiguration.standard.affixCount(for: .uncommon), 1)
        XCTAssertEqual(LootConfiguration.standard.affixCount(for: .rare), 2)
        XCTAssertEqual(LootConfiguration.standard.affixCount(for: .epic), 3)
    }

    func testRarityTablesSumToTenThousandAndBossesExcludeCommon() {
        for tier in EnemyTierID.allCases {
            XCTAssertEqual(
                LootConfiguration.standard.rarityTable(for: tier).reduce(0) { $0 + $1.weight },
                10_000
            )
        }
        XCTAssertEqual(
            LootConfiguration.standard.rarityTable(for: .boss).first(where: { $0.rarity == .common })?.weight,
            0
        )
    }

    func testSlotAffixPoolsMatchApprovedRules() {
        XCTAssertEqual(LootConfiguration.standard.affixPool(for: .weapon), [.haste, .might, .vitality])
        XCTAssertEqual(LootConfiguration.standard.affixPool(for: .armor), [.haste, .vitality, .ward])
    }
}
