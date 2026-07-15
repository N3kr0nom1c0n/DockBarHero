struct SalvageSelection: Codable, Equatable, Hashable, Sendable {
    let location: InventoryLocation
    let itemID: ItemID
    let quantity: UInt64
}

struct SalvageResult: Equatable, Sendable {
    var state: GameState
    let quantity: UInt64
    let goldGranted: Int64
}

struct SalvageResolver: Sendable {
    private struct SelectionKey: Hashable {
        let location: InventoryLocation
        let itemID: ItemID
    }

    let configuration: InventoryConfiguration

    init(configuration: InventoryConfiguration = .standard) {
        self.configuration = configuration
    }

    func salvage(_ selections: [SalvageSelection], in state: GameState) throws -> SalvageResult {
        let keys = selections.map { SelectionKey(location: $0.location, itemID: $0.itemID) }
        guard !selections.isEmpty, Set(keys).count == keys.count else {
            throw SimulationError.invalidState
        }
        let equippedIDs = Set(state.party.heroes.flatMap { hero in
            EquipmentSlot.allCases.compactMap { hero.equipment[$0] }
        })
        var gold: Int64 = 0
        var totalQuantity: UInt64 = 0
        for selection in selections {
            guard selection.quantity > 0 else { throw SimulationError.invalidState }
            let source = selection.location == .inventory ? state.inventory : state.overflowInventory
            guard let item = source.first(where: { $0.id == selection.itemID }),
                  item.quantity >= selection.quantity,
                  !item.isLocked,
                  item.rarity != .unique,
                  !equippedIDs.contains(item.id),
                  selection.quantity <= UInt64(Int64.max) else {
                throw SimulationError.invalidState
            }
            let multiplier = try configuration.salvageMultiplier(for: item.rarity)
            let (levelValue, levelOverflow) = Int64(item.level).multipliedReportingOverflow(by: multiplier)
            let (value, valueOverflow) = levelValue.multipliedReportingOverflow(by: Int64(selection.quantity))
            let (nextGold, goldOverflow) = gold.addingReportingOverflow(value)
            let (nextQuantity, quantityOverflow) = totalQuantity.addingReportingOverflow(selection.quantity)
            guard !levelOverflow, !valueOverflow, !goldOverflow, !quantityOverflow else {
                throw SimulationError.arithmeticOverflow
            }
            gold = nextGold
            totalQuantity = nextQuantity
        }
        let (economyGold, economyOverflow) = state.economy.gold.addingReportingOverflow(gold)
        guard !economyOverflow else { throw SimulationError.arithmeticOverflow }
        var result = state
        for selection in selections {
            if selection.location == .inventory {
                try remove(selection, from: &result.inventory)
            } else {
                try remove(selection, from: &result.overflowInventory)
            }
        }
        result.economy.gold = economyGold
        return SalvageResult(state: result, quantity: totalQuantity, goldGranted: gold)
    }

    private func remove(_ selection: SalvageSelection, from items: inout [Item]) throws {
        guard let index = items.firstIndex(where: { $0.id == selection.itemID }) else {
            throw SimulationError.invalidState
        }
        if items[index].quantity == selection.quantity {
            items.remove(at: index)
        } else {
            items[index].quantity -= selection.quantity
        }
    }
}
