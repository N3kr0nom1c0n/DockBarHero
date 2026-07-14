import AppKit
import SpriteKit

@MainActor
private final class RailTrackingView: SKView {
    var onPointerLocation: ((CGPoint?) -> Void)?
    private var railTrackingArea: NSTrackingArea?
    private var trackingEnabled = false

    func setTrackingEnabled(_ isEnabled: Bool) {
        trackingEnabled = isEnabled
        if !isEnabled {
            onPointerLocation?(nil)
        }
        updateTrackingAreas()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let railTrackingArea {
            removeTrackingArea(railTrackingArea)
            self.railTrackingArea = nil
        }
        guard trackingEnabled else { return }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        railTrackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        guard trackingEnabled else { return }
        onPointerLocation?(convert(event.locationInWindow, from: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        mouseMoved(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        guard trackingEnabled else { return }
        onPointerLocation?(nil)
    }
}

enum PrototypeSceneHostError: Error {
    case scenePresentationFailed
}

@MainActor
protocol SceneControlling: AnyObject {
    var view: SKView { get }
    func setAnimating(_ isAnimating: Bool)
    func setInteractive(_ isInteractive: Bool)
    func render(_ presentation: GamePresentation)
    func render(_ run: RunPresentation)
    func handle(_ events: [GameEvent])
    func setClassActionHandler(_ handler: @escaping (Int, ClassActionID) -> Void)
}

extension SceneControlling {
    func render(_ run: RunPresentation) {
        if case let .active(presentation) = run {
            render(presentation)
        }
    }

    func setClassActionHandler(_ handler: @escaping (Int, ClassActionID) -> Void) { }
}

@MainActor
final class PrototypeSceneHost: SceneControlling {
    let view: SKView
    let scene: PrototypeScene
    var onClassAction: ((Int, ClassActionID) -> Void)? {
        didSet { scene.onClassAction = onClassAction }
    }

    init(
        size: CGSize = CGSize(width: 1_140, height: 96),
        spriteCatalog: any SpriteCatalog = BuiltinSpriteCatalog()
    ) throws {
        let trackingView = RailTrackingView(frame: CGRect(origin: .zero, size: size))
        view = trackingView
        view.allowsTransparency = true
        view.preferredFramesPerSecond = 30
        scene = PrototypeScene(size: size, spriteCatalog: spriteCatalog)
        trackingView.onPointerLocation = { [weak scene] viewPoint in
            guard let scene else { return }
            scene.setPointerLocation(viewPoint.map { scene.convertPoint(fromView: $0) })
        }
        view.presentScene(scene)
        guard view.scene === scene else {
            throw PrototypeSceneHostError.scenePresentationFailed
        }
        AppLog.scene.info("Prototype scene created")
    }

    func setAnimating(_ isAnimating: Bool) {
        scene.setAnimationsEnabled(isAnimating)
        scene.isPaused = !isAnimating
        view.isPaused = !isAnimating
    }

    func setInteractive(_ isInteractive: Bool) {
        scene.setInteractive(isInteractive)
        (view as? RailTrackingView)?.setTrackingEnabled(isInteractive)
    }

    func render(_ presentation: GamePresentation) {
        scene.render(presentation)
    }

    func render(_ run: RunPresentation) {
        scene.render(run)
    }

    func handle(_ events: [GameEvent]) {
        scene.handle(events)
    }

    func setClassActionHandler(_ handler: @escaping (Int, ClassActionID) -> Void) {
        onClassAction = handler
    }
}
