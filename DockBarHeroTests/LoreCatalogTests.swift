import XCTest
@testable import DockBarHero

final class LoreCatalogTests: XCTestCase {
    func testValidCatalogIsSortedAndAccepted() throws {
        let catalog = try LoreCatalog.validated(LoreFixtures.catalog())
        XCTAssertEqual(catalog.pages.map(\.sortIndex), [0, 1])
    }

    func testRejectsDuplicatePageIDs() {
        let page = LoreFixtures.page("duplicate", index: 0, unlock: nil)
        XCTAssertThrowsError(try LoreCatalog.validated(.init(schemaVersion: 2, pages: [page, page])))
    }

    func testRejectsNonascendingSortIndices() {
        let pages = [
            LoreFixtures.page("second", index: 1, unlock: nil),
            LoreFixtures.page("first", index: 0, unlock: nil)
        ]
        XCTAssertThrowsError(try LoreCatalog.validated(.init(schemaVersion: 2, pages: pages)))
    }

    func testRejectsMissingRequiredCopyAndArt() {
        let invalid = LorePageDefinition(
            id: .init(rawValue: "empty"), sortIndex: 0,
            title: .init(unfiltered: "", clean: ""),
            body: .init(unfiltered: "", clean: ""), unlockAfterVictoryLevel: nil,
            art: .init(safeSpriteSheet: "", adultSpriteSheet: nil, accessibilitySafe: "", accessibilityAdult: nil),
            composition: LoreFixtures.composition("empty"),
            dialogueCueIDs: [], frameCount: 4, frameDurationMilliseconds: 600
        )
        XCTAssertThrowsError(try LoreCatalog.validated(.init(schemaVersion: 2, pages: [invalid])))
    }

    func testRejectsInvalidUnlockOrFrameDescriptor() {
        XCTAssertThrowsError(try LoreCatalog.validated(.init(schemaVersion: 2, pages: [LoreFixtures.page("bad-unlock", index: 0, unlock: 0)])))
        var badFrames = LoreFixtures.page("bad-frames", index: 0, unlock: nil)
        badFrames = LorePageDefinition(
            id: badFrames.id, sortIndex: badFrames.sortIndex, title: badFrames.title, body: badFrames.body,
            unlockAfterVictoryLevel: nil, art: badFrames.art, composition: badFrames.composition,
            dialogueCueIDs: [], frameCount: 5,
            frameDurationMilliseconds: 600
        )
        XCTAssertThrowsError(try LoreCatalog.validated(.init(schemaVersion: 2, pages: [badFrames])))
    }

    func testBundledCatalogContainsTheApprovedSixPages() throws {
        let catalog = try LoreCatalog.bundled()
        XCTAssertEqual(catalog.schemaVersion, 2)
        XCTAssertEqual(catalog.pages.map(\.id.rawValue), [
            "prologue.level-100000", "volume-1.level-1", "volume-1.level-5",
            "volume-1.level-10", "volume-1.level-15", "volume-1.level-20"
        ])
        let prologue = try XCTUnwrap(catalog.pages.first)
        XCTAssertTrue(prologue.body.unfiltered.contains("American jackass"))
        XCTAssertTrue(prologue.body.unfiltered.contains("arrow"))
        XCTAssertFalse(prologue.body.clean.lowercased().contains("fuck"))
    }

    func testBundledRequiredCopyIsNonemptyAndCleanOverlaysContainNoProfanity() throws {
        let catalog = try LoreCatalog.bundled()

        for page in catalog.pages {
            let requiredPageCopy = [
                page.title.unfiltered, page.title.clean,
                page.body.unfiltered, page.body.clean,
                page.art.accessibilitySafe
            ]
            XCTAssertTrue(requiredPageCopy.allSatisfy { !$0.trimmedForLoreTest.isEmpty }, page.id.rawValue)

            for overlay in page.composition.textOverlays {
                XCTAssertFalse(overlay.copy.unfiltered.trimmedForLoreTest.isEmpty, overlay.id)
                XCTAssertFalse(overlay.copy.clean.trimmedForLoreTest.isEmpty, overlay.id)
                XCTAssertFalse(overlay.copy.clean.lowercased().contains("fuck"), overlay.id)
            }
        }
    }

    func testBundledOverlaysFollowPanelReadingOrder() throws {
        for page in try LoreCatalog.bundled().pages {
            let panelOrder = Dictionary(uniqueKeysWithValues:
                page.composition.panels.map { ($0.id, $0.readingOrder) }
            )
            let overlayPanelOrders = try page.composition.textOverlays.map { overlay in
                try XCTUnwrap(panelOrder[overlay.panelID], overlay.panelID)
            }
            XCTAssertEqual(overlayPanelOrders, overlayPanelOrders.sorted(), page.id.rawValue)
        }
    }

    func testAcceptsEachSupportedLayoutWithItsExpectedPanelCount() throws {
        let expected: [(LoreMangaLayoutID, Int)] = [
            (.cascadeFive, 5),
            (.brokenSix, 6),
            (.staggeredSix, 6),
            (.shatteredSeven, 7)
        ]
        for (layoutID, count) in expected {
            var page = LoreFixtures.page("count-\(count)", index: 0, unlock: nil)
            let panels = (0..<count).map { index in
                LorePanelDefinition(
                    id: "p\(index + 1)", slotID: "slot\(index + 1)",
                    role: index == 1 ? .motion : .still,
                    sourceCell: index == 1 ? nil : min(index, 5),
                    readingOrder: index, focalPoint: .init(x: 0.5, y: 0.5)
                )
            }
            page = page.replacingComposition(
                LoreCompositionDefinition(
                    layoutID: layoutID,
                    safeContextSheet: page.composition.safeContextSheet,
                    adultContextSheet: page.composition.adultContextSheet,
                    panels: panels,
                    textOverlays: page.composition.textOverlays
                )
            )
            XCTAssertNoThrow(try LoreCatalog.validated(.init(schemaVersion: 2, pages: [page])))
        }
    }

    func testRejectsCompositionWithUnknownTemplateSlot() {
        let page = LoreFixtures.page("bad-slot", index: 0, unlock: nil)
        var panels = page.composition.panels
        let replaced = panels[4]
        panels[4] = LorePanelDefinition(
            id: replaced.id,
            slotID: "slot99",
            role: replaced.role,
            sourceCell: replaced.sourceCell,
            readingOrder: replaced.readingOrder,
            focalPoint: replaced.focalPoint
        )
        let invalid = page.replacingComposition(page.composition.replacingPanels(panels))

        XCTAssertThrowsError(try LoreCatalog.validated(.init(schemaVersion: 2, pages: [invalid]))) {
            XCTAssertEqual($0 as? LoreCatalogError, .invalidComposition("bad-slot"))
        }
    }

    func testRejectsCompositionOutsideFiveToSevenPanels() {
        for count in [4, 8] {
            var page = LoreFixtures.page("bad-count-\(count)", index: 0, unlock: nil)
            let panels = (0..<count).map { index in
                LorePanelDefinition(
                    id: "p\(index + 1)", slotID: "slot\(index + 1)",
                    role: index == 1 ? .motion : .still,
                    sourceCell: index == 1 ? nil : min(index, 5),
                    readingOrder: index, focalPoint: .init(x: 0.5, y: 0.5)
                )
            }
            page = page.replacingComposition(page.composition.replacingPanels(panels))
            XCTAssertThrowsError(try LoreCatalog.validated(.init(schemaVersion: 2, pages: [page]))) {
                XCTAssertEqual($0 as? LoreCatalogError, .invalidComposition("bad-count-\(count)"))
            }
        }
    }

    func testRejectsCompositionWithoutExactlyOneMotionPanel() {
        var page = LoreFixtures.page("bad-motion", index: 0, unlock: nil)
        page = page.replacingComposition(
            page.composition.replacingPanels(page.composition.panels.map {
                .init(
                    id: $0.id, slotID: $0.slotID, role: .still,
                    sourceCell: 0, readingOrder: $0.readingOrder,
                    focalPoint: $0.focalPoint
                )
            })
        )
        XCTAssertThrowsError(try LoreCatalog.validated(.init(schemaVersion: 2, pages: [page]))) {
            XCTAssertEqual($0 as? LoreCatalogError, .invalidComposition("bad-motion"))
        }
    }

    func testRejectsDuplicatePanelIDsSlotIDsAndReadingOrders() {
        let page = LoreFixtures.page("duplicates", index: 0, unlock: nil)
        let panels = page.composition.panels

        for duplicate in [
            LorePanelDefinition(
                id: panels[0].id, slotID: panels[1].slotID, role: panels[1].role,
                sourceCell: panels[1].sourceCell, readingOrder: panels[1].readingOrder,
                focalPoint: panels[1].focalPoint
            ),
            LorePanelDefinition(
                id: panels[1].id, slotID: panels[0].slotID, role: panels[1].role,
                sourceCell: panels[1].sourceCell, readingOrder: panels[1].readingOrder,
                focalPoint: panels[1].focalPoint
            ),
            LorePanelDefinition(
                id: panels[1].id, slotID: panels[1].slotID, role: panels[1].role,
                sourceCell: panels[1].sourceCell, readingOrder: panels[0].readingOrder,
                focalPoint: panels[1].focalPoint
            )
        ] {
            var invalidPanels = panels
            invalidPanels[1] = duplicate
            let invalid = page.replacingComposition(page.composition.replacingPanels(invalidPanels))
            XCTAssertThrowsError(try LoreCatalog.validated(.init(schemaVersion: 2, pages: [invalid]))) {
                XCTAssertEqual($0 as? LoreCatalogError, .invalidComposition("duplicates"))
            }
        }
    }

    func testRejectsDuplicateOverlayIDsAndOverlaysAttachedToMissingPanels() {
        let page = LoreFixtures.page("bad-overlays", index: 0, unlock: nil)
        let overlay = page.composition.textOverlays[0]
        let duplicate = LoreTextOverlayDefinition(
            id: overlay.id, panelID: "p2", style: .speech, placement: .center,
            speakerID: nil, dialogueCueID: nil,
            copy: .init(unfiltered: "duplicate", clean: "duplicate")
        )
        let duplicated = page.replacingComposition(
            page.composition.replacingTextOverlays([overlay, duplicate])
        )
        XCTAssertThrowsError(try LoreCatalog.validated(.init(schemaVersion: 2, pages: [duplicated]))) {
            XCTAssertEqual($0 as? LoreCatalogError, .invalidComposition("bad-overlays"))
        }

        let missingPanel = LoreTextOverlayDefinition(
            id: overlay.id, panelID: "missing", style: overlay.style,
            placement: overlay.placement, speakerID: overlay.speakerID,
            dialogueCueID: overlay.dialogueCueID, copy: overlay.copy
        )
        let unattached = page.replacingComposition(
            page.composition.replacingTextOverlays([missingPanel])
        )
        XCTAssertThrowsError(try LoreCatalog.validated(.init(schemaVersion: 2, pages: [unattached]))) {
            XCTAssertEqual($0 as? LoreCatalogError, .invalidComposition("bad-overlays"))
        }
    }

    func testRejectsInvalidStillSourceMotionSourceAndFocalPoint() {
        let page = LoreFixtures.page("bad-panel", index: 0, unlock: nil)
        let panels = page.composition.panels
        let invalidPanels = [
            LorePanelDefinition(
                id: panels[0].id, slotID: panels[0].slotID, role: .still,
                sourceCell: 6, readingOrder: panels[0].readingOrder, focalPoint: panels[0].focalPoint
            ),
            LorePanelDefinition(
                id: panels[1].id, slotID: panels[1].slotID, role: .motion,
                sourceCell: 0, readingOrder: panels[1].readingOrder, focalPoint: panels[1].focalPoint
            ),
            LorePanelDefinition(
                id: panels[0].id, slotID: panels[0].slotID, role: .still,
                sourceCell: 0, readingOrder: panels[0].readingOrder,
                focalPoint: .init(x: 1.1, y: 0.5)
            )
        ]

        for replacement in invalidPanels {
            var mutated = panels
            let index = replacement.role == .motion ? 1 : 0
            mutated[index] = replacement
            let invalid = page.replacingComposition(page.composition.replacingPanels(mutated))
            XCTAssertThrowsError(try LoreCatalog.validated(.init(schemaVersion: 2, pages: [invalid]))) {
                XCTAssertEqual($0 as? LoreCatalogError, .invalidComposition("bad-panel"))
            }
        }
    }

    func testAllowsGagWithMissingOrInvalidOptionalSource() throws {
        let page = LoreFixtures.page("optional-gag", index: 0, unlock: nil)
        for sourceCell in [nil, -1, 6] as [Int?] {
            var panels = page.composition.panels
            panels[4] = LorePanelDefinition(
                id: panels[4].id, slotID: panels[4].slotID, role: .gag,
                sourceCell: sourceCell, readingOrder: panels[4].readingOrder,
                focalPoint: panels[4].focalPoint
            )
            let candidate = page.replacingComposition(page.composition.replacingPanels(panels))
            XCTAssertNoThrow(try LoreCatalog.validated(.init(schemaVersion: 2, pages: [candidate])))
        }
    }

    func testRejectsEmptyContextArtNames() {
        let page = LoreFixtures.page("bad-context", index: 0, unlock: nil)
        for composition in [
            LoreCompositionDefinition(
                layoutID: page.composition.layoutID, safeContextSheet: "  ", adultContextSheet: nil,
                panels: page.composition.panels, textOverlays: page.composition.textOverlays
            ),
            LoreCompositionDefinition(
                layoutID: page.composition.layoutID,
                safeContextSheet: page.composition.safeContextSheet, adultContextSheet: "\n",
                panels: page.composition.panels, textOverlays: page.composition.textOverlays
            )
        ] {
            let invalid = page.replacingComposition(composition)
            XCTAssertThrowsError(try LoreCatalog.validated(.init(schemaVersion: 2, pages: [invalid]))) {
                XCTAssertEqual($0 as? LoreCatalogError, .invalidComposition("bad-context"))
            }
        }
    }

    func testRejectsEmptyOverlayVariantsAndMismatchedDialogueCues() {
        let page = LoreFixtures.page("bad-copy", index: 0, unlock: nil)
        let overlay = page.composition.textOverlays[0]
        for copy in [
            LoreTextVariants(unfiltered: "", clean: "clean"),
            LoreTextVariants(unfiltered: "uncensored", clean: " ")
        ] {
            let invalidOverlay = LoreTextOverlayDefinition(
                id: overlay.id, panelID: overlay.panelID, style: overlay.style,
                placement: overlay.placement, speakerID: overlay.speakerID,
                dialogueCueID: overlay.dialogueCueID, copy: copy
            )
            let invalid = page.replacingComposition(
                page.composition.replacingTextOverlays([invalidOverlay])
            )
            XCTAssertThrowsError(try LoreCatalog.validated(.init(schemaVersion: 2, pages: [invalid]))) {
                XCTAssertEqual($0 as? LoreCatalogError, .invalidComposition("bad-copy"))
            }
        }

        let cuePage = LorePageDefinition(
            id: page.id, sortIndex: page.sortIndex, title: page.title, body: page.body,
            unlockAfterVictoryLevel: page.unlockAfterVictoryLevel, art: page.art,
            composition: page.composition, dialogueCueIDs: ["missing"],
            frameCount: page.frameCount, frameDurationMilliseconds: page.frameDurationMilliseconds
        )
        XCTAssertThrowsError(try LoreCatalog.validated(.init(schemaVersion: 2, pages: [cuePage]))) {
            XCTAssertEqual($0 as? LoreCatalogError, .invalidComposition("bad-copy"))
        }
    }
}

private extension String {
    var trimmedForLoreTest: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum LoreFixtures {
    static func page(
        _ id: String,
        index: Int,
        unlock: Int?,
        adult: String? = nil,
        adultContext: String? = nil
    ) -> LorePageDefinition {
        LorePageDefinition(
            id: LorePageID(rawValue: id), sortIndex: index,
            title: LoreTextVariants(unfiltered: id, clean: id),
            body: LoreTextVariants(unfiltered: id, clean: id), unlockAfterVictoryLevel: unlock,
            art: LoreArtVariants(
                safeSpriteSheet: "\(id)-safe", adultSpriteSheet: adult,
                accessibilitySafe: id, accessibilityAdult: adult == nil ? nil : id
            ),
            composition: composition(id, adultContext: adultContext),
            dialogueCueIDs: [], frameCount: 4, frameDurationMilliseconds: 600
        )
    }

    static func composition(_ id: String, adultContext: String? = nil) -> LoreCompositionDefinition {
        LoreCompositionDefinition(
            layoutID: .cascadeFive,
            safeContextSheet: "\(id)-context-safe",
            adultContextSheet: adultContext,
            panels: [
                .init(id: "p1", slotID: "slot1", role: .still, sourceCell: 0, readingOrder: 0, focalPoint: .init(x: 0.5, y: 0.5)),
                .init(id: "p2", slotID: "slot2", role: .motion, sourceCell: nil, readingOrder: 1, focalPoint: .init(x: 0.5, y: 0.5)),
                .init(id: "p3", slotID: "slot3", role: .still, sourceCell: 1, readingOrder: 2, focalPoint: .init(x: 0.5, y: 0.5)),
                .init(id: "p4", slotID: "slot4", role: .still, sourceCell: 2, readingOrder: 3, focalPoint: .init(x: 0.5, y: 0.5)),
                .init(id: "p5", slotID: "slot5", role: .gag, sourceCell: 3, readingOrder: 4, focalPoint: .init(x: 0.5, y: 0.5))
            ],
            textOverlays: [
                .init(
                    id: "o1", panelID: "p1", style: .narration,
                    placement: .topTrailing, speakerID: nil, dialogueCueID: nil,
                    copy: .init(unfiltered: "\(id) narration", clean: "\(id) clean narration")
                )
            ]
        )
    }

    static func catalog() -> LoreCatalog {
        LoreCatalog(schemaVersion: 2, pages: [
            page("prologue.level-100000", index: 0, unlock: nil),
            page("volume-1.level-1", index: 1, unlock: nil)
        ])
    }
}

private extension LorePageDefinition {
    func replacingComposition(_ replacement: LoreCompositionDefinition) -> Self {
        .init(
            id: id, sortIndex: sortIndex, title: title, body: body,
            unlockAfterVictoryLevel: unlockAfterVictoryLevel, art: art,
            composition: replacement, dialogueCueIDs: dialogueCueIDs,
            frameCount: frameCount, frameDurationMilliseconds: frameDurationMilliseconds
        )
    }
}

private extension LoreCompositionDefinition {
    func replacingPanels(_ replacement: [LorePanelDefinition]) -> Self {
        .init(
            layoutID: layoutID, safeContextSheet: safeContextSheet,
            adultContextSheet: adultContextSheet, panels: replacement,
            textOverlays: textOverlays
        )
    }

    func replacingTextOverlays(_ replacement: [LoreTextOverlayDefinition]) -> Self {
        .init(
            layoutID: layoutID, safeContextSheet: safeContextSheet,
            adultContextSheet: adultContextSheet, panels: panels,
            textOverlays: replacement
        )
    }
}
