import SwiftUI

struct InventoryView: View {
    @ObservedObject var model: AppModel
    @State private var selection: ItemID?
    @State private var sortOrder = [
        KeyPathComparator(\InventoryRow.creationSequence, order: .reverse),
        KeyPathComparator(\InventoryRow.id.rawValue, order: .reverse),
    ]

    private var rows: [InventoryRow] {
        InventoryRow.sorted(InventoryRow.rows(for: model.game.state), using: sortOrder)
    }
    private var selectedItemIsOwned: Bool {
        guard let selection else { return false }
        return rows.contains { $0.id == selection }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Toggle("Auto-equip upgrades", isOn: Binding(
                    get: { model.game.state.autoEquipEnabled },
                    set: { model.send(ManagementIntent.autoEquip($0)) }
                ))
                Spacer()
                Button("Equip", systemImage: "arrow.up.circle") {
                    guard selectedItemIsOwned,
                          let intent = ManagementIntent.equip(selection) else { return }
                    model.send(intent)
                }
                .disabled(!selectedItemIsOwned)
                .accessibilityIdentifier("equip-selected-item")
            }

            Table(rows, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("Slot", value: \.slotName)
                TableColumn("Level", value: \.level) { Text(ManagementFormat.itemLevel($0.level)) }
                TableColumn("Stat", value: \.primaryStat) { Text("\($0.primaryStat)") }
                TableColumn("Created", value: \.creationSequence) { Text("\($0.creationSequence)") }
                TableColumn("Equipped", value: \.equippedLabel)
            }
            .accessibilityIdentifier("inventory-table")
        }
        .padding(24)
        .navigationTitle("Inventory")
    }
}
