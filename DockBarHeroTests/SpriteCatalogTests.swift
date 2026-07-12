import SpriteKit
import XCTest
@testable import DockBarHero

@MainActor
final class SpriteCatalogTests: XCTestCase {
    func testDefinitionValidatesDimensionsRowsAndPalette() {
        XCTAssertThrowsError(try PixelSpriteDefinition(
            width: 2,
            height: 1,
            palette: ["X": 0xFFFFFFFF],
            rows: ["X"]
        ).rgbaPixels())
        XCTAssertThrowsError(try PixelSpriteDefinition(
            width: 1,
            height: 1,
            palette: [:],
            rows: ["X"]
        ).rgbaPixels())
    }

    func testTransparentPixelsAndBitmapBytesAreDeterministic() throws {
        let definition = PixelSpriteDefinition(
            width: 2,
            height: 1,
            palette: ["X": 0x112233FF],
            rows: [".X"]
        )

        XCTAssertEqual(try definition.rgbaPixels(), [0, 0x112233FF])
        XCTAssertEqual(try definition.rgbaBytes(), [0, 0, 0, 0, 0x11, 0x22, 0x33, 0xFF])
    }

    func testBuiltinSpritesAreDistinctNonSolidSilhouettes() throws {
        let catalog = BuiltinSpriteCatalog()
        let hero = try XCTUnwrap(catalog.pixelData(for: .hero, action: .idle).first)
        let enemy = try XCTUnwrap(catalog.pixelData(for: .enemy, action: .idle).first)

        XCTAssertTrue(hero.contains(0))
        XCTAssertGreaterThan(Set(hero).count, 4)
        XCTAssertNotEqual(hero, enemy)
    }

    func testTexturesUseNearestFilteringAndStableDimensions() throws {
        let texture = try XCTUnwrap(BuiltinSpriteCatalog().textures(for: .hero, action: .idle).first)

        XCTAssertEqual(texture.filteringMode, .nearest)
        XCTAssertEqual(texture.size(), CGSize(width: 12, height: 18))
    }

    func testMissingActionFallsBackToIdle() {
        let idle = PixelSpriteDefinition(
            width: 1,
            height: 1,
            palette: ["X": 0xFFFFFFFF],
            rows: ["X"]
        )
        let catalog = BuiltinSpriteCatalog(definitions: [.hero: [.idle: [idle]]])

        XCTAssertEqual(
            catalog.pixelData(for: .hero, action: .attack),
            catalog.pixelData(for: .hero, action: .idle)
        )
    }
}
