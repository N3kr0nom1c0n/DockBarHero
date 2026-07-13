struct LootSystem {
    let balance: BalanceConfiguration

    init(balance: BalanceConfiguration = .standard) {
        self.balance = balance
    }

    mutating func drop(defeatedLevel: Int, state: inout GameState) throws -> Item {
        try drop(defeatedLevel: defeatedLevel, tier: .normal, state: &state)
    }

    mutating func drop(
        defeatedLevel: Int,
        tier: EnemyTierID,
        state: inout GameState
    ) throws -> Item {
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
        let item = try LootGenerator(balance: balance).generate(
            defeatedLevel: defeatedLevel,
            tier: tier,
            sequence: sequence,
            slot: slot
        )
        guard item.id == itemID, item.creationSequence == rawID else {
            throw SimulationError.invalidState
        }
        state.lootSequence = rawID
        let insertion = try InventoryResolver().insertDrop(item, into: state)
        state = insertion.state
        return Item(
            id: insertion.entryID,
            level: item.level,
            slot: item.slot,
            primaryStat: item.primaryStat,
            creationSequence: item.creationSequence,
            templateID: item.templateID,
            rarity: item.rarity,
            affixes: item.affixes,
            isLocked: item.isLocked,
            uniqueName: item.uniqueName,
            quantity: 1
        )
    }
}
