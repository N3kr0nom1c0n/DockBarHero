import AppKit
import SpriteKit
import XCTest
@testable import DockBarHero

@MainActor
final class AppModelTests: XCTestCase {
    func testRunLifecyclePresentationAndActionsAreForwarded() async throws {
        let session = FakeGameSession()
        let model = AppModel(gameSession: session)
        model.start()

        session.emit(RunPresentation.classSelection)
        try await model.chooseStartingClass(.healer)
        try await model.startNewGame()

        XCTAssertEqual(model.runPresentation, .classSelection)
        XCTAssertEqual(session.classChoices, [.healer])
        XCTAssertEqual(session.newGameCount, 1)
    }

    func testLoadedClassSelectionRequestsManagementWindow() {
        let session = FakeGameSession()
        let model = AppModel(gameSession: session)
        var requestCount = 0
        model.onManagementWindowRequest = { requestCount += 1 }

        model.start()
        XCTAssertEqual(requestCount, 0)

        session.emit(.classSelection)

        XCTAssertEqual(requestCount, 1)
    }

    func testPendingPartySelectionRequestsManagementWindow() {
        let session = FakeGameSession()
        let model = AppModel(gameSession: session)
        var requestCount = 0
        model.onManagementWindowRequest = { requestCount += 1 }
        model.start()
        let presentation = GameSimulation().presentation
        let pending = PendingPartyUnlock(milestone: .boss25, choices: [.tank, .healer])

        session.emit(.partySelection(pending, presentation))

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(model.runPresentation, .partySelection(pending, presentation))
    }

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

    func testLoadedPreferencesResolveBeforeOverlayCanBecomeVisible() {
        let dependencies = TestDependencies()
        let settings = FakeSettingsController(
            initial: AppSettings(
                schemaVersion: 1,
                manualVisibility: .hidden,
                animationMode: .paused,
                inputMode: .passive
            )
        )
        let model = dependencies.makeModel(settingsController: settings)

        model.start()
        dependencies.monitor.onVisibilityChange?(.normalSpace)
        XCTAssertFalse(dependencies.window.visibility.contains(true))

        settings.resolve()

        XCTAssertEqual(model.state.manualVisibility, .hidden)
        XCTAssertEqual(model.state.animationMode, .paused)
        XCTAssertFalse(dependencies.window.visibility.contains(true))
    }

    func testUserOverlayActionsSubmitLatestSettingsButEnvironmentDoesNot() {
        let dependencies = TestDependencies()
        let settings = FakeSettingsController(initial: .defaults)
        let model = dependencies.makeModel(settingsController: settings)
        model.start()
        settings.resolve()

        model.send(.setManualVisibility(.hidden))
        model.send(.setAnimationMode(.paused))
        model.send(.setInputMode(.interactive))
        let submittedBeforeEnvironment = settings.updates
        model.send(.setEnvironmentVisibility(.fullscreen))

        XCTAssertEqual(submittedBeforeEnvironment.count, 3)
        XCTAssertEqual(submittedBeforeEnvironment.last?.manualVisibility, .hidden)
        XCTAssertEqual(submittedBeforeEnvironment.last?.animationMode, .paused)
        XCTAssertEqual(submittedBeforeEnvironment.last?.inputMode, .interactive)
        XCTAssertEqual(settings.updates, submittedBeforeEnvironment)
    }

    func testSettingsScaleUpdatesPersistAndApplyToScene() {
        let dependencies = TestDependencies()
        let settings = FakeSettingsController(initial: .defaults)
        let model = dependencies.makeModel(settingsController: settings)
        model.start()
        settings.resolve()

        model.updateActorScalePercent(125)
        model.updateRailTextScalePercent(120)

        XCTAssertEqual(model.appSettings.actorScalePercent, 125)
        XCTAssertEqual(model.appSettings.railTextScalePercent, 120)
        XCTAssertEqual(settings.updates.last?.actorScalePercent, 125)
        XCTAssertEqual(settings.updates.last?.railTextScalePercent, 120)
        XCTAssertEqual(
            dependencies.scene.appearances.last,
            RailAppearance(actorScalePercent: 125, railTextScalePercent: 120)
        )
    }

    func testReceivedSettingsApplyAppearanceToConnectedScene() {
        let dependencies = TestDependencies()
        var initial = AppSettings.defaults
        initial.actorScalePercent = 90
        initial.railTextScalePercent = 115
        let settings = FakeSettingsController(initial: initial)
        let model = dependencies.makeModel(settingsController: settings)
        model.start()

        settings.resolve()

        XCTAssertEqual(
            dependencies.scene.appearances.last,
            RailAppearance(actorScalePercent: 90, railTextScalePercent: 115)
        )
        XCTAssertEqual(model.appSettings.actorScalePercent, 90)
        XCTAssertEqual(model.appSettings.railTextScalePercent, 115)
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

    func testManagementRouteDefaultsToOverviewAndSelectionDoesNotRestartGameplay() {
        let session = FakeGameSession()
        let model = AppModel(gameSession: session)
        model.start()

        XCTAssertEqual(model.managementRoute, .overview)

        model.selectManagementRoute(.inventory)
        model.selectManagementRoute(.inventory)
        model.selectManagementRoute(.settings)

        XCTAssertEqual(model.managementRoute, .settings)
        XCTAssertEqual(session.startCount, 1)
    }

    func testLeavingBookRouteClosesLoreSpeech() {
        let lore = LoreReaderControllerFake()
        let model = AppModel(loreReader: lore)

        model.selectManagementRoute(.book)
        model.selectManagementRoute(.overview)

        XCTAssertEqual(lore.openCount, 1)
        XCTAssertEqual(lore.closeCount, 1)
    }

    func testResolvedSettingsUpdateLoreReaderWithoutLosingLoreValues() {
        var initial = AppSettings.defaults
        initial.loreLanguageMode = .clean
        initial.bookVolumeDetent = 9
        initial.spokenDialogueEnabled = true
        let settings = FakeSettingsController(initial: initial)
        let lore = LoreReaderControllerFake()
        let model = AppModel(settingsController: settings, loreReader: lore)

        model.start()
        settings.resolve()

        XCTAssertEqual(model.appSettings, initial)
        XCTAssertEqual(lore.updates.last?.settings, initial)
    }

    func testSuccessfulNewGameClearsDisposableBookState() async throws {
        let session = FakeGameSession()
        var initial = AppSettings.defaults
        initial.hasSeenCurrentRunPrologue = true
        initial.lastAutoReadLorePageID = "volume-1.level-20"
        let settings = FakeSettingsController(initial: initial)
        let model = AppModel(gameSession: session, settingsController: settings)
        model.start()
        settings.resolve()

        try await model.startNewGame()

        XCTAssertFalse(model.appSettings.hasSeenCurrentRunPrologue)
        XCTAssertNil(model.appSettings.lastAutoReadLorePageID)
        XCTAssertEqual(settings.updates.last, model.appSettings)
    }

    func testFailedNewGamePreservesDisposableBookState() async {
        let session = FakeGameSession()
        session.newGameError = FakeGameSessionError.rejected
        var initial = AppSettings.defaults
        initial.hasSeenCurrentRunPrologue = true
        initial.lastAutoReadLorePageID = "volume-1.level-20"
        let settings = FakeSettingsController(initial: initial)
        let model = AppModel(gameSession: session, settingsController: settings)
        model.start()
        settings.resolve()

        do {
            try await model.startNewGame()
            XCTFail("Expected new game failure")
        } catch { }

        XCTAssertTrue(model.appSettings.hasSeenCurrentRunPrologue)
        XCTAssertEqual(model.appSettings.lastAutoReadLorePageID, "volume-1.level-20")
    }

    func testManagementWindowCloseStopsLoreSpeech() {
        let lore = LoreReaderControllerFake()
        let model = AppModel(loreReader: lore)
        model.selectManagementRoute(.book)

        model.managementWindowDidClose()

        XCTAssertEqual(lore.closeCount, 1)
        XCTAssertEqual(model.managementRoute, .overview)
    }

    func testLoreSettingActionsSubmitIndependentValues() {
        let settings = FakeSettingsController(initial: .defaults)
        let lore = LoreReaderControllerFake()
        let model = AppModel(settingsController: settings, loreReader: lore)
        model.start()
        settings.resolve()

        model.updateLoreLanguage(.clean)
        model.updateSpokenDialogue(true)
        model.updateBookVolume(0)

        XCTAssertEqual(settings.updates.last?.loreLanguageMode, .clean)
        XCTAssertEqual(settings.updates.last?.loreIllustrationMode, .safe)
        XCTAssertEqual(settings.updates.last?.spokenDialogueEnabled, true)
        XCTAssertEqual(settings.updates.last?.bookVolumeDetent, 0)
    }

    func testAdultIllustrationsRequireExplicitConfirmation() {
        let settings = FakeSettingsController(initial: .defaults)
        let model = AppModel(settingsController: settings)
        model.start()
        settings.resolve()

        model.updateLoreIllustration(.adult)
        XCTAssertTrue(model.isAdultIllustrationConfirmationPresented)
        XCTAssertEqual(model.appSettings.loreIllustrationMode, .safe)

        model.confirmAdultIllustrations()
        XCTAssertFalse(model.isAdultIllustrationConfirmationPresented)
        XCTAssertEqual(model.appSettings.loreIllustrationMode, .adult)
        XCTAssertEqual(settings.updates.last?.loreIllustrationMode, .adult)
    }

    func testCancelAdultConfirmationKeepsSafeMode() {
        let model = AppModel()
        model.updateLoreIllustration(.adult)
        model.cancelAdultIllustrations()
        XCTAssertEqual(model.appSettings.loreIllustrationMode, .safe)
        XCTAssertFalse(model.isAdultIllustrationConfirmationPresented)
    }

    func testDisablingSpeechImmediatelyUpdatesReader() {
        let lore = LoreReaderControllerFake()
        let model = AppModel(loreReader: lore)
        model.updateSpokenDialogue(true)
        model.updateSpokenDialogue(false)
        XCTAssertEqual(lore.updates.last?.settings.spokenDialogueEnabled, false)
    }

    func testStopAndSaveStopsOverlayAndAwaitsGameAndSettingsSessions() async {
        let dependencies = TestDependencies()
        let session = FakeGameSession()
        let settings = FakeSettingsController(initial: .defaults, blocksStop: true)
        let model = dependencies.makeModel(gameSession: session, settingsController: settings)
        model.start()

        let stopTask = Task { @MainActor in
            await model.stopAndSave()
        }
        await waitUntil { session.stopCount == 1 && settings.stopCount == 1 }

        XCTAssertEqual(dependencies.monitor.stopCount, 1)
        XCTAssertEqual(session.stopCount, 1)
        XCTAssertEqual(settings.stopCount, 1)
        XCTAssertFalse(session.stopCompleted)
        XCTAssertFalse(settings.stopCompleted)

        session.completeStop()
        await Task.yield()
        XCTAssertFalse(settings.stopCompleted)
        settings.completeStop()
        await stopTask.value

        XCTAssertTrue(session.stopCompleted)
        XCTAssertTrue(settings.stopCompleted)
    }

    private func waitUntil(
        _ predicate: @escaping @MainActor () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<1_000 {
            if predicate() { return }
            await Task.yield()
        }
        XCTFail("condition not met", file: file, line: line)
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

    func testOpenBookLaunchArgumentRequestsBookRoute() {
        XCTAssertEqual(
            AppLaunchOptions.managementRoute(arguments: ["DockBarHero", "--open-book"]),
            .book
        )
        XCTAssertNil(AppLaunchOptions.managementRoute(arguments: ["DockBarHero"]))
    }

    func testSimulationSpeedLaunchArgumentParsesBoundedMultiplier() {
        XCTAssertEqual(
            AppLaunchOptions.simulationTimeScale(arguments: ["DockBarHero", "--simulation-speed", "10"]),
            10
        )
        XCTAssertEqual(
            AppLaunchOptions.simulationTimeScale(arguments: ["DockBarHero", "--simulation-speed=25"]),
            25
        )
        XCTAssertEqual(
            AppLaunchOptions.simulationTimeScale(arguments: ["DockBarHero", "--simulation-speed", "0"]),
            1
        )
        XCTAssertEqual(
            AppLaunchOptions.simulationTimeScale(arguments: ["DockBarHero", "--simulation-speed", "250"]),
            100
        )
    }

    func testBundleDoesNotForceAgentOnlyActivationPolicy() {
        XCTAssertNil(Bundle.main.object(forInfoDictionaryKey: "LSUIElement"))
    }

    func testManagementDockPresenceTransitionsBetweenAccessoryAndRegularPolicies() {
        let application = FakeApplicationActivation()
        let presence = ManagementDockPresenceController(application: application)

        presence.configureForLaunch()
        presence.managementWindowWillOpen()
        presence.managementWindowDidClose()

        XCTAssertEqual(application.policies, [.accessory, .regular, .accessory])
        XCTAssertEqual(application.activateCount, 1)
    }

    func testDockReopenShowsExistingManagementWindowWithoutCreatingApplicationInstances() {
        let application = FakeApplicationActivation()
        let presence = ManagementDockPresenceController(application: application)
        var openCount = 0

        let handled = presence.handleDockReopen(openManagementWindow: { openCount += 1 })

        XCTAssertTrue(handled)
        XCTAssertEqual(openCount, 1)
        XCTAssertEqual(application.policies, [])
        XCTAssertEqual(application.activateCount, 0)
    }
}

@MainActor
private final class TestDependencies {
    let window = FakeWindow()
    let scene = FakeScene()
    let screen = FakeScreen()
    let monitor = FakeMonitor()

    func makeModel(
        gameSession: GameSessionControlling? = nil,
        settingsController: SettingsControlling? = nil
    ) -> AppModel {
        AppModel(
            window: window,
            scene: scene,
            screen: screen,
            monitor: monitor,
            gameSession: gameSession,
            settingsController: settingsController
        )
    }

    func connect(_ model: AppModel) {
        model.connect(window: window, scene: scene, screen: screen, monitor: monitor)
    }
}

@MainActor
private final class FakeSettingsController: SettingsControlling {
    var onSettings: ((AppSettings) -> Void)?
    let initial: AppSettings
    let blocksStop: Bool
    var startCount = 0
    var updates: [AppSettings] = []
    var stopCount = 0
    var stopCompleted = false
    private var stopContinuation: CheckedContinuation<Void, Never>?

    init(initial: AppSettings, blocksStop: Bool = false) {
        self.initial = initial
        self.blocksStop = blocksStop
    }

    func start() { startCount += 1 }
    func resolve() { onSettings?(initial) }
    func update(_ settings: AppSettings) { updates.append(settings) }

    func stopAndSave() async {
        stopCount += 1
        if blocksStop {
            await withCheckedContinuation { stopContinuation = $0 }
        }
        stopCompleted = true
    }

    func completeStop() {
        stopContinuation?.resume()
        stopContinuation = nil
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

private final class FakeApplicationActivation: ApplicationActivationControlling {
    var policies: [NSApplication.ActivationPolicy] = []
    var activateCount = 0

    func setActivationPolicy(_ activationPolicy: NSApplication.ActivationPolicy) -> Bool {
        policies.append(activationPolicy)
        return true
    }

    func activate() {
        activateCount += 1
    }
}

@MainActor
private final class FakeScene: SceneControlling {
    let view = SKView()
    var animationEnabled: [Bool] = []
    var interactionEnabled: [Bool] = []
    var appearances: [RailAppearance] = []
    var presentations: [GamePresentation] = []
    var events: [[GameEvent]] = []

    func setAnimating(_ isAnimating: Bool) { animationEnabled.append(isAnimating) }
    func setInteractive(_ isInteractive: Bool) { interactionEnabled.append(isInteractive) }
    func setAppearance(_ appearance: RailAppearance) { appearances.append(appearance) }
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
    var onRunState: ((RunPresentation) -> Void)?
    var onEvents: (([GameEvent]) -> Void)?
    var onSaveStatus: ((SaveStatus) -> Void)?
    var startCount = 0
    var intents: [GameIntent] = []
    var stopCount = 0
    var stopCompleted = false
    var classChoices: [HeroClassID] = []
    var newGameCount = 0
    var newGameError: Error?
    private var stopContinuation: CheckedContinuation<Void, Never>?

    func start() { startCount += 1 }

    func send(_ intent: GameIntent) throws {
        intents.append(intent)
    }

    func chooseStartingClass(_ classID: HeroClassID) async throws {
        classChoices.append(classID)
    }

    func startNewGame() async throws {
        newGameCount += 1
        if let newGameError { throw newGameError }
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

    func emit(_ run: RunPresentation) {
        onRunState?(run)
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

private enum FakeGameSessionError: Error { case rejected }

@MainActor
private final class LoreReaderControllerFake: LoreReaderControlling {
    struct Update {
        let settings: AppSettings
        let pages: [ResolvedLorePage]
    }
    var updates: [Update] = []
    var openCount = 0
    var closeCount = 0
    func update(settings: AppSettings, pages: [ResolvedLorePage]) { updates.append(.init(settings: settings, pages: pages)) }
    func open() { openCount += 1 }
    func close() { closeCount += 1 }
    func applicationBecameActive() { }
    func applicationBecameInactive() { }
    func select(_ pageID: LorePageID) { }
    func replay() { }
    func skip() { }
    func previewVolume(detent: Int) { }
}
