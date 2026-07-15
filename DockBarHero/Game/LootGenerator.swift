struct LootGenerator: Sendable {
    let configuration: LootConfiguration
    let balance: BalanceConfiguration

    init(
        configuration: LootConfiguration = .standard,
        balance: BalanceConfiguration = .standard
    ) {
        self.configuration = configuration
        self.balance = balance
    }

    func generate(
        defeatedLevel: Int,
        tier: EnemyTierID,
        sequence: UInt64,
        slot: EquipmentSlot
    ) throws -> Item {
        guard defeatedLevel > 0 else { throw SimulationError.invalidBalance }
        let (rawID, overflow) = sequence.addingReportingOverflow(1)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        var seed = mix(sequence ^ UInt64(defeatedLevel) &* 0x9E3779B97F4A7C15)
        seed = mix(seed ^ tierOrdinal(tier) ^ slotOrdinal(slot))
        let rarity = try rarity(for: seed % 10_000, tier: tier)
        let pool = configuration.affixPool(for: slot)
        let count = configuration.affixCount(for: rarity)
        let keyed: [(id: AffixID, key: UInt64)] = pool.map { id in
            (id: id, key: mix(seed ^ stableAffixValue(id)))
        }
        let ordered = keyed.sorted { lhs, rhs in
            lhs.key == rhs.key ? lhs.id < rhs.id : lhs.key < rhs.key
        }
        let selected: [AffixID] = Array(ordered.prefix(count).map(\.id)).sorted()
        let affixes = try selected.enumerated().map { offset, id in
            let roll = mix(seed ^ UInt64(offset + 1) &* 0xD1B54A32D192ED03)
            return ItemAffix(
                id: id,
                magnitude: try magnitude(
                    for: id,
                    rarity: rarity,
                    level: defeatedLevel,
                    roll: roll
                )
            )
        }
        guard let baseline = balance.itemPrimaryStat(level: defeatedLevel, slot: slot) else {
            throw SimulationError.invalidBalance
        }
        let scaled: Int64
        do {
            scaled = try ProgressionConfiguration.standard.applying(
                ProgressionConfiguration.standard.tierDefinition(for: tier).itemStatRatio,
                to: Int64(baseline),
                rounding: .up
            )
        } catch {
            throw SimulationError.arithmeticOverflow
        }
        guard scaled > 0, scaled <= Int64(Int.max) else { throw SimulationError.arithmeticOverflow }
        let item = Item(
            id: ItemID(rawValue: rawID),
            level: defeatedLevel,
            slot: slot,
            primaryStat: Int(scaled),
            creationSequence: rawID,
            rarity: rarity,
            affixes: affixes
        )
        try configuration.validate(item)
        return item
    }

    private func rarity(for roll: UInt64, tier: EnemyTierID) throws -> ItemRarity {
        var upper: UInt64 = 0
        for entry in configuration.rarityTable(for: tier) {
            let (next, overflow) = upper.addingReportingOverflow(entry.weight)
            guard !overflow else { throw SimulationError.arithmeticOverflow }
            upper = next
            if roll < upper { return entry.rarity }
        }
        throw SimulationError.invalidBalance
    }

    private func magnitude(
        for id: AffixID,
        rarity: ItemRarity,
        level: Int,
        roll: UInt64
    ) throws -> Int {
        let range = configuration.rollRangeBasisPoints(for: rarity)
        let width = UInt64(range.upperBound - range.lowerBound + 1)
        let basisPoints = range.lowerBound + Int(roll % width)
        if id == .haste { return basisPoints }
        let baseline: Int
        switch id {
        case .might:
            baseline = balance.itemPrimaryStat(level: level, slot: .weapon) ?? 0
        case .ward:
            baseline = balance.itemPrimaryStat(level: level, slot: .armor) ?? 0
        case .vitality:
            do {
                baseline = try ProgressionConfiguration.standard.scaledStat(
                    raw: 100,
                    level: level,
                    growthBasisPoints: 75
                )
            } catch {
                throw SimulationError.arithmeticOverflow
            }
        case .haste:
            baseline = 0
        }
        do {
            let value = try ProgressionConfiguration.standard.applying(
                Ratio(numerator: Int64(basisPoints), denominator: 10_000),
                to: Int64(baseline),
                rounding: .up
            )
            guard value > 0, value <= Int64(Int.max) else { throw SimulationError.invalidBalance }
            return Int(value)
        } catch let error as SimulationError {
            throw error
        } catch {
            throw SimulationError.arithmeticOverflow
        }
    }

    private func tierOrdinal(_ tier: EnemyTierID) -> UInt64 {
        switch tier { case .normal: 1; case .elite: 2; case .boss: 3 }
    }

    private func slotOrdinal(_ slot: EquipmentSlot) -> UInt64 {
        slot == .weapon ? 0xA5A5 : 0x5A5A
    }

    private func stableAffixValue(_ id: AffixID) -> UInt64 {
        switch id { case .haste: 11; case .might: 23; case .vitality: 37; case .ward: 53 }
    }

    private func mix(_ input: UInt64) -> UInt64 {
        var value = input &+ 0x9E3779B97F4A7C15
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
