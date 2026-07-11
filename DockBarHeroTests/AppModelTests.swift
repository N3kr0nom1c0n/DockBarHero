import AppKit
import SpriteKit
import XCTest
@testable import DockBarHero

@MainActor
final class AppModelTests: XCTestCase {
    func testStartPlacesButKeepsRailHiddenAndPausedUntilEnvironmentResolves() {
        let dependencies = TestDependencies()
        let model = dependencies.makeModel()

        model.start()
        model.start()

        XCTAssertEqual(dependencies.window.frames.count, 1)
        XCTAssertEqual(dependencies.window.visibility, [false])
        XCTAssertEqual(dependencies.window.inputEnabled, [false])
        XCTAssertEqual(dependencies.scene.animationEnabled, [false])
        XCTAssertEqual(dependencies.scene.interactionEnabled, [false])
        XCTAssertEqual(dependencies.monitor.startCount, 1)
    }

    func testUnconnectedStartCanConnectAndStartLater() {
        let dependencies = TestDependencies()
        let model = AppModel()

        model.start()
        dependencies.connect(model)
        model.start()

        XCTAssertEqual(dependencies.window.frames.count, 1)
        XCTAssertEqual(dependencies.window.visibility, [false])
        XCTAssertEqual(dependencies.window.inputEnabled, [false])
        XCTAssertEqual(dependencies.scene.animationEnabled, [false])
        XCTAssertEqual(dependencies.monitor.startCount, 1)
    }

    func testFirstFullscreenCallbackNeverShowsOrAnimatesRail() {
        let dependencies = TestDependencies()
        let model = dependencies.makeModel()
        model.start()

        dependencies.monitor.onVisibilityChange?(.fullscreen)

        XCTAssertEqual(dependencies.window.visibility, [false, false])
        XCTAssertEqual(dependencies.scene.animationEnabled, [false, false])
        XCTAssertEqual(dependencies.window.inputEnabled, [false, false])
        XCTAssertEqual(dependencies.scene.interactionEnabled, [false, false])
    }

    func testFirstNormalSpaceCallbackRevealsPlacedRail() {
        let dependencies = TestDependencies()
        let model = dependencies.makeModel()
        model.start()

        dependencies.monitor.onVisibilityChange?(.normalSpace)

        XCTAssertEqual(dependencies.window.visibility, [false, true])
        XCTAssertEqual(dependencies.scene.animationEnabled, [false, true])
        XCTAssertEqual(dependencies.window.inputEnabled, [false, false])
        XCTAssertEqual(dependencies.scene.interactionEnabled, [false, false])
    }

    func testActionsBeforeEnvironmentResolutionApplyAfterNormalSpaceCallback() {
        let dependencies = TestDependencies()
        let model = dependencies.makeModel()
        model.start()

        model.send(.setAnimationMode(.paused))
        model.send(.setInputMode(.interactive))
        dependencies.monitor.onVisibilityChange?(.normalSpace)

        XCTAssertTrue(model.state.isEffectivelyVisible)
        XCTAssertEqual(dependencies.window.visibility.last, true)
        XCTAssertEqual(dependencies.window.inputEnabled.last, true)
        XCTAssertEqual(dependencies.scene.animationEnabled.last, false)
        XCTAssertEqual(dependencies.scene.interactionEnabled.last, true)
    }

    func testFullscreenHidesAndPausesThenRestores() {
        let dependencies = TestDependencies()
        let model = dependencies.makeModel()
        model.start()

        dependencies.monitor.onVisibilityChange?(.normalSpace)
        dependencies.monitor.onVisibilityChange?(.fullscreen)
        dependencies.monitor.onVisibilityChange?(.normalSpace)

        XCTAssertEqual(dependencies.window.visibility, [false, true, false, true])
        XCTAssertEqual(dependencies.scene.animationEnabled, [false, true, false, true])
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
        dependencies.monitor.onVisibilityChange?(.normalSpace)

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

    func testNoTargetScreenHidesDisablesInputAndPausesScene() {
        let dependencies = TestDependencies()
        let model = dependencies.makeModel()
        model.start()
        dependencies.monitor.onVisibilityChange?(.normalSpace)
        model.send(.setInputMode(.interactive))

        XCTAssertTrue(model.state.isEffectivelyVisible)
        XCTAssertEqual(dependencies.window.visibility.last, true)
        XCTAssertEqual(dependencies.window.inputEnabled.last, true)
        XCTAssertEqual(dependencies.scene.animationEnabled.last, true)
        XCTAssertEqual(dependencies.scene.interactionEnabled.last, true)

        dependencies.screen.geometry = nil
        dependencies.monitor.onGeometryChange?()

        XCTAssertEqual(dependencies.window.visibility.last, false)
        XCTAssertEqual(dependencies.window.inputEnabled.last, false)
        XCTAssertEqual(dependencies.scene.animationEnabled.last, false)
        XCTAssertEqual(dependencies.scene.interactionEnabled.last, false)
    }

    func testManualHideBeforeEnvironmentResolutionRemainsHiddenAfterNormalSpaceCallback() {
        let dependencies = TestDependencies()
        let model = dependencies.makeModel()
        model.start()

        model.send(.setManualVisibility(.hidden))
        dependencies.monitor.onVisibilityChange?(.normalSpace)

        XCTAssertFalse(dependencies.window.visibility.last ?? true)
        XCTAssertFalse(dependencies.scene.animationEnabled.last ?? true)
        XCTAssertFalse(dependencies.window.inputEnabled.last ?? true)
        XCTAssertFalse(dependencies.scene.interactionEnabled.last ?? true)
        XCTAssertEqual(model.state.manualVisibility, .hidden)
        XCTAssertFalse(model.state.isEffectivelyVisible)
    }

    func testStateActionWhileNoTargetScreenKeepsRailUnavailable() {
        let dependencies = TestDependencies()
        let model = dependencies.makeModel()
        model.start()
        dependencies.monitor.onVisibilityChange?(.normalSpace)

        dependencies.screen.geometry = nil
        dependencies.monitor.onGeometryChange?()
        model.send(.setInputMode(.interactive))

        XCTAssertEqual(dependencies.window.visibility.last, false)
        XCTAssertEqual(dependencies.window.inputEnabled.last, false)
        XCTAssertEqual(dependencies.scene.animationEnabled.last, false)
        XCTAssertEqual(dependencies.scene.interactionEnabled.last, false)
    }

    func testValidGeometryRestoresRailUsingCurrentState() {
        let dependencies = TestDependencies()
        let model = dependencies.makeModel()
        model.start()
        dependencies.monitor.onVisibilityChange?(.normalSpace)

        dependencies.screen.geometry = nil
        dependencies.monitor.onGeometryChange?()
        model.send(.setInputMode(.interactive))
        dependencies.screen.geometry = FakeScreen.defaultGeometry
        dependencies.monitor.onGeometryChange?()

        XCTAssertEqual(dependencies.window.frames.count, 2)
        XCTAssertEqual(dependencies.window.visibility.last, true)
        XCTAssertEqual(dependencies.window.inputEnabled.last, true)
        XCTAssertEqual(dependencies.scene.animationEnabled.last, true)
        XCTAssertEqual(dependencies.scene.interactionEnabled.last, true)
    }

    func testGameplayStartsWithoutOverlayDependencies() {
        let session = FakeGameSession()
        let model = AppModel(gameSession: session)

        model.start()

        XCTAssertEqual(session.startCount, 1)
    }

    func testGameplayCallbacksPublishAndRenderWithoutChangingOverlayRules() {
        let dependencies = TestDependencies()
        let session = FakeGameSession()
        let model = dependencies.makeModel(gameSession: session)
        var presentation = GameSimulation().presentation
        presentation = GamePresentation(
            state: presentation.state,
            heroAttack: presentation.heroAttack,
            heroDefense: presentation.heroDefense,
            rollingDPS: 12.3,
            encounterDPS: presentation.encounterDPS
        )

        model.start()
        session.emit(presentation)
        session.emit([.attack(attacker: .hero, defender: .enemy, damage: 10)])
        session.emit(.unsupportedVersion(7))

        XCTAssertEqual(model.game, presentation)
        XCTAssertEqual(dependencies.scene.presentations, [presentation])
        XCTAssertEqual(dependencies.scene.events, [[.attack(attacker: .hero, defender: .enemy, damage: 10)]])
        XCTAssertEqual(model.saveStatus, .unsupportedVersion(7))
    }

    func testIntentForwardsExactlyOnce() {
        let session = FakeGameSession()
        let model = AppModel(gameSession: session)

        model.start()
        model.send(.setAutoEquip(false))

        XCTAssertEqual(session.intents, [.setAutoEquip(false)])
    }

    func testStopAndSaveStopsOverlayAndAwaitsGameSession() async {
        let dependencies = TestDependencies()
        let session = FakeGameSession()
        let model = dependencies.makeModel(gameSession: session)
        model.start()

        let stopTask = Task { @MainActor in
            await model.stopAndSave()
        }
        await Task.yield()

        XCTAssertEqual(dependencies.monitor.stopCount, 1)
        XCTAssertEqual(session.stopCount, 1)
        XCTAssertFalse(session.stopCompleted)

        session.completeStop()
        await stopTask.value

        XCTAssertTrue(session.stopCompleted)
    }

    func testTerminationHelperReturnsWhenSaveCompletes() async {
        let outcome = await AppDelegate.waitForSaveOrTimeout(
            timeout: .seconds(5),
            sleep: { _ in
                try await Task.sleep(for: .seconds(30))
            },
            save: {}
        )

        XCTAssertEqual(outcome, .completed)
    }

    func testTerminationHelperReturnsTimeoutWhenSaveDoesNotComplete() async {
        let outcome = await AppDelegate.waitForSaveOrTimeout(
            timeout: .milliseconds(1),
            sleep: { duration in
                try await Task.sleep(for: duration)
            },
            save: {
                try? await Task.sleep(for: .seconds(30))
            }
        )

        XCTAssertEqual(outcome, .timedOut)
    }

    func testTerminationRequestGateStartsOnceAndKeepsWaitingWhilePending() {
        var gate = TerminationRequestGate()

        let decisions = [gate.request(), gate.request(), gate.request()]

        XCTAssertEqual(decisions, [.startAndWait, .wait, .wait])
    }

    func testTerminationRequestGateAllowsOneReplyBeforeTerminateNow() {
        var gate = TerminationRequestGate()
        XCTAssertEqual(gate.request(), .startAndWait)

        XCTAssertTrue(gate.markReplyIssued())
        XCTAssertFalse(gate.markReplyIssued())
        XCTAssertEqual(gate.request(), .terminateNow)
    }
}

@MainActor
private final class TestDependencies {
    let window = FakeWindow()
    let scene = FakeScene()
    let screen = FakeScreen()
    let monitor = FakeMonitor()

    func makeModel(gameSession: GameSessionControlling? = nil) -> AppModel {
        AppModel(
            window: window,
            scene: scene,
            screen: screen,
            monitor: monitor,
            gameSession: gameSession
        )
    }

    func connect(_ model: AppModel) {
        model.connect(window: window, scene: scene, screen: screen, monitor: monitor)
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
    var presentations: [GamePresentation] = []
    var events: [[GameEvent]] = []

    func setAnimating(_ isAnimating: Bool) { animationEnabled.append(isAnimating) }
    func setInteractive(_ isInteractive: Bool) { interactionEnabled.append(isInteractive) }
    func render(_ presentation: GamePresentation) { presentations.append(presentation) }
    func handle(_ events: [GameEvent]) { self.events.append(events) }
}

@MainActor
private final class FakeScreen: ScreenProviding {
    static let defaultGeometry = ScreenGeometry(
        frame: CGRect(x: 0, y: 0, width: 1_728, height: 1_117),
        visibleFrame: CGRect(x: 0, y: 0, width: 1_728, height: 1_117),
        dockMode: .autoHidden
    )

    var geometry: ScreenGeometry? = defaultGeometry

    func currentGeometry() -> ScreenGeometry? {
        geometry
    }
}

@MainActor
private final class FakeMonitor: EnvironmentMonitoring {
    var onVisibilityChange: (@MainActor (EnvironmentVisibility) -> Void)?
    var onGeometryChange: (@MainActor () -> Void)?
    var startCount = 0
    var stopCount = 0

    func start() { startCount += 1 }
    func stop() { stopCount += 1 }
}

@MainActor
private final class FakeGameSession: GameSessionControlling {
    var onPresentation: ((GamePresentation) -> Void)?
    var onEvents: (([GameEvent]) -> Void)?
    var onSaveStatus: ((SaveStatus) -> Void)?
    var startCount = 0
    var intents: [GameIntent] = []
    var stopCount = 0
    var stopCompleted = false
    private var stopContinuation: CheckedContinuation<Void, Never>?

    func start() { startCount += 1 }

    func send(_ intent: GameIntent) throws {
        intents.append(intent)
    }

    func stopAndSave() async {
        stopCount += 1
        await withCheckedContinuation { continuation in
            stopContinuation = continuation
        }
        stopCompleted = true
    }

    func emit(_ presentation: GamePresentation) {
        onPresentation?(presentation)
    }

    func emit(_ events: [GameEvent]) {
        onEvents?(events)
    }

    func emit(_ status: SaveStatus) {
        onSaveStatus?(status)
    }

    func completeStop() {
        stopContinuation?.resume()
        stopContinuation = nil
    }
}
