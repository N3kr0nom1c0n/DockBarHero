struct EncounterDirector: Sendable {
    func beginNextEncounter(in state: GameState, balance: BalanceConfiguration) throws -> GameState {
        var result = state
        let (enemyLevel, overflow) = result.encounter.enemyLevel.addingReportingOverflow(1)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        guard let tier = EncounterSchedule.standard.tier(for: enemyLevel),
              let enemy = balance.enemy(
                level: enemyLevel,
                tier: tier,
                progression: .standard
              ) else {
            throw SimulationError.invalidBalance
        }

        result.encounter.enemyLevel = enemyLevel
        result.encounter.tier = tier
        result.hero.currentHealth = result.hero.maxHealth
        result.enemy = enemy
        resetEncounter(in: &result, phase: .active, reviveRemaining: .zero)
        return result
    }

    func beginRevive(in state: GameState, balance: BalanceConfiguration) throws -> GameState {
        guard balance.reviveDelay >= .zero, balance.reviveDelay <= .maximumAdvance else {
            throw SimulationError.invalidBalance
        }

        var result = state
        result.encounter.phase = .reviving
        result.encounter.activeElapsed = .zero
        result.encounter.heroDamage = 0
        result.encounter.reviveRemaining = balance.reviveDelay
        return result
    }

    func finishRevive(in state: GameState, balance: BalanceConfiguration) throws -> GameState {
        guard let enemy = balance.enemy(
            level: state.encounter.enemyLevel,
            tier: state.encounter.tier,
            progression: .standard
        ) else {
            throw SimulationError.invalidBalance
        }

        var result = state
        result.hero.currentHealth = result.hero.maxHealth
        result.enemy = enemy
        resetEncounter(in: &result, phase: .active, reviveRemaining: .zero)
        return result
    }

    private func resetEncounter(
        in state: inout GameState,
        phase: EncounterPhase,
        reviveRemaining: SimulationDuration
    ) {
        state.encounter.phase = phase
        state.encounter.activeElapsed = .zero
        state.encounter.heroDamage = 0
        state.encounter.reviveRemaining = reviveRemaining
        state.hero.timeUntilNextAttack = state.hero.attackInterval
        state.enemy.timeUntilNextAttack = state.enemy.attackInterval
    }
}
