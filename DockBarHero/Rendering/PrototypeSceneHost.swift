import SpriteKit

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
}

extension SceneControlling {
    func render(_ run: RunPresentation) {
        if case let .active(presentation) = run {
            render(presentation)
        }
    }
}

@MainActor
final class PrototypeSceneHost: SceneControlling {
    let view: SKView
    let scene: PrototypeScene

    init(
        size: CGSize = CGSize(width: 1_140, height: 96),
        spriteCatalog: any SpriteCatalog = BuiltinSpriteCatalog()
    ) throws {
        view = SKView(frame: CGRect(origin: .zero, size: size))
        view.allowsTransparency = true
        view.preferredFramesPerSecond = 30
        scene = PrototypeScene(size: size, spriteCatalog: spriteCatalog)
        view.presentScene(scene)
        guard view.scene === scene else {
            throw PrototypeSceneHostError.scenePresentationFailed
        }
        AppLog.scene.info("Prototype scene created")
    }

    func setAnimating(_ isAnimating: Bool) {
        scene.isPaused = !isAnimating
        view.isPaused = !isAnimating
    }

    func setInteractive(_ isInteractive: Bool) {
        scene.isUserInteractionEnabled = isInteractive
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
}
