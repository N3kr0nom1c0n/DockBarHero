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
        XCTAssertNotNil(host.scene.childNode(withName: "ground"))
    }

    func testAnimationAndInteractionControls() throws {
        let host = try PrototypeSceneHost()

        host.setAnimating(false)
        host.setInteractive(true)

        XCTAssertTrue(host.scene.isPaused)
        XCTAssertTrue(host.scene.isUserInteractionEnabled)
    }

    func testAuthoredAreaTitleUsesCenteredClippedLaneAndThirtyPointScrollSpeed() throws {
        let host = try PrototypeSceneHost(size: CGSize(width: 1_140, height: 96))
        var presentation = GameSimulation().presentation
        presentation.campaign = campaignPresentation(spriteID: .goblin)

        host.render(.active(presentation))

        let crop = try XCTUnwrap(
            host.scene.childNode(withName: "//areaTitleCrop") as? SKCropNode
        )
        let title = try XCTUnwrap(
            host.scene.childNode(withName: "//areaTitle") as? SKLabelNode
        )
        let mask = try XCTUnwrap(crop.maskNode)
        XCTAssertEqual(crop.position.x, 570, accuracy: 0.001)
        XCTAssertEqual(crop.position.y, 84, accuracy: 0.001)
        XCTAssertEqual(mask.calculateAccumulatedFrame().width, 300, accuracy: 0.001)
        XCTAssertEqual(title.text, "The Forgotten Shallow Depths That Were Remembered")
        let scrollDuration = try XCTUnwrap(title.action(forKey: "areaTitleScroll")?.duration)
        XCTAssertEqual(
            scrollDuration,
            TimeInterval((300 + title.frame.width) / 30),
            accuracy: 0.001
        )
        let rollingDPS = try XCTUnwrap(host.scene.childNode(withName: "//rollingDPS"))
        XCTAssertEqual(
            rollingDPS.position.y,
            70,
            accuracy: 0.001
        )
    }

    func testAreaTitleLaneWidthClampsAtMinimumForNarrowRail() throws {
        let host = try PrototypeSceneHost(size: CGSize(width: 400, height: 96))
        let crop = try XCTUnwrap(
            host.scene.childNode(withName: "//areaTitleCrop") as? SKCropNode
        )
        let mask = try XCTUnwrap(crop.maskNode)

        XCTAssertEqual(mask.calculateAccumulatedFrame().width, 180, accuracy: 0.001)
        XCTAssertEqual(crop.position.x, 200, accuracy: 0.001)
    }

    func testDisabledAnimationSettlesAreaTitleImmediately() throws {
        let host = try PrototypeSceneHost()
        host.setAnimating(false)
        var presentation = GameSimulation().presentation
        presentation.campaign = campaignPresentation(spriteID: .goblin)

        host.render(.active(presentation))

        let title = try XCTUnwrap(
            host.scene.childNode(withName: "//areaTitle") as? SKLabelNode
        )
        XCTAssertEqual(title.text, "Shallow Depths")
        XCTAssertNil(title.action(forKey: "areaTitleScroll"))
        XCTAssertFalse(title.isHidden)
    }

    func testSelectionAndProceduralPresentationsHideAndResetAreaTitle() throws {
        let host = try PrototypeSceneHost()
        var presentation = GameSimulation().presentation
        presentation.campaign = campaignPresentation(spriteID: .goblin)
        host.render(.active(presentation))

        host.render(.classSelection)
        XCTAssertTrue(host.scene.childNode(withName: "//areaTitleCrop")?.isHidden == true)

        let pending = PendingPartyUnlock(milestone: .boss25, choices: [.tank, .healer])
        host.render(.partySelection(pending, presentation))
        XCTAssertTrue(host.scene.childNode(withName: "//areaTitleCrop")?.isHidden == true)

        presentation.campaign = nil
        host.render(.active(presentation))
        let title = try XCTUnwrap(
            host.scene.childNode(withName: "//areaTitle") as? SKLabelNode
        )
        XCTAssertTrue(host.scene.childNode(withName: "//areaTitleCrop")?.isHidden == true)
        XCTAssertNil(title.text)
        XCTAssertNil(title.action(forKey: "areaTitleScroll"))

        presentation.campaign = campaignPresentation(spriteID: .goblin)
        host.render(.active(presentation))
        XCTAssertFalse(host.scene.childNode(withName: "//areaTitleCrop")?.isHidden == true)
        XCTAssertEqual(title.text, "The Forgotten Shallow Depths That Were Remembered")
        XCTAssertNotNil(title.action(forKey: "areaTitleScroll"))
    }

    func testInteractiveHoverReplayIsDeterministicAndPassiveRejectsIt() throws {
        let host = try PrototypeSceneHost()
        host.setAnimating(false)
        host.setAnimating(true)
        host.setInteractive(true)
        let title = try XCTUnwrap(
            host.scene.childNode(withName: "//areaTitle") as? SKLabelNode
        )

        XCTAssertFalse(host.scene.advanceMarqueeForTesting(by: 2.999, pointerInside: true))
        XCTAssertNil(title.action(forKey: "areaTitleScroll"))
        XCTAssertTrue(host.scene.advanceMarqueeForTesting(by: 0.001, pointerInside: true))
        XCTAssertNotNil(title.action(forKey: "areaTitleScroll"))

        host.setAnimating(false)
        host.setAnimating(true)
        host.setInteractive(false)
        XCTAssertFalse(host.scene.advanceMarqueeForTesting(by: 3, pointerInside: true))
        XCTAssertNil(title.action(forKey: "areaTitleScroll"))
    }

    func testInteractiveUsesLocalTrackingAreaAndDisablingClearsPointer() throws {
        let host = try PrototypeSceneHost()
        host.setInteractive(true)
        host.view.updateTrackingAreas()

        let trackingArea = try XCTUnwrap(host.view.trackingAreas.first)
        XCTAssertTrue(trackingArea.options.contains(.mouseMoved))
        XCTAssertTrue(trackingArea.options.contains(.mouseEnteredAndExited))
        XCTAssertTrue(trackingArea.options.contains(.activeInKeyWindow))
        XCTAssertTrue(trackingArea.options.contains(.inVisibleRect))

        host.scene.setPointerLocation(CGPoint(x: 570, y: 84))
        XCTAssertNotNil(host.scene.pointerLocationForTesting)
        host.setInteractive(false)
        XCTAssertNil(host.scene.pointerLocationForTesting)
        host.view.updateTrackingAreas()
        XCTAssertTrue(host.view.trackingAreas.isEmpty)
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

        XCTAssertTrue(catalog.calls.contains(.init(token: .enemy, action: .attack)))
        XCTAssertTrue(catalog.calls.contains(.init(token: .hero, action: .hit)))
        XCTAssertTrue(catalog.calls.contains(.init(token: .enemy, action: .defeated)))
        XCTAssertTrue(catalog.calls.contains(.init(token: .hero, action: .defeated)))
    }

    func testPresentationIdentityChangeUpdatesEnemyIdleTexture() throws {
        let catalog = EnemyRecordingSpriteCatalog()
        let host = try PrototypeSceneHost(spriteCatalog: catalog)
        var presentation = GameSimulation().presentation
        presentation.campaign = campaignPresentation(spriteID: .goblin)

        host.scene.render(presentation)

        let enemy = try XCTUnwrap(host.scene.childNode(withName: "enemy") as? SKSpriteNode)
        XCTAssertTrue(enemy.texture === catalog.texture(for: .goblin))

        presentation.campaign = campaignPresentation(spriteID: .bandit)
        host.scene.render(presentation)

        XCTAssertTrue(enemy.texture === catalog.texture(for: .bandit))
    }

    func testEnemyActionsUseRenderedPresentationIdentity() throws {
        let catalog = EnemyRecordingSpriteCatalog()
        let host = try PrototypeSceneHost(spriteCatalog: catalog)
        var presentation = GameSimulation().presentation
        presentation.campaign = campaignPresentation(spriteID: .goblin)
        host.scene.render(presentation)
        catalog.calls.removeAll()

        host.scene.handle([
            .attack(attacker: .hero, defender: .enemy, damage: 2),
            .enemyAttack(targetSlot: 0, damage: 2),
            .victory(defeatedLevel: 1),
        ])

        XCTAssertTrue(catalog.calls.contains(.init(spriteID: .goblin, action: .hit)))
        XCTAssertTrue(catalog.calls.contains(.init(spriteID: .goblin, action: .attack)))
        XCTAssertTrue(catalog.calls.contains(.init(spriteID: .goblin, action: .defeated)))
    }

    func testIdentityChangeDuringDefeatedTransitionDefersIdleReplacement() throws {
        let catalog = EnemyRecordingSpriteCatalog()
        let host = try PrototypeSceneHost(spriteCatalog: catalog)
        var presentation = GameSimulation().presentation
        presentation.campaign = campaignPresentation(spriteID: .goblin)
        host.scene.render(presentation)
        let enemy = try XCTUnwrap(host.scene.childNode(withName: "enemy") as? SKSpriteNode)
        host.scene.handle([.victory(defeatedLevel: 1)])
        XCTAssertNotNil(enemy.action(forKey: "spriteAction"))
        catalog.calls.removeAll()

        presentation.campaign = campaignPresentation(spriteID: .bandit)
        host.scene.render(presentation)

        XCTAssertNotNil(enemy.action(forKey: "spriteAction"))
        XCTAssertFalse(catalog.calls.contains(.init(spriteID: .bandit, action: .idle)))
    }

    func testRepeatedIdentityRenderDoesNotResetActiveEnemyAction() throws {
        let catalog = EnemyRecordingSpriteCatalog()
        let host = try PrototypeSceneHost(spriteCatalog: catalog)
        var presentation = GameSimulation().presentation
        presentation.campaign = campaignPresentation(spriteID: .goblin)
        host.scene.render(presentation)
        let enemy = try XCTUnwrap(host.scene.childNode(withName: "enemy") as? SKSpriteNode)
        host.scene.handle([.victory(defeatedLevel: 1)])
        XCTAssertNotNil(enemy.action(forKey: "spriteAction"))
        catalog.calls.removeAll()

        host.scene.render(presentation)

        XCTAssertNotNil(enemy.action(forKey: "spriteAction"))
        XCTAssertFalse(catalog.calls.contains(.init(spriteID: .goblin, action: .idle)))
    }

    func testProceduralPresentationUsesGenericEnemyIdentity() throws {
        let catalog = EnemyRecordingSpriteCatalog()
        let host = try PrototypeSceneHost(spriteCatalog: catalog)
        var presentation = GameSimulation().presentation
        presentation.campaign = nil
        catalog.calls.removeAll()

        host.scene.render(presentation)

        XCTAssertTrue(catalog.calls.contains(.init(
            spriteID: EnemySpriteID(rawValue: "generic.enemy"),
            action: .idle
        )))
    }

    func testVictoryUsesBriefEnemyFadeOutAndIn() throws {
        let host = try PrototypeSceneHost()
        let enemy = try XCTUnwrap(host.scene.childNode(withName: "enemy"))

        host.scene.handle([.victory(defeatedLevel: 7)])

        let action = try XCTUnwrap(enemy.action(forKey: "eventFade"))
        XCTAssertEqual(action.duration, 0.26, accuracy: 0.001)
        XCTAssertNil(enemy.action(forKey: "reviveVisibility"))
    }

    func testDefeatFadesHeroOutWithoutAutomaticRestore() throws {
        let host = try PrototypeSceneHost()
        let hero = try XCTUnwrap(host.scene.childNode(withName: "hero"))

        host.scene.handle([.defeat(enemyLevel: 7)])

        let action = try XCTUnwrap(hero.action(forKey: "reviveVisibility"))
        XCTAssertEqual(action.duration, 0.08, accuracy: 0.001)
        XCTAssertNil(hero.action(forKey: "eventFade"))
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

        XCTAssertNil(first.action(forKey: "reviveVisibility"))
        XCTAssertNotNil(secondNode.action(forKey: "reviveVisibility"))
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

    private func campaignPresentation(spriteID: EnemySpriteID) -> CampaignPresentation {
        CampaignPresentation(
            areaID: .forgottenShallowDepths,
            areaFullName: "The Forgotten Shallow Depths That Were Remembered",
            areaShortName: "Shallow Depths",
            enemyID: .goblin,
            enemyName: "Test Enemy",
            enemySpriteID: spriteID,
            tier: .normal,
            level: 1
        )
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

@MainActor
private final class EnemyRecordingSpriteCatalog: SpriteCatalog {
    struct Call: Equatable {
        let spriteID: EnemySpriteID
        let action: SpriteAction
    }

    var calls: [Call] = []
    private var texturesByID: [EnemySpriteID: SKTexture] = [:]
    private let genericTexture = SKTexture(image: NSImage(size: CGSize(width: 1, height: 1)))

    func textures(for token: SpriteToken, action: SpriteAction) -> [SKTexture] {
        [genericTexture]
    }

    func textures(forEnemy spriteID: EnemySpriteID, action: SpriteAction) -> [SKTexture] {
        calls.append(Call(spriteID: spriteID, action: action))
        return [texture(for: spriteID)]
    }

    func texture(for spriteID: EnemySpriteID) -> SKTexture {
        if let texture = texturesByID[spriteID] {
            return texture
        }
        let texture = SKTexture(image: NSImage(size: CGSize(width: 1, height: 1)))
        texture.filteringMode = .nearest
        texturesByID[spriteID] = texture
        return texture
    }
}
