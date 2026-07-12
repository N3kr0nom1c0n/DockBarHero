struct VictoryReward: Equatable, Sendable {
    let state: GameState
    let events: [GameEvent]
}

struct RewardResolver: Sendable {
    func applyVictory(
        defeatedLevel: Int,
        to state: GameState,
        balance: BalanceConfiguration
    ) throws -> VictoryReward {
        var result = state
        var loot = LootSystem(balance: balance)
        let item = try loot.drop(defeatedLevel: defeatedLevel, state: &result)
        var events: [GameEvent] = [.loot(item)]

        if result.autoEquipEnabled, try CombatResolver().isStrictUpgrade(item, in: result) {
            result.equipment[item.slot] = item.id
            events.append(.equipped(slot: item.slot, itemID: item.id))
        }

        return VictoryReward(state: result, events: events)
    }
}
