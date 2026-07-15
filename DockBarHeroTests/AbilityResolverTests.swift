import XCTest
@testable import DockBarHero

final class AbilityResolverTests: XCTestCase {
    func testGuardRedirectsNextEnemyAttackAndHalvesFinalDamage() throws {
        var state = partyState(classes: [.dps, .tank])
        state.enemy.timeUntilNextAttack = .zero
        state.party.heroes[0].combat.timeUntilNextAttack = try duration(seconds: 1)
        state.party.heroes[1].combat.timeUntilNextAttack = try duration(seconds: 1)
        let dpsHealth = state.party.heroes[0].combat.currentHealth
        let tankHealth = state.party.heroes[1].combat.currentHealth
        var simulation = GameSimulation(state: state)

        XCTAssertEqual(try simulation.apply(.castAction(heroSlot: 1, actionID: .guardAction)), [
            .classActionCast(heroSlot: 1, actionID: .guardAction),
            .guardActivated(heroSlot: 1),
        ])
        let events = try simulation.advance(by: .zero)

        XCTAssertEqual(simulation.state.party.heroes[0].combat.currentHealth, dpsHealth)
        XCTAssertLessThan(simulation.state.party.heroes[1].combat.currentHealth, tankHealth)
        XCTAssertTrue(events.contains(where: {
            if case .guardIntercepted(heroSlot: 1, damage: _) = $0 { return true }
            return false
        }))
        XCTAssertFalse(simulation.state.party.heroes[1].classAction.guardActive)
    }

    func testDuplicateGuardRejectsWithoutMutation() throws {
        var state = GameState.newGame(classID: .tank, balance: .standard, progression: .standard)
        state.party.heroes[0].classAction.guardActive = true
        var simulation = GameSimulation(state: state)
        let before = simulation.state

        XCTAssertEqual(try simulation.apply(.castAction(heroSlot: 0, actionID: .guardAction)), [
            .classActionRejected(heroSlot: 0, actionID: .guardAction, reason: .alreadyActive)
        ])
        XCTAssertEqual(simulation.state, before)
    }

    func testPowerStrikeDealsTwoHundredFiftyPercentAttackAndStartsCooldown() throws {
        var state = GameState.newGame(classID: .dps, balance: .standard, progression: .standard)
        state.enemy = CombatantState(
            id: .enemy,
            currentHealth: 100,
            maxHealth: 100,
            baseAttack: 3,
            baseDefense: 5,
            attackInterval: try duration(milliseconds: 1_500),
            timeUntilNextAttack: try duration(milliseconds: 1_500)
        )
        state.encounter.activeElapsed = try duration(seconds: 1)
        state.party.heroes[0].encounterAliveDuration = try duration(seconds: 1)
        var simulation = GameSimulation(state: state)

        let events = try simulation.apply(.castAction(heroSlot: 0, actionID: .powerStrike))

        XCTAssertEqual(events, [
            .classActionCast(heroSlot: 0, actionID: .powerStrike),
            .powerStrike(heroSlot: 0, damage: 25),
        ])
        XCTAssertEqual(simulation.state.enemy.currentHealth, 75)
        XCTAssertEqual(simulation.state.party.heroes[0].classAction.cooldownRemaining, try duration(seconds: 6))
        XCTAssertGreaterThan(simulation.presentation.rollingDPS, 0)
    }

    func testLethalPowerStrikeCompletesVictoryExactlyOnceAndCarriesCooldown() throws {
        var state = GameState.newGame(classID: .dps, balance: .standard, progression: .standard)
        state.enemy.currentHealth = 1
        var simulation = GameSimulation(state: state)

        let events = try simulation.apply(.castAction(heroSlot: 0, actionID: .powerStrike))

        XCTAssertEqual(events.filter {
            if case .victory = $0 { return true }
            return false
        }.count, 1)
        XCTAssertEqual(simulation.state.encounter.enemyLevel, 2)
        XCTAssertEqual(simulation.state.party.heroes[0].classAction.cooldownRemaining, try duration(seconds: 6))
    }

    func testMendTargetsLowestLivingRatioAndDoesNotRevive() throws {
        var state = partyState(classes: [.healer, .tank, .dps])
        state.party.heroes[0].combat.currentHealth = 80
        state.party.heroes[1].combat.currentHealth = 50
        state.party.heroes[2].combat.currentHealth = 0
        state.party.heroes[2].wasDownThisEncounter = true
        var simulation = GameSimulation(state: state)

        let events = try simulation.apply(.castAction(heroSlot: 0, actionID: .mend))

        XCTAssertEqual(events.first, .classActionCast(heroSlot: 0, actionID: .mend))
        XCTAssertTrue(events.contains(where: {
            if case .mended(casterSlot: 0, targetSlot: 1, amount: _) = $0 { return true }
            return false
        }))
        XCTAssertGreaterThan(simulation.state.party.heroes[1].combat.currentHealth, 50)
        XCTAssertEqual(simulation.state.party.heroes[2].combat.currentHealth, 0)
    }

    func testFullHealthMendRejectsWithoutCooldown() throws {
        var simulation = GameSimulation(
            state: GameState.newGame(classID: .healer, balance: .standard, progression: .standard)
        )
        let before = simulation.state

        XCTAssertEqual(try simulation.apply(.castAction(heroSlot: 0, actionID: .mend)), [
            .classActionRejected(heroSlot: 0, actionID: .mend, reason: .noValidTarget)
        ])
        XCTAssertEqual(simulation.state, before)
    }

    private func partyState(classes: [HeroClassID]) -> GameState {
        var state = GameState.newGame(classID: classes[0], balance: .standard, progression: .standard)
        let heroes = classes.map {
            GameState.newGame(classID: $0, balance: .standard, progression: .standard).party.heroes[0]
        }
        let unlocks: PartyUnlockState = classes.count == 3 ? .complete : .secondUnlocked
        state.party = PartyState(heroes: heroes, unlocks: unlocks)
        return state
    }

    private func duration(seconds: Int64) throws -> SimulationDuration {
        try XCTUnwrap(.seconds(seconds))
    }

    private func duration(milliseconds: Int64) throws -> SimulationDuration {
        try XCTUnwrap(.milliseconds(milliseconds))
    }
}
