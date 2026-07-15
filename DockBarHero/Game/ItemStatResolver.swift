struct HeroEffectiveStats: Equatable, Sendable {
    let attack: Int
    let defense: Int
    let maximumHealth: Int
    let attackInterval: SimulationDuration
    let hasteBasisPoints: Int
}

struct ItemStatResolver: Sendable {
    func stats(heroSlot: Int, in state: GameState) throws -> HeroEffectiveStats {
        guard state.party.heroes.indices.contains(heroSlot) else {
            throw SimulationError.invalidState
        }
        let hero = state.party.heroes[heroSlot]
        let progression = ProgressionConfiguration.standard
        let definition = progression.classDefinition(for: hero.classID)
        let weapon = try equippedItem(slot: .weapon, heroSlot: heroSlot, in: state)
        let armor = try equippedItem(slot: .armor, heroSlot: heroSlot, in: state)
        let baseAttack = try checkedBaseAdd(hero.combat.baseAttack, weapon?.primaryStat ?? 0)
        let baseDefense = try checkedBaseAdd(hero.combat.baseDefense, armor?.primaryStat ?? 0)
        let scaledAttack: Int
        let scaledDefense: Int
        let scaledHealth: Int
        do {
            scaledAttack = try progression.scaledStat(
                raw: baseAttack,
                level: hero.level,
                growthBasisPoints: definition.attackGrowthBasisPoints
            )
            scaledDefense = try progression.scaledStat(
                raw: baseDefense,
                level: hero.level,
                growthBasisPoints: definition.defenseGrowthBasisPoints
            )
            scaledHealth = try progression.scaledStat(
                raw: definition.baseHealth,
                level: hero.level,
                growthBasisPoints: definition.healthGrowthBasisPoints
            )
        } catch {
            throw SimulationError.arithmeticOverflow
        }

        let affixes = [weapon, armor].compactMap { $0 }.flatMap(\.affixes)
        let might = try sum(.might, in: affixes)
        let ward = try sum(.ward, in: affixes)
        let vitality = try sum(.vitality, in: affixes)
        let haste = min(4_000, try sum(.haste, in: affixes))
        let attack = try checkedAdd(scaledAttack, might)
        let defense = try checkedAdd(scaledDefense, ward)
        let maximumHealth = try checkedAdd(scaledHealth, vitality)
        let remainingBasisPoints = 10_000 - haste
        let (intervalProduct, intervalOverflow) = hero.combat.attackInterval.rawValue
            .multipliedReportingOverflow(by: Int64(remainingBasisPoints))
        guard !intervalOverflow else { throw SimulationError.arithmeticOverflow }
        let interval = SimulationDuration.nanoseconds(intervalProduct / 10_000)
        guard interval >= .minimumAttackInterval, maximumHealth > 0 else {
            throw SimulationError.invalidState
        }
        return HeroEffectiveStats(
            attack: attack,
            defense: defense,
            maximumHealth: maximumHealth,
            attackInterval: interval,
            hasteBasisPoints: haste
        )
    }

    private func equippedItem(
        slot: EquipmentSlot,
        heroSlot: Int,
        in state: GameState
    ) throws -> Item? {
        guard let itemID = state.party.heroes[heroSlot].equipment[slot] else { return nil }
        let matches = state.inventory.filter { $0.id == itemID }
        guard matches.count == 1,
              let item = matches.first,
              item.slot == slot,
              item.level > 0,
              item.primaryStat >= 0 else {
            throw SimulationError.invalidState
        }
        return item
    }

    private func sum(_ id: AffixID, in affixes: [ItemAffix]) throws -> Int {
        try affixes.filter { $0.id == id }.reduce(0) { partial, affix in
            try checkedAdd(partial, affix.magnitude)
        }
    }

    private func checkedAdd(_ lhs: Int, _ rhs: Int) throws -> Int {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        return value
    }

    private func checkedBaseAdd(_ lhs: Int, _ rhs: Int) throws -> Int {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        guard !overflow else { throw SimulationError.invalidState }
        return value
    }
}
