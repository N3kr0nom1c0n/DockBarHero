import AppKit
import SpriteKit
import XCTest
@testable import DockBarHero

@MainActor
final class AppModelTests: XCTestCase {
    func testStartPlacesVisiblePassiveAnimatingRailOnce() {
        let dependencies = TestDependencies()
        let model = dependencies.makeModel()

        model.start()
        model.start()

        XCTAssertEqual(dependencies.window.frames.count, 1)
        XCTAssertEqual(dependencies.window.visibility, [true])
        XCTAssertEqual(dependencies.window.inputEnabled, [false])
        XCTAssertEqual(dependencies.scene.animationEnabled, [true])
        XCTAssertEqual(dependencies.monitor.startCount, 1)
    }

    func testFullscreenHidesAndPausesThenRestores() {
        let dependencies = TestDependencies()
        let model = dependencies.makeModel()
        model.start()

        dependencies.monitor.onVisibilityChange?(.fullscreen)
        dependencies.monitor.onVisibilityChange?(.normalSpace)

        XCTAssertEqual(dependencies.window.visibility, [true, false, true])
        XCTAssertEqual(dependencies.scene.animationEnabled, [true, false, true])
    }

    func testManualHideSurvivesFullscreenRoundTrip() {
        let dependencies = TestDependencies()
        let model = dependencies.makeModel()
        model.start()

        model.send(.setManualVisibility(.hidden))
        dependencies.monitor.onVisibilityChange?(.fullscreen)
        dependencies.monitor.onVisibilityChange?(.normalSpace)

        XCTAssertFalse(model.state.isEffectivelyVisible)
        XCTAssertEqual(model.state.manualVisibility, .hidden)
    }

    func testInteractiveModeEnablesWindowAndSceneInput() {
        let dependencies = TestDependencies()
        let model = dependencies.makeModel()
        model.start()

        model.send(.setInputMode(.interactive))

        XCTAssertEqual(dependencies.window.inputEnabled.last, true)
        XCTAssertEqual(dependencies.scene.interactionEnabled.last, true)
    }

    func testGeometryChangeRefreshesPlacement() {
        let dependencies = TestDependencies()
        let model = dependencies.makeModel()
        model.start()

        dependencies.monitor.onGeometryChange?()

        XCTAssertEqual(dependencies.window.frames.count, 2)
    }
}

@MainActor
private final class TestDependencies {
    let window = FakeWindow()
    let scene = FakeScene()
    let screen = FakeScreen()
    let monitor = FakeMonitor()

    func makeModel() -> AppModel {
        AppModel(window: window, scene: scene, screen: screen, monitor: monitor)
    }
}

@MainActor
private final class FakeWindow: OverlayWindowControlling {
    var frames: [CGRect] = []
    var visibility: [Bool] = []
    var inputEnabled: [Bool] = []

    func setFrame(_ frame: CGRect) { frames.append(frame) }
    func setVisible(_ isVisible: Bool) { visibility.append(isVisible) }
    func setInputEnabled(_ isEnabled: Bool) { inputEnabled.append(isEnabled) }
}

@MainActor
private final class FakeScene: SceneControlling {
    let view = SKView()
    var animationEnabled: [Bool] = []
    var interactionEnabled: [Bool] = []

    func setAnimating(_ isAnimating: Bool) { animationEnabled.append(isAnimating) }
    func setInteractive(_ isInteractive: Bool) { interactionEnabled.append(isInteractive) }
}

@MainActor
private final class FakeScreen: ScreenProviding {
    func currentGeometry() -> ScreenGeometry? {
        ScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 1_728, height: 1_117),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_728, height: 1_117),
            dockMode: .autoHidden
        )
    }
}

@MainActor
private final class FakeMonitor: EnvironmentMonitoring {
    var onVisibilityChange: (@MainActor (EnvironmentVisibility) -> Void)?
    var onGeometryChange: (@MainActor () -> Void)?
    var startCount = 0

    func start() { startCount += 1 }
    func stop() {}
}
