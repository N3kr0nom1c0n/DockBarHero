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

    func testEnemyIdentityActionOverridesGenericEnemy() {
        let identityAttack = PixelSpriteDefinition(
            width: 1,
            height: 1,
            palette: ["I": 0x112233FF],
            rows: ["I"]
        )
        let genericAttack = PixelSpriteDefinition(
            width: 1,
            height: 1,
            palette: ["G": 0x445566FF],
            rows: ["G"]
        )
        let spriteID = EnemySpriteID(rawValue: "test.enemy")
        let catalog = BuiltinSpriteCatalog(
            definitions: [.enemy: [.attack: [genericAttack]]],
            enemyDefinitions: [spriteID: [.attack: [identityAttack]]]
        )

        XCTAssertEqual(
            catalog.pixelData(forEnemy: spriteID, action: .attack),
            [[0x112233FF]]
        )
    }

    func testMissingEnemyActionFallsBackToIdentityIdle() {
        let identityIdle = PixelSpriteDefinition(
            width: 1,
            height: 1,
            palette: ["I": 0x112233FF],
            rows: ["I"]
        )
        let spriteID = EnemySpriteID(rawValue: "test.enemy")
        let catalog = BuiltinSpriteCatalog(
            definitions: [:],
            enemyDefinitions: [spriteID: [.idle: [identityIdle]]]
        )

        XCTAssertEqual(
            catalog.pixelData(forEnemy: spriteID, action: .attack),
            [[0x112233FF]]
        )
    }

    func testMissingEnemyIdentityUsesGenericEnemy() {
        let catalog = BuiltinSpriteCatalog()

        XCTAssertEqual(
            catalog.pixelData(
                forEnemy: EnemySpriteID(rawValue: "missing.enemy"),
                action: .attack
            ),
            catalog.pixelData(for: .enemy, action: .attack)
        )
    }

    func testMissingEnemyAndGenericActionsFallBackToGenericIdle() {
        let genericIdle = PixelSpriteDefinition(
            width: 1,
            height: 1,
            palette: ["G": 0x445566FF],
            rows: ["G"]
        )
        let catalog = BuiltinSpriteCatalog(definitions: [.enemy: [.idle: [genericIdle]]])

        XCTAssertEqual(
            catalog.pixelData(
                forEnemy: EnemySpriteID(rawValue: "missing.enemy"),
                action: .attack
            ),
            [[0x445566FF]]
        )
    }

    func testEmptyEnemyIdentityActionFallsBackToIdentityIdle() {
        let identityIdle = PixelSpriteDefinition(
            width: 1,
            height: 1,
            palette: ["I": 0x112233FF],
            rows: ["I"]
        )
        let spriteID = EnemySpriteID(rawValue: "test.enemy")
        let catalog = BuiltinSpriteCatalog(
            definitions: [:],
            enemyDefinitions: [spriteID: [.idle: [identityIdle], .attack: []]]
        )

        XCTAssertEqual(
            catalog.pixelData(forEnemy: spriteID, action: .attack),
            [[0x112233FF]]
        )
    }

    func testEmptyEnemyIdentityIdleFallsBackToGenericAction() {
        let genericAttack = PixelSpriteDefinition(
            width: 1,
            height: 1,
            palette: ["G": 0x445566FF],
            rows: ["G"]
        )
        let spriteID = EnemySpriteID(rawValue: "test.enemy")
        let catalog = BuiltinSpriteCatalog(
            definitions: [.enemy: [.attack: [genericAttack]]],
            enemyDefinitions: [spriteID: [.idle: []]]
        )

        XCTAssertEqual(
            catalog.pixelData(forEnemy: spriteID, action: .attack),
            [[0x445566FF]]
        )
    }

    func testEmptyGenericEnemyActionFallsBackToGenericIdle() {
        let genericIdle = PixelSpriteDefinition(
            width: 1,
            height: 1,
            palette: ["G": 0x445566FF],
            rows: ["G"]
        )
        let catalog = BuiltinSpriteCatalog(
            definitions: [.enemy: [.idle: [genericIdle], .attack: []]]
        )

        XCTAssertEqual(
            catalog.pixelData(
                forEnemy: EnemySpriteID(rawValue: "missing.enemy"),
                action: .attack
            ),
            [[0x445566FF]]
        )
    }

    func testEmptyGenericEnemyIdleUsesMagentaDiagnosticFallback() throws {
        let catalog = BuiltinSpriteCatalog(definitions: [.enemy: [.idle: []]])

        let pixels = try XCTUnwrap(
            catalog.pixelData(
                forEnemy: EnemySpriteID(rawValue: "missing.enemy"),
                action: .attack
            ).first
        )
        XCTAssertEqual(pixels.count, 16)
        XCTAssertEqual(pixels[0], 0xFF00FFFF)
        XCTAssertEqual(pixels[1], 0x000000FF)
    }

    func testInvalidEnemyIdentityPixelsUseMagentaDiagnosticFallback() throws {
        let invalidIdentity = PixelSpriteDefinition(
            width: 2,
            height: 1,
            palette: ["I": 0x112233FF],
            rows: ["I"]
        )
        let genericIdle = PixelSpriteDefinition(
            width: 1,
            height: 1,
            palette: ["G": 0x445566FF],
            rows: ["G"]
        )
        let spriteID = EnemySpriteID(rawValue: "test.enemy")
        let catalog = BuiltinSpriteCatalog(
            definitions: [.enemy: [.idle: [genericIdle]]],
            enemyDefinitions: [spriteID: [.idle: [invalidIdentity]]]
        )

        let pixels = try XCTUnwrap(
            catalog.pixelData(forEnemy: spriteID, action: .idle).first
        )
        XCTAssertEqual(pixels.count, 16)
        XCTAssertEqual(pixels[0], 0xFF00FFFF)
        XCTAssertEqual(pixels[1], 0x000000FF)
    }
}
