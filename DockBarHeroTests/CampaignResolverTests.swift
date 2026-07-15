import XCTest
@testable import DockBarHero

final class CampaignResolverTests: XCTestCase {
    func testResolverUsesAuthoredContentThenProceduralFallback() throws {
        let resolver = CampaignResolver()
        let one = try resolver.resolve(level: 1)
        XCTAssertEqual(one.area?.id, .forgottenShallowDepths)
        XCTAssertEqual(one.enemy?.id, .slime)
        XCTAssertEqual(one.tier, .normal)

        let twentySix = try resolver.resolve(level: 26)
        XCTAssertNil(twentySix.area)
        XCTAssertNil(twentySix.enemy)
        XCTAssertEqual(twentySix.tier, .normal)
        XCTAssertEqual(try resolver.resolve(level: 50).tier, .boss)
        XCTAssertEqual(try resolver.resolve(level: 100).tier, .boss)
        XCTAssertEqual(try resolver.resolve(level: 192).tier, .normal)
    }

    func testResolverUsesAuthoredEliteAndBossDefinitions() throws {
        let resolver = CampaignResolver()

        XCTAssertEqual(try resolver.resolve(level: 5).enemy?.id, .knight)
        XCTAssertEqual(try resolver.resolve(level: 10).enemy?.id, .frostWraith)
        XCTAssertEqual(try resolver.resolve(level: 15).enemy?.id, .poisonNagaQueen)
        XCTAssertEqual(try resolver.resolve(level: 20).enemy?.id, .ancientGolem)
        XCTAssertEqual(try resolver.resolve(level: 25).enemy?.id, .unknownGuardian)
        XCTAssertEqual(try resolver.resolve(level: 5).tier, .elite)
        XCTAssertEqual(try resolver.resolve(level: 25).tier, .boss)
    }

    func testResolverRejectsNonpositiveLevels() {
        for level in [0, -1] {
            XCTAssertThrowsError(try CampaignResolver().resolve(level: level)) { error in
                XCTAssertEqual(error as? CampaignCatalogError, .invalidLevel(level))
            }
        }
    }
}
