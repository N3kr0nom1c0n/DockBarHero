import SwiftUI

struct InventoryView: View {
    @ObservedObject var model: AppModel
    @State private var selection: ItemID?
    @State private var selectedHeroSlot = 0
    @State private var sortOrder = [
        KeyPathComparator(\InventoryRow.creationSequence, order: .reverse),
        KeyPathComparator(\InventoryRow.id.rawValue, order: .reverse),
    ]

    private var rows: [InventoryRow] {
        InventoryRow.sorted(
            InventoryRow.rows(for: model.game.state, heroSlot: selectedHeroSlot),
            using: sortOrder
        )
    }
    private var selectedItemIsOwned: Bool {
        guard let selection else { return false }
        return rows.contains { $0.id == selection }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Picker("Hero", selection: $selectedHeroSlot) {
                    ForEach(Array(model.game.state.party.heroes.enumerated()), id: \.offset) { slot, hero in
                        Text("Hero \(slot + 1) · \(hero.classID.displayName)").tag(slot)
                    }
                }
                .frame(maxWidth: 220)
                Toggle("Auto-equip upgrades", isOn: Binding(
                    get: { model.game.state.autoEquipEnabled },
                    set: { model.send(ManagementIntent.autoEquip($0)) }
                ))
                Spacer()
                Button("Equip", systemImage: "arrow.up.circle") {
                    guard selectedItemIsOwned,
                          let intent = ManagementIntent.equip(
                              heroSlot: selectedHeroSlot,
                              selection: selection
                          ) else { return }
                    model.send(intent)
                }
                .disabled(!selectedItemIsOwned)
                .accessibilityIdentifier("equip-selected-item")
                if let selection,
                   let selected = rows.first(where: { $0.id == selection }) {
                    Button(selected.isLocked ? "Unlock" : "Lock") {
                        model.send(ManagementIntent.setItemLocked(
                            itemID: selection,
                            isLocked: !selected.isLocked
                        ))
                    }
                    .disabled(selected.rarity == .unique)
                    .accessibilityIdentifier("lock-selected-item")
                }
            }

            Table(rows, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("Slot", value: \.slotName)
                TableColumn("Level", value: \.level) { Text(ManagementFormat.itemLevel($0.level)) }
                TableColumn("Rarity", value: \.rarityName)
                TableColumn("Stat", value: \.primaryStat) { Text("\($0.primaryStat)") }
                TableColumn("Affixes", value: \.affixLabel)
                TableColumn("Comparison", value: \.comparisonLabel)
                TableColumn("Created", value: \.creationSequence) { Text("\($0.creationSequence)") }
                TableColumn("Equipped", value: \.equippedLabel)
                TableColumn("Locked") { Text($0.isLocked ? "Yes" : "No") }
            }
            .accessibilityIdentifier("inventory-table")
        }
        .padding(24)
        .navigationTitle("Inventory")
    }
}
