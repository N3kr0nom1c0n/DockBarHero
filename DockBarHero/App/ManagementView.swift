import Foundation
import SwiftUI

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
    let isEquipped: Bool

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
                    isEquipped: state.equipment[item.slot] == item.id
                )
            }
    }
}

struct ManagementView: View {
    @ObservedObject var model: AppModel
    @State private var selection: ItemID?

    private var presentation: GamePresentation { model.game }
    private var rows: [InventoryRow] { InventoryRow.rows(for: presentation.state) }
    private var selectedItemIsOwned: Bool {
        guard let selection else { return false }
        return rows.contains { $0.id == selection }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                combatSection
                dpsSection
                equipmentSection
                inventorySection
                saveStatusSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 720, minHeight: 520)
    }

    private var combatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Combat")
                .font(.title2.weight(.semibold))

            HStack(alignment: .top, spacing: 28) {
                statGrid(
                    title: "Hero",
                    values: [
                        ("Health", "\(presentation.state.hero.currentHealth)/\(presentation.state.hero.maxHealth)"),
                        ("Attack", "\(presentation.heroAttack)"),
                        ("Defense", "\(presentation.heroDefense)"),
                        ("Interval", ManagementFormat.interval(presentation.state.hero.attackInterval))
                    ]
                )
                statGrid(
                    title: "Enemy",
                    values: [
                        ("Health", "\(presentation.state.enemy.currentHealth)/\(presentation.state.enemy.maxHealth)"),
                        ("Attack", "\(presentation.state.enemy.baseAttack)"),
                        ("Defense", "\(presentation.state.enemy.baseDefense)"),
                        ("Interval", ManagementFormat.interval(presentation.state.enemy.attackInterval)),
                        ("Enemy level", "\(presentation.state.encounter.enemyLevel)")
                    ]
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dpsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Damage per second")
                .font(.headline)
            HStack(spacing: 32) {
                metric("Rolling", ManagementFormat.dps(presentation.rollingDPS))
                metric("Encounter average", ManagementFormat.dps(presentation.encounterDPS))
            }
        }
    }

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Equipment")
                .font(.headline)
            equipmentRow(for: .weapon)
            equipmentRow(for: .armor)
            Toggle("Auto-equip upgrades", isOn: Binding(
                get: { presentation.state.autoEquipEnabled },
                set: { model.send(ManagementIntent.autoEquip($0)) }
            ))
        }
    }

    private var inventorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Inventory")
                    .font(.headline)
                Spacer()
                Button("Equip", systemImage: "arrow.up.circle") {
                    guard selectedItemIsOwned,
                          let intent = ManagementIntent.equip(selection) else { return }
                    model.send(intent)
                }
                .disabled(!selectedItemIsOwned)
                .accessibilityIdentifier("equip-selected-item")
            }

            Table(rows, selection: $selection) {
                TableColumn("Slot") { row in
                    Text(row.slot.rawValue.capitalized)
                }
                TableColumn("Level") { row in
                    Text("\(row.level)")
                }
                TableColumn("Stat") { row in
                    Text("\(row.primaryStat)")
                }
                TableColumn("Equipped") { row in
                    Text(row.isEquipped ? "Yes" : "No")
                }
            }
            .accessibilityIdentifier("inventory-table")
            .frame(minHeight: 180)
        }
    }

    private var saveStatusSection: some View {
        Text(ManagementFormat.saveStatus(model.saveStatus))
            .foregroundStyle(model.saveStatus.isFailure ? Color.red : Color.secondary)
    }

    @ViewBuilder
    private func statGrid(title: String, values: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                ForEach(values, id: \.0) { label, value in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(value)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value) DPS")
                .font(.title3.monospacedDigit())
        }
    }

    private func equipmentRow(for slot: EquipmentSlot) -> some View {
        let item = presentation.state.inventory.first { $0.id == presentation.state.equipment[slot] }
        return HStack {
            Text(slot.rawValue.capitalized)
                .frame(width: 80, alignment: .leading)
            if let item {
                Text("Lv. \(item.level)  +\(item.primaryStat)")
            } else {
                Text("None")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private extension SaveStatus {
    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}
