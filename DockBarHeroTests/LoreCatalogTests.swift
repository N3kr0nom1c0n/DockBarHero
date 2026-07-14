import XCTest
@testable import DockBarHero

final class LoreCatalogTests: XCTestCase {
    func testValidCatalogIsSortedAndAccepted() throws {
        let catalog = try LoreCatalog.validated(LoreFixtures.catalog())
        XCTAssertEqual(catalog.pages.map(\.sortIndex), [0, 1])
    }

    func testRejectsDuplicatePageIDs() {
        let page = LoreFixtures.page("duplicate", index: 0, unlock: nil)
        XCTAssertThrowsError(try LoreCatalog.validated(.init(schemaVersion: 1, pages: [page, page])))
    }

    func testRejectsNonascendingSortIndices() {
        let pages = [
            LoreFixtures.page("second", index: 1, unlock: nil),
            LoreFixtures.page("first", index: 0, unlock: nil)
        ]
        XCTAssertThrowsError(try LoreCatalog.validated(.init(schemaVersion: 1, pages: pages)))
    }

    func testRejectsMissingRequiredCopyAndArt() {
        let invalid = LorePageDefinition(
            id: .init(rawValue: "empty"), sortIndex: 0,
            title: .init(unfiltered: "", clean: ""),
            body: .init(unfiltered: "", clean: ""), unlockAfterVictoryLevel: nil,
            art: .init(safeSpriteSheet: "", adultSpriteSheet: nil, accessibilitySafe: "", accessibilityAdult: nil),
            dialogueCueIDs: [], frameCount: 4, frameDurationMilliseconds: 600
        )
        XCTAssertThrowsError(try LoreCatalog.validated(.init(schemaVersion: 1, pages: [invalid])))
    }

    func testRejectsInvalidUnlockOrFrameDescriptor() {
        XCTAssertThrowsError(try LoreCatalog.validated(.init(schemaVersion: 1, pages: [LoreFixtures.page("bad-unlock", index: 0, unlock: 0)])))
        var badFrames = LoreFixtures.page("bad-frames", index: 0, unlock: nil)
        badFrames = LorePageDefinition(
            id: badFrames.id, sortIndex: badFrames.sortIndex, title: badFrames.title, body: badFrames.body,
            unlockAfterVictoryLevel: nil, art: badFrames.art, dialogueCueIDs: [], frameCount: 5,
            frameDurationMilliseconds: 600
        )
        XCTAssertThrowsError(try LoreCatalog.validated(.init(schemaVersion: 1, pages: [badFrames])))
    }

    func testBundledCatalogContainsTheApprovedSixPages() throws {
        let catalog = try LoreCatalog.bundled()
        XCTAssertEqual(catalog.pages.map(\.id.rawValue), [
            "prologue.level-100000", "volume-1.level-1", "volume-1.level-5",
            "volume-1.level-10", "volume-1.level-15", "volume-1.level-20"
        ])
    }
}

enum LoreFixtures {
    static func page(_ id: String, index: Int, unlock: Int?, adult: String? = nil) -> LorePageDefinition {
        LorePageDefinition(
            id: LorePageID(rawValue: id), sortIndex: index,
            title: LoreTextVariants(unfiltered: id, clean: id),
            body: LoreTextVariants(unfiltered: id, clean: id), unlockAfterVictoryLevel: unlock,
            art: LoreArtVariants(
                safeSpriteSheet: "\(id)-safe", adultSpriteSheet: adult,
                accessibilitySafe: id, accessibilityAdult: adult == nil ? nil : id
            ),
            dialogueCueIDs: [], frameCount: 4, frameDurationMilliseconds: 600
        )
    }

    static func catalog() -> LoreCatalog {
        LoreCatalog(schemaVersion: 1, pages: [
            page("prologue.level-100000", index: 0, unlock: nil),
            page("volume-1.level-1", index: 1, unlock: nil)
        ])
    }
}
