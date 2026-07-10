import AppKit
import SpriteKit

@MainActor
final class PrototypeScene: SKScene {
    override func didMove(to view: SKView) {
        guard childNode(withName: "ground") == nil else { return }
        backgroundColor = .clear
        scaleMode = .resizeFill
        isUserInteractionEnabled = false

        let ground = SKShapeNode(rectOf: CGSize(width: size.width, height: 2))
        ground.name = "ground"
        ground.fillColor = NSColor.white.withAlphaComponent(0.45)
        ground.strokeColor = .clear
        ground.position = CGPoint(x: size.width / 2, y: 12)
        addChild(ground)

        let hero = actor(name: "hero", color: .systemYellow, x: size.width * 0.22)
        let enemy = actor(name: "enemy", color: .systemRed, x: size.width * 0.78)
        addChild(hero)
        addChild(enemy)

        let idle = SKAction.repeatForever(.sequence([
            .moveBy(x: 0, y: 2, duration: 0.3),
            .moveBy(x: 0, y: -2, duration: 0.3)
        ]))
        hero.run(idle, withKey: "idle")
        enemy.run(idle.reversed(), withKey: "idle")

        let attack = SKAction.repeatForever(.sequence([
            .wait(forDuration: 1.4),
            .moveBy(x: 26, y: 0, duration: 0.12),
            .run { [weak self, weak enemy] in self?.showHit(at: enemy?.position) },
            .moveBy(x: -26, y: 0, duration: 0.12),
            .wait(forDuration: 0.8)
        ]))
        hero.run(attack, withKey: "attack")
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        childNode(withName: "ground")?.position = CGPoint(x: size.width / 2, y: 12)
        if let ground = childNode(withName: "ground") as? SKShapeNode {
            ground.path = CGPath(
                rect: CGRect(x: -size.width / 2, y: -1, width: size.width, height: 2),
                transform: nil
            )
        }
        childNode(withName: "hero")?.position.x = size.width * 0.22
        childNode(withName: "enemy")?.position.x = size.width * 0.78
    }

    override func mouseDown(with event: NSEvent) {
        guard isUserInteractionEnabled else { return }
        let point = event.location(in: self)
        guard let actor = nodes(at: point).first(where: { $0.name == "hero" || $0.name == "enemy" }) else {
            return
        }
        actor.run(.sequence([
            .scale(to: 1.25, duration: 0.08),
            .scale(to: 1.0, duration: 0.08)
        ]))
    }

    private func actor(name: String, color: NSColor, x: CGFloat) -> SKShapeNode {
        let node = SKShapeNode(rectOf: CGSize(width: 24, height: 36), cornerRadius: 2)
        node.name = name
        node.fillColor = color
        node.strokeColor = NSColor.black.withAlphaComponent(0.35)
        node.position = CGPoint(x: x, y: 32)
        return node
    }

    private func showHit(at point: CGPoint?) {
        guard let point else { return }
        let hit = SKLabelNode(text: "*")
        hit.fontName = "Menlo-Bold"
        hit.fontSize = 20
        hit.fontColor = .white
        hit.position = CGPoint(x: point.x, y: point.y + 24)
        addChild(hit)
        hit.run(.sequence([
            .group([.moveBy(x: 0, y: 14, duration: 0.25), .fadeOut(withDuration: 0.25)]),
            .removeFromParent()
        ]))
    }
}
