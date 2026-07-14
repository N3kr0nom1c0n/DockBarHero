struct AreaID: RawRepresentable, Hashable, Equatable, Sendable {
    let rawValue: String

    static let forgottenShallowDepths = AreaID(rawValue: "forgotten-shallow-depths")
}

struct EnemyContentID: RawRepresentable, Hashable, Equatable, Sendable {
    let rawValue: String

    static let goblin = EnemyContentID(rawValue: "goblin")
    static let bandit = EnemyContentID(rawValue: "bandit")
    static let slime = EnemyContentID(rawValue: "slime")
    static let mimic = EnemyContentID(rawValue: "mimic")
    static let skeleton = EnemyContentID(rawValue: "skeleton")
    static let bat = EnemyContentID(rawValue: "bat")
    static let zombie = EnemyContentID(rawValue: "zombie")
    static let knight = EnemyContentID(rawValue: "knight")
    static let frostWraith = EnemyContentID(rawValue: "frost-wraith")
    static let poisonNagaQueen = EnemyContentID(rawValue: "poison-naga-queen")
    static let ancientGolem = EnemyContentID(rawValue: "ancient-golem")
    static let unknownGuardian = EnemyContentID(rawValue: "unknown-guardian")
}

struct EnemySpriteID: RawRepresentable, Hashable, Equatable, Sendable {
    let rawValue: String

    static let goblin = EnemySpriteID(rawValue: "goblin")
    static let bandit = EnemySpriteID(rawValue: "bandit")
    static let slime = EnemySpriteID(rawValue: "slime")
    static let mimic = EnemySpriteID(rawValue: "mimic")
    static let skeleton = EnemySpriteID(rawValue: "skeleton")
    static let bat = EnemySpriteID(rawValue: "bat")
    static let zombie = EnemySpriteID(rawValue: "zombie")
    static let knight = EnemySpriteID(rawValue: "knight")
    static let frostWraith = EnemySpriteID(rawValue: "frost-wraith")
    static let poisonNagaQueen = EnemySpriteID(rawValue: "poison-naga-queen")
    static let ancientGolem = EnemySpriteID(rawValue: "ancient-golem")
    static let unknownGuardian = EnemySpriteID(rawValue: "unknown-guardian")
}

struct EnemyStatProfile: Equatable, Sendable {
    let healthBasisPoints: Int64
    let attackBasisPoints: Int64
    let defenseBonus: Int
    let attackIntervalBasisPoints: Int64
}

struct AreaDefinition: Equatable, Sendable {
    let id: AreaID
    let fullName: String
    let shortName: String
    let levels: ClosedRange<Int>
}

struct EnemyDefinition: Equatable, Sendable {
    let id: EnemyContentID
    let displayName: String
    let tier: EnemyTierID
    let spriteID: EnemySpriteID
    let profile: EnemyStatProfile
}

struct EncounterDefinition: Equatable, Sendable {
    let level: Int
    let areaID: AreaID
    let enemyID: EnemyContentID
}

enum CampaignCatalogError: Error, Equatable, Sendable {
    case invalidLevel(Int)
    case duplicateAreaID(AreaID)
    case duplicateEnemyID(EnemyContentID)
    case duplicateEncounterLevel(Int)
    case missingAuthoredLevel(Int)
    case unknownAreaReference(AreaID)
    case unknownEnemyReference(EnemyContentID)
    case tierMismatch(level: Int, expected: EnemyTierID, actual: EnemyTierID)
    case invalidArea(AreaID)
    case invalidEnemy(EnemyContentID)
}

struct CampaignCatalog: Sendable {
    var areas: [AreaDefinition]
    var enemies: [EnemyDefinition]
    var encounters: [EncounterDefinition]

    static let standard = CampaignCatalog(
        areas: [
            AreaDefinition(
                id: .forgottenShallowDepths,
                fullName: "The Forgotten Shallow Depths That Were Remembered",
                shortName: "Shallow Depths",
                levels: 1...25
            ),
        ],
        enemies: [
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
            enemy(
                .ancientGolem,
                "Ancient Golem",
                .elite,
                .ancientGolem,
                16_000,
                11_000,
                4,
                15_000
            ),
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
        ],
        encounters: [
            .slime, .bat, .goblin, .skeleton, .knight,
            .zombie, .bandit, .slime, .mimic, .frostWraith,
            .goblin, .bat, .skeleton, .zombie, .poisonNagaQueen,
            .bandit, .mimic, .goblin, .skeleton, .ancientGolem,
            .bat, .zombie, .bandit, .mimic, .unknownGuardian,
        ].enumerated().map { offset, enemyID in
            EncounterDefinition(
                level: offset + 1,
                areaID: .forgottenShallowDepths,
                enemyID: enemyID
            )
        }
    )

    func area(id: AreaID) -> AreaDefinition? {
        areas.first { $0.id == id }
    }

    func enemy(id: EnemyContentID) -> EnemyDefinition? {
        enemies.first { $0.id == id }
    }

    func authoredEncounter(level: Int) -> EncounterDefinition? {
        encounters.first { $0.level == level }
    }

    func validate() throws {
        var areaIDs: Set<AreaID> = []
        for area in areas {
            guard !area.id.rawValue.isEmpty,
                  !area.fullName.isEmpty,
                  !area.shortName.isEmpty,
                  area.levels.lowerBound >= 1 else {
                throw CampaignCatalogError.invalidArea(area.id)
            }
            guard areaIDs.insert(area.id).inserted else {
                throw CampaignCatalogError.duplicateAreaID(area.id)
            }
        }

        var enemyIDs: Set<EnemyContentID> = []
        for enemy in enemies {
            guard !enemy.id.rawValue.isEmpty,
                  !enemy.displayName.isEmpty,
                  !enemy.spriteID.rawValue.isEmpty,
                  enemy.profile.healthBasisPoints > 0,
                  enemy.profile.attackBasisPoints > 0,
                  enemy.profile.defenseBonus >= 0,
                  enemy.profile.attackIntervalBasisPoints > 0 else {
                throw CampaignCatalogError.invalidEnemy(enemy.id)
            }
            guard enemyIDs.insert(enemy.id).inserted else {
                throw CampaignCatalogError.duplicateEnemyID(enemy.id)
            }
        }

        var encounterLevels: Set<Int> = []
        for encounter in encounters {
            guard (1...25).contains(encounter.level) else {
                throw CampaignCatalogError.invalidLevel(encounter.level)
            }
            guard encounterLevels.insert(encounter.level).inserted else {
                throw CampaignCatalogError.duplicateEncounterLevel(encounter.level)
            }
        }

        for level in 1...25 where !encounterLevels.contains(level) {
            throw CampaignCatalogError.missingAuthoredLevel(level)
        }

        let areasByID = Dictionary(uniqueKeysWithValues: areas.map { ($0.id, $0) })
        let enemiesByID = Dictionary(uniqueKeysWithValues: enemies.map { ($0.id, $0) })
        for encounter in encounters {
            guard areasByID[encounter.areaID] != nil else {
                throw CampaignCatalogError.unknownAreaReference(encounter.areaID)
            }
            guard let enemy = enemiesByID[encounter.enemyID] else {
                throw CampaignCatalogError.unknownEnemyReference(encounter.enemyID)
            }
            guard let expectedTier = EncounterSchedule.standard.tier(for: encounter.level) else {
                throw CampaignCatalogError.invalidLevel(encounter.level)
            }
            guard enemy.tier == expectedTier else {
                throw CampaignCatalogError.tierMismatch(
                    level: encounter.level,
                    expected: expectedTier,
                    actual: enemy.tier
                )
            }
        }
    }

    private static func enemy(
        _ id: EnemyContentID,
        _ displayName: String,
        _ tier: EnemyTierID,
        _ spriteID: EnemySpriteID,
        _ healthBasisPoints: Int64,
        _ attackBasisPoints: Int64,
        _ defenseBonus: Int,
        _ attackIntervalBasisPoints: Int64
    ) -> EnemyDefinition {
        EnemyDefinition(
            id: id,
            displayName: displayName,
            tier: tier,
            spriteID: spriteID,
            profile: EnemyStatProfile(
                healthBasisPoints: healthBasisPoints,
                attackBasisPoints: attackBasisPoints,
                defenseBonus: defenseBonus,
                attackIntervalBasisPoints: attackIntervalBasisPoints
            )
        )
    }
}
