import XCTest
@testable import DockBarHero

final class LoreBookLayoutTests: XCTestCase {
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

    func testCaptionHeightIsBoundedAcrossSupportedWindowHeights() {
        XCTAssertEqual(LoreBookLayout.captionHeight(forPageHeight: 300), 150)
        XCTAssertEqual(LoreBookLayout.captionHeight(forPageHeight: 500), 180)
        XCTAssertEqual(LoreBookLayout.captionHeight(forPageHeight: 900), 190)
    }

    func testPageRegionsConsumeTheAvailableHeightWithoutOverlap() {
        let regions = LoreBookLayout.pageRegions(forPageHeight: 500, dividerHeight: 1)

        XCTAssertEqual(regions.artworkHeight, 319)
        XCTAssertEqual(regions.dividerHeight, 1)
        XCTAssertEqual(regions.captionHeight, 180)
        XCTAssertEqual(
            regions.artworkHeight + regions.dividerHeight + regions.captionHeight,
            500
        )
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
