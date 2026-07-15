import XCTest
@testable import DockBarHero

final class LoreBookLayoutTests: XCTestCase {
    func testInitialManagementWindowSizeIsAppliedOnlyOnFirstOpen() {
        var gate = InitialManagementWindowSizingGate()

        XCTAssertTrue(gate.shouldApplyInitialSize())
        XCTAssertFalse(gate.shouldApplyInitialSize())
    }

    func testWideContentUsesTwoPageSpreadAndCompactContentUsesSinglePage() {
        XCTAssertEqual(
            LoreBookLayout.mode(forContentWidth: LoreBookLayout.minimumSpreadWidth),
            .spread
        )
        XCTAssertEqual(
            LoreBookLayout.mode(forContentWidth: LoreBookLayout.minimumSpreadWidth - 1),
            .singlePage
        )
    }

    func testSpreadPlacesCurrentPageOnRightAndFollowingPageOnLeft() {
        XCTAssertEqual(
            LoreBookLayout.spread(pageCount: 6, currentIndex: 2),
            .init(leftIndex: 3, rightIndex: 2)
        )
    }

    func testFinalSpreadUsesBlankLeftPage() {
        XCTAssertEqual(
            LoreBookLayout.spread(pageCount: 6, currentIndex: 5),
            .init(leftIndex: nil, rightIndex: 5)
        )
    }

    func testSpreadRejectsEmptyOrOutOfBoundsSelection() {
        XCTAssertNil(LoreBookLayout.spread(pageCount: 0, currentIndex: 0))
        XCTAssertNil(LoreBookLayout.spread(pageCount: 2, currentIndex: -1))
        XCTAssertNil(LoreBookLayout.spread(pageCount: 2, currentIndex: 2))
    }

    func testPageCanvasInsetsRemainLegible() {
        XCTAssertEqual(LoreBookLayout.pageCanvasInsets(forPageWidth: 320), 8)
        XCTAssertEqual(LoreBookLayout.pageCanvasInsets(forPageWidth: 520), 12)
    }

    func testPanelGutterIsBounded() {
        XCTAssertEqual(LoreBookLayout.panelGutter(forPageWidth: 320), 5)
        XCTAssertEqual(LoreBookLayout.panelGutter(forPageWidth: 520), 8)
        XCTAssertEqual(LoreBookLayout.panelGutter(forPageWidth: 900), 8)
    }

    func testLongCopyInANarrowPanelUsesPageCallout() {
        XCTAssertTrue(LoreBookLayout.usesPageCallout(characterCount: 80, panelWidth: 160))
        XCTAssertFalse(LoreBookLayout.usesPageCallout(characterCount: 40, panelWidth: 220))
    }

    func testBookReactionsAlwaysUseReservedHeaderSpace() {
        let wide = LoreBookLayout.reactionPolicy(forContentWidth: 900)
        let compact = LoreBookLayout.reactionPolicy(forContentWidth: 560)

        XCTAssertEqual(wide.region, .reservedHeader)
        XCTAssertEqual(compact.region, .reservedHeader)
        XCTAssertEqual(wide.arrangement, .inline)
        XCTAssertEqual(compact.arrangement, .stacked)
        XCTAssertGreaterThan(wide.maximumBubbleWidth, 0)
        XCTAssertGreaterThan(compact.maximumBubbleWidth, 0)
    }

    func testDefaultManagementWindowCanShowSpreadBesideSidebar() {
        let maximumSidebarWidth: CGFloat = 230

        XCTAssertEqual(ManagementWindowSizing.initialContentSize.width, 1_100)
        XCTAssertEqual(ManagementWindowSizing.initialContentSize.height, 720)
        XCTAssertEqual(ManagementWindowSizing.minimumSize.width, 720)
        XCTAssertEqual(ManagementWindowSizing.minimumSize.height, 520)
        XCTAssertGreaterThanOrEqual(
            ManagementWindowSizing.initialContentSize.width - maximumSidebarWidth,
            LoreBookLayout.minimumSpreadWidth
        )
    }
}
