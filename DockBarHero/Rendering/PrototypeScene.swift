import AppKit
import SpriteKit

@MainActor
final class PrototypeScene: SKScene {
    private let actorSize = CGSize(width: 24, height: 36)
    private let healthBarSize = CGSize(width: 150, height: 5)

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

        addHealthBar(prefix: "hero", color: .systemGreen)
        addHealthBar(prefix: "enemy", color: .systemRed)

        let enemyLevel = label(name: "enemyLevel", fontSize: 12)
        let rollingDPS = label(name: "rollingDPS", fontSize: 12)
        addChild(enemyLevel)
        addChild(rollingDPS)
        updateLayout()

        let idle = SKAction.repeatForever(.sequence([
            .moveBy(x: 0, y: 2, duration: 0.3),
            .moveBy(x: 0, y: -2, duration: 0.3)
        ]))
        hero.run(idle, withKey: "idle")
        enemy.run(idle.reversed(), withKey: "idle")

        render(GameSimulation().presentation)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        updateLayout()
    }

    func render(_ presentation: GamePresentation) {
        let hero = presentation.state.hero
        let enemy = presentation.state.enemy
        setHealthFraction(for: "heroHealthFill", current: hero.currentHealth, maximum: hero.maxHealth)
        setHealthFraction(for: "enemyHealthFill", current: enemy.currentHealth, maximum: enemy.maxHealth)
        (childNode(withName: "enemyLevel") as? SKLabelNode)?.text = "Lv. \(presentation.state.encounter.enemyLevel)"
        (childNode(withName: "rollingDPS") as? SKLabelNode)?.text = String(
            format: "%.1f DPS",
            locale: Locale(identifier: "en_US_POSIX"),
            presentation.rollingDPS
        )
    }

    func handle(_ events: [GameEvent]) {
        for event in events {
            switch event {
            case let .attack(attacker, defender, _):
                animateAttack(from: attacker)
                showHit(at: position(of: defender))
            case .victory:
                animateBriefFade(nodeNamed: "enemy")
            case .defeat:
                animateDefeat()
            case .revived:
                restoreHeroAfterRevive()
            case .loot, .equipped, .autoEquipChanged:
                break
            }
        }
    }

    private func updateLayout() {
        childNode(withName: "ground")?.position = CGPoint(x: size.width / 2, y: 12)
        if let ground = childNode(withName: "ground") as? SKShapeNode {
            ground.path = CGPath(
                rect: CGRect(x: -size.width / 2, y: -1, width: size.width, height: 2),
                transform: nil
            )
        }
        let heroX = size.width * 0.22
        let enemyX = size.width * 0.78
        childNode(withName: "hero")?.position = CGPoint(x: heroX, y: 32)
        childNode(withName: "enemy")?.position = CGPoint(x: enemyX, y: 32)
        positionHealthBar(prefix: "hero", x: heroX, y: 59)
        positionHealthBar(prefix: "enemy", x: enemyX, y: 59)
        (childNode(withName: "enemyLevel") as? SKLabelNode)?.position = CGPoint(x: enemyX, y: 70)
        (childNode(withName: "rollingDPS") as? SKLabelNode)?.position = CGPoint(x: size.width / 2, y: 70)
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
        let node = SKShapeNode(rectOf: actorSize, cornerRadius: 2)
        node.name = name
        node.fillColor = color
        node.strokeColor = NSColor.black.withAlphaComponent(0.35)
        node.position = CGPoint(x: x, y: 32)
        return node
    }

    private func addHealthBar(prefix: String, color: NSColor) {
        let background = SKShapeNode(rect: CGRect(origin: .zero, size: healthBarSize), cornerRadius: 1)
        background.name = "\(prefix)HealthBackground"
        background.fillColor = NSColor.black.withAlphaComponent(0.5)
        background.strokeColor = .clear
        addChild(background)

        let fill = SKShapeNode(rect: CGRect(origin: .zero, size: healthBarSize), cornerRadius: 1)
        fill.name = "\(prefix)HealthFill"
        fill.fillColor = color
        fill.strokeColor = .clear
        addChild(fill)
    }

    private func positionHealthBar(prefix: String, x: CGFloat, y: CGFloat) {
        let origin = CGPoint(x: x - healthBarSize.width / 2, y: y)
        childNode(withName: "\(prefix)HealthBackground")?.position = origin
        childNode(withName: "\(prefix)HealthFill")?.position = origin
    }

    private func label(name: String, fontSize: CGFloat) -> SKLabelNode {
        let node = SKLabelNode(text: nil)
        node.name = name
        node.fontName = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular).fontName
        node.fontSize = fontSize
        node.fontColor = .white
        node.horizontalAlignmentMode = .center
        return node
    }

    private func setHealthFraction(for name: String, current: Int, maximum: Int) {
        let fraction: CGFloat
        if maximum > 0 {
            fraction = CGFloat(max(0, min(current, maximum))) / CGFloat(maximum)
        } else {
            fraction = 0
        }
        childNode(withName: name)?.xScale = fraction
    }

    private func position(of combatant: CombatantID) -> CGPoint? {
        childNode(withName: combatant == .hero ? "hero" : "enemy")?.position
    }

    private func animateAttack(from attacker: CombatantID) {
        let name = attacker == .hero ? "hero" : "enemy"
        guard let node = childNode(withName: name) else { return }
        let direction: CGFloat = attacker == .hero ? 1 : -1
        node.removeAction(forKey: "eventAttack")
        node.run(.sequence([
            .moveBy(x: direction * 18, y: 0, duration: 0.08),
            .moveBy(x: direction * -18, y: 0, duration: 0.12)
        ]), withKey: "eventAttack")
    }

    private func animateBriefFade(nodeNamed name: String) {
        guard let node = childNode(withName: name) else { return }
        node.removeAction(forKey: "eventFade")
        node.run(.sequence([
            .fadeOut(withDuration: 0.08),
            .fadeIn(withDuration: 0.18)
        ]), withKey: "eventFade")
    }

    private func animateDefeat() {
        guard let hero = childNode(withName: "hero") else { return }
        hero.removeAction(forKey: "eventFade")
        hero.removeAction(forKey: "reviveVisibility")
        hero.run(.fadeOut(withDuration: 0.08), withKey: "reviveVisibility")
    }

    private func restoreHeroAfterRevive() {
        guard let hero = childNode(withName: "hero") else { return }
        hero.removeAction(forKey: "reviveVisibility")
        hero.removeAction(forKey: "eventFade")
        hero.alpha = 1
    }

    private func showHit(at point: CGPoint?) {
        guard let point else { return }
        let hit = SKLabelNode(text: "*")
        hit.name = "hit"
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
