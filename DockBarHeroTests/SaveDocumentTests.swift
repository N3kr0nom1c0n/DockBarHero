import Foundation
import XCTest
@testable import DockBarHero

final class SaveDocumentTests: XCTestCase {
    private let savedAt = Date(timeIntervalSince1970: 1_783_641_600)

    func testActiveStateRoundTripsWithVersionAndTimestamp() throws {
        let state = GameState.newGame(balance: .standard)
        let codec = SaveCodec()

        let data = try codec.encode(state: state, savedAt: savedAt)
        let document = try codec.decode(data)

        XCTAssertEqual(document.schemaVersion, SaveDocument.currentVersion)
        XCTAssertEqual(document.savedAt, savedAt)
        XCTAssertEqual(document.state, state)
    }

    func testRevivingStateRoundTripsWithoutChangingEncounterPhase() throws {
        var state = GameState.newGame(balance: .standard)
        state.hero.currentHealth = 0
        state.encounter.phase = .reviving
        state.encounter.reviveRemaining = .nanoseconds(2_000_000_000)

        let codec = SaveCodec()
        let decoded = try codec.decode(try codec.encode(state: state, savedAt: savedAt))

        XCTAssertEqual(decoded.state, state)
        XCTAssertEqual(decoded.state.encounter.phase, .reviving)
    }

    func testEncodingUsesISO8601DatesAndSortedDeterministicKeys() throws {
        let codec = SaveCodec()
        let first = try codec.encode(state: .newGame(balance: .standard), savedAt: savedAt)
        let second = try codec.encode(state: .newGame(balance: .standard), savedAt: savedAt)
        let text = String(decoding: first, as: UTF8.self)

        XCTAssertEqual(first, second)
        XCTAssertTrue(text.contains(#""savedAt":"2026-07-10T00:00:00Z""#))
        XCTAssertLessThan(text.range(of: #""savedAt""#)!.lowerBound, text.range(of: #""schemaVersion""#)!.lowerBound)
        XCTAssertLessThan(text.range(of: #""autoEquipEnabled""#)!.lowerBound, text.range(of: #""encounter""#)!.lowerBound)
    }

    func testSimulationDurationRemainsOneScalarInt64InSave() throws {
        var state = GameState.newGame(balance: .standard)
        state.hero.timeUntilNextAttack = .nanoseconds(123_456_789)

        let data = try SaveCodec().encode(state: state, savedAt: savedAt)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let body = try XCTUnwrap(object["state"] as? [String: Any])
        let hero = try XCTUnwrap(body["hero"] as? [String: Any])

        XCTAssertEqual(hero["timeUntilNextAttack"] as? Int, 123_456_789)
    }

    func testFutureVersionIsRejectedBeforeMalformedBodyDecoding() {
        let data = Data(#"{"schemaVersion":2,"savedAt":"2026-07-10T00:00:00Z","state":{}}"#.utf8)

        XCTAssertThrowsError(try SaveCodec().decode(data)) { error in
            XCTAssertEqual(error as? SaveDecodingError, .unsupportedVersion(2))
        }
    }

    func testNegativeOrOutOfBoundsTimersAreRejected() throws {
        var negative = GameState.newGame(balance: .standard)
        negative.hero.timeUntilNextAttack = .nanoseconds(-1)
        assertValidation(.invalidTimer, for: negative)

        var shortInterval = GameState.newGame(balance: .standard)
        shortInterval.hero.timeUntilNextAttack = .nanoseconds(0)
        shortInterval.hero = CombatantState(
            id: .hero,
            currentHealth: 100,
            maxHealth: 100,
            baseAttack: 10,
            baseDefense: 0,
            attackInterval: .nanoseconds(999_999),
            timeUntilNextAttack: .nanoseconds(999_999)
        )
        assertValidation(.invalidTimer, for: shortInterval)

        var elapsed = GameState.newGame(balance: .standard)
        elapsed.encounter.activeElapsed = .nanoseconds(10_000_000_001)
        assertValidation(.invalidTimer, for: elapsed)
    }

    func testHealthAndEnemyLevelBoundsAreRejected() throws {
        var health = GameState.newGame(balance: .standard)
        health.hero.currentHealth = health.hero.maxHealth + 1
        assertValidation(.invalidHealth(.hero), for: health)

        var level = GameState.newGame(balance: .standard)
        level.encounter.enemyLevel = 0
        assertValidation(.invalidEnemyLevel, for: level)
    }

    func testItemsRequirePositiveUniqueIdentifiersLevelsAndStats() throws {
        var zeroID = GameState.newGame(balance: .standard)
        zeroID.inventory = [Item(id: ItemID(rawValue: 0), level: 1, slot: .weapon, primaryStat: 1, creationSequence: 1)]
        assertValidation(.invalidItem(zeroID.inventory[0].id), for: zeroID)

        var duplicate = GameState.newGame(balance: .standard)
        let item = Item(id: ItemID(rawValue: 1), level: 1, slot: .weapon, primaryStat: 1, creationSequence: 1)
        duplicate.inventory = [item, item]
        assertValidation(.duplicateItemID(item.id), for: duplicate)

        var invalidLevel = GameState.newGame(balance: .standard)
        invalidLevel.inventory = [Item(id: ItemID(rawValue: 1), level: 0, slot: .weapon, primaryStat: 1, creationSequence: 1)]
        assertValidation(.invalidItem(invalidLevel.inventory[0].id), for: invalidLevel)

        var invalidStat = GameState.newGame(balance: .standard)
        invalidStat.inventory = [Item(id: ItemID(rawValue: 1), level: 1, slot: .weapon, primaryStat: 0, creationSequence: 1)]
        assertValidation(.invalidItem(invalidStat.inventory[0].id), for: invalidStat)
    }

    func testEquipmentMustReferenceAnExistingItemInTheExactSlot() throws {
        var missing = GameState.newGame(balance: .standard)
        missing.equipment.weaponID = ItemID(rawValue: 99)
        assertValidation(.missingEquipment(ItemID(rawValue: 99)), for: missing)

        var wrongSlot = GameState.newGame(balance: .standard)
        let armor = Item(id: ItemID(rawValue: 1), level: 1, slot: .armor, primaryStat: 1, creationSequence: 1)
        wrongSlot.inventory = [armor]
        wrongSlot.equipment.weaponID = armor.id
        assertValidation(.equipmentSlotMismatch(armor.id), for: wrongSlot)
    }

    func testEncounterPhaseMustMatchCombatantHealthAndReviveBounds() throws {
        var active = GameState.newGame(balance: .standard)
        active.hero.currentHealth = 0
        assertValidation(.inconsistentEncounter, for: active)

        var reviving = GameState.newGame(balance: .standard)
        reviving.hero.currentHealth = 0
        reviving.encounter.phase = .reviving
        reviving.encounter.reviveRemaining = .nanoseconds(3_000_000_001)
        assertValidation(.inconsistentEncounter, for: reviving)

        var deadEnemy = GameState.newGame(balance: .standard)
        deadEnemy.enemy.currentHealth = 0
        assertValidation(.inconsistentEncounter, for: deadEnemy)
    }

    private func assertValidation(_ expected: SaveValidationError, for state: GameState, file: StaticString = #filePath, line: UInt = #line) {
        let data: Data
        do {
            data = try fixtureData(for: state)
        } catch {
            XCTFail("fixture encoding failed: \(error)", file: file, line: line)
            return
        }

        XCTAssertThrowsError(try SaveCodec().decode(data), file: file, line: line) { error in
            XCTAssertEqual(error as? SaveValidationError, expected, file: file, line: line)
        }
    }

    private func fixtureData(for state: GameState) throws -> Data {
        struct Fixture: Codable {
            let schemaVersion: Int
            let savedAt: Date
            let state: GameState
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(Fixture(schemaVersion: SaveDocument.currentVersion, savedAt: savedAt, state: state))
    }
}
