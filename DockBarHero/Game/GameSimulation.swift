import Foundation

enum SimulationError: Error, Equatable {
    case invalidElapsed
    case invalidTimer
    case eventDensity
}

struct GameSimulation {
    // A finite, positive interval can still be too small to reduce a much larger
    // remaining duration in Double precision. Bound work deterministically and
    // run on a candidate so the caller never observes a partial advance on error.
    private static let maximumScheduledEventsPerAdvance = 100_000

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

    mutating func advance(by elapsed: TimeInterval) throws -> [GameEvent] {
        guard elapsed.isFinite, elapsed >= 0 else {
            throw SimulationError.invalidElapsed
        }

        var candidate = self
        let events = try candidate.advanceCandidate(by: elapsed)
        self = candidate
        return events
    }

    private mutating func advanceCandidate(by elapsed: TimeInterval) throws -> [GameEvent] {
        try validateTimerState()

        var remaining = elapsed
        var events: [GameEvent] = []
        var scheduledEventCount = 0

        while true {
            switch state.encounter.phase {
            case .active:
                let heroCountdown = max(0, state.hero.timeUntilNextAttack)
                let enemyCountdown = max(0, state.enemy.timeUntilNextAttack)
                let step = min(remaining, heroCountdown, enemyCountdown)

                if step > 0 {
                    consumeActiveTime(step)
                    remaining = subtracting(step, from: remaining)
                }

                let heroReady = state.hero.timeUntilNextAttack <= 0
                let enemyReady = state.enemy.timeUntilNextAttack <= 0
                guard heroReady || enemyReady else { break }

                var heroWon = false
                if heroReady {
                    try consumeEventBudget(&scheduledEventCount)
                    heroWon = resolveHeroAction(into: &events)
                }

                if enemyReady, !heroWon, state.encounter.phase == .active {
                    try consumeEventBudget(&scheduledEventCount)
                    resolveEnemyAction(into: &events)
                }

            case .reviving:
                let step = min(remaining, max(0, state.encounter.reviveRemaining))
                if step > 0 {
                    state.encounter.reviveRemaining = subtracting(step, from: state.encounter.reviveRemaining)
                    remaining = subtracting(step, from: remaining)
                }

                guard state.encounter.reviveRemaining <= 0 else { break }
                try consumeEventBudget(&scheduledEventCount)
                let enemyLevel = state.encounter.enemyLevel
                finishRevive()
                events.append(.revived(enemyLevel: enemyLevel))
            }

            if remaining <= 0 {
                let hasReadyActor = state.encounter.phase == .active &&
                    (state.hero.timeUntilNextAttack <= 0 || state.enemy.timeUntilNextAttack <= 0)
                let reviveIsDue = state.encounter.phase == .reviving && state.encounter.reviveRemaining <= 0
                if !hasReadyActor && !reviveIsDue {
                    break
                }
            }
        }

        return events
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

    private mutating func consumeActiveTime(_ elapsed: TimeInterval) {
        state.hero.timeUntilNextAttack = subtracting(elapsed, from: state.hero.timeUntilNextAttack)
        state.enemy.timeUntilNextAttack = subtracting(elapsed, from: state.enemy.timeUntilNextAttack)
        state.encounter.activeElapsed += elapsed
    }

    private mutating func beginNextEncounter() {
        state.encounter.enemyLevel += 1
        state.hero.currentHealth = state.hero.maxHealth
        state.enemy = balance.enemy(level: state.encounter.enemyLevel)
        resetEncounterMetrics(phase: .active, reviveRemaining: 0)
    }

    private mutating func beginRevive() {
        state.encounter.phase = .reviving
        state.encounter.reviveRemaining = balance.reviveDelay
    }

    private mutating func finishRevive() {
        state.hero.currentHealth = state.hero.maxHealth
        state.enemy = balance.enemy(level: state.encounter.enemyLevel)
        resetEncounterMetrics(phase: .active, reviveRemaining: 0)
    }

    private mutating func resetEncounterMetrics(phase: EncounterPhase, reviveRemaining: TimeInterval) {
        state.encounter.phase = phase
        state.encounter.activeElapsed = 0
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

        guard attackIntervals.allSatisfy({ $0.isFinite && $0 > 0 }),
              countdowns.allSatisfy({ $0.isFinite && $0 >= 0 }),
              state.encounter.activeElapsed.isFinite,
              state.encounter.activeElapsed >= 0,
              state.encounter.reviveRemaining.isFinite,
              state.encounter.reviveRemaining >= 0,
              balance.reviveDelay.isFinite,
              balance.reviveDelay >= 0 else {
            throw SimulationError.invalidTimer
        }
    }

    private func subtracting(_ amount: TimeInterval, from value: TimeInterval) -> TimeInterval {
        let result = Decimal(value) - Decimal(amount)
        guard result > 0 else { return 0 }
        return NSDecimalNumber(decimal: result).doubleValue
    }

    private func consumeEventBudget(_ scheduledEventCount: inout Int) throws {
        guard scheduledEventCount < Self.maximumScheduledEventsPerAdvance else {
            throw SimulationError.eventDensity
        }
        scheduledEventCount += 1
    }
}
