struct AbilityResolution: Equatable, Sendable {
    var state: GameState
    var events: [GameEvent]
    var damageDealt: Int
    var enemyDefeated: Bool
}

struct AbilityResolver: Sendable {
    let configuration: ClassActionConfiguration
    let combatResolver: CombatResolver

    init(
        configuration: ClassActionConfiguration = .standard,
        combatResolver: CombatResolver = CombatResolver()
    ) {
        self.configuration = configuration
        self.combatResolver = combatResolver
    }

    func resolve(
        heroSlot: Int,
        actionID: ClassActionID,
        in state: GameState
    ) throws -> AbilityResolution {
        guard state.encounter.phase == .active else {
            return rejected(.encounterInactive, slot: heroSlot, actionID: actionID, state: state)
        }
        guard state.party.heroes.indices.contains(heroSlot) else {
            return rejected(.invalidSlot, slot: heroSlot, actionID: actionID, state: state)
        }
        let hero = state.party.heroes[heroSlot]
        guard hero.classAction.actionID == actionID,
              configuration.action(for: hero.classID) == actionID else {
            return rejected(.wrongClass, slot: heroSlot, actionID: actionID, state: state)
        }
        guard hero.combat.currentHealth > 0 else {
            return rejected(.casterDown, slot: heroSlot, actionID: actionID, state: state)
        }
        guard hero.classAction.cooldownRemaining == .zero else {
            return rejected(.cooldown, slot: heroSlot, actionID: actionID, state: state)
        }
        let definition = try configuration.definition(for: actionID)

        switch actionID {
        case .guardAction:
            guard !hero.classAction.guardActive else {
                return rejected(.alreadyActive, slot: heroSlot, actionID: actionID, state: state)
            }
            var result = state
            result.party.heroes[heroSlot].classAction.guardActive = true
            result.party.heroes[heroSlot].classAction.cooldownRemaining = definition.cooldown
            return AbilityResolution(
                state: result,
                events: [
                    .classActionCast(heroSlot: heroSlot, actionID: actionID),
                    .guardActivated(heroSlot: heroSlot),
                ],
                damageDealt: 0,
                enemyDefeated: false
            )

        case .powerStrike:
            let effectiveAttack = try combatResolver.effectiveAttack(forHeroAt: heroSlot, in: state)
            let scaled: Int64
            do {
                scaled = try ProgressionConfiguration.standard.applying(
                    Ratio(numerator: definition.powerBasisPoints, denominator: 10_000),
                    to: Int64(effectiveAttack),
                    rounding: .down
                )
            } catch {
                throw SimulationError.arithmeticOverflow
            }
            guard scaled <= Int64(Int.max) else { throw SimulationError.arithmeticOverflow }
            let (rawDamage, overflow) = Int(scaled).subtractingReportingOverflow(state.enemy.baseDefense)
            guard !overflow else { throw SimulationError.arithmeticOverflow }
            let damage = max(1, rawDamage)
            let health = try combatResolver.health(afterTaking: damage, from: state.enemy.currentHealth)
            let (actualDamage, actualOverflow) = state.enemy.currentHealth.subtractingReportingOverflow(health)
            guard !actualOverflow else { throw SimulationError.arithmeticOverflow }
            let (heroDamage, totalOverflow) = state.encounter.heroDamage.addingReportingOverflow(actualDamage)
            guard !totalOverflow else { throw SimulationError.arithmeticOverflow }
            var result = state
            result.enemy.currentHealth = health
            result.encounter.heroDamage = heroDamage
            result.party.heroes[heroSlot].classAction.cooldownRemaining = definition.cooldown
            return AbilityResolution(
                state: result,
                events: [
                    .classActionCast(heroSlot: heroSlot, actionID: actionID),
                    .powerStrike(heroSlot: heroSlot, damage: damage),
                ],
                damageDealt: actualDamage,
                enemyDefeated: health == 0
            )

        case .mend:
            let targets = state.party.heroes.indices.filter {
                state.party.heroes[$0].combat.currentHealth > 0 &&
                    state.party.heroes[$0].combat.currentHealth < state.party.heroes[$0].combat.maxHealth
            }
            guard let targetSlot = try targets.min(by: { lhs, rhs in
                let left = state.party.heroes[lhs].combat
                let right = state.party.heroes[rhs].combat
                let (leftProduct, leftOverflow) = left.currentHealth.multipliedReportingOverflow(
                    by: right.maxHealth
                )
                let (rightProduct, rightOverflow) = right.currentHealth.multipliedReportingOverflow(
                    by: left.maxHealth
                )
                guard !leftOverflow, !rightOverflow else { throw SimulationError.arithmeticOverflow }
                return leftProduct == rightProduct ? lhs < rhs : leftProduct < rightProduct
            }) else {
                return rejected(.noValidTarget, slot: heroSlot, actionID: actionID, state: state)
            }
            let target = state.party.heroes[targetSlot].combat
            let scaled: Int64
            do {
                scaled = try ProgressionConfiguration.standard.applying(
                    Ratio(numerator: definition.powerBasisPoints, denominator: 10_000),
                    to: Int64(target.maxHealth),
                    rounding: .down
                )
            } catch {
                throw SimulationError.arithmeticOverflow
            }
            guard scaled <= Int64(Int.max) else { throw SimulationError.arithmeticOverflow }
            let (missing, missingOverflow) = target.maxHealth.subtractingReportingOverflow(target.currentHealth)
            guard !missingOverflow else { throw SimulationError.arithmeticOverflow }
            let amount = min(missing, max(1, Int(scaled)))
            let (health, healthOverflow) = target.currentHealth.addingReportingOverflow(amount)
            guard !healthOverflow else { throw SimulationError.arithmeticOverflow }
            var result = state
            result.party.heroes[targetSlot].combat.currentHealth = health
            result.party.heroes[heroSlot].classAction.cooldownRemaining = definition.cooldown
            return AbilityResolution(
                state: result,
                events: [
                    .classActionCast(heroSlot: heroSlot, actionID: actionID),
                    .mended(casterSlot: heroSlot, targetSlot: targetSlot, amount: amount),
                ],
                damageDealt: 0,
                enemyDefeated: false
            )
        }
    }

    private func rejected(
        _ reason: ClassActionRejection,
        slot: Int,
        actionID: ClassActionID,
        state: GameState
    ) -> AbilityResolution {
        AbilityResolution(
            state: state,
            events: [.classActionRejected(heroSlot: slot, actionID: actionID, reason: reason)],
            damageDealt: 0,
            enemyDefeated: false
        )
    }
}
