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
}

enum ManagementFormat {
    static func dps(_ value: Double) -> String { String(format: "%.1f", value) }
    static func heroLevel(_ level: Int) -> String { "Hero Lv. \(level)" }
    static func enemyLevel(_ level: Int) -> String { "Enemy Lv. \(level)" }
    static func itemLevel(_ level: Int) -> String { "Item Lv. \(level)" }
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

    var slotName: String { slot.rawValue.capitalized }
    var equippedLabel: String {
        guard let equippedHeroSlot, let equippedHeroClass else { return "No" }
        return "Hero \(equippedHeroSlot + 1) · \(equippedHeroClass.displayName)"
    }

    static func rows(for state: GameState) -> [InventoryRow] {
        state.inventory
            .sorted {
                if $0.creationSequence != $1.creationSequence {
                    return $0.creationSequence > $1.creationSequence
                }
                return $0.id.rawValue > $1.id.rawValue
            }
            .map { item in
                let owner = state.party.heroes.enumerated().first { _, hero in
                    hero.equipment[item.slot] == item.id
                }
                return InventoryRow(
                    id: item.id,
                    slot: item.slot,
                    level: item.level,
                    primaryStat: item.primaryStat,
                    creationSequence: item.creationSequence,
                    isEquipped: owner != nil,
                    equippedHeroSlot: owner?.offset,
                    equippedHeroClass: owner?.element.classID
                )
            }
    }

    static func sorted(
        _ rows: [InventoryRow],
        using sortOrder: [KeyPathComparator<InventoryRow>]
    ) -> [InventoryRow] {
        rows.sorted(using: sortOrder)
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
