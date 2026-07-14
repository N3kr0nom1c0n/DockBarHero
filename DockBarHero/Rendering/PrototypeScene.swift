import AppKit
import SpriteKit

@MainActor
final class PrototypeScene: SKScene {
    private let actorSize = CGSize(width: 54, height: 36)
    private let healthBarSize = CGSize(width: 150, height: 5)
    private let spriteCatalog: any SpriteCatalog
    private var renderedHeroClasses: [HeroClassID] = [.dps]
    private var renderedActions: [ClassActionID] = [.powerStrike]
    private var renderedEnemyToken: SpriteToken = .goblin
    var onClassAction: ((Int, ClassActionID) -> Void)?

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

        let hero = actor(name: "hero", token: .dps, x: size.width * 0.22)
        let enemy = actor(name: "enemy", token: .goblin, x: size.width * 0.78)
        enemy.xScale = -1
        addChild(hero)
        addChild(enemy)
        startSpriteLoop(on: hero, token: .dps)
        startSpriteLoop(on: enemy, token: .goblin)

        addHealthBar(prefix: "hero", color: .systemGreen)
        addHealthBar(prefix: "enemy", color: .systemRed)

        let heroLevel = label(name: "heroLevel", fontSize: 12)
        let heroAction = label(name: "heroAction", fontSize: 10)
        let enemyLevel = label(name: "enemyLevel", fontSize: 12)
        let farmingStatus = label(name: "farmingStatus", fontSize: 10)
        farmingStatus.fontColor = .systemOrange
        farmingStatus.isUserInteractionEnabled = false
        let rollingDPS = label(name: "rollingDPS", fontSize: 12)
        addChild(heroLevel)
        addChild(heroAction)
        addChild(enemyLevel)
        addChild(farmingStatus)
        addChild(rollingDPS)
        updateLayout()

        render(GameSimulation().presentation)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        updateLayout()
    }

    func render(_ presentation: GamePresentation) {
        setCombatHidden(false)
        syncHeroNodes(with: presentation.state.party.heroes)
        syncEnemyIdentity(
            level: presentation.state.encounter.enemyLevel,
            tier: presentation.state.encounter.tier
        )
        let enemy = presentation.state.enemy
        for slot in presentation.state.party.heroes.indices {
            let hero = presentation.state.party.heroes[slot]
            let prefix = heroPrefix(slot)
            setHealthFraction(
                for: "\(prefix)HealthFill",
                current: hero.combat.currentHealth,
                maximum: hero.combat.maxHealth
            )
            if let level = childNode(withName: "\(prefix)Level") as? SKLabelNode {
                setOutlinedText(ManagementFormat.heroLevel(hero.level), on: level)
            }
            if let action = childNode(withName: "\(prefix)Action") as? SKLabelNode {
                let remaining = hero.classAction.cooldownRemaining.timeInterval
                let text = remaining > 0
                    ? "\(actionAbbreviation(hero.classAction.actionID)) \(String(format: "%.1f", remaining))"
                    : "\(actionAbbreviation(hero.classAction.actionID)) READY"
                setOutlinedText(text, on: action)
                action.alpha = hero.combat.currentHealth > 0 && remaining == 0 ? 1 : 0.55
            }
        }
        setHealthFraction(for: "enemyHealthFill", current: enemy.currentHealth, maximum: enemy.maxHealth)
        let tier = presentation.state.encounter.tier.rawValue.capitalized
        if let enemyLevel = childNode(withName: "enemyLevel") as? SKLabelNode {
            setOutlinedText(
                "\(tier) · \(ManagementFormat.enemyLevel(presentation.state.encounter.enemyLevel))",
                on: enemyLevel
            )
        }
        if let farmingStatus = childNode(withName: "farmingStatus") as? SKLabelNode {
            switch presentation.state.campaign.mode {
            case .farming:
                setOutlinedText(
                    "FARMING • FRONTIER \(presentation.state.campaign.highestUnlockedLevel)",
                    on: farmingStatus
                )
                farmingStatus.isHidden = false
            case .push:
                setOutlinedText(nil, on: farmingStatus)
                farmingStatus.isHidden = true
            }
        }
        if let rollingDPS = childNode(withName: "rollingDPS") as? SKLabelNode {
            setOutlinedText(
                String(
                    format: "%.1f DPS",
                    locale: Locale(identifier: "en_US_POSIX"),
                    presentation.rollingDPS
                ),
                on: rollingDPS
            )
        }
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
                if attacker == .hero {
                    playHeroSpriteAction(slot: 0, action: .attack)
                } else {
                    playEnemySpriteAction(.attack)
                }
                if defender == .hero {
                    playHeroSpriteAction(slot: 0, action: .hit)
                } else {
                    playEnemySpriteAction(.hit)
                }
                showHit(at: position(of: defender))
            case let .heroAttack(slot, _):
                playHeroSpriteAction(slot: slot, action: .attack)
                playEnemySpriteAction(.hit)
                showHit(at: childNode(withName: "enemy")?.position)
            case let .enemyAttack(targetSlot, _):
                playEnemySpriteAction(.attack)
                playHeroSpriteAction(slot: targetSlot, action: .hit)
                showHit(at: childNode(withName: heroPrefix(targetSlot))?.position)
            case let .heroDown(slot):
                playHeroSpriteAction(slot: slot, action: .defeated, returnsToIdle: false)
            case .victory:
                playEnemySpriteAction(.defeated, returnsToIdle: false)
                for slot in renderedHeroClasses.indices {
                    restoreHeroToIdle(slot: slot)
                }
            case .defeat:
                playHeroSpriteAction(slot: 0, action: .defeated, returnsToIdle: false)
            case .revived:
                for slot in renderedHeroClasses.indices {
                    restoreHeroToIdle(slot: slot)
                }
            case let .classActionCast(heroSlot, _):
                playHeroSpriteAction(slot: heroSlot, action: .classAction)
            case .loot, .xpGained, .heroLeveled, .goldGained, .equipped, .equippedHero,
                 .autoEquipChanged, .destinationQueued, .farmingStarted, .returnedToFrontier,
                 .partyUnlockPending, .classActionReady, .guardActivated,
                 .guardIntercepted, .powerStrike, .mended, .classActionRejected:
                break
            case .itemLockChanged:
                break
            case .inventoryCapacityPurchased, .overflowMoved, .itemsSalvaged:
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
        for slot in renderedHeroClasses.indices {
            let x = renderedHeroClasses.count == 1
                ? heroX
                : size.width * (0.12 + 0.12 * CGFloat(slot))
            let prefix = heroPrefix(slot)
            childNode(withName: prefix)?.position = CGPoint(x: x, y: 32)
            positionHealthBar(prefix: prefix, x: x, y: 59)
            (childNode(withName: "\(prefix)Level") as? SKLabelNode)?.position = CGPoint(x: x, y: 70)
            (childNode(withName: "\(prefix)Action") as? SKLabelNode)?.position = CGPoint(x: x, y: 82)
        }
        childNode(withName: "enemy")?.position = CGPoint(x: enemyX, y: 32)
        positionHealthBar(prefix: "enemy", x: enemyX, y: 59)
        (childNode(withName: "enemyLevel") as? SKLabelNode)?.position = CGPoint(x: enemyX, y: 70)
        (childNode(withName: "farmingStatus") as? SKLabelNode)?.position = CGPoint(x: enemyX, y: 82)
        (childNode(withName: "rollingDPS") as? SKLabelNode)?.position = CGPoint(x: size.width / 2, y: 70)
    }

    override func mouseDown(with event: NSEvent) {
        guard isUserInteractionEnabled else { return }
        let point = event.location(in: self)
        if let slot = renderedActions.indices.first(where: { slot in
            nodes(at: point).contains(where: { $0.name == "\(heroPrefix(slot))Action" })
        }) {
            activateClassActionForTesting(slot: slot)
            return
        }
        guard let actor = nodes(at: point).first(where: {
            $0.name == "enemy" || $0.name?.hasPrefix("hero") == true
        }) else {
            return
        }
        actor.run(.sequence([
            .scale(to: 1.25, duration: 0.08),
            .scale(to: 1.0, duration: 0.08)
        ]))
    }

    private func actor(name: String, token: SpriteToken, x: CGFloat) -> SKSpriteNode {
        let node = SKSpriteNode(
            texture: spriteCatalog.clip(for: token, action: .idle).textures.first,
            size: actorSize
        )
        node.name = name
        node.position = CGPoint(x: x, y: 32)
        return node
    }

    private func startSpriteLoop(on node: SKSpriteNode, token: SpriteToken) {
        let clip = spriteCatalog.clip(for: token, action: .idle)
        guard let first = clip.textures.first else { return }
        node.removeAction(forKey: "spriteAction")
        node.removeAction(forKey: "spriteLoop")
        node.texture = first
        node.alpha = 1
        let metadata = node.userData ?? NSMutableDictionary()
        metadata["spriteToken"] = token.rawValue
        node.userData = metadata
        node.run(
            .repeatForever(.animate(
                with: clip.textures,
                timePerFrame: clip.secondsPerFrame,
                resize: false,
                restore: false
            )),
            withKey: "spriteLoop"
        )
    }

    private func playHeroSpriteAction(
        slot: Int,
        action: SpriteAction,
        returnsToIdle: Bool = true
    ) {
        guard renderedHeroClasses.indices.contains(slot),
              let node = childNode(withName: heroPrefix(slot)) as? SKSpriteNode else { return }
        let token = spriteToken(for: renderedHeroClasses[slot])
        playSpriteAction(on: node, token: token, action: action, returnsToIdle: returnsToIdle)
    }

    private func playEnemySpriteAction(
        _ action: SpriteAction,
        returnsToIdle: Bool = true
    ) {
        guard let node = childNode(withName: "enemy") as? SKSpriteNode else { return }
        playSpriteAction(
            on: node,
            token: renderedEnemyToken,
            action: action,
            returnsToIdle: returnsToIdle
        )
    }

    private func playSpriteAction(
        on node: SKSpriteNode,
        token: SpriteToken,
        action: SpriteAction,
        returnsToIdle: Bool
    ) {
        let clip = spriteCatalog.clip(for: token, action: action)
        guard let first = clip.textures.first else { return }
        node.removeAction(forKey: "spriteLoop")
        node.removeAction(forKey: "spriteAction")
        node.texture = first
        let completion: SKAction = returnsToIdle
            ? .run { [weak self, weak node] in
                guard let self, let node else { return }
                self.startSpriteLoop(on: node, token: token)
            }
            : .run { [weak node] in node?.texture = clip.textures.last }
        node.run(.sequence([
            .animate(
                with: clip.textures,
                timePerFrame: clip.secondsPerFrame,
                resize: false,
                restore: false
            ),
            completion,
        ]), withKey: "spriteAction")
    }

    private func restoreHeroToIdle(slot: Int) {
        guard renderedHeroClasses.indices.contains(slot),
              let node = childNode(withName: heroPrefix(slot)) as? SKSpriteNode else { return }
        node.removeAction(forKey: "reviveVisibility")
        node.removeAction(forKey: "eventFade")
        startSpriteLoop(on: node, token: spriteToken(for: renderedHeroClasses[slot]))
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

    private func setOutlinedText(_ text: String?, on label: SKLabelNode) {
        label.text = text
        guard let text else {
            label.attributedText = nil
            return
        }
        let font = NSFont(name: label.fontName ?? "", size: label.fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: label.fontSize, weight: .regular)
        label.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: label.fontColor ?? .white,
                .strokeColor: NSColor.black,
                .strokeWidth: -8,
            ]
        )
    }

    private func setCombatHidden(_ isHidden: Bool) {
        var names = [
            "enemy", "enemyHealthBackground", "enemyHealthFill", "enemyLevel",
            "farmingStatus", "rollingDPS"
        ]
        for slot in renderedHeroClasses.indices {
            let prefix = heroPrefix(slot)
            names += [prefix, "\(prefix)HealthBackground", "\(prefix)HealthFill", "\(prefix)Level", "\(prefix)Action"]
        }
        names.forEach { childNode(withName: $0)?.isHidden = isHidden }
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

    private func syncHeroNodes(with heroes: [HeroState]) {
        guard !heroes.isEmpty else { return }
        let oldCount = renderedHeroClasses.count
        renderedHeroClasses = heroes.map(\.classID)
        renderedActions = heroes.map { $0.classAction.actionID }
        if heroes.count > oldCount {
            for slot in oldCount..<heroes.count {
                let prefix = heroPrefix(slot)
                addChild(actor(name: prefix, token: spriteToken(for: heroes[slot].classID), x: 0))
                addHealthBar(prefix: prefix, color: .systemGreen)
                addChild(label(name: "\(prefix)Level", fontSize: 12))
                addChild(label(name: "\(prefix)Action", fontSize: 10))
            }
        } else if heroes.count < oldCount {
            for slot in heroes.count..<oldCount {
                let prefix = heroPrefix(slot)
                [prefix, "\(prefix)HealthBackground", "\(prefix)HealthFill", "\(prefix)Level", "\(prefix)Action"]
                    .forEach { childNode(withName: $0)?.removeFromParent() }
            }
        }
        for slot in heroes.indices {
            guard let node = childNode(withName: heroPrefix(slot)) as? SKSpriteNode else { continue }
            let token = spriteToken(for: heroes[slot].classID)
            if node.userData?["spriteToken"] as? String != token.rawValue {
                startSpriteLoop(on: node, token: token)
            }
        }
        updateLayout()
    }

    private func syncEnemyIdentity(level: Int, tier: EnemyTierID) {
        let token = EnemySpriteResolver.token(level: level, tier: tier)
        guard let node = childNode(withName: "enemy") as? SKSpriteNode else { return }
        renderedEnemyToken = token
        if node.userData?["spriteToken"] as? String != token.rawValue {
            startSpriteLoop(on: node, token: token)
        }
    }

    private func heroPrefix(_ slot: Int) -> String {
        slot == 0 ? "hero" : "hero-\(slot)"
    }

    private func spriteToken(for classID: HeroClassID) -> SpriteToken {
        switch classID {
        case .tank: .tank
        case .dps: .dps
        case .healer: .healer
        }
    }

    func activateClassActionForTesting(slot: Int) {
        guard isUserInteractionEnabled, renderedActions.indices.contains(slot) else { return }
        onClassAction?(slot, renderedActions[slot])
    }

    private func actionAbbreviation(_ actionID: ClassActionID) -> String {
        switch actionID {
        case .guardAction: "G"
        case .powerStrike: "PS"
        case .mend: "M"
        }
    }

    private func showHit(at point: CGPoint?) {
        guard let point else { return }
        let hit = SKLabelNode(text: nil)
        hit.name = "hit"
        hit.fontName = "Menlo-Bold"
        hit.fontSize = 20
        hit.fontColor = .white
        setOutlinedText("*", on: hit)
        hit.position = CGPoint(x: point.x, y: point.y + 24)
        addChild(hit)
        hit.run(.sequence([
            .group([.moveBy(x: 0, y: 14, duration: 0.25), .fadeOut(withDuration: 0.25)]),
            .removeFromParent()
        ]))
    }
}
