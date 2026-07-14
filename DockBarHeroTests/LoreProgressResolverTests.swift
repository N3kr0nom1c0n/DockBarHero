import XCTest
@testable import DockBarHero

final class LoreProgressResolverTests: XCTestCase {
    func testFrontierUnlocksOnlyCompletedMilestones() throws {
        let catalog = try makeCatalog()
        let atLevelOne = LoreProgressResolver.resolve(
            catalog: catalog, highestUnlockedLevel: 1,
            languageMode: .unfiltered, illustrationMode: .safe
        )
        XCTAssertEqual(atLevelOne.map(\.id.rawValue), ["prologue.level-100000", "volume-1.level-1"])

        let afterLevelTen = LoreProgressResolver.resolve(
            catalog: catalog, highestUnlockedLevel: 11,
            languageMode: .clean, illustrationMode: .safe
        )
        XCTAssertEqual(afterLevelTen.map(\.id.rawValue), [
            "prologue.level-100000", "volume-1.level-1", "volume-1.level-5", "volume-1.level-10"
        ])
        XCTAssertTrue(afterLevelTen.allSatisfy { !$0.body.contains("fuck") })
    }

    func testLevelTwentyAdultModeUsesAlternateWhenPresent() throws {
        let pages = LoreProgressResolver.resolve(
            catalog: try makeCatalog(), highestUnlockedLevel: 21,
            languageMode: .unfiltered, illustrationMode: .adult
        )
        XCTAssertEqual(pages.last?.spriteSheetName, "volume1-level20-adult")
    }

    func testAdultModeFallsBackToSafeSheet() throws {
        let pages = LoreProgressResolver.resolve(
            catalog: try makeCatalog(), highestUnlockedLevel: 11,
            languageMode: .unfiltered, illustrationMode: .adult
        )
        XCTAssertEqual(pages[2].spriteSheetName, "volume-1.level-5-safe")
    }
}

private func makeCatalog() throws -> LoreCatalog {
    try LoreCatalog.validated(LoreCatalog(schemaVersion: 1, pages: [
        LoreFixtures.page("prologue.level-100000", index: 0, unlock: nil),
        LoreFixtures.page("volume-1.level-1", index: 1, unlock: nil),
        LoreFixtures.page("volume-1.level-5", index: 2, unlock: 5),
        LoreFixtures.page("volume-1.level-10", index: 3, unlock: 10),
        LoreFixtures.page("volume-1.level-20", index: 4, unlock: 20, adult: "volume1-level20-adult")
    ]))
}
