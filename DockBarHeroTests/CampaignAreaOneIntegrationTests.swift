import Foundation
import XCTest
@testable import DockBarHero

final class CampaignAreaOneIntegrationTests: XCTestCase {
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
}
