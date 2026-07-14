import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var state = OverlayState()
    @Published private(set) var game = GameSimulation().presentation
    @Published private(set) var runPresentation: RunPresentation = .classSelection
    @Published private(set) var saveStatus: SaveStatus = .notLoaded
    @Published private(set) var managementRoute: ManagementRoute = .overview
    @Published private(set) var appSettings = AppSettings.defaults
    @Published private(set) var lorePages: [ResolvedLorePage] = []
    @Published private(set) var isAdultIllustrationConfirmationPresented = false
    let loreReader: any LoreReaderControlling
    var onManagementWindowRequest: (() -> Void)?

    private var window: OverlayWindowControlling?
    private var scene: SceneControlling?
    private var screen: ScreenProviding?
    private var monitor: EnvironmentMonitoring?
    private var gameSession: GameSessionControlling?
    private var settingsController: SettingsControlling?
    private let loreCatalog: LoreCatalog?
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
        settingsController: SettingsControlling? = nil,
        loreCatalog: LoreCatalog? = nil,
        loreReader: (any LoreReaderControlling)? = nil
    ) {
        self.window = window
        self.scene = scene
        self.screen = screen
        self.monitor = monitor
        self.gameSession = gameSession
        self.settingsController = settingsController
        self.loreCatalog = loreCatalog
        self.loreReader = loreReader ?? SilentLoreReaderController()
        self.hasResolvedSettings = settingsController == nil
        if let controller = self.loreReader as? LoreReaderController {
            controller.onAutoReadPage = { [weak self] pageID in
                self?.recordAutoRead(pageID)
            }
        }
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
            scene.render(runPresentation)
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
        loreReader.close()
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
        appSettings.manualVisibility = state.manualVisibility
        appSettings.animationMode = state.animationMode
        appSettings.inputMode = state.inputMode
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

    func chooseStartingClass(_ classID: HeroClassID) async throws {
        try await gameSession?.chooseStartingClass(classID)
    }

    func startNewGame() async throws {
        try await gameSession?.startNewGame()
        appSettings.hasSeenCurrentRunPrologue = false
        appSettings.lastAutoReadLorePageID = nil
        publishLoreSettings()
    }

    func selectManagementRoute(_ route: ManagementRoute) {
        guard managementRoute != route else { return }
        if managementRoute == .book { loreReader.close() }
        managementRoute = route
        if route == .book { loreReader.open() }
    }

    func managementWindowDidClose() {
        loreReader.close()
        if managementRoute == .book {
            managementRoute = .overview
        }
    }

    func updateLoreLanguage(_ mode: LoreLanguageMode) {
        appSettings.loreLanguageMode = mode
        publishLoreSettings()
    }

    func updateLoreIllustration(_ mode: LoreIllustrationMode) {
        if mode == .adult && appSettings.loreIllustrationMode != .adult {
            isAdultIllustrationConfirmationPresented = true
            return
        }
        appSettings.loreIllustrationMode = mode
        publishLoreSettings()
    }

    func confirmAdultIllustrations() {
        isAdultIllustrationConfirmationPresented = false
        appSettings.loreIllustrationMode = .adult
        publishLoreSettings()
    }

    func cancelAdultIllustrations() {
        isAdultIllustrationConfirmationPresented = false
    }

    func updateSpokenDialogue(_ enabled: Bool) {
        appSettings.spokenDialogueEnabled = enabled
        publishLoreSettings()
    }

    func updateAutoReadNewLorePages(_ enabled: Bool) {
        appSettings.autoReadNewLorePages = enabled
        publishLoreSettings()
    }

    func updateBookVolume(_ detent: Int) {
        appSettings.bookVolumeDetent = min(max(detent, 0), 10)
        publishLoreSettings()
        loreReader.previewVolume(detent: appSettings.bookVolumeDetent)
    }

    private func startGameplayIfNeeded() {
        guard !gameplayStarted, let gameSession else { return }
        gameplayStarted = true
        gameSession.onPresentation = { [weak self] presentation in
            self?.receive(presentation)
        }
        gameSession.onRunState = { [weak self] run in
            self?.receive(run)
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
        appSettings = settings
        state.manualVisibility = settings.manualVisibility
        state.animationMode = settings.animationMode
        state.inputMode = settings.inputMode
        hasResolvedSettings = true
        refreshLore()
        applyState()
    }

    private var currentSettings: AppSettings {
        appSettings
    }

    private func receive(_ presentation: GamePresentation) {
        game = presentation
        runPresentation = .active(presentation)
        scene?.render(presentation)
        refreshLore()
    }

    private func receive(_ run: RunPresentation) {
        runPresentation = run
        switch run {
        case .classSelection:
            scene?.render(run)
            onManagementWindowRequest?()
        case let .active(presentation):
            receive(presentation)
        }
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

    private func refreshLore() {
        guard let loreCatalog else {
            lorePages = []
            loreReader.update(settings: appSettings, pages: [])
            return
        }
        lorePages = LoreProgressResolver.resolve(
            catalog: loreCatalog,
            highestUnlockedLevel: game.state.campaign.highestUnlockedLevel,
            languageMode: appSettings.loreLanguageMode,
            illustrationMode: appSettings.loreIllustrationMode
        )
        loreReader.update(settings: appSettings, pages: lorePages)
    }

    private func publishLoreSettings() {
        refreshLore()
        settingsController?.update(appSettings)
    }

    private func recordAutoRead(_ pageID: LorePageID) {
        appSettings.lastAutoReadLorePageID = pageID.rawValue
        if pageID.rawValue == "prologue.level-100000" {
            appSettings.hasSeenCurrentRunPrologue = true
        }
        settingsController?.update(appSettings)
    }
}
