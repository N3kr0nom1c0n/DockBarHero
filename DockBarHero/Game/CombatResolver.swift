struct CombatResolver: Sendable {
    func effectiveAttack(for combatant: CombatantID, in state: GameState) throws -> Int {
        guard combatant == .hero else {
            return state.enemy.baseAttack
        }
        return try effectiveAttack(forHeroAt: 0, in: state)
    }

    func effectiveDefense(for combatant: CombatantID, in state: GameState) throws -> Int {
        guard combatant == .hero else {
            return state.enemy.baseDefense
        }
        return try effectiveDefense(forHeroAt: 0, in: state)
    }

    func effectiveAttack(forHeroAt index: Int, in state: GameState) throws -> Int {
        let hero = try validatedHero(at: index, in: state)
        let weapon = try equippedItem(in: .weapon, state: state)
        let rawAttack = try addingEffectiveStat(weapon?.primaryStat ?? 0, to: hero.combat.baseAttack)
        return try scaledStat(
            raw: rawAttack,
            level: hero.level,
            growthBasisPoints: ProgressionConfiguration.standard
                .classDefinition(for: hero.classID)
                .attackGrowthBasisPoints
        )
    }

    func effectiveDefense(forHeroAt index: Int, in state: GameState) throws -> Int {
        let hero = try validatedHero(at: index, in: state)
        let armor = try equippedItem(in: .armor, state: state)
        let rawDefense = try addingEffectiveStat(armor?.primaryStat ?? 0, to: hero.combat.baseDefense)
        return try scaledStat(
            raw: rawDefense,
            level: hero.level,
            growthBasisPoints: ProgressionConfiguration.standard
                .classDefinition(for: hero.classID)
                .defenseGrowthBasisPoints
        )
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
        guard state.party.heroes.count == 1 else {
            throw SimulationError.invalidState
        }
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

    private func validatedHero(at index: Int, in state: GameState) throws -> HeroState {
        guard state.party.heroes.count == 1,
              state.party.heroes.indices.contains(index),
              index == 0 else {
            throw SimulationError.invalidState
        }
        let hero = state.party.heroes[index]
        guard hero.level >= 1, hero.currentXP >= 0 else {
            throw SimulationError.invalidState
        }
        return hero
    }

    private func scaledStat(raw: Int, level: Int, growthBasisPoints: Int64) throws -> Int {
        do {
            return try ProgressionConfiguration.standard.scaledStat(
                raw: raw,
                level: level,
                growthBasisPoints: growthBasisPoints
            )
        } catch {
            throw SimulationError.invalidState
        }
    }

    private func addingEffectiveStat(_ amount: Int, to value: Int) throws -> Int {
        let (result, overflow) = value.addingReportingOverflow(amount)
        guard !overflow else { throw SimulationError.invalidState }
        return result
    }
}
