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

    func testEveryBundledCatalogSheetLoadsAsFourFrames() throws {
        let catalog = try LoreCatalog.bundled()
        for page in catalog.pages {
            XCTAssertEqual(try LoreSpriteSheet.frames(named: page.art.safeSpriteSheet).count, 4, page.id.rawValue)
            if let adult = page.art.adultSpriteSheet {
                XCTAssertEqual(try LoreSpriteSheet.frames(named: adult).count, 4, page.id.rawValue)
            }
        }
    }
}
