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

    func testResolverUsesCleanOverlayAndSafeContextFallback() throws {
        let page = LoreFixtures.page("resolved", index: 0, unlock: nil, adult: "resolved-adult")
        let resolved = try XCTUnwrap(LoreProgressResolver.resolve(
            catalog: try LoreCatalog.validated(.init(schemaVersion: 2, pages: [page])),
            highestUnlockedLevel: 1, languageMode: .clean, illustrationMode: .adult
        ).first)
        XCTAssertEqual(resolved.spriteSheetName, "resolved-adult")
        XCTAssertEqual(resolved.composition.contextSheetName, "resolved-context-safe")
        XCTAssertEqual(resolved.composition.textOverlays.first?.text, "resolved clean narration")
    }

    func testResolverUsesAdultContextWhenAvailable() throws {
        let page = LoreFixtures.page(
            "adult-context", index: 0, unlock: nil, adult: "adult-context-motion-adult",
            adultContext: "adult-context-context-adult"
        )
        let resolved = try XCTUnwrap(LoreProgressResolver.resolve(
            catalog: try LoreCatalog.validated(.init(schemaVersion: 2, pages: [page])),
            highestUnlockedLevel: 1, languageMode: .unfiltered, illustrationMode: .adult
        ).first)
        XCTAssertEqual(resolved.spriteSheetName, "adult-context-motion-adult")
        XCTAssertEqual(resolved.composition.contextSheetName, "adult-context-context-adult")
        XCTAssertEqual(resolved.composition.textOverlays.first?.text, "adult-context narration")
    }

    func testBundledLevelTwentyAdultModeUsesAdultMotionAndSafeContext() throws {
        let page = try XCTUnwrap(LoreProgressResolver.resolve(
            catalog: try LoreCatalog.bundled(), highestUnlockedLevel: 21,
            languageMode: .unfiltered, illustrationMode: .adult
        ).last)

        XCTAssertEqual(page.id.rawValue, "volume-1.level-20")
        XCTAssertEqual(page.spriteSheetName, "volume1-level20-adult")
        XCTAssertEqual(page.composition.contextSheetName, "volume1-level20-context-safe")
    }

    func testBundledOverlayOrderIsStableWhenResolvingLanguageModes() throws {
        let catalog = try LoreCatalog.bundled()
        let unfiltered = LoreProgressResolver.resolve(
            catalog: catalog, highestUnlockedLevel: 21,
            languageMode: .unfiltered, illustrationMode: .safe
        )
        let clean = LoreProgressResolver.resolve(
            catalog: catalog, highestUnlockedLevel: 21,
            languageMode: .clean, illustrationMode: .safe
        )

        XCTAssertEqual(unfiltered.map { $0.composition.textOverlays.map(\.id) },
                       catalog.pages.map { $0.composition.textOverlays.map(\.id) })
        XCTAssertEqual(clean.map { $0.composition.textOverlays.map(\.id) },
                       unfiltered.map { $0.composition.textOverlays.map(\.id) })
    }
}

private func makeCatalog() throws -> LoreCatalog {
    try LoreCatalog.validated(LoreCatalog(schemaVersion: 2, pages: [
        LoreFixtures.page("prologue.level-100000", index: 0, unlock: nil),
        LoreFixtures.page("volume-1.level-1", index: 1, unlock: nil),
        LoreFixtures.page("volume-1.level-5", index: 2, unlock: 5),
        LoreFixtures.page("volume-1.level-10", index: 3, unlock: 10),
        LoreFixtures.page("volume-1.level-20", index: 4, unlock: 20, adult: "volume1-level20-adult")
    ]))
}
