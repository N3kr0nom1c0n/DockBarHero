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
        guard let baselineStat = balance.itemPrimaryStat(level: defeatedLevel, slot: slot) else {
            throw SimulationError.invalidBalance
        }
        let primaryStat: Int
        do {
            let scaled = try ProgressionConfiguration.standard.applying(
                ProgressionConfiguration.standard.tierDefinition(for: tier).itemStatRatio,
                to: Int64(baselineStat),
                rounding: .up
            )
            guard scaled <= Int64(Int.max) else { throw SimulationError.arithmeticOverflow }
            primaryStat = Int(scaled)
        } catch let error as SimulationError {
            throw error
        } catch {
            throw SimulationError.arithmeticOverflow
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
