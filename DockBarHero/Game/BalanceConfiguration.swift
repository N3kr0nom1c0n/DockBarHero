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

    func enemy(level: Int) -> CombatantState {
        precondition(level >= 1)
        let enemyHealth = Int((Double(enemyBaseHealth) * pow(1.06, Double(level - 1))).rounded())
        let enemyAttack = Int((Double(enemyBaseAttack) * pow(1.04, Double(level - 1))).rounded())

        return CombatantState(
            id: .enemy,
            currentHealth: enemyHealth,
            maxHealth: enemyHealth,
            baseAttack: enemyAttack,
            baseDefense: enemyBaseDefense,
            attackInterval: enemyAttackInterval,
            timeUntilNextAttack: enemyAttackInterval
        )
    }

    func itemPrimaryStat(level: Int, slot: EquipmentSlot) -> Int {
        precondition(level >= 1)
        switch slot {
        case .weapon:
            return Int(ceil(10.0 * (pow(1.06, Double(level)) - 1.0)))
        case .armor:
            return Int(ceil(3.0 * (pow(1.04, Double(level)) - 1.0)))
        }
    }
}

extension GameState {
    static func newGame(balance: BalanceConfiguration) -> GameState {
        let hero = CombatantState(
            id: .hero,
            currentHealth: balance.heroMaxHealth,
            maxHealth: balance.heroMaxHealth,
            baseAttack: balance.heroBaseAttack,
            baseDefense: balance.heroBaseDefense,
            attackInterval: balance.heroAttackInterval,
            timeUntilNextAttack: balance.heroAttackInterval
        )

        return GameState(
            hero: hero,
            enemy: balance.enemy(level: 1),
            encounter: EncounterState(
                enemyLevel: 1,
                phase: .active,
                activeElapsed: .zero,
                heroDamage: 0,
                reviveRemaining: .zero
            ),
            inventory: [],
            equipment: EquipmentState(weaponID: nil, armorID: nil),
            autoEquipEnabled: true,
            lootSequence: 0
        )
    }
}
