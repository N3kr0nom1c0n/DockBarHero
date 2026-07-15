struct InventoryConfiguration: Sendable {
    static let standard = InventoryConfiguration()

    let startingCapacity = 40
    let boss25Capacity = 10
    let boss100Capacity = 20
    let slotsPerPurchase = 10
    let maximumCapacity = 200
    let startingPurchasePrice: Int64 = 500

    func purchasePrice(after purchases: Int) throws -> Int64 {
        guard purchases >= 0 else { throw SimulationError.invalidState }
        var price = startingPurchasePrice
        for _ in 0..<purchases {
            let (next, overflow) = price.multipliedReportingOverflow(by: 2)
            guard !overflow else { throw SimulationError.arithmeticOverflow }
            price = next
        }
        return price
    }

    func salvageMultiplier(for rarity: ItemRarity) throws -> Int64 {
        switch rarity {
        case .common: 1
        case .uncommon: 2
        case .rare: 4
        case .epic: 8
        case .unique: throw SimulationError.invalidState
        }
    }
}
