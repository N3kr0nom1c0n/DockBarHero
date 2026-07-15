import XCTest
@testable import DockBarHero

final class ClassActionsViewTests: XCTestCase {
    func testCardsRemainInPartyOrderAndExposeCooldownReason() throws {
        var state = partyState(classes: [.dps, .healer])
        state.party.heroes[0].classAction.cooldownRemaining = try XCTUnwrap(.seconds(2))
        state.party.heroes[1].combat.currentHealth -= 1

        let cards = ClassActionCard.cards(for: state)

        XCTAssertEqual(cards.map(\.title), ["Power Strike", "Mend"])
        XCTAssertEqual(cards[0].disabledReason, "Ready in 2.0s")
        XCTAssertNil(cards[1].disabledReason)
        XCTAssertEqual(cards.map(\.heroLabel), ["Hero 1 · DPS", "Hero 2 · Healer"])
    }

    func testFullHealthMendAndActiveGuardExplainDisabledState() {
        var state = partyState(classes: [.tank, .healer])
        state.party.heroes[0].classAction.guardActive = true

        let cards = ClassActionCard.cards(for: state)

        XCTAssertEqual(cards[0].disabledReason, "Guard is already active")
        XCTAssertEqual(cards[1].disabledReason, "Everyone is at full health")
    }

    func testInactiveEncounterDisablesEveryCard() {
        var state = partyState(classes: [.dps, .healer])
        state.encounter.phase = .awaitingPartyChoice

        XCTAssertTrue(ClassActionCard.cards(for: state).allSatisfy {
            $0.disabledReason == "Encounter inactive"
        })
    }

    private func partyState(classes: [HeroClassID]) -> GameState {
        var state = GameState.newGame(classID: classes[0], balance: .standard, progression: .standard)
        state.party = PartyState(
            heroes: classes.map {
                GameState.newGame(classID: $0, balance: .standard, progression: .standard).party.heroes[0]
            },
            unlocks: classes.count == 3 ? .complete : .secondUnlocked
        )
        return state
    }
}
