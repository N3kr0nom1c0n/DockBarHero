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
        XCTAssertEqual(
            (host.scene.childNode(withName: "//enemyIdentity") as? SKLabelNode)?.text,
            "Unknown Guardian"
        )
    }

    func testLongAuthoredEnemyIdentityFitsOutsideNarrowAreaTitleLane() throws {
        let host = try PrototypeSceneHost(size: CGSize(width: 400, height: 96))
        var state = GameState.newGame(balance: .standard)
        state.encounter.enemyLevel = 15
        state.encounter.tier = .normal
        var presentation = GameSimulation(state: state).presentation
        presentation.campaign = CampaignPresentation(
            areaID: .forgottenShallowDepths,
            areaFullName: "The Forgotten Shallow Depths That Were Remembered",
            areaShortName: "Shallow Depths",
            enemyID: .poisonNagaQueen,
            enemyName: "Poison Naga Queen",
            enemySpriteID: .poisonNagaQueen,
            tier: .normal,
            level: 15
        )

        host.render(.active(presentation))

        let identity = try XCTUnwrap(
            host.scene.childNode(withName: "//enemyIdentity") as? SKLabelNode
        )
        let level = try XCTUnwrap(
            host.scene.childNode(withName: "//enemyLevel") as? SKLabelNode
        )
        XCTAssertEqual(identity.text, "Poison Naga Queen")
        XCTAssertEqual(level.text, "Normal · Enemy Lv. 15")
        XCTAssertGreaterThanOrEqual(identity.fontSize, 8)
        XCTAssertGreaterThanOrEqual(level.fontSize, 8)
        XCTAssertGreaterThanOrEqual(identity.frame.minX, 297.5)
        XCTAssertLessThanOrEqual(identity.frame.maxX, 392.5)
        XCTAssertGreaterThanOrEqual(level.frame.minX, 297.5)
        XCTAssertLessThanOrEqual(level.frame.maxX, 392.5)
        XCTAssertGreaterThan(level.position.y, identity.position.y)
        XCTAssertFalse(identity.frame.intersects(level.frame))
    }

    func testNarrowAuthoredFarmingLabelsAreReadableAndDoNotIntersect() throws {
        let host = try PrototypeSceneHost(size: CGSize(width: 400, height: 96))
        var state = GameState.newGame(balance: .standard)
        state.campaign.highestUnlockedLevel = 15
        state.campaign.selectedLevel = 15
        state.campaign.mode = .farming
        state.encounter.enemyLevel = 15
        state.encounter.tier = .normal
        var presentation = GameSimulation(state: state).presentation
        presentation.campaign = CampaignPresentation(
            areaID: .forgottenShallowDepths,
            areaFullName: "The Forgotten Shallow Depths That Were Remembered",
            areaShortName: "Shallow Depths",
            enemyID: .poisonNagaQueen,
            enemyName: "Poison Naga Queen",
            enemySpriteID: .poisonNagaQueen,
            tier: .normal,
            level: 15
        )

        host.render(.active(presentation))

        let identity = try XCTUnwrap(
            host.scene.childNode(withName: "//enemyIdentity") as? SKLabelNode
        )
        let level = try XCTUnwrap(
            host.scene.childNode(withName: "//enemyLevel") as? SKLabelNode
        )
        let status = try XCTUnwrap(
            host.scene.childNode(withName: "//farmingStatus") as? SKLabelNode
        )
        XCTAssertEqual(identity.text, "Poison Naga Queen")
        XCTAssertEqual(level.text, "Normal · Enemy Lv. 15")
        XCTAssertEqual(status.text, "FARMING • FRONTIER 15")
        for label in [identity, level, status] {
            XCTAssertGreaterThanOrEqual(label.fontSize, 8)
            XCTAssertGreaterThanOrEqual(label.frame.minX, 297.5)
            XCTAssertLessThanOrEqual(label.frame.maxX, 392.5)
        }
        XCTAssertFalse(identity.frame.intersects(level.frame))
        XCTAssertFalse(identity.frame.intersects(status.frame))
        XCTAssertFalse(level.frame.intersects(status.frame))
    }

    func testNarrowProceduralFarmingStatusStaysVisibleAndOnRail() throws {
        let host = try PrototypeSceneHost(size: CGSize(width: 400, height: 96))
        var state = GameState.newGame(balance: .standard)
        state.campaign.highestUnlockedLevel = 26
        state.campaign.selectedLevel = 26
        state.campaign.mode = .farming
        state.encounter.enemyLevel = 26
        state.encounter.tier = .normal
        var presentation = GameSimulation(state: state).presentation
        presentation.campaign = nil

        host.render(.active(presentation))

        let identity = try XCTUnwrap(
            host.scene.childNode(withName: "//enemyIdentity") as? SKLabelNode
        )
        let level = try XCTUnwrap(
            host.scene.childNode(withName: "//enemyLevel") as? SKLabelNode
        )
        let status = try XCTUnwrap(
            host.scene.childNode(withName: "//farmingStatus") as? SKLabelNode
        )
        XCTAssertTrue(identity.isHidden)
        XCTAssertEqual(level.text, "Normal · Enemy Lv. 26")
        XCTAssertEqual(status.text, "FARMING • FRONTIER 26")
        XCTAssertFalse(status.isHidden)
        let statusColor = try XCTUnwrap(status.fontColor?.usingColorSpace(.deviceRGB))
        let expectedColor = try XCTUnwrap(NSColor.systemOrange.usingColorSpace(.deviceRGB))
        XCTAssertEqual(statusColor.redComponent, expectedColor.redComponent, accuracy: 0.001)
        XCTAssertEqual(statusColor.greenComponent, expectedColor.greenComponent, accuracy: 0.001)
        XCTAssertEqual(statusColor.blueComponent, expectedColor.blueComponent, accuracy: 0.001)
        for label in [level, status] {
            XCTAssertGreaterThanOrEqual(label.fontSize, 8)
            XCTAssertGreaterThanOrEqual(label.frame.minX, 297.5)
            XCTAssertLessThanOrEqual(label.frame.maxX, 392.5)
            XCTAssertGreaterThanOrEqual(label.frame.minY, 0)
            XCTAssertLessThanOrEqual(label.frame.maxY, host.scene.size.height)
        }
        XCTAssertFalse(level.frame.intersects(status.frame))

        state.campaign.mode = .push
        presentation = GameSimulation(state: state).presentation
        presentation.campaign = nil
        host.render(.active(presentation))

        XCTAssertTrue(identity.isHidden)
        XCTAssertEqual(level.text, "Normal · Enemy Lv. 26")
        XCTAssertTrue(status.isHidden)
        XCTAssertNil(status.text)
    }

    func testReviewedProceduralFarmingLabelsStayReadableAndSeparated() throws {
        let host = try PrototypeSceneHost(size: CGSize(width: 1_140, height: 96))
        var state = GameState.newGame(balance: .standard)
        state.campaign.highestUnlockedLevel = 100
        state.campaign.selectedLevel = 74
        state.campaign.mode = .farming
        state.encounter.enemyLevel = 74
        state.encounter.tier = .normal
        var presentation = GameSimulation(state: state).presentation
        presentation.campaign = nil

        host.render(.active(presentation))

        let enemy = try requiredNode("enemy", in: host.scene, file: #filePath, line: #line)
        let enemyHealth = try requiredNode("enemyHealthBackground", in: host.scene, file: #filePath, line: #line)
        let level = try XCTUnwrap(
            host.scene.childNode(withName: "//enemyLevel") as? SKLabelNode
        )
        let status = try XCTUnwrap(
            host.scene.childNode(withName: "//farmingStatus") as? SKLabelNode
        )
        let rollingDPS = try requiredNode("rollingDPS", in: host.scene, file: #filePath, line: #line)

        XCTAssertEqual(level.text, "Normal · Enemy Lv. 74")
        XCTAssertEqual(status.text, "FARMING • FRONTIER 100")
        XCTAssertEqual(level.fontSize, 12, accuracy: 0.001)
        XCTAssertEqual(status.fontSize, 12, accuracy: 0.001)

        for frame in [enemy.frame, enemyHealth.frame, level.frame, status.frame, rollingDPS.frame] {
            assertFrameIsOnRail(frame, width: host.scene.size.width, file: #filePath, line: #line)
        }
        XCTAssertFalse(level.frame.intersects(status.frame))
        XCTAssertFalse(level.frame.intersects(enemy.frame))
        XCTAssertFalse(status.frame.intersects(enemy.frame))
        XCTAssertFalse(level.frame.intersects(enemyHealth.frame))
        XCTAssertFalse(status.frame.intersects(enemyHealth.frame))
        XCTAssertFalse(level.frame.intersects(rollingDPS.frame))
        XCTAssertFalse(status.frame.intersects(rollingDPS.frame))
    }

    func testEnemyLabelsUseAccessibleCondensedFontWithoutSerifFallback() throws {
        let host = try PrototypeSceneHost(size: CGSize(width: 400, height: 96))
        var state = GameState.newGame(balance: .standard)
        state.campaign.mode = .farming

        host.render(.active(GameSimulation(state: state).presentation))

        for name in ["enemyIdentity", "enemyLevel", "farmingStatus"] {
            let label = try XCTUnwrap(
                host.scene.childNode(withName: "//\(name)") as? SKLabelNode
            )
            XCTAssertEqual(label.fontName, "AvenirNextCondensed-Regular")
            let effectiveFont = try XCTUnwrap(
                label.fontName.flatMap { NSFont(name: $0, size: label.fontSize) }
            )
            XCTAssertEqual(effectiveFont.fontName, "AvenirNextCondensed-Regular")
            XCTAssertNotEqual(effectiveFont.fontName, "TimesNewRomanPSMT")
        }
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
        XCTAssertLessThanOrEqual(status.frame.maxY, host.scene.size.height)
        XCTAssertEqual(
            (host.scene.childNode(withName: "//enemyLevel") as? SKLabelNode)?.text,
            "Normal · Enemy Lv. 1"
        )
        XCTAssertEqual(
            (host.scene.childNode(withName: "//enemyIdentity") as? SKLabelNode)?.text,
            "Slime"
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

    func testRailLabelsKeepVisibleForegroundAboveEightBlackOutlineLayers() throws {
        let host = try PrototypeSceneHost(size: CGSize(width: 1_140, height: 96))
        var state = GameState.newGame(balance: .standard)
        state.campaign.mode = .farming

        host.render(.active(GameSimulation(state: state).presentation))

        let whiteLabelNames = ["heroLevel", "heroAction", "enemyLevel", "rollingDPS"]
        for name in whiteLabelNames {
            let label = try XCTUnwrap(
                host.scene.childNode(withName: "//\(name)") as? SKLabelNode
            )
            XCTAssertNil(label.attributedText)
            try assertColor(label.fontColor, equals: .white)
            try assertOutlineLayers(of: label)
        }

        let farmingStatus = try XCTUnwrap(
            host.scene.childNode(withName: "//farmingStatus") as? SKLabelNode
        )
        XCTAssertNil(farmingStatus.attributedText)
        try assertColor(farmingStatus.fontColor, equals: .systemOrange)
        try assertOutlineLayers(of: farmingStatus)
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

    func testNarrowOneHeroAuthoredFarmingLayoutAvoidsTitleAndRailCollisions() throws {
        try assertAuthoredFarmingLayout(width: 400, heroCount: 1)
    }

    func testNarrowThreeHeroAuthoredFarmingLayoutAvoidsTitleAndRailCollisions() throws {
        try assertAuthoredFarmingLayout(width: 400, heroCount: 3)
    }

    func testDefaultOneHeroAuthoredFarmingLayoutAvoidsTitleAndRailCollisions() throws {
        try assertAuthoredFarmingLayout(width: 1_140, heroCount: 1)
    }

    func testDefaultThreeHeroAuthoredFarmingLayoutAvoidsTitleAndRailCollisions() throws {
        try assertAuthoredFarmingLayout(width: 1_140, heroCount: 3)
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

    func testStartupPauseDefersPlaceholderInitialPassUntilActualCampaignIsReady() throws {
        let host = try PrototypeSceneHost()
        let title = try XCTUnwrap(
            host.scene.childNode(withName: "//areaTitle") as? SKLabelNode
        )
        XCTAssertNotNil(title.action(forKey: "areaTitleScroll"))

        host.setAnimating(false)
        var actualPresentation = GameSimulation().presentation
        actualPresentation.campaign = campaignPresentation(spriteID: .poisonNagaQueen)
        host.render(.active(actualPresentation))

        XCTAssertEqual(title.text, "Shallow Depths")
        XCTAssertNil(title.action(forKey: "areaTitleScroll"))

        host.setAnimating(true)

        XCTAssertEqual(title.text, "The Forgotten Shallow Depths That Were Remembered")
        XCTAssertNotNil(title.action(forKey: "areaTitleScroll"))
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
        host.scene.completeMarqueeForTesting()
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

    func testInteractiveTrackingIsActiveForNonKeyOverlayAndDisablingClearsPointer() throws {
        let host = try PrototypeSceneHost()
        let window = OverlayWindowController(contentView: host.view)
        window.setInputEnabled(true)
        window.setVisible(true)
        host.setInteractive(true)
        host.view.updateTrackingAreas()

        let trackingArea = try XCTUnwrap(host.view.trackingAreas.first)
        XCTAssertFalse(window.panel.canBecomeKey)
        XCTAssertFalse(window.panel.isKeyWindow)
        XCTAssertTrue(window.panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertTrue(trackingArea.options.contains(.mouseMoved))
        XCTAssertTrue(trackingArea.options.contains(.mouseEnteredAndExited))
        XCTAssertTrue(trackingArea.options.contains(.activeAlways))
        XCTAssertFalse(trackingArea.options.contains(.activeInKeyWindow))
        XCTAssertTrue(trackingArea.options.contains(.inVisibleRect))
        XCTAssertTrue(trackingArea.owner === host.view)

        host.scene.setPointerLocation(CGPoint(x: 570, y: 84))
        XCTAssertNotNil(host.scene.pointerLocationForTesting)
        host.setInteractive(false)
        XCTAssertNil(host.scene.pointerLocationForTesting)
        host.view.updateTrackingAreas()
        XCTAssertTrue(host.view.trackingAreas.isEmpty)
        window.setVisible(false)
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
        XCTAssertTrue(host.scene.childNode(withName: "//enemyIdentity")?.isHidden == true)
        XCTAssertEqual(rollingDPS.text, "12.3 DPS AVG")
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
        let expectedEnemyToken = SpriteToken(
            enemySpriteID: try XCTUnwrap(GameSimulation().presentation.campaign?.enemySpriteID)
        )
        catalog.calls.removeAll()

        host.scene.handle([
            .attack(attacker: .enemy, defender: .hero, damage: 2),
            .victory(defeatedLevel: 1),
            .defeat(enemyLevel: 2),
        ])

        XCTAssertTrue(catalog.calls.contains(.init(token: expectedEnemyToken, action: .attack)))
        XCTAssertTrue(catalog.calls.contains(.init(token: .dps, action: .hit)))
        XCTAssertTrue(catalog.calls.contains(.init(token: expectedEnemyToken, action: .defeated)))
        XCTAssertTrue(catalog.calls.contains(.init(token: .dps, action: .defeated)))
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

    func testProceduralPresentationUsesLevelResolvedProductionEnemyIdentity() throws {
        let catalog = RecordingSpriteCatalog()
        let host = try PrototypeSceneHost(spriteCatalog: catalog)
        var presentation = GameSimulation().presentation
        presentation.campaign = nil
        catalog.calls.removeAll()

        host.scene.render(presentation)

        let expectedToken = EnemySpriteResolver.token(
            level: presentation.state.encounter.enemyLevel,
            tier: presentation.state.encounter.tier
        )
        XCTAssertTrue(catalog.calls.contains(.init(token: expectedToken, action: .idle)))
    }

    func testProceduralEnemyKeepsLevelResolvedIdentityDuringCombatAction() throws {
        let catalog = RecordingSpriteCatalog()
        let host = try PrototypeSceneHost(spriteCatalog: catalog)
        var state = GameState.newGame(balance: .standard)
        state.encounter.enemyLevel = 74
        state.encounter.tier = .normal
        var presentation = GameSimulation(state: state).presentation
        presentation.campaign = nil
        host.scene.render(presentation)
        catalog.calls.removeAll()

        host.scene.handle([.heroAttack(slot: 0, damage: 1)])

        let expectedToken = EnemySpriteResolver.token(level: 74, tier: .normal)
        XCTAssertEqual(expectedToken, .wolf)
        XCTAssertTrue(catalog.calls.contains(.init(token: expectedToken, action: .hit)))
        XCTAssertFalse(catalog.calls.contains(.init(token: .enemy, action: .hit)))
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

    func testThreeHeroFormationStaysGroupedWithCompactHealthBars() throws {
        let host = try PrototypeSceneHost(size: CGSize(width: 1_140, height: 96))
        var state = GameState.newGame(classID: .tank, balance: .standard, progression: .standard)
        let dps = GameState.newGame(classID: .dps, balance: .standard, progression: .standard).party.heroes[0]
        let healer = GameState.newGame(classID: .healer, balance: .standard, progression: .standard).party.heroes[0]
        state.party = PartyState(heroes: [state.party.heroes[0], dps, healer], unlocks: .complete)

        host.render(.active(GameSimulation(state: state).presentation))

        let heroes = try (0..<3).map { slot in
            try requiredNode(slot == 0 ? "hero" : "hero-\(slot)", in: host.scene, file: #filePath, line: #line)
        }
        let healthBars = try (0..<3).map { slot in
            let prefix = slot == 0 ? "hero" : "hero-\(slot)"
            return try requiredNode("\(prefix)HealthBackground", in: host.scene, file: #filePath, line: #line)
        }
        let heroSpan = heroes.map(\.frame).reduce(CGRect.null) { $0.union($1) }

        XCTAssertLessThanOrEqual(heroSpan.width, 186)
        for healthBar in healthBars {
            XCTAssertLessThanOrEqual(healthBar.frame.width, 56)
        }
    }

    func testActorScaleResizesPartyAndEnemyWithoutScalingHealthBars() throws {
        let host = try PrototypeSceneHost(size: CGSize(width: 1_140, height: 96))
        var state = GameState.newGame(classID: .tank, balance: .standard, progression: .standard)
        let dps = GameState.newGame(classID: .dps, balance: .standard, progression: .standard).party.heroes[0]
        let healer = GameState.newGame(classID: .healer, balance: .standard, progression: .standard).party.heroes[0]
        state.party = PartyState(heroes: [state.party.heroes[0], dps, healer], unlocks: .complete)
        host.render(.active(GameSimulation(state: state).presentation))

        let heroes = try (0..<3).map { slot in
            try requiredNode(slot == 0 ? "hero" : "hero-\(slot)", in: host.scene, file: #filePath, line: #line)
        }
        let enemy = try requiredNode("enemy", in: host.scene, file: #filePath, line: #line)
        let healthBar = try requiredNode("heroHealthBackground", in: host.scene, file: #filePath, line: #line)
        let defaultMidpoint = (heroes[0].position.x + heroes[2].position.x) / 2

        host.scene.setAppearance(RailAppearance(actorScalePercent: 125, railTextScalePercent: 100))

        XCTAssertEqual((heroes[0].position.x + heroes[2].position.x) / 2, defaultMidpoint, accuracy: 0.001)
        for hero in heroes {
            XCTAssertEqual(hero.frame.width, 67.5, accuracy: 0.001)
            assertFrameIsOnRail(hero.frame, width: host.scene.size.width, file: #filePath, line: #line)
        }
        XCTAssertEqual(enemy.frame.width, 67.5, accuracy: 0.001)
        XCTAssertEqual(healthBar.frame.width, 56, accuracy: 0.001)
        assertPairwiseDisjoint(heroes.map(\.frame), file: #filePath, line: #line)
    }

    func testRailTextScaleResizesLabelsAndOutlines() throws {
        let host = try PrototypeSceneHost(size: CGSize(width: 1_140, height: 96))
        let state = GameState.newGame(classID: .tank, balance: .standard, progression: .standard)
        host.render(.active(GameSimulation(state: state).presentation))

        let heroLevel = try XCTUnwrap(host.scene.childNode(withName: "//heroLevel") as? SKLabelNode)
        let heroAction = try XCTUnwrap(host.scene.childNode(withName: "//heroAction") as? SKLabelNode)
        let enemyLevel = try XCTUnwrap(host.scene.childNode(withName: "//enemyLevel") as? SKLabelNode)
        let rollingDPS = try XCTUnwrap(host.scene.childNode(withName: "//rollingDPS") as? SKLabelNode)

        host.scene.setAppearance(RailAppearance(actorScalePercent: 100, railTextScalePercent: 125))

        XCTAssertEqual(heroLevel.fontSize, 15, accuracy: 0.001)
        XCTAssertEqual(heroAction.fontSize, 12.5, accuracy: 0.001)
        XCTAssertEqual(enemyLevel.fontSize, 12.5, accuracy: 0.001)
        XCTAssertEqual(rollingDPS.fontSize, 15, accuracy: 0.001)
        for label in [heroLevel, heroAction, enemyLevel, rollingDPS] {
            for outline in label.children.compactMap({ $0 as? SKLabelNode }) {
                XCTAssertEqual(outline.fontSize, label.fontSize, accuracy: 0.001)
            }
        }
    }

    func testClusteredTwoHeroFormationUsesCompactNonOverlappingLabels() throws {
        let host = try PrototypeSceneHost(size: CGSize(width: 800, height: 96))
        var state = GameState.newGame(classID: .tank, balance: .standard, progression: .standard)
        var dps = GameState.newGame(classID: .dps, balance: .standard, progression: .standard).party.heroes[0]
        state.party.heroes[0].level = 262
        dps.level = 262
        state.party = PartyState(heroes: [state.party.heroes[0], dps], unlocks: .secondUnlocked)

        host.render(.active(GameSimulation(state: state).presentation))

        let firstLevel = try XCTUnwrap(host.scene.childNode(withName: "//heroLevel") as? SKLabelNode)
        let secondLevel = try XCTUnwrap(host.scene.childNode(withName: "//hero-1Level") as? SKLabelNode)
        let firstAction = try XCTUnwrap(host.scene.childNode(withName: "//heroAction") as? SKLabelNode)
        let secondAction = try XCTUnwrap(host.scene.childNode(withName: "//hero-1Action") as? SKLabelNode)

        XCTAssertEqual(firstLevel.text, "Lv. 262")
        XCTAssertEqual(secondLevel.text, "Lv. 262")
        XCTAssertEqual(firstAction.text, "G")
        XCTAssertEqual(secondAction.text, "PS")
        assertPairwiseDisjoint(
            [firstLevel.frame, secondLevel.frame, firstAction.frame, secondAction.frame],
            file: #filePath,
            line: #line
        )
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
            "M"
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

    func testRenderUsesAuthoredCampaignEnemyIdentityWithoutReplacingStableNode() throws {
        let catalog = RecordingSpriteCatalog()
        let host = try PrototypeSceneHost(spriteCatalog: catalog)
        let enemy = try XCTUnwrap(host.scene.childNode(withName: "enemy"))
        var state = GameState.newGame(balance: .standard)
        state.encounter.enemyLevel = 25
        state.encounter.tier = .boss
        catalog.calls.removeAll()

        let presentation = GameSimulation(state: state).presentation
        let expectedToken = SpriteToken(
            enemySpriteID: try XCTUnwrap(presentation.campaign?.enemySpriteID)
        )
        host.render(.active(presentation))

        XCTAssertTrue(host.scene.childNode(withName: "enemy") === enemy)
        XCTAssertTrue(catalog.calls.contains(.init(token: expectedToken, action: .idle)))
        catalog.calls.removeAll()
        host.render(.active(presentation))
        XCTAssertFalse(catalog.calls.contains(.init(token: expectedToken, action: .idle)))
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

    private func assertOutlineLayers(
        of label: SKLabelNode,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let layers = label.children.compactMap { $0 as? SKLabelNode }
        XCTAssertEqual(layers.count, 8, file: file, line: line)
        XCTAssertEqual(
            Set(layers.map(\.position)),
            Set([
                CGPoint(x: -1, y: -1), CGPoint(x: 0, y: -1), CGPoint(x: 1, y: -1),
                CGPoint(x: -1, y: 0), CGPoint(x: 1, y: 0),
                CGPoint(x: -1, y: 1), CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1),
            ]),
            file: file,
            line: line
        )
        for layer in layers {
            XCTAssertEqual(layer.text, label.text, file: file, line: line)
            XCTAssertEqual(layer.zPosition, -1, accuracy: 0.001, file: file, line: line)
            try assertColor(layer.fontColor, equals: .black, file: file, line: line)
        }
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

    private func assertAuthoredFarmingLayout(
        width: CGFloat,
        heroCount: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let host = try PrototypeSceneHost(size: CGSize(width: width, height: 96))
        var state = GameState.newGame(classID: .tank, balance: .standard, progression: .standard)
        if heroCount == 3 {
            let dps = GameState.newGame(
                classID: .dps,
                balance: .standard,
                progression: .standard
            ).party.heroes[0]
            let healer = GameState.newGame(
                classID: .healer,
                balance: .standard,
                progression: .standard
            ).party.heroes[0]
            state.party = PartyState(
                heroes: [state.party.heroes[0], dps, healer],
                unlocks: .complete
            )
        }
        state.campaign.highestUnlockedLevel = 15
        state.campaign.selectedLevel = 15
        state.campaign.mode = .farming
        state.encounter.enemyLevel = 15
        state.encounter.tier = .normal
        var presentation = GameSimulation(state: state).presentation
        presentation.campaign = CampaignPresentation(
            areaID: .forgottenShallowDepths,
            areaFullName: "The Forgotten Shallow Depths That Were Remembered",
            areaShortName: "Shallow Depths",
            enemyID: .poisonNagaQueen,
            enemyName: "Poison Naga Queen",
            enemySpriteID: .poisonNagaQueen,
            tier: .normal,
            level: 15
        )

        host.render(.active(presentation))

        let crop = try XCTUnwrap(
            host.scene.childNode(withName: "//areaTitleCrop") as? SKCropNode,
            file: file,
            line: line
        )
        let mask = try XCTUnwrap(crop.maskNode, file: file, line: line)
        let title = try XCTUnwrap(
            host.scene.childNode(withName: "//areaTitle") as? SKLabelNode,
            file: file,
            line: line
        )
        let maskSize = mask.calculateAccumulatedFrame().size
        let titleLane = CGRect(
            x: crop.position.x - maskSize.width / 2,
            y: crop.position.y - maskSize.height / 2,
            width: maskSize.width,
            height: maskSize.height
        )
        XCTAssertEqual(crop.position.x, width / 2, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(crop.position.y, 84, accuracy: 0.001, file: file, line: line)
        XCTAssertGreaterThanOrEqual(maskSize.width, 180, file: file, line: line)
        XCTAssertLessThanOrEqual(maskSize.width, 300, file: file, line: line)
        XCTAssertNotNil(title.action(forKey: "areaTitleScroll"), file: file, line: line)
        XCTAssertEqual(title.text, presentation.campaign?.areaFullName, file: file, line: line)

        // Sample the scrolling label at mid-lane. Its visible pixels must remain clipped to the lane.
        title.position.x = 0
        let titleOrigin = crop.convert(title.frame.origin, to: host.scene)
        let titleMaximum = crop.convert(
            CGPoint(x: title.frame.maxX, y: title.frame.maxY),
            to: host.scene
        )
        let titleInScene = CGRect(
            x: min(titleOrigin.x, titleMaximum.x),
            y: min(titleOrigin.y, titleMaximum.y),
            width: abs(titleMaximum.x - titleOrigin.x),
            height: abs(titleMaximum.y - titleOrigin.y)
        )
        let visibleScrollingTitle = titleInScene.intersection(titleLane)
        XCTAssertFalse(visibleScrollingTitle.isNull, file: file, line: line)

        let rollingDPS = try requiredNode("rollingDPS", in: host.scene, file: file, line: line)
        let enemyIdentity = try requiredNode("enemyIdentity", in: host.scene, file: file, line: line)
        let enemyLevel = try requiredNode("enemyLevel", in: host.scene, file: file, line: line)
        let farmingStatus = try requiredNode("farmingStatus", in: host.scene, file: file, line: line)
        let enemyFrames = [enemyIdentity.frame, enemyLevel.frame, farmingStatus.frame]
        let rightFrames = [rollingDPS.frame] + enemyFrames

        for frame in [titleLane, visibleScrollingTitle] + rightFrames {
            assertFrameIsOnRail(frame, width: width, file: file, line: line)
        }
        for frame in rightFrames {
            XCTAssertFalse(frame.intersects(titleLane), file: file, line: line)
            XCTAssertFalse(frame.intersects(visibleScrollingTitle), file: file, line: line)
        }
        assertPairwiseDisjoint(enemyFrames, file: file, line: line)
        XCTAssertFalse(rollingDPS.frame.intersects(enemyIdentity.frame), file: file, line: line)
        XCTAssertFalse(rollingDPS.frame.intersects(enemyLevel.frame), file: file, line: line)
        XCTAssertFalse(rollingDPS.frame.intersects(farmingStatus.frame), file: file, line: line)

        var actorFrames: [CGRect] = []
        var healthFrames: [CGRect] = []
        var levelFrames: [CGRect] = []
        var actionFrames: [CGRect] = []
        for slot in 0..<heroCount {
            let prefix = slot == 0 ? "hero" : "hero-\(slot)"
            let actor = try requiredNode(prefix, in: host.scene, file: file, line: line)
            let health = try requiredNode(
                "\(prefix)HealthBackground",
                in: host.scene,
                file: file,
                line: line
            )
            let level = try XCTUnwrap(
                host.scene.childNode(withName: "//\(prefix)Level") as? SKLabelNode,
                file: file,
                line: line
            )
            let action = try XCTUnwrap(
                host.scene.childNode(withName: "//\(prefix)Action") as? SKLabelNode,
                file: file,
                line: line
            )
            XCTAssertFalse(level.text?.isEmpty ?? true, file: file, line: line)
            XCTAssertFalse(action.text?.isEmpty ?? true, file: file, line: line)
            XCTAssertGreaterThanOrEqual(level.fontSize, 8, file: file, line: line)
            XCTAssertGreaterThanOrEqual(action.fontSize, 8, file: file, line: line)
            for frame in [actor.frame, health.frame, level.frame, action.frame] {
                assertFrameIsOnRail(frame, width: width, file: file, line: line)
                XCTAssertFalse(frame.intersects(titleLane), file: file, line: line)
                XCTAssertFalse(frame.intersects(visibleScrollingTitle), file: file, line: line)
                for rightFrame in rightFrames {
                    XCTAssertFalse(frame.intersects(rightFrame), file: file, line: line)
                }
            }
            actorFrames.append(actor.frame)
            healthFrames.append(health.frame)
            levelFrames.append(level.frame)
            actionFrames.append(action.frame)
        }
        assertPairwiseDisjoint(actorFrames, file: file, line: line)
        assertPairwiseDisjoint(healthFrames, file: file, line: line)
        assertPairwiseDisjoint(levelFrames, file: file, line: line)
        assertPairwiseDisjoint(actionFrames, file: file, line: line)
    }

    private func requiredNode(
        _ name: String,
        in scene: SKScene,
        file: StaticString,
        line: UInt
    ) throws -> SKNode {
        try XCTUnwrap(scene.childNode(withName: "//\(name)"), file: file, line: line)
    }

    private func assertFrameIsOnRail(
        _ frame: CGRect,
        width: CGFloat,
        file: StaticString,
        line: UInt
    ) {
        XCTAssertGreaterThanOrEqual(frame.minX, 0, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, width, file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.minY, 0, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxY, 96, file: file, line: line)
    }

    private func assertPairwiseDisjoint(
        _ frames: [CGRect],
        file: StaticString,
        line: UInt
    ) {
        for first in frames.indices {
            for second in frames.indices where second > first {
                XCTAssertFalse(frames[first].intersects(frames[second]), file: file, line: line)
            }
        }
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
