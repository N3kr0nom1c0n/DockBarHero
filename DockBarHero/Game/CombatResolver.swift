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
        let weapon = try equippedItem(in: .weapon, heroIndex: index, state: state)
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
        let armor = try equippedItem(in: .armor, heroIndex: index, state: state)
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
        if attacker == .enemy, defender == .hero {
            return try enemyDamage(in: state, tier: state.encounter.tier)
        }
        let attack = try effectiveAttack(for: attacker, in: state)
        let defense = try effectiveDefense(for: defender, in: state)
        let (difference, overflow) = attack.subtractingReportingOverflow(defense)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        return max(1, difference)
    }

    func enemyDamage(in state: GameState, tier: EnemyTierID) throws -> Int {
        try enemyDamage(targetingHeroAt: 0, in: state, tier: tier)
    }

    func enemyDamage(targetingHeroAt index: Int, in state: GameState, tier: EnemyTierID) throws -> Int {
        let defense = try effectiveDefense(forHeroAt: index, in: state)
        let (difference, overflow) = state.enemy.baseAttack.subtractingReportingOverflow(defense)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        let baseline = max(1, difference)
        do {
            let scaled = try ProgressionConfiguration.standard.applying(
                ProgressionConfiguration.standard.tierDefinition(for: tier).damageRatio,
                to: Int64(baseline),
                rounding: .up
            )
            guard scaled <= Int64(Int.max) else { throw SimulationError.arithmeticOverflow }
            return Int(scaled)
        } catch let error as SimulationError {
            throw error
        } catch {
            throw SimulationError.arithmeticOverflow
        }
    }

    func health(afterTaking damage: Int, from currentHealth: Int) throws -> Int {
        let (remaining, overflow) = currentHealth.subtractingReportingOverflow(damage)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        return max(0, remaining)
    }

    func isStrictUpgrade(_ item: Item, in state: GameState) throws -> Bool {
        guard !state.party.heroes.isEmpty else {
            throw SimulationError.invalidState
        }
        return try upgradeAmount(for: item, heroIndex: 0, in: state) != nil
    }

    func upgradeAmount(for item: Item, heroIndex: Int, in state: GameState) throws -> Int? {
        _ = try validatedHero(at: heroIndex, in: state)
        guard state.inventory.filter({ $0.id == item.id }).count == 1,
              item.level >= 1,
              item.primaryStat >= 0 else {
            throw SimulationError.invalidState
        }
        let usedByAnotherHero = state.party.heroes.indices.contains { slot in
            slot != heroIndex && EquipmentSlot.allCases.contains {
                state.party.heroes[slot].equipment[$0] == item.id
            }
        }
        guard !usedByAnotherHero else { return nil }
        let current = try effectiveStat(for: item.slot, heroIndex: heroIndex, in: state)
        var candidate = state
        candidate.party.heroes[heroIndex].equipment[item.slot] = item.id
        let replacement = try effectiveStat(for: item.slot, heroIndex: heroIndex, in: candidate)
        let (difference, overflow) = replacement.subtractingReportingOverflow(current)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        return difference > 0 ? difference : nil
    }

    private func effectiveStat(for slot: EquipmentSlot, heroIndex: Int, in state: GameState) throws -> Int {
        switch slot {
        case .weapon: try effectiveAttack(forHeroAt: heroIndex, in: state)
        case .armor: try effectiveDefense(forHeroAt: heroIndex, in: state)
        }
    }

    private func equippedItem(in slot: EquipmentSlot, heroIndex: Int, state: GameState) throws -> Item? {
        let hero = try validatedHero(at: heroIndex, in: state)
        guard let id = hero.equipment[slot] else { return nil }
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
        guard (1...3).contains(state.party.heroes.count),
              state.party.heroes.indices.contains(index) else {
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
