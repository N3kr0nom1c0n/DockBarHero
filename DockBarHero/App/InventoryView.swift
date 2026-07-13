import SwiftUI

struct InventoryView: View {
    @ObservedObject var model: AppModel
    @State private var selection: ItemID?
    @State private var selectedHeroSlot = 0
    @State private var rarityFilter: ItemRarity?
    @State private var slotFilter: EquipmentSlot?
    @State private var upgradeOnly = false
    @State private var sortOption = InventorySortOption.newest
    @State private var operationQuantity: UInt64 = 1
    @State private var pendingSalvage: [SalvageSelection] = []
    @State private var showingSalvageConfirmation = false

    private var rows: [InventoryRow] {
        InventoryQuery(
            rarity: rarityFilter,
            slot: slotFilter,
            upgradeOnly: upgradeOnly,
            sort: sortOption
        ).apply(to: InventoryRow.rows(for: model.game.state, heroSlot: selectedHeroSlot))
    }

    private var selectedRow: InventoryRow? {
        guard let selection else { return nil }
        return rows.first { $0.id == selection }
    }

    private var capacity: Int {
        (try? InventoryResolver().capacity(for: model.game.state)) ?? 0
    }

    private var nextPurchasePrice: Int64? {
        guard capacity < InventoryConfiguration.standard.maximumCapacity else { return nil }
        return try? InventoryConfiguration.standard.purchasePrice(
            after: model.game.state.inventoryExpansionPurchases
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            capacityHeader
            heroAndFilterControls
            operationControls
            inventoryTable
        }
        .padding(24)
        .navigationTitle("Inventory")
        .onChange(of: selection) { _, _ in operationQuantity = 1 }
        .alert("Salvage selected items?", isPresented: $showingSalvageConfirmation) {
            Button("Cancel", role: .cancel) { pendingSalvage = [] }
            Button("Salvage", role: .destructive) {
                model.send(ManagementIntent.salvage(pendingSalvage))
                pendingSalvage = []
                selection = nil
            }
        } message: {
            Text("This permanently removes \(pendingSalvage.reduce(UInt64(0)) { $0 + $1.quantity }) item(s) and grants gold.")
        }
    }

    private var capacityHeader: some View {
        HStack(spacing: 12) {
            Label("\(model.game.state.inventory.count)/\(capacity) slots", systemImage: "shippingbox")
                .accessibilityIdentifier("inventory-capacity")
            if !model.game.state.overflowInventory.isEmpty {
                Text("Overflow: \(model.game.state.overflowInventory.count) stacks")
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("inventory-overflow-count")
            }
            Spacer()
            if let price = nextPurchasePrice {
                Button("Add 10 Slots · \(price) Gold") {
                    model.send(ManagementIntent.purchaseInventoryCapacity)
                }
                .disabled(model.game.state.economy.gold < price)
                .help(model.game.state.economy.gold < price ? "Not enough gold" : "Purchase ten inventory slots")
                .accessibilityIdentifier("purchase-inventory-capacity")
            } else {
                Text("Maximum capacity")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var heroAndFilterControls: some View {
        HStack {
            Picker("Hero", selection: $selectedHeroSlot) {
                ForEach(Array(model.game.state.party.heroes.enumerated()), id: \.offset) { slot, hero in
                    Text("Hero \(slot + 1) · \(hero.classID.displayName)").tag(slot)
                }
            }
            .frame(maxWidth: 210)
            Picker("Rarity", selection: $rarityFilter) {
                Text("All rarities").tag(nil as ItemRarity?)
                ForEach(ItemRarity.allCases, id: \.rawValue) { rarity in
                    Text(rarity.rawValue.capitalized).tag(rarity as ItemRarity?)
                }
            }
            .frame(maxWidth: 155)
            Picker("Slot", selection: $slotFilter) {
                Text("All slots").tag(nil as EquipmentSlot?)
                ForEach(EquipmentSlot.allCases, id: \.rawValue) { slot in
                    Text(slot.rawValue.capitalized).tag(slot as EquipmentSlot?)
                }
            }
            .frame(maxWidth: 140)
            Picker("Sort", selection: $sortOption) {
                ForEach(InventorySortOption.allCases, id: \.rawValue) { option in
                    Text(option.label).tag(option)
                }
            }
            .frame(maxWidth: 145)
            Toggle("Upgrades only", isOn: $upgradeOnly)
            Toggle("Auto-equip", isOn: Binding(
                get: { model.game.state.autoEquipEnabled },
                set: { model.send(ManagementIntent.autoEquip($0)) }
            ))
        }
    }

    private var operationControls: some View {
        HStack(spacing: 10) {
            Button("Equip", systemImage: "arrow.up.circle") {
                guard let selectedRow,
                      let intent = ManagementIntent.equip(
                          heroSlot: selectedHeroSlot,
                          selection: selectedRow.id
                      ) else { return }
                model.send(intent)
            }
            .disabled(selectedRow?.location != .inventory || selectedRow?.isEquipped == true)
            .help(selectedRow?.location == .overflow ? "Move this item out of overflow first" : "Equip one item on the selected hero")
            .accessibilityIdentifier("equip-selected-item")

            if let selectedRow {
                Button(selectedRow.isLocked ? "Unlock" : "Lock") {
                    model.send(ManagementIntent.setItemLocked(
                        itemID: selectedRow.id,
                        isLocked: !selectedRow.isLocked
                    ))
                }
                .disabled(selectedRow.rarity == .unique || selectedRow.location == .overflow)
                .accessibilityIdentifier("lock-selected-item")

                Stepper(
                    "Quantity: \(operationQuantity)",
                    value: $operationQuantity,
                    in: 1...max(1, selectedRow.quantity)
                )
                .frame(maxWidth: 170)

                if selectedRow.location == .overflow {
                    Button("Move to Inventory") {
                        model.send(ManagementIntent.moveOverflow(
                            itemID: selectedRow.id,
                            quantity: min(operationQuantity, selectedRow.quantity)
                        ))
                    }
                    .accessibilityIdentifier("move-overflow-selection")
                }

                Button("Salvage…", role: .destructive) {
                    pendingSalvage = [SalvageSelection(
                        location: selectedRow.location,
                        itemID: selectedRow.id,
                        quantity: min(operationQuantity, selectedRow.quantity)
                    )]
                    showingSalvageConfirmation = true
                }
                .disabled(!selectedRow.isSalvageable)
                .help(selectedRow.isSalvageable ? "Salvage the selected quantity" : "Equipped, locked, and Unique items cannot be salvaged")
                .accessibilityIdentifier("salvage-selected-items")
            }

            Spacer()
            Button("Select Salvageable…") {
                pendingSalvage = rows.filter(\.isSalvageable).map {
                    SalvageSelection(location: $0.location, itemID: $0.id, quantity: $0.quantity)
                }
                showingSalvageConfirmation = !pendingSalvage.isEmpty
            }
            .disabled(!rows.contains(where: \.isSalvageable))
            .accessibilityIdentifier("salvage-visible-items")
        }
    }

    private var inventoryTable: some View {
        Table(rows, selection: $selection) {
            TableColumn("Location", value: \.locationName)
            TableColumn("Qty") { Text("\($0.quantity)") }
            TableColumn("Slot", value: \.slotName)
            TableColumn("Level") { Text(ManagementFormat.itemLevel($0.level)) }
            TableColumn("Rarity", value: \.rarityName)
            TableColumn("Stat") { Text("\($0.primaryStat)") }
            TableColumn("Affixes", value: \.affixLabel)
            TableColumn("Comparison", value: \.comparisonLabel)
            TableColumn("Equipped", value: \.equippedLabel)
            TableColumn("Locked") { Text($0.isLocked ? "Yes" : "No") }
        }
        .accessibilityIdentifier("inventory-table")
    }
}
