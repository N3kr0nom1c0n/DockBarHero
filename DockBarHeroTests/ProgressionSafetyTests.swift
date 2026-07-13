import XCTest
@testable import DockBarHero

final class ProgressionSafetyTests: XCTestCase {
    func testVictoryOrdersProgressionBeforeLootAndTransition() throws {
        var simulation = try lethalHeroSimulation(level: 5, tier: .elite)

        let events = try simulation.advance(by: .zero)

        XCTAssertEqual(events.map(\.kind), [
            .attack, .victory, .xpGained, .heroLeveled, .goldGained, .loot, .equipped
        ])
        XCTAssertEqual(simulation.state.campaign.highestUnlockedLevel, 6)
        XCTAssertEqual(simulation.state.campaign.selectedLevel, 6)
    }

    func testThreeLevel174DefeatsRetreatTo149() throws {
        var simulation = try doomedSimulation(frontier: 174)

        for _ in 0..<3 {
            try resolveOneDefeatAndRevive(&simulation)
        }

        XCTAssertEqual(simulation.state.campaign.highestUnlockedLevel, 174)
        XCTAssertEqual(simulation.state.campaign.selectedLevel, 149)
        XCTAssertEqual(simulation.state.campaign.mode, .farming)
    }

    func testSelectingFarmLevelDoesNotInterruptFight() throws {
        var simulation = try activeSimulation(frontier: 10)
        let health = simulation.state.enemy.currentHealth

        XCTAssertEqual(try simulation.apply(.selectLevel(5)), [.destinationQueued(5)])

        XCTAssertEqual(simulation.state.enemy.currentHealth, health)
        XCTAssertEqual(simulation.state.campaign.selectedLevel, 10)
        XCTAssertEqual(simulation.state.campaign.queuedLevel, 5)
    }

    private func lethalHeroSimulation(
        level: Int,
        tier: EnemyTierID
    ) throws -> GameSimulation {
        var state = try activeState(frontier: level)
        state.encounter.tier = tier
        state.enemy = try XCTUnwrap(
            BalanceConfiguration.standard.enemy(
                level: level,
                tier: tier,
                progression: .standard
            )
        )
        state.party.heroes[0].level = level
        let reward = try ProgressionConfiguration.standard.xpReward(
            enemyLevel: level,
            heroLevel: level,
            tier: tier
        )
        state.party.heroes[0].currentXP = try ProgressionConfiguration.standard.xpRequired(for: level) - reward
        state.enemy.currentHealth = 1
        state.party.heroes[0].combat.timeUntilNextAttack = .zero
        return GameSimulation(state: state)
    }

    private func doomedSimulation(frontier: Int) throws -> GameSimulation {
        var state = try activeState(frontier: frontier)
        state.party.heroes[0].combat.currentHealth = 1
        state.party.heroes[0].combat.timeUntilNextAttack = .nanoseconds(1_000_000_000)
        state.enemy.timeUntilNextAttack = .nanoseconds(1_000_000_000)
        return GameSimulation(state: state)
    }

    private func activeSimulation(frontier: Int) throws -> GameSimulation {
        GameSimulation(state: try activeState(frontier: frontier))
    }

    private func activeState(frontier: Int) throws -> GameState {
        var state = GameState.newGame(
            classID: .dps,
            balance: .standard,
            progression: .standard
        )
        let tier = try XCTUnwrap(EncounterSchedule.standard.tier(for: frontier))
        state.campaign = CampaignState(
            highestUnlockedLevel: frontier,
            selectedLevel: frontier,
            queuedLevel: nil,
            mode: .push,
            consecutiveDefeats: 0
        )
        state.encounter.enemyLevel = frontier
        state.encounter.tier = tier
        state.enemy = try XCTUnwrap(
            BalanceConfiguration.standard.enemy(
                level: frontier,
                tier: tier,
                progression: .standard
            )
        )
        return state
    }

    private func resolveOneDefeatAndRevive(_ simulation: inout GameSimulation) throws {
        _ = try simulation.advance(by: .nanoseconds(1_000_000_000))
        _ = try simulation.advance(by: simulation.balance.reviveDelay)
        if simulation.state.campaign.consecutiveDefeats < 3 {
            var state = simulation.state
            state.party.heroes[0].combat.currentHealth = 1
            state.party.heroes[0].combat.timeUntilNextAttack = .nanoseconds(1_000_000_000)
            state.enemy.timeUntilNextAttack = .nanoseconds(1_000_000_000)
            simulation = GameSimulation(state: state)
        }
    }
}

private enum EventKind: Equatable {
    case attack
    case victory
    case xpGained
    case heroLeveled
    case goldGained
    case loot
    case equipped
    case other
}

private extension GameEvent {
    var kind: EventKind {
        switch self {
        case .attack: .attack
        case .victory: .victory
        case .xpGained: .xpGained
        case .heroLeveled: .heroLeveled
        case .goldGained: .goldGained
        case .loot: .loot
        case .equipped: .equipped
        case .equippedHero: .equipped
        case .heroAttack, .enemyAttack, .heroDown, .defeat, .revived, .autoEquipChanged, .destinationQueued,
             .farmingStarted, .returnedToFrontier, .partyUnlockPending: .other
        }
    }
}
