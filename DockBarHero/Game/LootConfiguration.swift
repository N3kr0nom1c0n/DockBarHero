struct RarityWeight: Equatable, Sendable {
    let rarity: ItemRarity
    let weight: UInt64
}

struct UniqueItemDefinition: Equatable, Sendable {
    let templateID: ItemTemplateID
    let displayName: String
    let level: Int
    let slot: EquipmentSlot
    let primaryStat: Int
    let affixes: [ItemAffix]
}

struct LootConfiguration: Sendable {
    static let standard = LootConfiguration()

    let uniqueDefinitions: [UniqueItemDefinition]

    init(uniqueDefinitions: [UniqueItemDefinition] = []) {
        self.uniqueDefinitions = uniqueDefinitions
    }

    func grantUnique(
        templateID: ItemTemplateID,
        id: ItemID,
        creationSequence: UInt64
    ) throws -> Item {
        let matches = uniqueDefinitions.filter { $0.templateID == templateID }
        guard matches.count == 1, let definition = matches.first,
              id.rawValue > 0, creationSequence > 0 else {
            throw SimulationError.invalidState
        }
        let item = Item(
            id: id,
            level: definition.level,
            slot: definition.slot,
            primaryStat: definition.primaryStat,
            creationSequence: creationSequence,
            templateID: definition.templateID,
            rarity: .unique,
            affixes: definition.affixes,
            isLocked: true,
            uniqueName: definition.displayName,
            quantity: 1
        )
        try validate(item)
        return item
    }

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
            let matches = uniqueDefinitions.filter { $0.templateID == item.templateID }
            guard matches.count == 1, let definition = matches.first,
                  item.isLocked,
                  item.quantity == 1,
                  item.uniqueName == definition.displayName,
                  item.level == definition.level,
                  item.slot == definition.slot,
                  item.primaryStat == definition.primaryStat,
                  item.affixes == definition.affixes else {
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
