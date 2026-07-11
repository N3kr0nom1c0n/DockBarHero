enum SimulationError: Error, Equatable {
    case invalidElapsed
    case invalidTimer
    case arithmeticOverflow
}

struct GameSimulation {
    private(set) var state: GameState
    let balance: BalanceConfiguration
    private let policy: any ActionPolicy

    init(balance: BalanceConfiguration = .standard, policy: any ActionPolicy = BasicAttackPolicy()) {
        self.state = .newGame(balance: balance)
        self.balance = balance
        self.policy = policy
    }

    init(state: GameState, balance: BalanceConfiguration = .standard, policy: any ActionPolicy = BasicAttackPolicy()) {
        self.state = state
        self.balance = balance
        self.policy = policy
    }

    mutating func advance(by elapsed: SimulationDuration) throws -> [GameEvent] {
        guard elapsed >= .zero, elapsed <= .maximumAdvance else {
            throw SimulationError.invalidElapsed
        }

        var candidate = self
        let events = try candidate.advanceCandidate(by: elapsed)
        self = candidate
        return events
    }

    private mutating func advanceCandidate(by elapsed: SimulationDuration) throws -> [GameEvent] {
        try validateTimerState()

        var remaining = elapsed
        var events: [GameEvent] = []

        while true {
            switch state.encounter.phase {
            case .active:
                let step = min(remaining, state.hero.timeUntilNextAttack, state.enemy.timeUntilNextAttack)
                if step > .zero {
                    try consumeActiveTime(step)
                    remaining = try subtracting(step, from: remaining)
                }

                let heroReady = state.hero.timeUntilNextAttack == .zero
                let enemyReady = state.enemy.timeUntilNextAttack == .zero
                guard heroReady || enemyReady else { return events }

                var heroWon = false
                if heroReady {
                    heroWon = resolveHeroAction(into: &events)
                }

                if enemyReady, !heroWon, state.encounter.phase == .active {
                    resolveEnemyAction(into: &events)
                }

            case .reviving:
                let step = min(remaining, state.encounter.reviveRemaining)
                if step > .zero {
                    state.encounter.reviveRemaining = try subtracting(step, from: state.encounter.reviveRemaining)
                    remaining = try subtracting(step, from: remaining)
                }

                guard state.encounter.reviveRemaining == .zero else { return events }
                let enemyLevel = state.encounter.enemyLevel
                finishRevive()
                events.append(.revived(enemyLevel: enemyLevel))
            }

            if remaining == .zero {
                let hasReadyActor = state.encounter.phase == .active &&
                    (state.hero.timeUntilNextAttack == .zero || state.enemy.timeUntilNextAttack == .zero)
                let reviveIsDue = state.encounter.phase == .reviving && state.encounter.reviveRemaining == .zero
                if !hasReadyActor && !reviveIsDue {
                    return events
                }
            }
        }
    }

    private mutating func resolveHeroAction(into events: inout [GameEvent]) -> Bool {
        switch policy.action(for: .hero, in: state) {
        case .basicAttack:
            let damage = damage(attacker: .hero, defender: .enemy)
            state.enemy.currentHealth = max(0, state.enemy.currentHealth - damage)
            state.hero.timeUntilNextAttack = state.hero.attackInterval
            state.encounter.heroDamage += damage
            events.append(.attack(attacker: .hero, defender: .enemy, damage: damage))

            guard state.enemy.currentHealth == 0 else { return false }
            let defeatedLevel = state.encounter.enemyLevel
            events.append(.victory(defeatedLevel: defeatedLevel))
            beginNextEncounter()
            return true
        }
    }

    private mutating func resolveEnemyAction(into events: inout [GameEvent]) {
        switch policy.action(for: .enemy, in: state) {
        case .basicAttack:
            let damage = damage(attacker: .enemy, defender: .hero)
            state.hero.currentHealth = max(0, state.hero.currentHealth - damage)
            state.enemy.timeUntilNextAttack = state.enemy.attackInterval
            events.append(.attack(attacker: .enemy, defender: .hero, damage: damage))

            guard state.hero.currentHealth == 0 else { return }
            let enemyLevel = state.encounter.enemyLevel
            events.append(.defeat(enemyLevel: enemyLevel))
            beginRevive()
        }
    }

    private func damage(attacker: CombatantID, defender: CombatantID) -> Int {
        max(1, effectiveAttack(for: attacker) - effectiveDefense(for: defender))
    }

    private func effectiveAttack(for combatant: CombatantID) -> Int {
        let baseAttack = combatant == .hero ? state.hero.baseAttack : state.enemy.baseAttack
        guard combatant == .hero,
              let weaponID = state.equipment.weaponID,
              let weapon = state.inventory.first(where: { $0.id == weaponID }),
              weapon.slot == .weapon else {
            return baseAttack
        }
        return baseAttack + weapon.primaryStat
    }

    private func effectiveDefense(for combatant: CombatantID) -> Int {
        let baseDefense = combatant == .hero ? state.hero.baseDefense : state.enemy.baseDefense
        guard combatant == .hero,
              let armorID = state.equipment.armorID,
              let armor = state.inventory.first(where: { $0.id == armorID }),
              armor.slot == .armor else {
            return baseDefense
        }
        return baseDefense + armor.primaryStat
    }

    private mutating func consumeActiveTime(_ elapsed: SimulationDuration) throws {
        state.hero.timeUntilNextAttack = try subtracting(elapsed, from: state.hero.timeUntilNextAttack)
        state.enemy.timeUntilNextAttack = try subtracting(elapsed, from: state.enemy.timeUntilNextAttack)
        state.encounter.activeElapsed = try adding(elapsed, to: state.encounter.activeElapsed)
    }

    private mutating func beginNextEncounter() {
        state.encounter.enemyLevel += 1
        state.hero.currentHealth = state.hero.maxHealth
        state.enemy = balance.enemy(level: state.encounter.enemyLevel)
        resetEncounterMetrics(phase: .active, reviveRemaining: .zero)
    }

    private mutating func beginRevive() {
        state.encounter.phase = .reviving
        state.encounter.reviveRemaining = balance.reviveDelay
    }

    private mutating func finishRevive() {
        state.hero.currentHealth = state.hero.maxHealth
        state.enemy = balance.enemy(level: state.encounter.enemyLevel)
        resetEncounterMetrics(phase: .active, reviveRemaining: .zero)
    }

    private mutating func resetEncounterMetrics(phase: EncounterPhase, reviveRemaining: SimulationDuration) {
        state.encounter.phase = phase
        state.encounter.activeElapsed = .zero
        state.encounter.heroDamage = 0
        state.encounter.reviveRemaining = reviveRemaining
        state.hero.timeUntilNextAttack = state.hero.attackInterval
        state.enemy.timeUntilNextAttack = state.enemy.attackInterval
    }

    private func validateTimerState() throws {
        let attackIntervals = [
            state.hero.attackInterval,
            state.enemy.attackInterval,
            balance.heroAttackInterval,
            balance.enemyAttackInterval
        ]
        let countdowns = [
            state.hero.timeUntilNextAttack,
            state.enemy.timeUntilNextAttack
        ]

        guard attackIntervals.allSatisfy({ $0 >= .minimumAttackInterval }),
              countdowns.allSatisfy({ $0 >= .zero }),
              state.encounter.activeElapsed >= .zero,
              state.encounter.reviveRemaining >= .zero,
              state.encounter.reviveRemaining <= .maximumAdvance,
              balance.reviveDelay >= .zero,
              balance.reviveDelay <= .maximumAdvance else {
            throw SimulationError.invalidTimer
        }
    }

    private func adding(_ amount: SimulationDuration, to value: SimulationDuration) throws -> SimulationDuration {
        let (rawValue, overflow) = value.rawValue.addingReportingOverflow(amount.rawValue)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        return SimulationDuration(rawValue: rawValue)
    }

    private func subtracting(_ amount: SimulationDuration, from value: SimulationDuration) throws -> SimulationDuration {
        let (rawValue, overflow) = value.rawValue.subtractingReportingOverflow(amount.rawValue)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        return SimulationDuration(rawValue: rawValue)
    }
}
