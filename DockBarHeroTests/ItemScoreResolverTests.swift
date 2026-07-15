import XCTest
@testable import DockBarHero

final class ItemScoreResolverTests: XCTestCase {
    func testDPSValuesMightAndHasteAsStrictUpgradeWithExactDeltas() throws {
        var state = GameState.newGame(classID: .dps, balance: .standard, progression: .standard)
        let candidate = Item(
            id: ItemID(rawValue: 1),
            level: 1,
            slot: .weapon,
            primaryStat: 3,
            creationSequence: 1,
            rarity: .rare,
            affixes: [
                .init(id: .haste, magnitude: 1_500),
                .init(id: .might, magnitude: 2),
            ]
        )
        state.inventory = [candidate]
        state.lootSequence = 1

        let result = try ItemScoreResolver().compare(item: candidate, heroSlot: 0, in: state)

        XCTAssertTrue(result.isStrictUpgrade)
        XCTAssertEqual(result.deltas.attack, 5)
        XCTAssertEqual(result.deltas.attackInterval, .nanoseconds(-150_000_000))
    }

    func testEqualCandidateScoreKeepsCurrentItem() throws {
        var state = GameState.newGame(classID: .tank, balance: .standard, progression: .standard)
        let current = Item(
            id: ItemID(rawValue: 1), level: 1, slot: .armor,
            primaryStat: 2, creationSequence: 1
        )
        let equal = Item(
            id: ItemID(rawValue: 2), level: 1, slot: .armor,
            primaryStat: 2, creationSequence: 2
        )
        state.inventory = [current, equal]
        state.lootSequence = 2
        state.party.heroes[0].equipment.armorID = current.id

        let result = try ItemScoreResolver().compare(item: equal, heroSlot: 0, in: state)

        XCTAssertEqual(result.currentScore, result.candidateScore)
        XCTAssertFalse(result.isStrictUpgrade)
    }

    func testOrdinaryLockTogglesAndUniqueUnlockRollsBack() throws {
        var state = GameState.newGame(balance: .standard)
        let ordinary = Item(
            id: ItemID(rawValue: 1), level: 1, slot: .weapon,
            primaryStat: 1, creationSequence: 1
        )
        let unique = Item(
            id: ItemID(rawValue: 2), level: 1, slot: .armor,
            primaryStat: 2, creationSequence: 2,
            templateID: ItemTemplateID(rawValue: "unique.test"),
            rarity: .unique, isLocked: true, uniqueName: "Test Relic"
        )
        state.inventory = [ordinary, unique]
        state.lootSequence = 2
        var simulation = GameSimulation(state: state)

        XCTAssertEqual(
            try simulation.apply(.setItemLocked(itemID: ordinary.id, isLocked: true)),
            [.itemLockChanged(itemID: ordinary.id, isLocked: true)]
        )
        let before = simulation.state
        XCTAssertThrowsError(
            try simulation.apply(.setItemLocked(itemID: unique.id, isLocked: false))
        )
        XCTAssertEqual(simulation.state, before)
    }
}
