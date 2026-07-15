import XCTest
@testable import DockBarHero

final class EnemySpriteResolverTests: XCTestCase {
    func testNormalEncountersCycleThroughApprovedOrder() {
        let expected: [SpriteToken] = [
            .goblin, .skeleton, .bandit, .wolf, .orc, .bat, .slime,
            .harpy, .mimic, .ghost, .darkMage, .zombie,
            .elementalSlimeNormal, .plantMonster,
        ]

        XCTAssertEqual(
            (1...14).map { EnemySpriteResolver.token(level: $0, tier: .normal) },
            expected
        )
        XCTAssertEqual(EnemySpriteResolver.token(level: 15, tier: .normal), .goblin)
    }

    func testEliteEncountersCycleThroughApprovedOrder() {
        let expected: [SpriteToken] = [
            .eliteKnight, .dreadSkeleton, .infernalBrute, .frostWraith,
            .poisonNaga, .stormLich, .dragonWhelp, .ancientGolem,
        ]

        XCTAssertEqual(
            stride(from: 5, through: 40, by: 5).map {
                EnemySpriteResolver.token(level: $0, tier: .elite)
            },
            expected
        )
        XCTAssertEqual(EnemySpriteResolver.token(level: 45, tier: .elite), .eliteKnight)
    }

    func testBossSegmentsCycleThroughOriginalBosses() {
        XCTAssertEqual(EnemySpriteResolver.token(level: 25, tier: .boss), .ironrootWarchief)
        XCTAssertEqual(EnemySpriteResolver.token(level: 50, tier: .boss), .ossuarySovereign)
        XCTAssertEqual(EnemySpriteResolver.token(level: 75, tier: .boss), .embermawColossus)
        XCTAssertEqual(EnemySpriteResolver.token(level: 100, tier: .boss), .astralWyrm)
        XCTAssertEqual(EnemySpriteResolver.token(level: 125, tier: .boss), .ironrootWarchief)
    }

    func testInvalidLevelsUseGenericFallback() {
        for tier in EnemyTierID.allCases {
            XCTAssertEqual(EnemySpriteResolver.token(level: 0, tier: tier), .enemy)
            XCTAssertEqual(EnemySpriteResolver.token(level: -1, tier: tier), .enemy)
        }
    }
}
