import XCTest
@testable import DockBarHero

final class ClassActionConfigurationTests: XCTestCase {
    func testStandardDefinitionsMatchApprovedValues() throws {
        let configuration = ClassActionConfiguration.standard

        XCTAssertEqual(try configuration.definition(for: .guardAction).cooldown, try duration(8))
        XCTAssertEqual(try configuration.definition(for: .guardAction).powerBasisPoints, 5_000)
        XCTAssertEqual(try configuration.definition(for: .powerStrike).cooldown, try duration(6))
        XCTAssertEqual(try configuration.definition(for: .powerStrike).powerBasisPoints, 25_000)
        XCTAssertEqual(try configuration.definition(for: .mend).cooldown, try duration(10))
        XCTAssertEqual(try configuration.definition(for: .mend).powerBasisPoints, 3_500)
    }

    func testNewHeroStartsWithAssignedActionReady() {
        for classID in HeroClassID.allCases {
            let hero = GameState.newGame(
                classID: classID,
                balance: .standard,
                progression: .standard
            ).party.heroes[0]

            XCTAssertEqual(hero.classAction.actionID, ClassActionConfiguration.standard.action(for: classID))
            XCTAssertEqual(hero.classAction.cooldownRemaining, .zero)
            XCTAssertFalse(hero.classAction.guardActive)
        }
    }

    func testSaveRejectsWrongClassActionAndExcessCooldown() throws {
        var wrongAction = GameState.newGame(classID: .tank, balance: .standard, progression: .standard)
        wrongAction.party.heroes[0].classAction = ClassActionState(
            actionID: .mend,
            cooldownRemaining: .zero,
            guardActive: false
        )
        XCTAssertThrowsError(try SaveCodec().encode(state: wrongAction, savedAt: .distantPast))

        var excessCooldown = GameState.newGame(classID: .dps, balance: .standard, progression: .standard)
        excessCooldown.party.heroes[0].classAction.cooldownRemaining = try duration(7)
        XCTAssertThrowsError(try SaveCodec().encode(state: excessCooldown, savedAt: .distantPast))
    }

    func testSaveRejectsGuardStateOnNonTank() throws {
        var state = GameState.newGame(classID: .dps, balance: .standard, progression: .standard)
        state.party.heroes[0].classAction.guardActive = true

        XCTAssertThrowsError(try SaveCodec().encode(state: state, savedAt: .distantPast))
    }

    private func duration(_ seconds: Int64) throws -> SimulationDuration {
        try XCTUnwrap(.seconds(seconds))
    }
}
