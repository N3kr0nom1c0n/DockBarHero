struct EncounterDirector: Sendable {
    func beginNextEncounter(in state: GameState, balance: BalanceConfiguration) throws -> GameState {
        try completeVictory(in: state, balance: balance)
    }

    func queue(level: Int, in state: GameState) throws -> GameState {
        guard level >= 1, level < state.campaign.highestUnlockedLevel else {
            throw SimulationError.invalidState
        }
        var result = state
        result.campaign.queuedLevel = level
        return result
    }

    func queueFrontier(in state: GameState) throws -> GameState {
        guard state.campaign.highestUnlockedLevel >= 1 else {
            throw SimulationError.invalidState
        }
        var result = state
        result.campaign.queuedLevel = result.campaign.highestUnlockedLevel
        return result
    }

    func completeVictory(in state: GameState, balance: BalanceConfiguration) throws -> GameState {
        guard state.campaign.selectedLevel == state.encounter.enemyLevel else {
            throw SimulationError.invalidState
        }
        var result = state

        if let queued = result.campaign.queuedLevel {
            let mode: CampaignMode = queued == result.campaign.highestUnlockedLevel ? .push : .farming
            return try activate(
                level: queued,
                mode: mode,
                resetDefeats: true,
                in: result,
                balance: balance
            )
        }

        switch result.campaign.mode {
        case .farming:
            return try activate(
                level: result.campaign.selectedLevel,
                mode: .farming,
                resetDefeats: true,
                in: result,
                balance: balance
            )
        case .push:
            guard result.campaign.selectedLevel == result.campaign.highestUnlockedLevel else {
                throw SimulationError.invalidState
            }
            let (nextLevel, overflow) = result.campaign.highestUnlockedLevel.addingReportingOverflow(1)
            guard !overflow else { throw SimulationError.arithmeticOverflow }
            result.campaign.highestUnlockedLevel = nextLevel
            return try activate(
                level: nextLevel,
                mode: .push,
                resetDefeats: true,
                in: result,
                balance: balance
            )
        }
    }

    func beginDefeat(in state: GameState, balance: BalanceConfiguration) throws -> GameState {
        var result = state
        let (streak, overflow) = result.campaign.consecutiveDefeats.addingReportingOverflow(1)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        result.campaign.consecutiveDefeats = streak
        return try beginRevive(in: result, balance: balance)
    }

    func fallback(afterFailing level: Int) throws -> Int {
        guard level >= 1 else { throw SimulationError.invalidState }
        if level <= 25 {
            var candidate = max(1, level - 1)
            while candidate > 1, EncounterSchedule.standard.tier(for: candidate) != .normal {
                candidate -= 1
            }
            return candidate
        }

        var boundary = level / 25
        if !level.isMultiple(of: 25) {
            let (incremented, overflow) = boundary.addingReportingOverflow(1)
            guard !overflow else { throw SimulationError.arithmeticOverflow }
            boundary = incremented
        }
        let (scaledBoundary, multiplyOverflow) = boundary.multipliedReportingOverflow(by: 25)
        guard !multiplyOverflow else { throw SimulationError.arithmeticOverflow }
        let (destination, subtractOverflow) = scaledBoundary.subtractingReportingOverflow(26)
        guard !subtractOverflow, destination >= 1 else { throw SimulationError.arithmeticOverflow }
        return destination
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
        if let queued = state.campaign.queuedLevel {
            let mode: CampaignMode = queued == state.campaign.highestUnlockedLevel ? .push : .farming
            return try activate(
                level: queued,
                mode: mode,
                resetDefeats: true,
                in: state,
                balance: balance
            )
        }
        if state.campaign.consecutiveDefeats >= 3 {
            return try activate(
                level: fallback(afterFailing: state.campaign.selectedLevel),
                mode: .farming,
                resetDefeats: true,
                in: state,
                balance: balance
            )
        }

        return try activate(
            level: state.campaign.selectedLevel,
            mode: state.campaign.mode,
            resetDefeats: false,
            in: state,
            balance: balance
        )
    }

    private func activate(
        level: Int,
        mode: CampaignMode,
        resetDefeats: Bool,
        in state: GameState,
        balance: BalanceConfiguration
    ) throws -> GameState {
        guard level >= 1,
              level <= state.campaign.highestUnlockedLevel,
              let tier = EncounterSchedule.standard.tier(for: level),
              let enemy = balance.enemy(level: level, tier: tier, progression: .standard) else {
            throw SimulationError.invalidBalance
        }

        var result = state
        result.campaign.selectedLevel = level
        result.campaign.queuedLevel = nil
        result.campaign.mode = mode
        if resetDefeats {
            result.campaign.consecutiveDefeats = 0
        }
        result.encounter.enemyLevel = level
        result.encounter.tier = tier
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
