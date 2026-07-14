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

    func testPartyClassSpritesAreDistinct() throws {
        let catalog = BuiltinSpriteCatalog()
        let tank = try XCTUnwrap(catalog.pixelData(for: .tank, action: .idle).first)
        let dps = try XCTUnwrap(catalog.pixelData(for: .dps, action: .idle).first)
        let healer = try XCTUnwrap(catalog.pixelData(for: .healer, action: .idle).first)

        XCTAssertNotEqual(tank, dps)
        XCTAssertNotEqual(dps, healer)
        XCTAssertNotEqual(tank, healer)
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

    func testBundledManifestSlicesEqualCellsWithDeclaredPlaybackPolicy() throws {
        let manifest = Data("""
        {
          "version": 1,
          "cell": {"width": 96, "height": 64},
          "clips": [{
            "token": "dps",
            "action": "idle",
            "resource": "dps/idle.png",
            "frameCount": 2,
            "secondsPerFrame": 0.125,
            "repeats": true
          }]
        }
        """.utf8)
        let image = try XCTUnwrap(Self.image(width: 192, height: 64))
        let catalog = try BundledSpriteCatalog(
            manifestData: manifest,
            imageProvider: { $0 == "dps/idle.png" ? image : nil },
            fallback: BuiltinSpriteCatalog()
        )

        let clip = catalog.clip(for: .dps, action: .idle)

        XCTAssertEqual(clip.textures.count, 2)
        XCTAssertEqual(clip.textures.map { $0.size() }, [
            CGSize(width: 96, height: 64),
            CGSize(width: 96, height: 64),
        ])
        XCTAssertTrue(clip.textures.allSatisfy { $0.filteringMode == .nearest })
        XCTAssertEqual(clip.secondsPerFrame, 0.125, accuracy: 0.000_001)
        XCTAssertTrue(clip.repeats)
    }

    func testBundledCatalogFallsBackWhenClipOrResourceIsMissing() throws {
        let manifest = Data("""
        {"version":1,"cell":{"width":96,"height":64},"clips":[]}
        """.utf8)
        let fallback = BuiltinSpriteCatalog()
        let catalog = try BundledSpriteCatalog(
            manifestData: manifest,
            imageProvider: { _ in nil },
            fallback: fallback
        )

        let clip = catalog.clip(for: .dps, action: .attack3)

        XCTAssertEqual(clip.textures.first?.size(), CGSize(width: 12, height: 18))
        XCTAssertEqual(clip.secondsPerFrame, 0.08, accuracy: 0.000_001)
        XCTAssertFalse(clip.repeats)
    }

    private static func image(width: Int, height: Int) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.setFillColor(NSColor.systemRed.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        context.setFillColor(NSColor.systemBlue.cgColor)
        context.fill(CGRect(x: width / 2, y: 0, width: width / 2, height: height))
        return context.makeImage()
    }
}
