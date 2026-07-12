struct CombatResolver: Sendable {
    func effectiveAttack(for combatant: CombatantID, in state: GameState) throws -> Int {
        let baseAttack = combatant == .hero ? state.hero.baseAttack : state.enemy.baseAttack
        guard combatant == .hero, let weapon = try equippedItem(in: .weapon, state: state) else {
            return baseAttack
        }
        return try addingEffectiveStat(weapon.primaryStat, to: baseAttack)
    }

    func effectiveDefense(for combatant: CombatantID, in state: GameState) throws -> Int {
        let baseDefense = combatant == .hero ? state.hero.baseDefense : state.enemy.baseDefense
        guard combatant == .hero, let armor = try equippedItem(in: .armor, state: state) else {
            return baseDefense
        }
        return try addingEffectiveStat(armor.primaryStat, to: baseDefense)
    }

    func damage(attacker: CombatantID, defender: CombatantID, in state: GameState) throws -> Int {
        let attack = try effectiveAttack(for: attacker, in: state)
        let defense = try effectiveDefense(for: defender, in: state)
        let (difference, overflow) = attack.subtractingReportingOverflow(defense)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        return max(1, difference)
    }

    func health(afterTaking damage: Int, from currentHealth: Int) throws -> Int {
        let (remaining, overflow) = currentHealth.subtractingReportingOverflow(damage)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        return max(0, remaining)
    }

    func isStrictUpgrade(_ item: Item, in state: GameState) throws -> Bool {
        guard let equipped = try equippedItem(in: item.slot, state: state) else { return true }
        return item.primaryStat > equipped.primaryStat
    }

    private func equippedItem(in slot: EquipmentSlot, state: GameState) throws -> Item? {
        guard let id = state.equipment[slot] else { return nil }
        let matches = state.inventory.filter { $0.id == id }
        guard matches.count == 1,
              let item = matches.first,
              item.slot == slot,
              item.level >= 1,
              item.primaryStat >= 0 else {
            throw SimulationError.invalidState
        }
        return item
    }

    private func addingEffectiveStat(_ amount: Int, to value: Int) throws -> Int {
        let (result, overflow) = value.addingReportingOverflow(amount)
        guard !overflow else { throw SimulationError.invalidState }
        return result
    }
}
