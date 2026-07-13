import XCTest
@testable import DockBarHero

final class ClassActionCooldownTests: XCTestCase {
    func testLivingCooldownConsumesActiveTimePartitionInvariant() throws {
        var state = GameState.newGame(classID: .dps, balance: .standard, progression: .standard)
        state.party.heroes[0].classAction.cooldownRemaining = try duration(seconds: 6)
        var whole = GameSimulation(state: state)
        var partitioned = GameSimulation(state: state)

        let wholeEvents = try whole.advance(by: try duration(seconds: 2))
        var partitionedEvents: [GameEvent] = []
        partitionedEvents += try partitioned.advance(by: try duration(seconds: 1))
        partitionedEvents += try partitioned.advance(by: try duration(seconds: 1))

        XCTAssertEqual(whole.state, partitioned.state)
        XCTAssertEqual(wholeEvents, partitionedEvents)
        XCTAssertEqual(whole.state.party.heroes[0].classAction.cooldownRemaining, try duration(seconds: 4))
    }

    func testDownedHeroCooldownFreezesWhileLivingHeroAdvances() throws {
        var state = twoHeroState()
        state.party.heroes[0].combat.currentHealth = 0
        state.party.heroes[0].wasDownThisEncounter = true
        state.party.heroes[0].classAction.cooldownRemaining = try duration(seconds: 5)
        state.party.heroes[1].classAction.cooldownRemaining = try duration(seconds: 5)
        var simulation = GameSimulation(state: state)

        _ = try simulation.advance(by: try duration(milliseconds: 500))

        XCTAssertEqual(simulation.state.party.heroes[0].classAction.cooldownRemaining, try duration(seconds: 5))
        XCTAssertEqual(simulation.state.party.heroes[1].classAction.cooldownRemaining, try duration(milliseconds: 4_500))
    }

    func testCooldownCrossingZeroEmitsReadyExactlyOnce() throws {
        var state = GameState.newGame(classID: .healer, balance: .standard, progression: .standard)
        state.party.heroes[0].classAction.cooldownRemaining = try duration(milliseconds: 500)
        var simulation = GameSimulation(state: state)

        let first = try simulation.advance(by: try duration(milliseconds: 500))
        let second = try simulation.advance(by: try duration(milliseconds: 100))

        XCTAssertTrue(first.contains(.classActionReady(heroSlot: 0, actionID: .mend)))
        XCTAssertFalse(second.contains(.classActionReady(heroSlot: 0, actionID: .mend)))
    }

    private func twoHeroState() -> GameState {
        var state = GameState.newGame(classID: .tank, balance: .standard, progression: .standard)
        let second = GameState.newGame(classID: .dps, balance: .standard, progression: .standard).party.heroes[0]
        state.party = PartyState(heroes: [state.party.heroes[0], second], unlocks: .secondUnlocked)
        return state
    }

    private func duration(seconds: Int64) throws -> SimulationDuration {
        try XCTUnwrap(.seconds(seconds))
    }

    private func duration(milliseconds: Int64) throws -> SimulationDuration {
        try XCTUnwrap(.milliseconds(milliseconds))
    }
}
