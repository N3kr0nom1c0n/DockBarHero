import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var state = OverlayState()
    @Published private(set) var game = GameSimulation().presentation
    @Published private(set) var saveStatus: SaveStatus = .notLoaded
    @Published private(set) var managementRoute: ManagementRoute = .overview

    private var window: OverlayWindowControlling?
    private var scene: SceneControlling?
    private var screen: ScreenProviding?
    private var monitor: EnvironmentMonitoring?
    private var gameSession: GameSessionControlling?
    private var settingsController: SettingsControlling?
    private var placement = PlacementResolver()
    private var hasCurrentPlacement = false
    private var hasResolvedEnvironment = false
    private var hasResolvedSettings: Bool
    private var gameplayStarted = false
    private var settingsStarted = false
    private var overlayStarted = false

    init(
        window: OverlayWindowControlling? = nil,
        scene: SceneControlling? = nil,
        screen: ScreenProviding? = nil,
        monitor: EnvironmentMonitoring? = nil,
        gameSession: GameSessionControlling? = nil,
        settingsController: SettingsControlling? = nil
    ) {
        self.window = window
        self.scene = scene
        self.screen = screen
        self.monitor = monitor
        self.gameSession = gameSession
        self.settingsController = settingsController
        self.hasResolvedSettings = settingsController == nil
    }

    private func handleEnvironmentVisibility(_ visibility: EnvironmentVisibility) {
        hasResolvedEnvironment = true
        send(.setEnvironmentVisibility(visibility))
    }

    func connect(
        window: OverlayWindowControlling,
        scene: SceneControlling,
        screen: ScreenProviding,
        monitor: EnvironmentMonitoring
    ) {
        precondition(!overlayStarted, "Dependencies must be connected before overlay start")
        self.window = window
        self.scene = scene
        self.screen = screen
        self.monitor = monitor
        if gameplayStarted {
            scene.render(game)
        }
    }

    func start() {
        startGameplayIfNeeded()
        startSettingsIfNeeded()

        guard !overlayStarted else { return }
        guard window != nil,
              scene != nil,
              screen != nil,
              monitor != nil else {
            AppLog.lifecycle.error("Overlay coordination requires connected dependencies")
            return
        }
        overlayStarted = true
        monitor?.onVisibilityChange = { [weak self] visibility in
            self?.handleEnvironmentVisibility(visibility)
        }
        monitor?.onGeometryChange = { [weak self] in
            self?.refreshPlacement()
        }
        refreshPlacement()
        monitor?.start()
        AppLog.lifecycle.info("Application coordination started")
    }

    func stop() {
        monitor?.stop()
        window?.setVisible(false)
        scene?.setAnimating(false)
    }

    func stopAndSave() async {
        stop()
        let gameTask = Task { @MainActor [gameSession] in
            await gameSession?.stopAndSave()
        }
        let settingsTask = Task { @MainActor [settingsController] in
            await settingsController?.stopAndSave()
        }
        await gameTask.value
        await settingsTask.value
    }

    func send(_ action: OverlayAction) {
        state.apply(action)
        applyState()
        if case .setEnvironmentVisibility = action {
            // Environment visibility is runtime-only.
        } else {
            settingsController?.update(currentSettings)
        }
        AppLog.overlay.debug("Overlay state updated")
    }

    func send(_ intent: GameIntent) {
        do {
            try gameSession?.send(intent)
        } catch {
            AppLog.gameplay.error("Gameplay intent failed: \(String(describing: error), privacy: .public)")
        }
    }

    func selectManagementRoute(_ route: ManagementRoute) {
        guard managementRoute != route else { return }
        managementRoute = route
    }

    private func startGameplayIfNeeded() {
        guard !gameplayStarted, let gameSession else { return }
        gameplayStarted = true
        gameSession.onPresentation = { [weak self] presentation in
            self?.receive(presentation)
        }
        gameSession.onEvents = { [weak self] events in
            self?.receive(events)
        }
        gameSession.onSaveStatus = { [weak self] status in
            self?.saveStatus = status
        }
        gameSession.start()
    }

    private func startSettingsIfNeeded() {
        guard !settingsStarted, let settingsController else { return }
        settingsStarted = true
        settingsController.onSettings = { [weak self] settings in
            self?.receive(settings)
        }
        settingsController.start()
    }

    private func receive(_ settings: AppSettings) {
        state.manualVisibility = settings.manualVisibility
        state.animationMode = settings.animationMode
        state.inputMode = settings.inputMode
        hasResolvedSettings = true
        applyState()
    }

    private var currentSettings: AppSettings {
        AppSettings(
            schemaVersion: AppSettings.currentVersion,
            manualVisibility: state.manualVisibility,
            animationMode: state.animationMode,
            inputMode: state.inputMode
        )
    }

    private func receive(_ presentation: GamePresentation) {
        game = presentation
        scene?.render(presentation)
    }

    private func receive(_ events: [GameEvent]) {
        scene?.handle(events)
    }

    private func refreshPlacement() {
        guard let geometry = screen?.currentGeometry(),
              let frame = placement.resolve(geometry) else {
            hasCurrentPlacement = false
            applyState()
            return
        }
        hasCurrentPlacement = true
        window?.setFrame(frame)
        applyState()
    }

    private func applyState() {
        let isAvailable = hasResolvedSettings && hasResolvedEnvironment && hasCurrentPlacement
        window?.setVisible(state.isEffectivelyVisible && isAvailable)
        window?.setInputEnabled(state.acceptsInput && isAvailable)
        scene?.setAnimating(state.shouldAnimate && isAvailable)
        scene?.setInteractive(state.acceptsInput && isAvailable)
    }
}
