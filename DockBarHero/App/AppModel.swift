import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var state = OverlayState()

    private var window: OverlayWindowControlling?
    private var scene: SceneControlling?
    private var screen: ScreenProviding?
    private var monitor: EnvironmentMonitoring?
    private var placement = PlacementResolver()
    private var hasCurrentPlacement = false
    private var hasResolvedEnvironment = false
    private var started = false

    init(
        window: OverlayWindowControlling? = nil,
        scene: SceneControlling? = nil,
        screen: ScreenProviding? = nil,
        monitor: EnvironmentMonitoring? = nil
    ) {
        self.window = window
        self.scene = scene
        self.screen = screen
        self.monitor = monitor
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
        precondition(!started, "Dependencies must be connected before start")
        self.window = window
        self.scene = scene
        self.screen = screen
        self.monitor = monitor
    }

    func start() {
        guard !started else { return }
        guard window != nil,
              scene != nil,
              screen != nil,
              monitor != nil else {
            AppLog.lifecycle.error("Application coordination requires connected dependencies")
            return
        }
        started = true
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

    func send(_ action: OverlayAction) {
        state.apply(action)
        applyState()
        AppLog.overlay.debug("Overlay state updated")
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
        let isAvailable = hasResolvedEnvironment && hasCurrentPlacement
        window?.setVisible(state.isEffectivelyVisible && isAvailable)
        window?.setInputEnabled(state.acceptsInput && isAvailable)
        scene?.setAnimating(state.shouldAnimate && isAvailable)
        scene?.setInteractive(state.acceptsInput && isAvailable)
    }
}
