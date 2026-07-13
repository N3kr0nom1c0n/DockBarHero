struct InventoryInsertion: Equatable, Sendable {
    var state: GameState
    let entryID: ItemID
    let location: InventoryLocation
}

enum InventoryLocation: String, Codable, Equatable, Sendable {
    case inventory
    case overflow
}

struct InventoryResolver: Sendable {
    let configuration: InventoryConfiguration

    init(configuration: InventoryConfiguration = .standard) {
        self.configuration = configuration
    }

    func capacity(for state: GameState) throws -> Int {
        guard state.inventoryExpansionPurchases >= 0 else { throw SimulationError.invalidState }
        let milestone: Int
        switch state.party.unlocks {
        case .locked: milestone = 0
        case .pendingSecond, .secondUnlocked: milestone = configuration.boss25Capacity
        case .complete: milestone = configuration.boss25Capacity + configuration.boss100Capacity
        }
        let (purchased, purchaseOverflow) = configuration.slotsPerPurchase
            .multipliedReportingOverflow(by: state.inventoryExpansionPurchases)
        guard !purchaseOverflow else { throw SimulationError.arithmeticOverflow }
        let (base, baseOverflow) = configuration.startingCapacity.addingReportingOverflow(milestone)
        guard !baseOverflow else { throw SimulationError.arithmeticOverflow }
        let (total, totalOverflow) = base.addingReportingOverflow(purchased)
        guard !totalOverflow else { throw SimulationError.arithmeticOverflow }
        return min(configuration.maximumCapacity, total)
    }

    func occupiedSlots(in state: GameState) -> Int { state.inventory.count }

    func canStack(_ lhs: Item, with rhs: Item) -> Bool {
        lhs.rarity != .unique && rhs.rarity != .unique &&
            lhs.templateID == rhs.templateID &&
            lhs.level == rhs.level &&
            lhs.slot == rhs.slot &&
            lhs.primaryStat == rhs.primaryStat &&
            lhs.rarity == rhs.rarity &&
            lhs.affixes == rhs.affixes &&
            lhs.isLocked == rhs.isLocked
    }

    func insertDrop(_ item: Item, into state: GameState) throws -> InventoryInsertion {
        guard item.quantity > 0 else { throw SimulationError.invalidState }
        var result = state
        let equippedIDs = Set(result.party.heroes.flatMap { hero in
            EquipmentSlot.allCases.compactMap { hero.equipment[$0] }
        })
        if item.rarity != .unique,
           let index = result.inventory.indices.first(where: {
               !equippedIDs.contains(result.inventory[$0].id) &&
                   canStack(result.inventory[$0], with: item)
           }) {
            result.inventory[index].quantity = try add(
                result.inventory[index].quantity,
                item.quantity
            )
            return InventoryInsertion(
                state: result,
                entryID: result.inventory[index].id,
                location: .inventory
            )
        }
        if result.inventory.count < (try capacity(for: result)) {
            result.inventory.append(item)
            return InventoryInsertion(state: result, entryID: item.id, location: .inventory)
        }
        if item.rarity != .unique,
           let index = result.overflowInventory.indices.first(where: {
               canStack(result.overflowInventory[$0], with: item)
           }) {
            result.overflowInventory[index].quantity = try add(
                result.overflowInventory[index].quantity,
                item.quantity
            )
            return InventoryInsertion(
                state: result,
                entryID: result.overflowInventory[index].id,
                location: .overflow
            )
        }
        result.overflowInventory.append(item)
        return InventoryInsertion(state: result, entryID: item.id, location: .overflow)
    }

    private func add(_ lhs: UInt64, _ rhs: UInt64) throws -> UInt64 {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        return value
    }
}
