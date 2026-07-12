import Foundation

enum ManagementIntent {
    static func autoEquip(_ enabled: Bool) -> GameIntent { .setAutoEquip(enabled) }

    static func equip(_ selection: ItemID?) -> GameIntent? {
        selection.map(GameIntent.equip)
    }
}

enum ManagementFormat {
    static func dps(_ value: Double) -> String { String(format: "%.1f", value) }

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

    var slotName: String { slot.rawValue.capitalized }
    var equippedLabel: String { isEquipped ? "Yes" : "No" }

    static func rows(for state: GameState) -> [InventoryRow] {
        state.inventory
            .sorted {
                if $0.creationSequence != $1.creationSequence {
                    return $0.creationSequence > $1.creationSequence
                }
                return $0.id.rawValue > $1.id.rawValue
            }
            .map { item in
                InventoryRow(
                    id: item.id,
                    slot: item.slot,
                    level: item.level,
                    primaryStat: item.primaryStat,
                    creationSequence: item.creationSequence,
                    isEquipped: state.equipment[item.slot] == item.id
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

extension SaveStatus {
    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}
