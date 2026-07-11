enum SimulationError: Error, Equatable {
    case invalidElapsed
    case invalidTimer
    case invalidState
    case invalidBalance
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
        try validateStateAndBalance()

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
                    heroWon = try resolveHeroAction(into: &events)
                }

                if enemyReady, !heroWon, state.encounter.phase == .active {
                    try resolveEnemyAction(into: &events)
                }

            case .reviving:
                let step = min(remaining, state.encounter.reviveRemaining)
                if step > .zero {
                    state.encounter.reviveRemaining = try subtracting(step, from: state.encounter.reviveRemaining)
                    remaining = try subtracting(step, from: remaining)
                }

                guard state.encounter.reviveRemaining == .zero else { return events }
                let enemyLevel = state.encounter.enemyLevel
                try finishRevive()
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

    private mutating func resolveHeroAction(into events: inout [GameEvent]) throws -> Bool {
        switch policy.action(for: .hero, in: state) {
        case .basicAttack:
            let damage = try damage(attacker: .hero, defender: .enemy)
            let enemyHealth = try health(afterTaking: damage, from: state.enemy.currentHealth)
            let heroDamage = try adding(damage, to: state.encounter.heroDamage)
            state.enemy.currentHealth = enemyHealth
            state.hero.timeUntilNextAttack = state.hero.attackInterval
            state.encounter.heroDamage = heroDamage
            events.append(.attack(attacker: .hero, defender: .enemy, damage: damage))

            guard state.enemy.currentHealth == 0 else { return false }
            let defeatedLevel = state.encounter.enemyLevel
            events.append(.victory(defeatedLevel: defeatedLevel))
            try beginNextEncounter()
            return true
        }
    }

    private mutating func resolveEnemyAction(into events: inout [GameEvent]) throws {
        switch policy.action(for: .enemy, in: state) {
        case .basicAttack:
            let damage = try damage(attacker: .enemy, defender: .hero)
            let heroHealth = try health(afterTaking: damage, from: state.hero.currentHealth)
            state.hero.currentHealth = heroHealth
            state.enemy.timeUntilNextAttack = state.enemy.attackInterval
            events.append(.attack(attacker: .enemy, defender: .hero, damage: damage))

            guard state.hero.currentHealth == 0 else { return }
            let enemyLevel = state.encounter.enemyLevel
            events.append(.defeat(enemyLevel: enemyLevel))
            try beginRevive()
        }
    }

    private func damage(attacker: CombatantID, defender: CombatantID) throws -> Int {
        let attack = try effectiveAttack(for: attacker)
        let defense = try effectiveDefense(for: defender)
        let (difference, overflow) = attack.subtractingReportingOverflow(defense)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        return max(1, difference)
    }

    private func effectiveAttack(for combatant: CombatantID) throws -> Int {
        let baseAttack = combatant == .hero ? state.hero.baseAttack : state.enemy.baseAttack
        guard combatant == .hero,
              let weapon = try equippedItem(in: .weapon) else {
            return baseAttack
        }
        return try adding(weapon.primaryStat, to: baseAttack)
    }

    private func effectiveDefense(for combatant: CombatantID) throws -> Int {
        let baseDefense = combatant == .hero ? state.hero.baseDefense : state.enemy.baseDefense
        guard combatant == .hero,
              let armor = try equippedItem(in: .armor) else {
            return baseDefense
        }
        return try adding(armor.primaryStat, to: baseDefense)
    }

    private mutating func consumeActiveTime(_ elapsed: SimulationDuration) throws {
        state.hero.timeUntilNextAttack = try subtracting(elapsed, from: state.hero.timeUntilNextAttack)
        state.enemy.timeUntilNextAttack = try subtracting(elapsed, from: state.enemy.timeUntilNextAttack)
        state.encounter.activeElapsed = try adding(elapsed, to: state.encounter.activeElapsed)
    }

    private mutating func beginNextEncounter() throws {
        let (enemyLevel, overflow) = state.encounter.enemyLevel.addingReportingOverflow(1)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        guard let enemy = balance.enemy(level: enemyLevel) else {
            throw SimulationError.invalidBalance
        }
        state.encounter.enemyLevel = enemyLevel
        state.hero.currentHealth = state.hero.maxHealth
        state.enemy = enemy
        resetEncounterMetrics(phase: .active, reviveRemaining: .zero)
    }

    private mutating func beginRevive() throws {
        guard balance.reviveDelay >= .zero, balance.reviveDelay <= .maximumAdvance else {
            throw SimulationError.invalidBalance
        }
        state.encounter.phase = .reviving
        state.encounter.reviveRemaining = balance.reviveDelay
    }

    private mutating func finishRevive() throws {
        guard let enemy = balance.enemy(level: state.encounter.enemyLevel) else {
            throw SimulationError.invalidBalance
        }
        state.hero.currentHealth = state.hero.maxHealth
        state.enemy = enemy
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

    private func validateStateAndBalance() throws {
        try validateBalance()
        try validateCombatant(state.hero, expectedID: .hero)
        try validateCombatant(state.enemy, expectedID: .enemy)

        guard state.encounter.enemyLevel >= 1,
              state.encounter.heroDamage >= 0 else {
            throw SimulationError.invalidState
        }

        switch state.encounter.phase {
        case .active:
            guard state.hero.currentHealth > 0,
                  state.enemy.currentHealth > 0,
                  state.encounter.reviveRemaining == .zero else {
                throw SimulationError.invalidState
            }
        case .reviving:
            guard state.hero.currentHealth == 0,
                  state.enemy.currentHealth > 0,
                  state.encounter.reviveRemaining <= balance.reviveDelay else {
                throw SimulationError.invalidState
            }
        }

        _ = try equippedItem(in: .weapon)
        _ = try equippedItem(in: .armor)
        try validateEnemyScaling()
        try validateTimerState()
    }

    private func validateBalance() throws {
        guard balance.heroMaxHealth > 0,
              balance.heroBaseAttack >= 0,
              balance.heroBaseDefense >= 0,
              balance.enemyBaseHealth > 0,
              balance.enemyBaseAttack >= 0,
              balance.enemyBaseDefense >= 0,
              balance.heroAttackInterval >= .minimumAttackInterval,
              balance.enemyAttackInterval >= .minimumAttackInterval,
              balance.reviveDelay >= .zero,
              balance.reviveDelay <= .maximumAdvance else {
            throw SimulationError.invalidBalance
        }
    }

    private func validateCombatant(_ combatant: CombatantState, expectedID: CombatantID) throws {
        guard combatant.id == expectedID,
              combatant.maxHealth > 0,
              combatant.currentHealth >= 0,
              combatant.currentHealth <= combatant.maxHealth,
              combatant.baseAttack >= 0,
              combatant.baseDefense >= 0 else {
            throw SimulationError.invalidState
        }
    }

    private func validateEnemyScaling() throws {
        guard balance.enemy(level: state.encounter.enemyLevel) != nil else {
            throw SimulationError.invalidBalance
        }
        let (nextLevel, overflow) = state.encounter.enemyLevel.addingReportingOverflow(1)
        guard !overflow, balance.enemy(level: nextLevel) != nil else {
            throw SimulationError.invalidBalance
        }
    }

    private func equippedItem(in slot: EquipmentSlot) throws -> Item? {
        guard let itemID = state.equipment[slot] else { return nil }
        let items = state.inventory.filter { $0.id == itemID }
        guard items.count == 1,
              let item = items.first,
              item.slot == slot,
              item.level >= 1,
              item.primaryStat >= 0 else {
            throw SimulationError.invalidState
        }

        let baseStat = slot == .weapon ? state.hero.baseAttack : state.hero.baseDefense
        let (_, overflow) = baseStat.addingReportingOverflow(item.primaryStat)
        guard !overflow else { throw SimulationError.invalidState }
        return item
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
              state.encounter.reviveRemaining <= .maximumAdvance else {
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

    private func adding(_ amount: Int, to value: Int) throws -> Int {
        let (result, overflow) = value.addingReportingOverflow(amount)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        return result
    }

    private func health(afterTaking damage: Int, from currentHealth: Int) throws -> Int {
        let (remaining, overflow) = currentHealth.subtractingReportingOverflow(damage)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        return max(0, remaining)
    }
}
