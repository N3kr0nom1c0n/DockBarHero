struct EnemyFactory: Sendable {
    func makeEnemy(
        for resolved: ResolvedCampaignEncounter,
        balance: BalanceConfiguration,
        progression: ProgressionConfiguration
    ) throws -> CombatantState {
        guard let baseline = balance.enemy(
            level: resolved.level,
            tier: resolved.tier,
            progression: progression
        ) else {
            throw SimulationError.invalidBalance
        }
        guard let definition = resolved.enemy else {
            return baseline
        }

        let profile = definition.profile
        let maximumHealth = try progression.applying(
            Ratio(numerator: profile.healthBasisPoints, denominator: 10_000),
            to: Int64(baseline.maxHealth),
            rounding: .up
        )
        let baseAttack = try progression.applying(
            Ratio(numerator: profile.attackBasisPoints, denominator: 10_000),
            to: Int64(baseline.baseAttack),
            rounding: .up
        )
        let attackInterval = try progression.applying(
            Ratio(numerator: profile.attackIntervalBasisPoints, denominator: 10_000),
            to: baseline.attackInterval.rawValue,
            rounding: .up
        )
        let (baseDefense, defenseOverflow) = baseline.baseDefense.addingReportingOverflow(
            profile.defenseBonus
        )

        guard !defenseOverflow else {
            throw SimulationError.arithmeticOverflow
        }
        guard maximumHealth > 0,
              maximumHealth <= Int64(Int.max),
              baseAttack <= Int64(Int.max),
              attackInterval >= SimulationDuration.minimumAttackInterval.rawValue else {
            throw SimulationError.invalidBalance
        }

        let interval = SimulationDuration.nanoseconds(attackInterval)
        return CombatantState(
            id: .enemy,
            currentHealth: Int(maximumHealth),
            maxHealth: Int(maximumHealth),
            baseAttack: Int(baseAttack),
            baseDefense: baseDefense,
            attackInterval: interval,
            timeUntilNextAttack: interval
        )
    }
}
