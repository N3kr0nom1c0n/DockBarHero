import AppKit
import SpriteKit
import XCTest
@testable import DockBarHero

@MainActor
final class PrototypeSceneHostTests: XCTestCase {
    func testRailUsesExplicitHeroEnemyAndTierLabels() throws {
        let host = try PrototypeSceneHost()
        var state = GameState.newGame(balance: .standard)
        state.party.heroes[0].level = 12
        state.campaign.highestUnlockedLevel = 25
        state.campaign.selectedLevel = 25
        state.encounter.enemyLevel = 25
        state.encounter.tier = .boss
        state.enemy = try XCTUnwrap(
            BalanceConfiguration.standard.enemy(
                level: 25,
                tier: .boss,
                progression: .standard
            )
        )

        host.render(.active(GameSimulation(state: state).presentation))

        XCTAssertEqual(
            (host.scene.childNode(withName: "//heroLevel") as? SKLabelNode)?.text,
            "Hero Lv. 12"
        )
        XCTAssertEqual(
            (host.scene.childNode(withName: "//enemyLevel") as? SKLabelNode)?.text,
            "Boss · Enemy Lv. 25"
        )
    }

    func testFarmingStatusShowsFrontierAndTracksModeTransitions() throws {
        let host = try PrototypeSceneHost(size: CGSize(width: 1_140, height: 96))
        var state = GameState.newGame(balance: .standard)
        state.campaign.highestUnlockedLevel = 192
        state.campaign.selectedLevel = 1
        state.campaign.mode = .farming

        host.render(.active(GameSimulation(state: state).presentation))

        let status = try XCTUnwrap(
            host.scene.childNode(withName: "//farmingStatus") as? SKLabelNode
        )
        XCTAssertEqual(status.text, "FARMING • FRONTIER 192")
        let statusColor = try XCTUnwrap(status.fontColor?.usingColorSpace(.deviceRGB))
        let expectedColor = try XCTUnwrap(NSColor.systemOrange.usingColorSpace(.deviceRGB))
        XCTAssertEqual(statusColor.redComponent, expectedColor.redComponent, accuracy: 0.001)
        XCTAssertEqual(statusColor.greenComponent, expectedColor.greenComponent, accuracy: 0.001)
        XCTAssertEqual(statusColor.blueComponent, expectedColor.blueComponent, accuracy: 0.001)
        XCTAssertEqual(statusColor.alphaComponent, expectedColor.alphaComponent, accuracy: 0.001)
        XCTAssertFalse(status.isHidden)
        XCTAssertFalse(status.isUserInteractionEnabled)
        XCTAssertEqual(status.position.x, host.scene.size.width * 0.78, accuracy: 0.001)
        XCTAssertEqual(status.position.y, 82, accuracy: 0.001)
        XCTAssertEqual(
            (host.scene.childNode(withName: "//enemyLevel") as? SKLabelNode)?.text,
            "Normal · Enemy Lv. 1"
        )

        let originalStatus = status
        state.campaign.selectedLevel = 192
        state.campaign.mode = .push
        state.encounter.enemyLevel = 192
        host.render(.active(GameSimulation(state: state).presentation))

        let pushedStatus = try XCTUnwrap(
            host.scene.childNode(withName: "//farmingStatus") as? SKLabelNode
        )
        XCTAssertTrue(pushedStatus === originalStatus)
        XCTAssertTrue(pushedStatus.isHidden)
        XCTAssertNil(pushedStatus.text)
    }

    func testRailLabelsUseBlackOutlineWithoutChangingForegroundColor() throws {
        let host = try PrototypeSceneHost(size: CGSize(width: 1_140, height: 96))
        var state = GameState.newGame(balance: .standard)
        state.campaign.mode = .farming

        host.render(.active(GameSimulation(state: state).presentation))

        let whiteLabelNames = ["heroLevel", "heroAction", "enemyLevel", "rollingDPS"]
        for name in whiteLabelNames {
            let label = try XCTUnwrap(
                host.scene.childNode(withName: "//\(name)") as? SKLabelNode
            )
            let text = try XCTUnwrap(label.attributedText)
            XCTAssertEqual(text.attribute(.strokeWidth, at: 0, effectiveRange: nil) as? Double, -8)
            try assertColor(text.attribute(.strokeColor, at: 0, effectiveRange: nil), equals: .black)
            try assertColor(text.attribute(.foregroundColor, at: 0, effectiveRange: nil), equals: .white)
        }

        let farmingStatus = try XCTUnwrap(
            host.scene.childNode(withName: "//farmingStatus") as? SKLabelNode
        )
        let farmingText = try XCTUnwrap(farmingStatus.attributedText)
        XCTAssertEqual(farmingText.attribute(.strokeWidth, at: 0, effectiveRange: nil) as? Double, -8)
        try assertColor(farmingText.attribute(.strokeColor, at: 0, effectiveRange: nil), equals: .black)
        try assertColor(
            farmingText.attribute(.foregroundColor, at: 0, effectiveRange: nil),
            equals: .systemOrange
        )
    }

    func testClassSelectionHidesCombatPresentation() throws {
        let host = try PrototypeSceneHost()

        host.render(.classSelection)

        XCTAssertTrue(host.scene.childNode(withName: "//hero")?.isHidden == true)
        XCTAssertTrue(host.scene.childNode(withName: "//enemy")?.isHidden == true)
        XCTAssertTrue(host.scene.childNode(withName: "//heroLevel")?.isHidden == true)
        XCTAssertTrue(host.scene.childNode(withName: "//rollingDPS")?.isHidden == true)
        XCTAssertTrue(host.scene.childNode(withName: "//farmingStatus")?.isHidden == true)
    }

    func testHostConfiguresTransparentThirtyFPSScene() throws {
        let host = try PrototypeSceneHost()

        XCTAssertEqual(host.view.preferredFramesPerSecond, 30)
        XCTAssertTrue(host.view.allowsTransparency)
        XCTAssertEqual(host.scene.backgroundColor.cgColor.alpha, 0)
        let hero = try XCTUnwrap(host.scene.childNode(withName: "hero") as? SKSpriteNode)
        let enemy = try XCTUnwrap(host.scene.childNode(withName: "enemy") as? SKSpriteNode)
        XCTAssertEqual(hero.texture?.filteringMode, .nearest)
        XCTAssertEqual(enemy.texture?.filteringMode, .nearest)
        XCTAssertEqual(hero.texture?.size(), CGSize(width: 96, height: 64))
        XCTAssertEqual(enemy.texture?.size(), CGSize(width: 96, height: 64))
        XCTAssertEqual(hero.size, CGSize(width: 54, height: 36))
        XCTAssertEqual(enemy.size, CGSize(width: 54, height: 36))
        XCTAssertEqual(hero.xScale, 1, accuracy: 0.001)
        XCTAssertEqual(enemy.xScale, -1, accuracy: 0.001)
        XCTAssertNotNil(host.scene.childNode(withName: "ground"))
    }

    func testActorsUseOneTexelExteriorOutlineWithoutChangingPresentation() throws {
        let host = try PrototypeSceneHost()
        let hero = try XCTUnwrap(host.scene.childNode(withName: "hero") as? SKSpriteNode)
        let enemy = try XCTUnwrap(host.scene.childNode(withName: "enemy") as? SKSpriteNode)

        for actor in [hero, enemy] {
            let shader = try XCTUnwrap(actor.shader)
            let step = try XCTUnwrap(shader.uniformNamed("u_outlineStep")).floatVector2Value
            XCTAssertEqual(step.x, 1.0 / 96.0, accuracy: 0.000_001)
            XCTAssertEqual(step.y, 1.0 / 64.0, accuracy: 0.000_001)
            XCTAssertEqual(actor.texture?.filteringMode, .nearest)
            XCTAssertEqual(actor.texture?.size(), CGSize(width: 96, height: 64))
            XCTAssertEqual(actor.size, CGSize(width: 54, height: 36))
            XCTAssertEqual(actor.alpha, 1, accuracy: 0.001)
            XCTAssertEqual(actor.colorBlendFactor, 0, accuracy: 0.001)
        }
        XCTAssertEqual(hero.xScale, 1, accuracy: 0.001)
        XCTAssertEqual(enemy.xScale, -1, accuracy: 0.001)
    }

    func testAnimationAndInteractionControls() throws {
        let host = try PrototypeSceneHost()

        host.setAnimating(false)
        host.setInteractive(true)

        XCTAssertTrue(host.scene.isPaused)
        XCTAssertTrue(host.scene.isUserInteractionEnabled)
    }

    func testRenderingUsesStableNamedNodesAndClampedSnapshotValues() throws {
        let host = try PrototypeSceneHost()
        let originalHero = try XCTUnwrap(host.scene.childNode(withName: "hero") as? SKSpriteNode)
        let originalEnemy = try XCTUnwrap(host.scene.childNode(withName: "enemy") as? SKSpriteNode)
        var state = GameState.newGame(balance: .standard)
        state.hero.currentHealth = 75
        state.enemy.currentHealth = 12
        state.encounter.enemyLevel = 7
        let presentation = GamePresentation(
            state: state,
            heroAttack: 10,
            heroDefense: 0,
            rollingDPS: 12.34,
            encounterDPS: 4.0
        )

        host.scene.render(presentation)

        XCTAssertTrue(host.scene.childNode(withName: "hero") === originalHero)
        XCTAssertTrue(host.scene.childNode(withName: "enemy") === originalEnemy)

        let enemyLevel = try XCTUnwrap(host.scene.childNode(withName: "//enemyLevel") as? SKLabelNode)
        let rollingDPS = try XCTUnwrap(host.scene.childNode(withName: "//rollingDPS") as? SKLabelNode)
        let heroHealthFill = try XCTUnwrap(host.scene.childNode(withName: "//heroHealthFill"))
        let enemyHealthFill = try XCTUnwrap(host.scene.childNode(withName: "//enemyHealthFill"))

        XCTAssertEqual(enemyLevel.text, "Normal · Enemy Lv. 7")
        XCTAssertEqual(rollingDPS.text, "12.3 DPS")
        XCTAssertEqual(heroHealthFill.xScale, 0.75, accuracy: 0.001)
        XCTAssertEqual(enemyHealthFill.xScale, 0.4, accuracy: 0.001)

        state.hero.currentHealth = 200
        state.enemy.currentHealth = -10
        host.scene.render(GamePresentation(
            state: state,
            heroAttack: 10,
            heroDefense: 0,
            rollingDPS: 0,
            encounterDPS: 0
        ))

        XCTAssertEqual(heroHealthFill.xScale, 1, accuracy: 0.001)
        XCTAssertEqual(enemyHealthFill.xScale, 0, accuracy: 0.001)
    }

    func testEventsDriveTransientActionsAndNoRepeatingMockAttack() throws {
        let host = try PrototypeSceneHost()
        let hero = try XCTUnwrap(host.scene.childNode(withName: "hero"))

        XCTAssertNil(hero.action(forKey: "attack"))

        host.scene.handle([.attack(attacker: .hero, defender: .enemy, damage: 10)])

        XCTAssertNotNil(host.scene.childNode(withName: "//hit"))
        XCTAssertNotNil(hero.action(forKey: "spriteAction"))
    }

    func testEventsRequestPresentationOnlySpriteActions() throws {
        let catalog = RecordingSpriteCatalog()
        let host = try PrototypeSceneHost(spriteCatalog: catalog)
        catalog.calls.removeAll()

        host.scene.handle([
            .attack(attacker: .enemy, defender: .hero, damage: 2),
            .victory(defeatedLevel: 1),
            .defeat(enemyLevel: 2),
        ])

        XCTAssertTrue(catalog.calls.contains(.init(token: .goblin, action: .attack)))
        XCTAssertTrue(catalog.calls.contains(.init(token: .dps, action: .hit)))
        XCTAssertTrue(catalog.calls.contains(.init(token: .goblin, action: .defeated)))
        XCTAssertTrue(catalog.calls.contains(.init(token: .dps, action: .defeated)))
    }

    func testVictoryKeepsEnemyDefeatSpriteWithoutProceduralFade() throws {
        let host = try PrototypeSceneHost()
        let enemy = try XCTUnwrap(host.scene.childNode(withName: "enemy"))

        host.scene.handle([.victory(defeatedLevel: 7)])

        XCTAssertNotNil(enemy.action(forKey: "spriteAction"))
        XCTAssertNil(enemy.action(forKey: "eventFade"))
        XCTAssertNil(enemy.action(forKey: "reviveVisibility"))
    }

    func testDefeatRetainsHeroDefeatPoseWithoutHidingActor() throws {
        let host = try PrototypeSceneHost()
        let hero = try XCTUnwrap(host.scene.childNode(withName: "hero"))

        host.scene.handle([.defeat(enemyLevel: 7)])

        XCTAssertNotNil(hero.action(forKey: "spriteAction"))
        XCTAssertNil(hero.action(forKey: "reviveVisibility"))
        XCTAssertNil(hero.action(forKey: "eventFade"))
        XCTAssertEqual(hero.alpha, 1, accuracy: 0.001)
    }

    func testRevivedReplacesDefeatFadeAndRestoresHeroOpacity() throws {
        let host = try PrototypeSceneHost()
        let hero = try XCTUnwrap(host.scene.childNode(withName: "hero"))
        host.scene.handle([.defeat(enemyLevel: 7)])
        hero.alpha = 0

        host.scene.handle([.revived(enemyLevel: 7)])

        XCTAssertNil(hero.action(forKey: "reviveVisibility"))
        XCTAssertNil(hero.action(forKey: "eventFade"))
        XCTAssertEqual(hero.alpha, 1, accuracy: 0.001)
    }

    func testVictoryRestoresEveryDefeatedPartySprite() throws {
        let host = try PrototypeSceneHost()
        var state = GameState.newGame(classID: .dps, balance: .standard, progression: .standard)
        let tank = GameState.newGame(classID: .tank, balance: .standard, progression: .standard).party.heroes[0]
        let healer = GameState.newGame(classID: .healer, balance: .standard, progression: .standard).party.heroes[0]
        state.party = PartyState(heroes: [state.party.heroes[0], tank, healer], unlocks: .complete)
        host.render(.active(GameSimulation(state: state).presentation))

        let first = try XCTUnwrap(host.scene.childNode(withName: "//hero"))
        let third = try XCTUnwrap(host.scene.childNode(withName: "//hero-2"))
        host.scene.handle([.heroDown(slot: 0), .heroDown(slot: 2)])
        first.alpha = 0
        third.alpha = 0

        host.scene.handle([.victory(defeatedLevel: 25)])

        XCTAssertNil(first.action(forKey: "reviveVisibility"))
        XCTAssertNil(third.action(forKey: "reviveVisibility"))
        XCTAssertEqual(first.alpha, 1, accuracy: 0.001)
        XCTAssertEqual(third.alpha, 1, accuracy: 0.001)
    }

    func testRailCreatesOrderedNodesAndHealthBarsForEveryPartySlot() throws {
        let host = try PrototypeSceneHost(size: CGSize(width: 1_140, height: 96))
        var state = GameState.newGame(classID: .tank, balance: .standard, progression: .standard)
        let dps = GameState.newGame(classID: .dps, balance: .standard, progression: .standard).party.heroes[0]
        let healer = GameState.newGame(classID: .healer, balance: .standard, progression: .standard).party.heroes[0]
        state.party = PartyState(heroes: [state.party.heroes[0], dps, healer], unlocks: .complete)

        host.render(.active(GameSimulation(state: state).presentation))

        let first = try XCTUnwrap(host.scene.childNode(withName: "//hero"))
        let second = try XCTUnwrap(host.scene.childNode(withName: "//hero-1"))
        let third = try XCTUnwrap(host.scene.childNode(withName: "//hero-2"))
        XCTAssertLessThan(first.position.x, second.position.x)
        XCTAssertLessThan(second.position.x, third.position.x)
        XCTAssertNotNil(host.scene.childNode(withName: "//hero-1HealthFill"))
        XCTAssertNotNil(host.scene.childNode(withName: "//hero-2Level"))
    }

    func testSlotAddressedEventsAnimateExactHero() throws {
        let host = try PrototypeSceneHost()
        var state = GameState.newGame(classID: .tank, balance: .standard, progression: .standard)
        let second = GameState.newGame(classID: .dps, balance: .standard, progression: .standard).party.heroes[0]
        state.party = PartyState(heroes: [state.party.heroes[0], second], unlocks: .secondUnlocked)
        host.render(.active(GameSimulation(state: state).presentation))
        let first = try XCTUnwrap(host.scene.childNode(withName: "//hero"))
        let secondNode = try XCTUnwrap(host.scene.childNode(withName: "//hero-1"))

        host.scene.handle([.heroAttack(slot: 1, damage: 12), .heroDown(slot: 1)])

        XCTAssertNil(first.action(forKey: "spriteAction"))
        XCTAssertNotNil(secondNode.action(forKey: "spriteAction"))
    }

    func testRailCreatesActionNodeForEveryHeroAndShowsCooldown() throws {
        let host = try PrototypeSceneHost()
        var state = GameState.newGame(classID: .dps, balance: .standard, progression: .standard)
        let healer = GameState.newGame(classID: .healer, balance: .standard, progression: .standard).party.heroes[0]
        state.party = PartyState(heroes: [state.party.heroes[0], healer], unlocks: .secondUnlocked)
        state.party.heroes[0].classAction.cooldownRemaining = try XCTUnwrap(.seconds(6))

        host.render(.active(GameSimulation(state: state).presentation))

        XCTAssertEqual(
            (host.scene.childNode(withName: "//heroAction") as? SKLabelNode)?.text,
            "PS 6.0"
        )
        XCTAssertEqual(
            (host.scene.childNode(withName: "//hero-1Action") as? SKLabelNode)?.text,
            "M READY"
        )
    }

    func testEveryPartySlotOwnsStableIdleLoopAndAttacksDoNotMoveActors() throws {
        let host = try PrototypeSceneHost()
        var state = GameState.newGame(classID: .tank, balance: .standard, progression: .standard)
        let dps = GameState.newGame(classID: .dps, balance: .standard, progression: .standard).party.heroes[0]
        let healer = GameState.newGame(classID: .healer, balance: .standard, progression: .standard).party.heroes[0]
        state.party = PartyState(heroes: [state.party.heroes[0], dps, healer], unlocks: .complete)
        host.render(.active(GameSimulation(state: state).presentation))
        let heroes = try (0..<3).map { slot in
            try XCTUnwrap(host.scene.childNode(withName: slot == 0 ? "//hero" : "//hero-\(slot)"))
        }
        let positions = heroes.map(\.position)

        XCTAssertTrue(heroes.allSatisfy { $0.action(forKey: "spriteLoop") != nil })
        XCTAssertTrue(heroes.allSatisfy { $0.action(forKey: "idle") == nil })
        host.scene.handle([.heroAttack(slot: 1, damage: 12)])

        XCTAssertEqual(heroes.map(\.position), positions)
        XCTAssertNil(heroes[1].action(forKey: "eventAttack"))
        XCTAssertNotNil(heroes[1].action(forKey: "spriteAction"))
    }

    func testClassActionCastAnimatesOnlyAddressedHero() throws {
        let catalog = RecordingSpriteCatalog()
        let host = try PrototypeSceneHost(spriteCatalog: catalog)
        var state = GameState.newGame(classID: .tank, balance: .standard, progression: .standard)
        let healer = GameState.newGame(classID: .healer, balance: .standard, progression: .standard).party.heroes[0]
        state.party = PartyState(heroes: [state.party.heroes[0], healer], unlocks: .secondUnlocked)
        host.render(.active(GameSimulation(state: state).presentation))
        catalog.calls.removeAll()

        host.scene.handle([.classActionCast(heroSlot: 1, actionID: .mend)])

        XCTAssertTrue(catalog.calls.contains(.init(token: .healer, action: .classAction)))
        XCTAssertFalse(catalog.calls.contains(.init(token: .tank, action: .classAction)))
    }

    func testRenderResolvesEnemyIdentityWithoutReplacingStableNode() throws {
        let catalog = RecordingSpriteCatalog()
        let host = try PrototypeSceneHost(spriteCatalog: catalog)
        let enemy = try XCTUnwrap(host.scene.childNode(withName: "enemy"))
        var state = GameState.newGame(balance: .standard)
        state.encounter.enemyLevel = 25
        state.encounter.tier = .boss
        catalog.calls.removeAll()

        host.render(.active(GameSimulation(state: state).presentation))

        XCTAssertTrue(host.scene.childNode(withName: "enemy") === enemy)
        XCTAssertTrue(catalog.calls.contains(.init(token: .ironrootWarchief, action: .idle)))
        catalog.calls.removeAll()
        host.render(.active(GameSimulation(state: state).presentation))
        XCTAssertFalse(catalog.calls.contains(.init(token: .ironrootWarchief, action: .idle)))
    }

    func testPassiveRailDoesNotEmitCastButInteractiveRailDoes() throws {
        let host = try PrototypeSceneHost()
        var casts: [(Int, ClassActionID)] = []
        host.onClassAction = { casts.append(($0, $1)) }
        host.render(.active(GameSimulation().presentation))

        host.setInteractive(false)
        host.scene.activateClassActionForTesting(slot: 0)
        XCTAssertTrue(casts.isEmpty)

        host.setInteractive(true)
        host.scene.activateClassActionForTesting(slot: 0)
        XCTAssertEqual(casts.map(\.0), [0])
        XCTAssertEqual(casts.map(\.1), [.powerStrike])
    }

    private func assertColor(
        _ value: Any?,
        equals expected: NSColor,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let actualRGB = try XCTUnwrap(
            (value as? NSColor)?.usingColorSpace(.deviceRGB),
            file: file,
            line: line
        )
        let expectedRGB = try XCTUnwrap(
            expected.usingColorSpace(.deviceRGB),
            file: file,
            line: line
        )
        XCTAssertEqual(actualRGB.redComponent, expectedRGB.redComponent, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actualRGB.greenComponent, expectedRGB.greenComponent, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actualRGB.blueComponent, expectedRGB.blueComponent, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actualRGB.alphaComponent, expectedRGB.alphaComponent, accuracy: 0.001, file: file, line: line)
    }
}

@MainActor
private final class RecordingSpriteCatalog: SpriteCatalog {
    struct Call: Equatable {
        let token: SpriteToken
        let action: SpriteAction
    }

    var calls: [Call] = []
    private let texture: SKTexture

    init() {
        let image = NSImage(size: CGSize(width: 1, height: 1))
        texture = SKTexture(image: image)
        texture.filteringMode = .nearest
    }

    func textures(for token: SpriteToken, action: SpriteAction) -> [SKTexture] {
        calls.append(Call(token: token, action: action))
        return [texture]
    }
}
