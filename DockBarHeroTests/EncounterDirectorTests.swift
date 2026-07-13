import XCTest
@testable import DockBarHero

final class EncounterDirectorTests: XCTestCase {
    func testFarmingVictoryRepeatsSelectionWithoutLoweringFrontier() throws {
        let state = try fixture(frontier: 50, selected: 24, mode: .farming)

        let result = try EncounterDirector().completeVictory(in: state, balance: .standard)

        XCTAssertEqual(result.campaign.highestUnlockedLevel, 50)
        XCTAssertEqual(result.campaign.selectedLevel, 24)
        XCTAssertEqual(result.encounter.enemyLevel, 24)
    }

    func testQueuedChoiceOverridesThirdDefeatFallback() throws {
        var state = try fixture(frontier: 174, selected: 174, mode: .push)
        state.campaign.consecutiveDefeats = 2
        state = try EncounterDirector().queue(level: 100, in: state)

        XCTAssertEqual(state.campaign.selectedLevel, 174)
        state = try EncounterDirector().beginDefeat(in: state, balance: .standard)
        state = try EncounterDirector().finishRevive(in: state, balance: .standard)

        XCTAssertEqual(state.campaign.selectedLevel, 100)
        XCTAssertEqual(state.campaign.mode, .farming)
        XCTAssertEqual(state.campaign.consecutiveDefeats, 0)
    }

    func testApprovedFallbacks() throws {
        XCTAssertEqual(try EncounterDirector().fallback(afterFailing: 25), 24)
        XCTAssertEqual(try EncounterDirector().fallback(afterFailing: 50), 24)
        XCTAssertEqual(try EncounterDirector().fallback(afterFailing: 75), 49)
        XCTAssertEqual(try EncounterDirector().fallback(afterFailing: 174), 149)
    }

    func testThirdFrontierDefeatRetreatsWithoutLoweringFrontier() throws {
        var state = try fixture(frontier: 174, selected: 174, mode: .push)
        state.campaign.consecutiveDefeats = 2

        state = try EncounterDirector().beginDefeat(in: state, balance: .standard)
        state = try EncounterDirector().finishRevive(in: state, balance: .standard)

        XCTAssertEqual(state.campaign.highestUnlockedLevel, 174)
        XCTAssertEqual(state.campaign.selectedLevel, 149)
        XCTAssertEqual(state.campaign.mode, .farming)
        XCTAssertEqual(state.campaign.consecutiveDefeats, 0)
        XCTAssertEqual(state.encounter.enemyLevel, 149)
        XCTAssertEqual(state.encounter.tier, .normal)
    }


    func testQueueLeavesActiveEncounterUntouched() throws {
        let state = try fixture(frontier: 10, selected: 10, mode: .push)

        let result = try EncounterDirector().queue(level: 5, in: state)

        XCTAssertEqual(result.campaign.selectedLevel, 10)
        XCTAssertEqual(result.campaign.queuedLevel, 5)
        XCTAssertEqual(result.enemy, state.enemy)
        XCTAssertEqual(result.encounter, state.encounter)
    }

    func testBeginNextEncounterBuildsScheduledElite() throws {
        var state = GameState.newGame(balance: .standard)
        state.encounter.enemyLevel = 4
        state.campaign.highestUnlockedLevel = 4
        state.campaign.selectedLevel = 4

        let result = try EncounterDirector().beginNextEncounter(in: state, balance: .standard)

        XCTAssertEqual(result.encounter.enemyLevel, 5)
        XCTAssertEqual(result.encounter.tier, .elite)
        XCTAssertEqual(result.enemy.maxHealth, 54)
    }

    func testBeginNextEncounterCreatesNextLevelAndResetsHeroAndTimers() throws {
        var state = GameState.newGame(balance: .standard)
        state.hero.currentHealth = 1
        state.hero.timeUntilNextAttack = .zero
        state.enemy.timeUntilNextAttack = .zero
        state.encounter.activeElapsed = .nanoseconds(4)
        state.encounter.heroDamage = 12

        let result = try EncounterDirector().beginNextEncounter(in: state, balance: .standard)

        XCTAssertEqual(result.encounter.enemyLevel, 2)
        XCTAssertEqual(result.hero.currentHealth, result.hero.maxHealth)
        XCTAssertEqual(result.enemy, BalanceConfiguration.standard.enemy(level: 2))
        XCTAssertEqual(result.encounter.phase, .active)
        XCTAssertEqual(result.encounter.activeElapsed, .zero)
        XCTAssertEqual(result.encounter.heroDamage, 0)
        XCTAssertEqual(result.encounter.reviveRemaining, .zero)
        XCTAssertEqual(result.hero.timeUntilNextAttack, result.hero.attackInterval)
        XCTAssertEqual(result.enemy.timeUntilNextAttack, result.enemy.attackInterval)
    }

    func testBeginReviveResetsEncounterMetricsAndUsesBalanceDelay() throws {
        var state = GameState.newGame(balance: .standard)
        state.hero.currentHealth = 0
        state.hero.timeUntilNextAttack = .nanoseconds(111)
        state.enemy.timeUntilNextAttack = .nanoseconds(222)
        state.encounter.activeElapsed = .nanoseconds(4)
        state.encounter.heroDamage = 12

        let result = try EncounterDirector().beginRevive(in: state, balance: .standard)

        XCTAssertEqual(result.encounter.phase, .reviving)
        XCTAssertEqual(result.encounter.activeElapsed, .zero)
        XCTAssertEqual(result.encounter.heroDamage, 0)
        XCTAssertEqual(result.encounter.reviveRemaining, BalanceConfiguration.standard.reviveDelay)
        XCTAssertEqual(result.hero.timeUntilNextAttack, .nanoseconds(111))
        XCTAssertEqual(result.enemy.timeUntilNextAttack, .nanoseconds(222))
    }

    func testFinishReviveRestoresSameEnemyAndTimers() throws {
        var state = GameState.newGame(balance: .standard)
        state.hero.currentHealth = 0
        state.encounter.phase = .reviving
        state.encounter.reviveRemaining = .zero

        let result = try EncounterDirector().finishRevive(in: state, balance: .standard)

        XCTAssertEqual(result.encounter.enemyLevel, 1)
        XCTAssertEqual(result.hero.currentHealth, result.hero.maxHealth)
        XCTAssertEqual(result.enemy.currentHealth, result.enemy.maxHealth)
        XCTAssertEqual(result.encounter.phase, .active)
        XCTAssertEqual(result.encounter.activeElapsed, .zero)
        XCTAssertEqual(result.encounter.heroDamage, 0)
        XCTAssertEqual(result.encounter.reviveRemaining, .zero)
        XCTAssertEqual(result.hero.timeUntilNextAttack, result.hero.attackInterval)
        XCTAssertEqual(result.enemy.timeUntilNextAttack, result.enemy.attackInterval)
    }

    func testBeginNextEncounterRejectsEnemyLevelOverflow() {
        var state = GameState.newGame(balance: .standard)
        state.encounter.enemyLevel = .max
        state.campaign.highestUnlockedLevel = .max
        state.campaign.selectedLevel = .max
        let original = state

        XCTAssertThrowsError(try EncounterDirector().beginNextEncounter(in: state, balance: .standard)) { error in
            XCTAssertEqual(error as? SimulationError, .arithmeticOverflow)
        }
        XCTAssertEqual(state, original)
    }

    func testBeginReviveRejectsInvalidBalance() {
        let invalidBalance = BalanceConfiguration(
            heroMaxHealth: 100,
            heroBaseAttack: 10,
            heroBaseDefense: 0,
            heroAttackInterval: .nanoseconds(1_000_000_000),
            enemyBaseHealth: 30,
            enemyBaseAttack: 3,
            enemyBaseDefense: 0,
            enemyAttackInterval: .nanoseconds(1_500_000_000),
            reviveDelay: .nanoseconds(-1)
        )
        let state = GameState.newGame(balance: .standard)

        XCTAssertThrowsError(try EncounterDirector().beginRevive(in: state, balance: invalidBalance)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidBalance)
        }
    }

    func testCompletingSecondUnlockSeedsHighestLevelAndResumesDeferredVictory() throws {
        var state = try fixture(frontier: 25, selected: 25, mode: .push)
        state.party.heroes[0].level = 7
        state.enemy.currentHealth = 0
        state.encounter.phase = .awaitingPartyChoice
        state.party.unlocks = .pendingSecond(PendingPartyUnlock(
            milestone: .boss25,
            choices: [.tank, .healer]
        ))

        let result = try PartyUnlockResolver().completeSecondUnlock(
            classID: .healer,
            in: state,
            balance: .standard
        )

        XCTAssertEqual(result.party.heroes.map(\.classID), [.dps, .healer])
        XCTAssertEqual(result.party.heroes[1].level, 7)
        XCTAssertEqual(result.party.heroes[1].currentXP, 0)
        XCTAssertEqual(result.party.unlocks, .secondUnlocked)
        XCTAssertEqual(result.encounter.phase, .active)
        XCTAssertEqual(result.encounter.enemyLevel, 26)
    }

    func testBoss100AutomaticallyAddsFinalMissingClassOnce() throws {
        var state = try fixture(frontier: 100, selected: 100, mode: .push)
        let tank = GameState.newGame(classID: .tank, balance: .standard, progression: .standard).party.heroes[0]
        state.party = PartyState(heroes: [state.party.heroes[0], tank], unlocks: .secondUnlocked)

        let result = try PartyUnlockResolver().addFinalHeroIfEarned(
            afterDefeating: 100,
            in: state,
            balance: .standard
        )

        XCTAssertEqual(result.party.heroes.map(\.classID), [.dps, .tank, .healer])
        XCTAssertEqual(result.party.unlocks, .complete)
        XCTAssertEqual(try PartyUnlockResolver().addFinalHeroIfEarned(
            afterDefeating: 100,
            in: result,
            balance: .standard
        ), result)
    }

    private func fixture(
        frontier: Int,
        selected: Int,
        mode: CampaignMode
    ) throws -> GameState {
        var state = try GameState.newGame(
            classID: .dps,
            balance: .standard,
            progression: .standard
        )
        let tier = try XCTUnwrap(EncounterSchedule.standard.tier(for: selected))
        state.campaign = CampaignState(
            highestUnlockedLevel: frontier,
            selectedLevel: selected,
            queuedLevel: nil,
            mode: mode,
            consecutiveDefeats: 0
        )
        state.encounter.enemyLevel = selected
        state.encounter.tier = tier
        state.enemy = try XCTUnwrap(
            BalanceConfiguration.standard.enemy(
                level: selected,
                tier: tier,
                progression: .standard
            )
        )
        return state
    }
}
