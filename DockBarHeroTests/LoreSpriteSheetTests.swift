import CoreGraphics
import XCTest
@testable import DockBarHero

final class LoreSpriteSheetTests: XCTestCase {
    func testFourFrameQuadrantsUseStableOrder() throws {
        XCTAssertEqual(
            try LoreSpriteSheet.frameRects(pixelWidth: 1024, pixelHeight: 1024, frameCount: 4),
            [
                CGRect(x: 0, y: 512, width: 512, height: 512),
                CGRect(x: 512, y: 512, width: 512, height: 512),
                CGRect(x: 0, y: 0, width: 512, height: 512),
                CGRect(x: 512, y: 0, width: 512, height: 512)
            ]
        )
    }

    func testRejectsNonSquareOddOrNonFourFrameSheets() {
        XCTAssertThrowsError(try LoreSpriteSheet.frameRects(pixelWidth: 1024, pixelHeight: 512, frameCount: 4))
        XCTAssertThrowsError(try LoreSpriteSheet.frameRects(pixelWidth: 1023, pixelHeight: 1023, frameCount: 4))
        XCTAssertThrowsError(try LoreSpriteSheet.frameRects(pixelWidth: 1024, pixelHeight: 1024, frameCount: 5))
    }
}
