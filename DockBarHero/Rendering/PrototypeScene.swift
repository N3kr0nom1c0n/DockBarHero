import AppKit
import SpriteKit

@MainActor
final class PrototypeScene: SKScene {
    private let actorSize = CGSize(width: 24, height: 36)
    private let healthBarSize = CGSize(width: 150, height: 5)
    private let spriteCatalog: any SpriteCatalog

    init(size: CGSize, spriteCatalog: any SpriteCatalog) {
        self.spriteCatalog = spriteCatalog
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

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

        let hero = actor(name: "hero", token: .hero, x: size.width * 0.22)
        let enemy = actor(name: "enemy", token: .enemy, x: size.width * 0.78)
        addChild(hero)
        addChild(enemy)

        addHealthBar(prefix: "hero", color: .systemGreen)
        addHealthBar(prefix: "enemy", color: .systemRed)

        let heroLevel = label(name: "heroLevel", fontSize: 12)
        let enemyLevel = label(name: "enemyLevel", fontSize: 12)
        let rollingDPS = label(name: "rollingDPS", fontSize: 12)
        addChild(heroLevel)
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
        setCombatHidden(false)
        let hero = presentation.state.hero
        let enemy = presentation.state.enemy
        setHealthFraction(for: "heroHealthFill", current: hero.currentHealth, maximum: hero.maxHealth)
        setHealthFraction(for: "enemyHealthFill", current: enemy.currentHealth, maximum: enemy.maxHealth)
        (childNode(withName: "heroLevel") as? SKLabelNode)?.text = ManagementFormat.heroLevel(
            presentation.state.party.heroes[0].level
        )
        let tier = presentation.state.encounter.tier.rawValue.capitalized
        (childNode(withName: "enemyLevel") as? SKLabelNode)?.text = "\(tier) · \(ManagementFormat.enemyLevel(presentation.state.encounter.enemyLevel))"
        (childNode(withName: "rollingDPS") as? SKLabelNode)?.text = String(
            format: "%.1f DPS",
            locale: Locale(identifier: "en_US_POSIX"),
            presentation.rollingDPS
        )
    }

    func render(_ run: RunPresentation) {
        switch run {
        case .classSelection:
            setCombatHidden(true)
        case .partySelection:
            setCombatHidden(true)
        case let .active(presentation):
            render(presentation)
        }
    }

    func handle(_ events: [GameEvent]) {
        for event in events {
            switch event {
            case let .attack(attacker, defender, _):
                animateAttack(from: attacker)
                playSpriteAction(attacker == .hero ? .hero : .enemy, action: .attack)
                playSpriteAction(defender == .hero ? .hero : .enemy, action: .hit)
                showHit(at: position(of: defender))
            case .victory:
                playSpriteAction(.enemy, action: .defeated)
                animateBriefFade(nodeNamed: "enemy")
            case .defeat:
                playSpriteAction(.hero, action: .defeated)
                animateDefeat()
            case .revived:
                setIdleTexture(for: .hero)
                restoreHeroAfterRevive()
            case .loot, .xpGained, .heroLeveled, .goldGained, .equipped,
                 .autoEquipChanged, .destinationQueued, .farmingStarted, .returnedToFrontier,
                 .partyUnlockPending:
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
        (childNode(withName: "heroLevel") as? SKLabelNode)?.position = CGPoint(x: heroX, y: 70)
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

    private func actor(name: String, token: SpriteToken, x: CGFloat) -> SKSpriteNode {
        let node = SKSpriteNode(
            texture: spriteCatalog.textures(for: token, action: .idle).first,
            size: actorSize
        )
        node.name = name
        node.position = CGPoint(x: x, y: 32)
        return node
    }

    private func playSpriteAction(_ token: SpriteToken, action: SpriteAction) {
        let name = token == .hero ? "hero" : "enemy"
        guard let node = childNode(withName: name) as? SKSpriteNode else { return }
        let textures = spriteCatalog.textures(for: token, action: action)
        guard !textures.isEmpty else { return }
        node.removeAction(forKey: "spriteAction")
        node.run(.sequence([
            .animate(with: textures, timePerFrame: 0.08, resize: false, restore: false),
            .run { [weak self, weak node] in
                node?.texture = self?.spriteCatalog.textures(for: token, action: .idle).first
            },
        ]), withKey: "spriteAction")
    }

    private func setIdleTexture(for token: SpriteToken) {
        let name = token == .hero ? "hero" : "enemy"
        guard let node = childNode(withName: name) as? SKSpriteNode else { return }
        node.removeAction(forKey: "spriteAction")
        node.texture = spriteCatalog.textures(for: token, action: .idle).first
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

    private func setCombatHidden(_ isHidden: Bool) {
        [
            "hero", "enemy", "heroHealthBackground", "heroHealthFill",
            "enemyHealthBackground", "enemyHealthFill", "heroLevel",
            "enemyLevel", "rollingDPS"
        ].forEach { childNode(withName: $0)?.isHidden = isHidden }
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
