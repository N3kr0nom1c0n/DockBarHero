import Foundation
import XCTest
@testable import DockBarHero

final class CampaignAreaOneIntegrationTests: XCTestCase {
    func testTankClearsAuthoredAreaOneWithOrdinaryDropsAndAutoEquip() throws {
        try assertSoloClear(classID: .tank)
    }

    func testDPSClearsAuthoredAreaOneWithOrdinaryDropsAndAutoEquip() throws {
        try assertSoloClear(classID: .dps)
    }

    func testHealerClearsAuthoredAreaOneWithOrdinaryDropsAndAutoEquip() throws {
        try assertSoloClear(classID: .healer)
    }

    func testAuthoredEncounterIsDeterministicAcrossTimePartitions() throws {
        let state = try authoredState(level: 15)
        var single = GameSimulation(state: state)
        var split = GameSimulation(state: state)

        let singleEvents = try single.advance(by: .nanoseconds(3_000_000_000))
        var splitEvents: [GameEvent] = []
        for _ in 0..<3 {
            splitEvents += try split.advance(by: .nanoseconds(1_000_000_000))
        }

        XCTAssertEqual(single.state, split.state)
        XCTAssertEqual(singleEvents, splitEvents)
    }

    func testAuthoredFarmingVictoryRepeatsSelectedLevel() throws {
        var state = try authoredState(level: 9, frontier: 15, mode: .farming)
        state.enemy.currentHealth = 1
        state.hero.timeUntilNextAttack = .zero
        var simulation = GameSimulation(state: state)

        _ = try simulation.advance(by: .zero)

        XCTAssertEqual(simulation.state.campaign.highestUnlockedLevel, 15)
        XCTAssertEqual(simulation.state.campaign.selectedLevel, 9)
        XCTAssertEqual(simulation.state.campaign.mode, .farming)
        XCTAssertEqual(simulation.state.encounter.enemyLevel, 9)
        XCTAssertEqual(
            simulation.state.enemy,
            try enemy(level: 9)
        )
    }

    func testQueuedReturnToAuthoredFrontierCommitsAfterVictory() throws {
        var state = try authoredState(level: 9, frontier: 15, mode: .farming)
        state.campaign.queuedLevel = 15
        state.enemy.currentHealth = 1
        state.hero.timeUntilNextAttack = .zero
        var simulation = GameSimulation(state: state)

        _ = try simulation.advance(by: .zero)

        XCTAssertEqual(simulation.state.campaign.highestUnlockedLevel, 15)
        XCTAssertEqual(simulation.state.campaign.selectedLevel, 15)
        XCTAssertEqual(simulation.state.campaign.mode, .push)
        XCTAssertNil(simulation.state.campaign.queuedLevel)
        XCTAssertEqual(simulation.state.encounter.enemyLevel, 15)
        XCTAssertEqual(simulation.state.enemy, try enemy(level: 15))
    }

    func testThirdAuthoredFrontierDefeatRetreatsToAuthoredFarmLevel() throws {
        var state = try authoredState(level: 25)
        state.campaign.consecutiveDefeats = 2
        state.hero.currentHealth = 1
        state.hero.timeUntilNextAttack = .nanoseconds(1_000_000_000)
        state.enemy.timeUntilNextAttack = .zero
        var simulation = GameSimulation(state: state)

        _ = try simulation.advance(by: .zero)
        _ = try simulation.advance(by: simulation.balance.reviveDelay)

        XCTAssertEqual(simulation.state.campaign.highestUnlockedLevel, 25)
        XCTAssertEqual(simulation.state.campaign.selectedLevel, 24)
        XCTAssertEqual(simulation.state.campaign.mode, .farming)
        XCTAssertEqual(simulation.state.campaign.consecutiveDefeats, 0)
        XCTAssertEqual(simulation.state.encounter.enemyLevel, 24)
        XCTAssertEqual(simulation.state.enemy, try enemy(level: 24))
    }

    private func authoredState(
        level: Int,
        frontier: Int? = nil,
        mode: CampaignMode = .push
    ) throws -> GameState {
        var state = GameState.newGame(balance: .standard)
        let resolved = try CampaignResolver().resolve(level: level)
        state.campaign = CampaignState(
            highestUnlockedLevel: frontier ?? level,
            selectedLevel: level,
            queuedLevel: nil,
            mode: mode,
            consecutiveDefeats: 0
        )
        state.encounter.enemyLevel = level
        state.encounter.tier = resolved.tier
        state.enemy = try EnemyFactory().makeEnemy(
            for: resolved,
            balance: .standard,
            progression: .standard
        )
        return state
    }

    private func enemy(level: Int) throws -> CombatantState {
        try EnemyFactory().makeEnemy(
            for: CampaignResolver().resolve(level: level),
            balance: .standard,
            progression: .standard
        )
    }

    private func assertSoloClear(
        classID: HeroClassID,
        stepCap: Int = 50_000
    ) throws {
        let startingState = try EncounterDirector().prepareNewGame(
            in: GameState.newGame(
                classID: classID,
                balance: .standard,
                progression: .standard
            ),
            balance: .standard
        )
        var simulation = GameSimulation(state: startingState)
        var victories = 0
        var defeats = 0
        var farmingVictories = 0
        var queuedReturns = 0

        for _ in 0..<stepCap {
            let modeBeforeStep = simulation.state.campaign.mode
            let events = try simulation.advance(by: .nanoseconds(1_000_000_000))
            let stepVictories = events.reduce(into: 0) { count, event in
                if case .victory = event { count += 1 }
            }
            defeats += events.reduce(into: 0) { count, event in
                if case .defeat = event { count += 1 }
            }
            victories += stepVictories
            if modeBeforeStep == .farming, stepVictories > 0 {
                farmingVictories += stepVictories
                if simulation.state.campaign.queuedLevel == nil {
                    _ = try simulation.apply(.returnToFrontier)
                    queuedReturns += 1
                }
            }

            if simulation.state.encounter.phase == .awaitingPartyChoice {
                XCTAssertEqual(simulation.state.encounter.enemyLevel, 25, "\(classID) stopped at the wrong level")
                XCTAssertEqual(simulation.state.encounter.tier, .boss)
                XCTAssertEqual(simulation.state.enemy.currentHealth, 0)
                XCTAssertEqual(simulation.state.campaign.highestUnlockedLevel, 25)
                XCTAssertEqual(simulation.state.party.heroes.map(\.classID), [classID])
                XCTAssertEqual(
                    simulation.state.party.unlocks.pendingUnlock?.milestone,
                    .boss25
                )
                XCTAssertEqual(victories, 25)
                XCTAssertEqual(defeats, 0)
                XCTAssertEqual(farmingVictories, 0)
                XCTAssertEqual(queuedReturns, 0)
                XCTAssertGreaterThan(simulation.state.lootSequence, 0)
                XCTAssertTrue(simulation.state.autoEquipEnabled)
                XCTAssertTrue(
                    EquipmentSlot.allCases.contains {
                        simulation.state.party.heroes[0].equipment[$0] != nil
                    },
                    "\(classID) should use an ordinarily dropped auto-equipped item"
                )
                return
            }
        }

        XCTFail(
            "\(classID) did not clear Boss 25 within \(stepCap) deterministic seconds; " +
            "frontier=\(simulation.state.campaign.highestUnlockedLevel), " +
            "selected=\(simulation.state.campaign.selectedLevel), " +
            "mode=\(simulation.state.campaign.mode), victories=\(victories), " +
            "defeats=\(defeats), farmingVictories=\(farmingVictories), " +
            "queuedReturns=\(queuedReturns)"
        )
    }
}
