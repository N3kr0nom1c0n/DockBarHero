import XCTest
@testable import DockBarHero

final class CampaignCatalogTests: XCTestCase {
    func testStandardAreaOneHasExactAuthoredSequence() throws {
        let catalog = CampaignCatalog.standard
        try catalog.validate()

        XCTAssertEqual((1...25).compactMap { catalog.authoredEncounter(level: $0)?.enemyID }, [
            .slime, .bat, .goblin, .skeleton, .knight,
            .zombie, .bandit, .slime, .mimic, .frostWraith,
            .goblin, .bat, .skeleton, .zombie, .poisonNagaQueen,
            .bandit, .mimic, .goblin, .skeleton, .ancientGolem,
            .bat, .zombie, .bandit, .mimic, .unknownGuardian,
        ])
        XCTAssertEqual(
            catalog.area(id: .forgottenShallowDepths)?.fullName,
            "The Forgotten Shallow Depths That Were Remembered"
        )
        XCTAssertEqual(catalog.area(id: .forgottenShallowDepths)?.shortName, "Shallow Depths")
    }

    func testStandardEnemiesHaveExactCopyProfilesAndSpriteIDs() {
        XCTAssertEqual(CampaignCatalog.standard.enemies, [
            enemy(.goblin, "Goblin", .normal, .goblin, 10_000, 10_000, 0, 10_000),
            enemy(.bandit, "Bandit", .normal, .bandit, 8_500, 11_500, 0, 8_000),
            enemy(.slime, "Slime", .normal, .slime, 13_000, 7_500, 0, 13_000),
            enemy(.mimic, "Mimic", .normal, .mimic, 12_500, 11_500, 2, 11_500),
            enemy(.skeleton, "Skeleton", .normal, .skeleton, 10_500, 9_000, 1, 10_500),
            enemy(.bat, "Bat", .normal, .bat, 7_000, 8_000, 0, 6_000),
            enemy(.zombie, "Zombie", .normal, .zombie, 14_000, 9_000, 0, 13_500),
            enemy(.knight, "Knight", .elite, .knight, 12_500, 10_000, 3, 11_000),
            enemy(.frostWraith, "Frost Wraith", .elite, .frostWraith, 8_500, 11_500, 1, 7_000),
            enemy(
                .poisonNagaQueen,
                "Poison Naga Queen",
                .elite,
                .poisonNagaQueen,
                11_000,
                12_000,
                2,
                8_500
            ),
            enemy(.ancientGolem, "Ancient Golem", .elite, .ancientGolem, 16_000, 11_000, 4, 15_000),
            enemy(
                .unknownGuardian,
                "Unknown Guardian",
                .boss,
                EnemySpriteID(rawValue: "generic.enemy"),
                10_000,
                10_000,
                0,
                10_000
            ),
        ])
    }

    func testAllAuthoredIdentityConstantsAreNonempty() {
        XCTAssertFalse([
            EnemyContentID.goblin, .bandit, .slime, .mimic, .skeleton, .bat,
            .zombie, .knight, .frostWraith, .poisonNagaQueen, .ancientGolem,
            .unknownGuardian,
        ].contains { $0.rawValue.isEmpty })
        XCTAssertFalse([
            EnemySpriteID.goblin, .bandit, .slime, .mimic, .skeleton, .bat,
            .zombie, .knight, .frostWraith, .poisonNagaQueen, .ancientGolem,
            .unknownGuardian,
        ].contains { $0.rawValue.isEmpty })
    }

    func testCatalogRejectsMissingAuthoredLevel() {
        var catalog = CampaignCatalog.standard
        catalog.encounters.removeAll { $0.level == 17 }

        assertValidationError(.missingAuthoredLevel(17), in: catalog)
    }

    func testCatalogRejectsInvalidEncounterLevel() {
        var catalog = CampaignCatalog.standard
        catalog.encounters.append(EncounterDefinition(
            level: 0,
            areaID: .forgottenShallowDepths,
            enemyID: .slime
        ))

        assertValidationError(.invalidLevel(0), in: catalog)
    }

    func testCatalogRejectsDuplicateAreaID() {
        var catalog = CampaignCatalog.standard
        catalog.areas.append(catalog.areas[0])

        assertValidationError(.duplicateAreaID(.forgottenShallowDepths), in: catalog)
    }

    func testCatalogRejectsDuplicateEnemyID() {
        var catalog = CampaignCatalog.standard
        catalog.enemies.append(catalog.enemies[0])

        assertValidationError(.duplicateEnemyID(.goblin), in: catalog)
    }

    func testCatalogRejectsDuplicateEncounterLevel() {
        var catalog = CampaignCatalog.standard
        catalog.encounters.append(catalog.encounters[0])

        assertValidationError(.duplicateEncounterLevel(1), in: catalog)
    }

    func testCatalogRejectsUnknownAreaReference() {
        var catalog = CampaignCatalog.standard
        catalog.encounters[0] = EncounterDefinition(
            level: 1,
            areaID: AreaID(rawValue: "missing.area"),
            enemyID: .slime
        )

        assertValidationError(.unknownAreaReference(AreaID(rawValue: "missing.area")), in: catalog)
    }

    func testCatalogRejectsUnknownEnemyReference() {
        var catalog = CampaignCatalog.standard
        catalog.encounters[0] = EncounterDefinition(
            level: 1,
            areaID: .forgottenShallowDepths,
            enemyID: EnemyContentID(rawValue: "missing.enemy")
        )

        assertValidationError(.unknownEnemyReference(EnemyContentID(rawValue: "missing.enemy")), in: catalog)
    }

    func testCatalogRejectsTierDisagreement() {
        var catalog = CampaignCatalog.standard
        catalog.encounters[4] = EncounterDefinition(
            level: 5,
            areaID: .forgottenShallowDepths,
            enemyID: .goblin
        )

        assertValidationError(
            .tierMismatch(level: 5, expected: .elite, actual: .normal),
            in: catalog
        )
    }

    func testCatalogRejectsEmptyAreaIDAndCopy() {
        var emptyID = CampaignCatalog.standard
        emptyID.areas[0] = AreaDefinition(
            id: AreaID(rawValue: ""),
            fullName: "The Forgotten Shallow Depths That Were Remembered",
            shortName: "Shallow Depths",
            levels: 1...25
        )
        assertValidationError(.invalidArea(AreaID(rawValue: "")), in: emptyID)

        var emptyCopy = CampaignCatalog.standard
        emptyCopy.areas[0] = AreaDefinition(
            id: .forgottenShallowDepths,
            fullName: "",
            shortName: "Shallow Depths",
            levels: 1...25
        )
        assertValidationError(.invalidArea(.forgottenShallowDepths), in: emptyCopy)
    }

    func testCatalogRejectsEmptyEnemyID() {
        var catalog = CampaignCatalog.standard
        catalog.enemies[0] = EnemyDefinition(
            id: EnemyContentID(rawValue: ""),
            displayName: "Goblin",
            tier: .normal,
            spriteID: .goblin,
            profile: profile(10_000, 10_000, 0, 10_000)
        )

        assertValidationError(.invalidEnemy(EnemyContentID(rawValue: "")), in: catalog)
    }

    func testCatalogRejectsEmptyEnemyDisplayName() {
        var catalog = CampaignCatalog.standard
        catalog.enemies[0] = enemy(.goblin, "", .normal, .goblin, 10_000, 10_000, 0, 10_000)

        assertValidationError(.invalidEnemy(.goblin), in: catalog)
    }

    func testCatalogRejectsEmptySpriteID() {
        var catalog = CampaignCatalog.standard
        catalog.enemies[0] = enemy(
            .goblin,
            "Goblin",
            .normal,
            EnemySpriteID(rawValue: ""),
            10_000,
            10_000,
            0,
            10_000
        )

        assertValidationError(.invalidEnemy(.goblin), in: catalog)
    }

    func testCatalogRejectsZeroHealthBasisPoints() {
        var catalog = CampaignCatalog.standard
        catalog.enemies[0] = enemy(.goblin, "Goblin", .normal, .goblin, 0, 10_000, 0, 10_000)

        assertValidationError(.invalidEnemy(.goblin), in: catalog)
    }

    func testCatalogRejectsNegativeAttackBasisPoints() {
        var catalog = CampaignCatalog.standard
        catalog.enemies[0] = enemy(.goblin, "Goblin", .normal, .goblin, 10_000, -1, 0, 10_000)

        assertValidationError(.invalidEnemy(.goblin), in: catalog)
    }

    func testCatalogRejectsNegativeDefense() {
        var catalog = CampaignCatalog.standard
        catalog.enemies[0] = enemy(.goblin, "Goblin", .normal, .goblin, 10_000, 10_000, -1, 10_000)

        assertValidationError(.invalidEnemy(.goblin), in: catalog)
    }

    func testCatalogRejectsZeroAttackIntervalBasisPoints() {
        var catalog = CampaignCatalog.standard
        catalog.enemies[0] = enemy(.goblin, "Goblin", .normal, .goblin, 10_000, 10_000, 0, 0)

        assertValidationError(.invalidEnemy(.goblin), in: catalog)
    }

    private func assertValidationError(
        _ expected: CampaignCatalogError,
        in catalog: CampaignCatalog,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try catalog.validate(), file: file, line: line) {
            XCTAssertEqual($0 as? CampaignCatalogError, expected, file: file, line: line)
        }
    }

    private func enemy(
        _ id: EnemyContentID,
        _ displayName: String,
        _ tier: EnemyTierID,
        _ spriteID: EnemySpriteID,
        _ health: Int64,
        _ attack: Int64,
        _ defense: Int,
        _ interval: Int64
    ) -> EnemyDefinition {
        EnemyDefinition(
            id: id,
            displayName: displayName,
            tier: tier,
            spriteID: spriteID,
            profile: profile(health, attack, defense, interval)
        )
    }

    private func profile(
        _ health: Int64,
        _ attack: Int64,
        _ defense: Int,
        _ interval: Int64
    ) -> EnemyStatProfile {
        EnemyStatProfile(
            healthBasisPoints: health,
            attackBasisPoints: attack,
            defenseBonus: defense,
            attackIntervalBasisPoints: interval
        )
    }
}
