import Foundation

enum ManagementIntent {
    static func autoEquip(_ enabled: Bool) -> GameIntent { .setAutoEquip(enabled) }

    static func equip(_ selection: ItemID?) -> GameIntent? {
        selection.map(GameIntent.equip)
    }

    static func equip(heroSlot: Int, selection: ItemID?) -> GameIntent? {
        selection.map { .equipHero(slot: heroSlot, itemID: $0) }
    }

    static func selectLevel(_ level: Int) -> GameIntent { .selectLevel(level) }
    static var returnToFrontier: GameIntent { .returnToFrontier }
    static func cast(heroSlot: Int, actionID: ClassActionID) -> GameIntent {
        .castAction(heroSlot: heroSlot, actionID: actionID)
    }
    static func setItemLocked(itemID: ItemID, isLocked: Bool) -> GameIntent {
        .setItemLocked(itemID: itemID, isLocked: isLocked)
    }
    static var purchaseInventoryCapacity: GameIntent { .purchaseInventoryCapacity }
    static func moveOverflow(itemID: ItemID, quantity: UInt64) -> GameIntent {
        .moveOverflow(itemID: itemID, quantity: quantity)
    }
    static func salvage(_ selections: [SalvageSelection]) -> GameIntent {
        .salvage(selections)
    }
}

enum ManagementFormat {
    static func dps(_ value: Double) -> String { String(format: "%.1f", value) }
    static func heroLevel(_ level: Int) -> String { "Hero Lv. \(level)" }
    static func enemyLevel(_ level: Int) -> String { "Enemy Lv. \(level)" }
    static func itemLevel(_ level: Int) -> String { "Item Lv. \(level)" }
    static func destination(level: Int) -> String {
        guard let enemy = (try? CampaignResolver().resolve(level: level))?.enemy else {
            return enemyLevel(level)
        }
        return "\(enemy.displayName) · \(enemyLevel(level))"
    }
    static func isNewGameConfirmationValid(_ value: String) -> Bool {
        value == "GAME OVER MAN!"
    }

    static func saveStatus(_ status: SaveStatus) -> String {
        switch status {
        case .notLoaded: "Loading"
        case .saving: "Saving"
        case .saved: "Saved"
        case .recovered: "Recovered from backup"
        case .unsupportedVersion(let version): "Unsupported save version: \(version)"
        case .failed(let message): "Save error: \(message)"
        }
    }

    static func interval(_ duration: SimulationDuration) -> String {
        String(format: "%.1fs", Double(duration.rawValue) / 1_000_000_000)
    }
}

struct InventoryRow: Identifiable, Equatable {
    let id: ItemID
    let slot: EquipmentSlot
    let level: Int
    let primaryStat: Int
    let creationSequence: UInt64
    let isEquipped: Bool
    let equippedHeroSlot: Int?
    let equippedHeroClass: HeroClassID?
    let rarity: ItemRarity
    let affixLabel: String
    let isLocked: Bool
    let comparisonScore: Int64?
    let comparisonLabel: String
    let location: InventoryLocation
    let quantity: UInt64
    let itemName: String

    var slotName: String { slot.rawValue.capitalized }
    var equippedLabel: String {
        guard let equippedHeroSlot, let equippedHeroClass else { return "No" }
        return "Hero \(equippedHeroSlot + 1) · \(equippedHeroClass.displayName)"
    }

    var rarityName: String { rarity.rawValue.capitalized }
    var locationName: String { location == .inventory ? "Inventory" : "Overflow" }
    var isSalvageable: Bool { !isEquipped && !isLocked && rarity != .unique }

    static func rows(for state: GameState, heroSlot: Int = 0) -> [InventoryRow] {
        let inventoryRows = state.inventory.map { ($0, InventoryLocation.inventory) }
        let overflowRows = state.overflowInventory.map { ($0, InventoryLocation.overflow) }
        return (inventoryRows + overflowRows)
            .sorted {
                if $0.0.creationSequence != $1.0.creationSequence {
                    return $0.0.creationSequence > $1.0.creationSequence
                }
                return $0.0.id.rawValue > $1.0.id.rawValue
            }
            .map { item, location in
                let owner = state.party.heroes.enumerated().first { _, hero in
                    hero.equipment[item.slot] == item.id
                }
                let comparison = try? ItemScoreResolver().compare(
                    item: item,
                    heroSlot: heroSlot,
                    in: state
                )
                return InventoryRow(
                    id: item.id,
                    slot: item.slot,
                    level: item.level,
                    primaryStat: item.primaryStat,
                    creationSequence: item.creationSequence,
                    isEquipped: owner != nil,
                    equippedHeroSlot: owner?.offset,
                    equippedHeroClass: owner?.element.classID,
                    rarity: item.rarity,
                    affixLabel: item.affixes.map {
                        "\($0.id.rawValue.capitalized) +\($0.magnitude)"
                    }.joined(separator: ", "),
                    isLocked: item.isLocked,
                    comparisonScore: comparison?.candidateScore,
                    comparisonLabel: comparison.map {
                        let marker = $0.isStrictUpgrade ? "Upgrade" : "Sidegrade"
                        return "\(marker) · A \(signed($0.deltas.attack)) · D \(signed($0.deltas.defense)) · HP \(signed($0.deltas.maximumHealth)) · \(ManagementFormat.interval($0.deltas.attackInterval))"
                    } ?? "Unavailable",
                    location: location,
                    quantity: item.quantity,
                    itemName: item.uniqueName ?? item.templateID.rawValue
                )
            }
    }

    private static func signed(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }

    static func sorted(
        _ rows: [InventoryRow],
        using sortOrder: [KeyPathComparator<InventoryRow>]
    ) -> [InventoryRow] {
        rows.sorted(using: sortOrder)
    }
}

enum InventorySortOption: String, CaseIterable, Equatable, Sendable {
    case newest
    case level
    case rarity
    case heroScore

    var label: String {
        switch self {
        case .newest: "Newest"
        case .level: "Level"
        case .rarity: "Rarity"
        case .heroScore: "Hero score"
        }
    }
}

struct InventoryQuery: Equatable, Sendable {
    var rarities: Set<ItemRarity>
    var slot: EquipmentSlot?
    var upgradeOnly: Bool
    var sort: InventorySortOption
    var locked: Bool? = nil
    var equipped: Bool? = nil
    var location: InventoryLocation? = nil

    init(
        rarity: ItemRarity?,
        slot: EquipmentSlot?,
        upgradeOnly: Bool,
        sort: InventorySortOption,
        locked: Bool? = nil,
        equipped: Bool? = nil,
        location: InventoryLocation? = nil
    ) {
        self.rarities = rarity.map { [$0] } ?? []
        self.slot = slot
        self.upgradeOnly = upgradeOnly
        self.sort = sort
        self.locked = locked
        self.equipped = equipped
        self.location = location
    }

    init(
        rarities: Set<ItemRarity>,
        slot: EquipmentSlot?,
        upgradeOnly: Bool,
        sort: InventorySortOption,
        locked: Bool? = nil,
        equipped: Bool? = nil,
        location: InventoryLocation? = nil
    ) {
        self.rarities = rarities
        self.slot = slot
        self.upgradeOnly = upgradeOnly
        self.sort = sort
        self.locked = locked
        self.equipped = equipped
        self.location = location
    }

    func apply(to rows: [InventoryRow]) -> [InventoryRow] {
        rows.filter { row in
            (rarities.isEmpty || rarities.contains(row.rarity)) &&
                (slot == nil || row.slot == slot) &&
                (!upgradeOnly || row.comparisonLabel.hasPrefix("Upgrade")) &&
                (locked == nil || row.isLocked == locked) &&
                (equipped == nil || row.isEquipped == equipped) &&
                (location == nil || row.location == location)
        }.sorted { lhs, rhs in
            switch sort {
            case .newest:
                if lhs.creationSequence != rhs.creationSequence {
                    return lhs.creationSequence > rhs.creationSequence
                }
            case .level:
                if lhs.level != rhs.level { return lhs.level > rhs.level }
            case .rarity:
                if lhs.rarity != rhs.rarity { return lhs.rarity > rhs.rarity }
            case .heroScore:
                if lhs.comparisonScore != rhs.comparisonScore {
                    return (lhs.comparisonScore ?? .min) > (rhs.comparisonScore ?? .min)
                }
            }
            return lhs.id.rawValue > rhs.id.rawValue
        }
    }
}

struct SalvagePreview: Equatable, Sendable {
    let units: UInt64
    let entries: Int
    let gold: Int64

    init(
        selections: [SalvageSelection],
        rows: [InventoryRow],
        configuration: InventoryConfiguration = .standard
    ) throws {
        guard !selections.isEmpty else { throw SimulationError.invalidState }
        var units: UInt64 = 0
        var gold: Int64 = 0
        for selection in selections {
            guard let row = rows.first(where: {
                $0.id == selection.itemID && $0.location == selection.location
            }), row.isSalvageable, selection.quantity > 0,
                  selection.quantity <= row.quantity,
                  selection.quantity <= UInt64(Int64.max) else {
                throw SimulationError.invalidState
            }
            let multiplier = try configuration.salvageMultiplier(for: row.rarity)
            let (unitGold, levelOverflow) = Int64(row.level).multipliedReportingOverflow(by: multiplier)
            let (selectionGold, valueOverflow) = unitGold.multipliedReportingOverflow(
                by: Int64(selection.quantity)
            )
            let (nextGold, goldOverflow) = gold.addingReportingOverflow(selectionGold)
            let (nextUnits, quantityOverflow) = units.addingReportingOverflow(selection.quantity)
            guard !levelOverflow, !valueOverflow, !goldOverflow, !quantityOverflow else {
                throw SimulationError.arithmeticOverflow
            }
            gold = nextGold
            units = nextUnits
        }
        self.units = units
        self.entries = selections.count
        self.gold = gold
    }
}

extension HeroClassID {
    var displayName: String {
        switch self {
        case .tank: "Tank"
        case .dps: "DPS"
        case .healer: "Healer"
        }
    }
}

extension SaveStatus {
    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}
