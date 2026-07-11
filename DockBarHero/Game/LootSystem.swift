struct LootSystem {
    let balance: BalanceConfiguration

    init(balance: BalanceConfiguration = .standard) {
        self.balance = balance
    }

    mutating func drop(defeatedLevel: Int, state: inout GameState) throws -> Item {
        let sequence = state.lootSequence
        let (rawID, idOverflow) = sequence.addingReportingOverflow(1)
        guard !idOverflow else { throw SimulationError.arithmeticOverflow }
        let itemID = ItemID(rawValue: rawID)
        guard !state.inventory.contains(where: {
            $0.id == itemID || $0.creationSequence == rawID
        }) else {
            throw SimulationError.invalidState
        }

        let slot: EquipmentSlot = sequence.isMultiple(of: 2) ? .weapon : .armor
        guard let primaryStat = balance.itemPrimaryStat(level: defeatedLevel, slot: slot) else {
            throw SimulationError.invalidBalance
        }

        let item = Item(
            id: itemID,
            level: defeatedLevel,
            slot: slot,
            primaryStat: primaryStat,
            creationSequence: rawID
        )
        state.inventory.append(item)
        state.lootSequence = rawID
        return item
    }
}
