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
}
