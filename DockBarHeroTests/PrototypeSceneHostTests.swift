import SpriteKit
import XCTest
@testable import DockBarHero

@MainActor
final class PrototypeSceneHostTests: XCTestCase {
    func testHostConfiguresTransparentThirtyFPSScene() throws {
        let host = try PrototypeSceneHost()

        XCTAssertEqual(host.view.preferredFramesPerSecond, 30)
        XCTAssertTrue(host.view.allowsTransparency)
        XCTAssertEqual(host.scene.backgroundColor.cgColor.alpha, 0)
        XCTAssertNotNil(host.scene.childNode(withName: "hero"))
        XCTAssertNotNil(host.scene.childNode(withName: "enemy"))
        XCTAssertNotNil(host.scene.childNode(withName: "ground"))
    }

    func testAnimationAndInteractionControls() throws {
        let host = try PrototypeSceneHost()

        host.setAnimating(false)
        host.setInteractive(true)

        XCTAssertTrue(host.scene.isPaused)
        XCTAssertTrue(host.scene.isUserInteractionEnabled)
    }

    func testRenderingUsesStableNamedNodesAndClampedSnapshotValues() throws {
        let host = try PrototypeSceneHost()
        var state = GameState.newGame(balance: .standard)
        state.hero.currentHealth = 75
        state.enemy.currentHealth = 12
        state.encounter.enemyLevel = 7
        let presentation = GamePresentation(
            state: state,
            heroAttack: 10,
            heroDefense: 0,
            rollingDPS: 12.34,
            encounterDPS: 4.0
        )

        host.scene.render(presentation)

        let enemyLevel = try XCTUnwrap(host.scene.childNode(withName: "//enemyLevel") as? SKLabelNode)
        let rollingDPS = try XCTUnwrap(host.scene.childNode(withName: "//rollingDPS") as? SKLabelNode)
        let heroHealthFill = try XCTUnwrap(host.scene.childNode(withName: "//heroHealthFill"))
        let enemyHealthFill = try XCTUnwrap(host.scene.childNode(withName: "//enemyHealthFill"))

        XCTAssertEqual(enemyLevel.text, "Lv. 7")
        XCTAssertEqual(rollingDPS.text, "12.3 DPS")
        XCTAssertEqual(heroHealthFill.xScale, 0.75, accuracy: 0.001)
        XCTAssertEqual(enemyHealthFill.xScale, 0.4, accuracy: 0.001)

        state.hero.currentHealth = 200
        state.enemy.currentHealth = -10
        host.scene.render(GamePresentation(
            state: state,
            heroAttack: 10,
            heroDefense: 0,
            rollingDPS: 0,
            encounterDPS: 0
        ))

        XCTAssertEqual(heroHealthFill.xScale, 1, accuracy: 0.001)
        XCTAssertEqual(enemyHealthFill.xScale, 0, accuracy: 0.001)
    }

    func testEventsDriveTransientActionsAndNoRepeatingMockAttack() throws {
        let host = try PrototypeSceneHost()
        let hero = try XCTUnwrap(host.scene.childNode(withName: "hero"))

        XCTAssertNil(hero.action(forKey: "attack"))

        host.scene.handle([.attack(attacker: .hero, defender: .enemy, damage: 10)])

        XCTAssertNotNil(host.scene.childNode(withName: "//hit"))
    }

    func testVictoryUsesBriefEnemyFadeOutAndIn() throws {
        let host = try PrototypeSceneHost()
        let enemy = try XCTUnwrap(host.scene.childNode(withName: "enemy"))

        host.scene.handle([.victory(defeatedLevel: 7)])

        let action = try XCTUnwrap(enemy.action(forKey: "eventFade"))
        XCTAssertEqual(action.duration, 0.26, accuracy: 0.001)
        XCTAssertNil(enemy.action(forKey: "reviveVisibility"))
    }

    func testDefeatFadesHeroOutWithoutAutomaticRestore() throws {
        let host = try PrototypeSceneHost()
        let hero = try XCTUnwrap(host.scene.childNode(withName: "hero"))

        host.scene.handle([.defeat(enemyLevel: 7)])

        let action = try XCTUnwrap(hero.action(forKey: "reviveVisibility"))
        XCTAssertEqual(action.duration, 0.08, accuracy: 0.001)
        XCTAssertNil(hero.action(forKey: "eventFade"))
    }

    func testRevivedReplacesDefeatFadeAndRestoresHeroOpacity() throws {
        let host = try PrototypeSceneHost()
        let hero = try XCTUnwrap(host.scene.childNode(withName: "hero"))
        host.scene.handle([.defeat(enemyLevel: 7)])
        hero.alpha = 0

        host.scene.handle([.revived(enemyLevel: 7)])

        XCTAssertNil(hero.action(forKey: "reviveVisibility"))
        XCTAssertNil(hero.action(forKey: "eventFade"))
        XCTAssertEqual(hero.alpha, 1, accuracy: 0.001)
    }
}
