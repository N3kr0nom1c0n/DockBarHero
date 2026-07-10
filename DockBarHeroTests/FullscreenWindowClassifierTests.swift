import CoreGraphics
import XCTest
@testable import DockBarHero

final class FullscreenWindowClassifierTests: XCTestCase {
    func testClassifiesFrontmostLayerZeroScreenSizedWindow() {
        let windows = [
            WindowSnapshot(ownerPID: 42, layer: 0, bounds: CGRect(x: 0, y: 0, width: 1_728, height: 1_117), isOnScreen: true)
        ]

        XCTAssertTrue(FullscreenWindowClassifier().isFullscreen(
            frontmostPID: 42,
            ownPID: 99,
            screenFrame: CGRect(x: 0, y: 0, width: 1_728, height: 1_117),
            windows: windows
        ))
    }

    func testRejectsOwnAppWrongLayerAndPartialWindows() {
        let screen = CGRect(x: 0, y: 0, width: 1_728, height: 1_117)
        let classifier = FullscreenWindowClassifier()

        XCTAssertFalse(classifier.isFullscreen(frontmostPID: 99, ownPID: 99, screenFrame: screen, windows: []))
        XCTAssertFalse(classifier.isFullscreen(
            frontmostPID: 42,
            ownPID: 99,
            screenFrame: screen,
            windows: [WindowSnapshot(ownerPID: 42, layer: 1, bounds: screen, isOnScreen: true)]
        ))
        XCTAssertFalse(classifier.isFullscreen(
            frontmostPID: 42,
            ownPID: 99,
            screenFrame: screen,
            windows: [WindowSnapshot(ownerPID: 42, layer: 0, bounds: screen.insetBy(dx: 20, dy: 20), isOnScreen: true)]
        ))
    }

    func testRejectsScreenSizedWindowAtWrongOriginOnOffsetDisplay() {
        let screen = CGRect(x: -1_728, y: 0, width: 1_728, height: 1_117)

        XCTAssertFalse(FullscreenWindowClassifier().isFullscreen(
            frontmostPID: 42,
            ownPID: 99,
            screenFrame: screen,
            windows: [
                WindowSnapshot(
                    ownerPID: 42,
                    layer: 0,
                    bounds: CGRect(x: 0, y: 0, width: 1_728, height: 1_117),
                    isOnScreen: true
                )
            ]
        ))
    }

    func testClassifiesMenuBarVisibleFullscreenWithTransparentTopCompanion() {
        let screen = CGRect(x: 0, y: 0, width: 1_728, height: 1_117)

        XCTAssertTrue(FullscreenWindowClassifier().isFullscreen(
            frontmostPID: 42,
            ownPID: 99,
            screenFrame: screen,
            windows: [
                WindowSnapshot(
                    ownerPID: 42,
                    layer: 0,
                    bounds: CGRect(x: 0, y: 33, width: 1_728, height: 1_084),
                    isOnScreen: true,
                    alpha: 1
                ),
                WindowSnapshot(
                    ownerPID: 42,
                    layer: 7,
                    bounds: CGRect(x: 0, y: 0, width: 1_728, height: 33),
                    isOnScreen: true,
                    alpha: 0
                )
            ]
        ))
    }

    func testRejectsMenuBarSizedMainWindowWithoutTransparentTopCompanion() {
        let screen = CGRect(x: 0, y: 0, width: 1_728, height: 1_117)

        XCTAssertFalse(FullscreenWindowClassifier().isFullscreen(
            frontmostPID: 42,
            ownPID: 99,
            screenFrame: screen,
            windows: [
                WindowSnapshot(
                    ownerPID: 42,
                    layer: 0,
                    bounds: CGRect(x: 0, y: 33, width: 1_728, height: 1_084),
                    isOnScreen: true
                )
            ]
        ))
    }

    func testRejectsMenuBarSizedMainWindowWithOpaqueTopCompanion() {
        let screen = CGRect(x: 0, y: 0, width: 1_728, height: 1_117)

        XCTAssertFalse(FullscreenWindowClassifier().isFullscreen(
            frontmostPID: 42,
            ownPID: 99,
            screenFrame: screen,
            windows: [
                WindowSnapshot(
                    ownerPID: 42,
                    layer: 0,
                    bounds: CGRect(x: 0, y: 33, width: 1_728, height: 1_084),
                    isOnScreen: true,
                    alpha: 1
                ),
                WindowSnapshot(
                    ownerPID: 42,
                    layer: 7,
                    bounds: CGRect(x: 0, y: 0, width: 1_728, height: 33),
                    isOnScreen: true,
                    alpha: 1
                )
            ]
        ))
    }
}
