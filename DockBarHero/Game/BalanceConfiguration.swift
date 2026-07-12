import Foundation

struct BalanceConfiguration: Codable, Equatable, Sendable {
    let heroMaxHealth: Int
    let heroBaseAttack: Int
    let heroBaseDefense: Int
    let heroAttackInterval: SimulationDuration
    let enemyBaseHealth: Int
    let enemyBaseAttack: Int
    let enemyBaseDefense: Int
    let enemyAttackInterval: SimulationDuration
    let reviveDelay: SimulationDuration

    static let standard = BalanceConfiguration(
        heroMaxHealth: 100,
        heroBaseAttack: 10,
        heroBaseDefense: 0,
        heroAttackInterval: .nanoseconds(1_000_000_000),
        enemyBaseHealth: 30,
        enemyBaseAttack: 3,
        enemyBaseDefense: 0,
        enemyAttackInterval: .nanoseconds(1_500_000_000),
        reviveDelay: .nanoseconds(3_000_000_000)
    )

    func enemy(level: Int) -> CombatantState? {
        guard level >= 1 else { return nil }
        guard level > 1 else { return initialEnemy }
        guard let enemyHealth = scaledInteger(enemyBaseHealth, rate: 1.06, level: level, rounding: .toNearestOrAwayFromZero),
              let enemyAttack = scaledInteger(enemyBaseAttack, rate: 1.04, level: level, rounding: .toNearestOrAwayFromZero) else {
            return nil
        }

        return makeEnemy(health: enemyHealth, attack: enemyAttack)
    }

    func enemy(
        level: Int,
        tier: EnemyTierID,
        progression: ProgressionConfiguration
    ) -> CombatantState? {
        guard let baseline = enemy(level: level) else { return nil }
        let ratio = progression.tierDefinition(for: tier).healthRatio
        guard let scaledHealth = try? progression.applying(
            ratio,
            to: Int64(baseline.maxHealth),
            rounding: .up
        ), scaledHealth > 0, scaledHealth <= Int64(Int.max) else {
            return nil
        }
        return makeEnemy(health: Int(scaledHealth), attack: baseline.baseAttack)
    }

    func itemPrimaryStat(level: Int, slot: EquipmentSlot) -> Int? {
        guard level >= 1 else { return nil }
        switch slot {
        case .weapon:
            return scaledItemPrimaryStat(base: 10, rate: 1.06, level: level)
        case .armor:
            return scaledItemPrimaryStat(base: 3, rate: 1.04, level: level)
        }
    }

    var initialEnemy: CombatantState {
        makeEnemy(health: enemyBaseHealth, attack: enemyBaseAttack)
    }

    private func makeEnemy(health: Int, attack: Int) -> CombatantState {
        CombatantState(
            id: .enemy,
            currentHealth: health,
            maxHealth: health,
            baseAttack: attack,
            baseDefense: enemyBaseDefense,
            attackInterval: enemyAttackInterval,
            timeUntilNextAttack: enemyAttackInterval
        )
    }

    private func scaledInteger(
        _ base: Int,
        rate: Double,
        level: Int,
        offset: Double = 0,
        rounding: FloatingPointRoundingRule
    ) -> Int? {
        guard base >= 0, level >= 1 else { return nil }
        let exponent = level - 1
        let scaled = Double(base) * pow(rate, Double(exponent)) + offset
        let rounded = scaled.rounded(rounding)
        guard rounded.isFinite,
              rounded >= Double(Int.min),
              rounded < Double(Int.max) else {
            return nil
        }
        return Int(rounded)
    }

    private func scaledItemPrimaryStat(base: Int, rate: Double, level: Int) -> Int? {
        let scaled = Double(base) * (pow(rate, Double(level)) - 1)
        let rounded = scaled.rounded(.up)
        guard rounded.isFinite,
              rounded >= Double(Int.min),
              rounded < Double(Int.max) else {
            return nil
        }
        return Int(rounded)
    }
}

extension GameState {
    static func newGame(balance: BalanceConfiguration) -> GameState {
        var state = newGame(classID: .dps, balance: balance, progression: .standard)
        state.hero = CombatantState(
            id: .hero,
            currentHealth: balance.heroMaxHealth,
            maxHealth: balance.heroMaxHealth,
            baseAttack: balance.heroBaseAttack,
            baseDefense: balance.heroBaseDefense,
            attackInterval: balance.heroAttackInterval,
            timeUntilNextAttack: balance.heroAttackInterval
        )
        return state
    }

    static func newGame(
        classID: HeroClassID,
        balance: BalanceConfiguration,
        progression: ProgressionConfiguration
    ) -> GameState {
        let definition = progression.classDefinition(for: classID)
        let hero = CombatantState(
            id: .hero,
            currentHealth: definition.baseHealth,
            maxHealth: definition.baseHealth,
            baseAttack: definition.baseAttack,
            baseDefense: definition.baseDefense,
            attackInterval: balance.heroAttackInterval,
            timeUntilNextAttack: balance.heroAttackInterval
        )

        return GameState(
            party: PartyState(heroes: [
                HeroState(
                    classID: classID,
                    level: 1,
                    currentXP: 0,
                    combat: hero,
                    equipment: EquipmentState(weaponID: nil, armorID: nil)
                )
            ]),
            enemy: balance.initialEnemy,
            encounter: EncounterState(
                enemyLevel: 1,
                tier: .normal,
                phase: .active,
                activeElapsed: .zero,
                heroDamage: 0,
                reviveRemaining: .zero
            ),
            campaign: CampaignState(
                highestUnlockedLevel: 1,
                selectedLevel: 1,
                queuedLevel: nil,
                mode: .push,
                consecutiveDefeats: 0
            ),
            economy: EconomyState(gold: 0),
            inventory: [],
            autoEquipEnabled: true,
            lootSequence: 0
        )
    }
}
