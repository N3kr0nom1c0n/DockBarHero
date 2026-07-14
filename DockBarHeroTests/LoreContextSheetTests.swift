import CoreGraphics
import XCTest
@testable import DockBarHero

final class LoreContextSheetTests: XCTestCase {
    func testCellsUseRightToLeftTopThenRightToLeftBottomOrder() throws {
        XCTAssertEqual(
            try LoreContextSheet.cellRects(pixelWidth: 1536, pixelHeight: 1024),
            [
                CGRect(x: 1024, y: 512, width: 512, height: 512),
                CGRect(x: 512, y: 512, width: 512, height: 512),
                CGRect(x: 0, y: 512, width: 512, height: 512),
                CGRect(x: 1024, y: 0, width: 512, height: 512),
                CGRect(x: 512, y: 0, width: 512, height: 512),
                CGRect(x: 0, y: 0, width: 512, height: 512)
            ]
        )
    }

    func testRejectsWrongAspectOddDimensionsAndMissingResource() {
        XCTAssertThrowsError(try LoreContextSheet.cellRects(pixelWidth: 1024, pixelHeight: 1024))
        XCTAssertThrowsError(try LoreContextSheet.cellRects(pixelWidth: 1535, pixelHeight: 1024))
        XCTAssertThrowsError(try LoreContextSheet.cellRects(pixelWidth: 1536, pixelHeight: 1023))
        XCTAssertThrowsError(try LoreContextSheet.cells(named: "missing-lore-context"))
    }

    func testRejectsZeroAndNegativeDimensions() {
        XCTAssertThrowsError(try LoreContextSheet.cellRects(pixelWidth: 0, pixelHeight: 1024))
        XCTAssertThrowsError(try LoreContextSheet.cellRects(pixelWidth: 1536, pixelHeight: 0))
        XCTAssertThrowsError(try LoreContextSheet.cellRects(pixelWidth: 0, pixelHeight: 0))
        XCTAssertThrowsError(try LoreContextSheet.cellRects(pixelWidth: -1536, pixelHeight: 1024))
        XCTAssertThrowsError(try LoreContextSheet.cellRects(pixelWidth: 1536, pixelHeight: -1024))
        XCTAssertThrowsError(try LoreContextSheet.cellRects(pixelWidth: -1536, pixelHeight: -1024))
    }
}
