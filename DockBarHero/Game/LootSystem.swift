struct LootSystem {
    let balance: BalanceConfiguration

    init(balance: BalanceConfiguration = .standard) {
        self.balance = balance
    }

    mutating func drop(defeatedLevel: Int, state: inout GameState) throws -> Item {
        let sequence = state.lootSequence
        let (rawID, idOverflow) = sequence.addingReportingOverflow(1)
        guard !idOverflow else { throw SimulationError.arithmeticOverflow }

        let slot: EquipmentSlot = sequence.isMultiple(of: 2) ? .weapon : .armor
        guard let primaryStat = balance.itemPrimaryStat(level: defeatedLevel, slot: slot) else {
            throw SimulationError.invalidBalance
        }

        let item = Item(
            id: ItemID(rawValue: rawID),
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
