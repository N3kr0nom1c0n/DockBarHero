struct ItemStatDeltas: Equatable, Sendable {
    let attack: Int
    let defense: Int
    let maximumHealth: Int
    let attackInterval: SimulationDuration
}

struct ItemComparison: Equatable, Sendable {
    let currentScore: Int64
    let candidateScore: Int64
    let deltas: ItemStatDeltas

    var isStrictUpgrade: Bool { candidateScore > currentScore }
    var improvement: Int64 { candidateScore - currentScore }
}

struct ItemScoreResolver: Sendable {
    func compare(item: Item, heroSlot: Int, in state: GameState) throws -> ItemComparison {
        guard state.party.heroes.indices.contains(heroSlot),
              state.inventory.filter({ $0.id == item.id }).count == 1 else {
            throw SimulationError.invalidState
        }
        let current = try ItemStatResolver().stats(heroSlot: heroSlot, in: state)
        var candidateState = state
        candidateState.party.heroes[heroSlot].equipment[item.slot] = item.id
        let candidate = try ItemStatResolver().stats(heroSlot: heroSlot, in: candidateState)
        let hero = state.party.heroes[heroSlot]
        return ItemComparison(
            currentScore: try score(stats: current, heroClass: hero.classID, itemLevel: item.level),
            candidateScore: try score(stats: candidate, heroClass: hero.classID, itemLevel: item.level),
            deltas: ItemStatDeltas(
                attack: try subtract(candidate.attack, current.attack),
                defense: try subtract(candidate.defense, current.defense),
                maximumHealth: try subtract(candidate.maximumHealth, current.maximumHealth),
                attackInterval: .nanoseconds(try subtract(
                    candidate.attackInterval.rawValue,
                    current.attackInterval.rawValue
                ))
            )
        )
    }

    private func score(
        stats: HeroEffectiveStats,
        heroClass: HeroClassID,
        itemLevel: Int
    ) throws -> Int64 {
        let progression = ProgressionConfiguration.standard
        let definition = progression.classDefinition(for: heroClass)
        let referenceAttack: Int
        let referenceDefense: Int
        let referenceHealth: Int
        do {
            referenceAttack = try progression.scaledStat(
                raw: definition.baseAttack,
                level: itemLevel,
                growthBasisPoints: definition.attackGrowthBasisPoints
            )
            referenceDefense = try progression.scaledStat(
                raw: max(1, definition.baseDefense),
                level: itemLevel,
                growthBasisPoints: definition.defenseGrowthBasisPoints
            )
            referenceHealth = try progression.scaledStat(
                raw: definition.baseHealth,
                level: itemLevel,
                growthBasisPoints: definition.healthGrowthBasisPoints
            )
        } catch {
            throw SimulationError.arithmeticOverflow
        }
        let weights = weights(for: heroClass)
        let attack = try normalized(stats.attack, reference: referenceAttack)
        let defense = try normalized(stats.defense, reference: referenceDefense)
        let health = try normalized(stats.maximumHealth, reference: referenceHealth)
        let haste = Int64(stats.hasteBasisPoints)
        var total: Int64 = 0
        total = try add(total, try multiply(attack, weights.attack))
        total = try add(total, try multiply(defense, weights.defense))
        total = try add(total, try multiply(health, weights.health))
        total = try add(total, try multiply(haste, weights.haste))
        return total
    }

    private func weights(for heroClass: HeroClassID) -> (attack: Int64, defense: Int64, health: Int64, haste: Int64) {
        switch heroClass {
        case .tank: (10, 40, 40, 10)
        case .dps: (45, 10, 15, 30)
        case .healer: (10, 20, 40, 30)
        }
    }

    private func normalized(_ value: Int, reference: Int) throws -> Int64 {
        guard value >= 0, reference > 0 else { throw SimulationError.invalidState }
        let (product, overflow) = Int64(value).multipliedReportingOverflow(by: 10_000)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        return product / Int64(reference)
    }

    private func multiply(_ lhs: Int64, _ rhs: Int64) throws -> Int64 {
        let (value, overflow) = lhs.multipliedReportingOverflow(by: rhs)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        return value
    }

    private func add(_ lhs: Int64, _ rhs: Int64) throws -> Int64 {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        return value
    }

    private func subtract(_ lhs: Int, _ rhs: Int) throws -> Int {
        let (value, overflow) = lhs.subtractingReportingOverflow(rhs)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        return value
    }

    private func subtract(_ lhs: Int64, _ rhs: Int64) throws -> Int64 {
        let (value, overflow) = lhs.subtractingReportingOverflow(rhs)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        return value
    }
}
