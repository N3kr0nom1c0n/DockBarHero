struct RarityWeight: Equatable, Sendable {
    let rarity: ItemRarity
    let weight: UInt64
}

struct LootConfiguration: Sendable {
    static let standard = LootConfiguration()

    func affixCount(for rarity: ItemRarity) -> Int {
        switch rarity {
        case .common: 0
        case .uncommon: 1
        case .rare: 2
        case .epic: 3
        case .unique: 0
        }
    }

    func rarityTable(for tier: EnemyTierID) -> [RarityWeight] {
        switch tier {
        case .normal:
            [
                .init(rarity: .common, weight: 6_000),
                .init(rarity: .uncommon, weight: 3_000),
                .init(rarity: .rare, weight: 900),
                .init(rarity: .epic, weight: 100),
            ]
        case .elite:
            [
                .init(rarity: .common, weight: 2_500),
                .init(rarity: .uncommon, weight: 4_500),
                .init(rarity: .rare, weight: 2_500),
                .init(rarity: .epic, weight: 500),
            ]
        case .boss:
            [
                .init(rarity: .common, weight: 0),
                .init(rarity: .uncommon, weight: 2_500),
                .init(rarity: .rare, weight: 5_500),
                .init(rarity: .epic, weight: 2_000),
            ]
        }
    }

    func affixPool(for slot: EquipmentSlot) -> [AffixID] {
        switch slot {
        case .weapon: [.haste, .might, .vitality]
        case .armor: [.haste, .vitality, .ward]
        }
    }

    func rollRangeBasisPoints(for rarity: ItemRarity) -> ClosedRange<Int> {
        switch rarity {
        case .common, .unique: 0...0
        case .uncommon: 800...1_200
        case .rare: 1_000...1_500
        case .epic: 1_200...1_800
        }
    }

    func validate(_ item: Item) throws {
        guard item.level > 0,
              item.primaryStat > 0,
              item.creationSequence > 0,
              item.affixes == item.affixes.sorted(by: { $0.id < $1.id }),
              Set(item.affixes.map(\.id)).count == item.affixes.count,
              item.affixes.allSatisfy({ $0.magnitude > 0 }),
              Set(item.affixes.map(\.id)).isSubset(of: Set(affixPool(for: item.slot))) else {
            throw SimulationError.invalidState
        }
        if item.rarity == .unique {
            guard item.isLocked, item.uniqueName?.isEmpty == false else {
                throw SimulationError.invalidState
            }
        } else {
            guard item.affixes.count == affixCount(for: item.rarity),
                  item.uniqueName == nil else {
                throw SimulationError.invalidState
            }
        }
    }
}
