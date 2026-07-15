import XCTest
@testable import DockBarHero

final class LoreMangaAccessibilityTests: XCTestCase {
    func testNarrativeUsesPanelReadingOrderThenCatalogOverlayOrder() {
        let page = makePage(overlays: [
            overlay(id: "late-first", panelID: "late", text: "Late first"),
            overlay(id: "early", panelID: "early", text: "Early"),
            overlay(id: "late-second", panelID: "late", text: "Late second")
        ])

        XCTAssertEqual(
            LoreMangaAccessibility.narrative(
                for: page,
                visiblePanelIDs: ["early", "late"]
            ),
            "Page art\nEarly\nLate first\nLate second"
        )
    }

    func testNarrativeOmitsSoundEffects() {
        let page = makePage(overlays: [
            overlay(id: "speech", panelID: "early", text: "Spoken"),
            overlay(id: "sound", panelID: "early", style: .soundEffect, text: "KRAK")
        ])

        XCTAssertEqual(
            LoreMangaAccessibility.narrative(
                for: page,
                visiblePanelIDs: ["early", "late"]
            ),
            "Page art\nSpoken"
        )
    }

    func testNarrativeOmitsSpeechAttachedToAnOmittedGagPanel() {
        let page = makePage(overlays: [
            overlay(id: "visible", panelID: "early", text: "Visible speech"),
            overlay(id: "missing-gag", panelID: "gag", text: "Hidden gag speech")
        ])

        XCTAssertEqual(
            LoreMangaAccessibility.narrative(
                for: page,
                visiblePanelIDs: ["early", "late"]
            ),
            "Page art\nVisible speech"
        )
    }

    private func makePage(overlays: [ResolvedLoreTextOverlay]) -> ResolvedLorePage {
        ResolvedLorePage(
            id: LorePageID(rawValue: "accessibility-test"),
            title: "Test",
            body: "Test body",
            spriteSheetName: "test-sheet",
            accessibilityDescription: "Page art",
            composition: ResolvedLoreComposition(
                layoutID: .cascadeFive,
                contextSheetName: "test-context",
                panels: [
                    panel(id: "late", readingOrder: 1),
                    panel(id: "early", readingOrder: 0),
                    panel(id: "gag", role: .gag, sourceCell: nil, readingOrder: 2)
                ],
                textOverlays: overlays
            ),
            dialogueCueIDs: [],
            frameCount: 4,
            frameDurationMilliseconds: 180
        )
    }

    private func panel(
        id: String,
        role: LorePanelRole = .still,
        sourceCell: Int? = 0,
        readingOrder: Int
    ) -> LorePanelDefinition {
        LorePanelDefinition(
            id: id,
            slotID: "slot1",
            role: role,
            sourceCell: sourceCell,
            readingOrder: readingOrder,
            focalPoint: LoreFocalPoint(x: 0.5, y: 0.5)
        )
    }

    private func overlay(
        id: String,
        panelID: String,
        style: LoreTextOverlayStyle = .speech,
        text: String
    ) -> ResolvedLoreTextOverlay {
        ResolvedLoreTextOverlay(
            id: id,
            panelID: panelID,
            style: style,
            placement: .center,
            speakerID: nil,
            dialogueCueID: nil,
            text: text
        )
    }
}
