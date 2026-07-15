struct ResolvedCampaignEncounter: Equatable, Sendable {
    let level: Int
    let tier: EnemyTierID
    let area: AreaDefinition?
    let enemy: EnemyDefinition?
}

struct CampaignResolver: Sendable {
    let catalog: CampaignCatalog

    init(catalog: CampaignCatalog = .standard) {
        self.catalog = catalog
    }

    func resolve(level: Int) throws -> ResolvedCampaignEncounter {
        guard level >= 1 else {
            throw CampaignCatalogError.invalidLevel(level)
        }
        try catalog.validate()

        guard let encounter = catalog.authoredEncounter(level: level) else {
            guard let tier = EncounterSchedule.standard.tier(for: level) else {
                throw CampaignCatalogError.invalidLevel(level)
            }
            return ResolvedCampaignEncounter(
                level: level,
                tier: tier,
                area: nil,
                enemy: nil
            )
        }
        guard let area = catalog.area(id: encounter.areaID) else {
            throw CampaignCatalogError.unknownAreaReference(encounter.areaID)
        }
        guard let enemy = catalog.enemy(id: encounter.enemyID) else {
            throw CampaignCatalogError.unknownEnemyReference(encounter.enemyID)
        }
        return ResolvedCampaignEncounter(
            level: level,
            tier: enemy.tier,
            area: area,
            enemy: enemy
        )
    }
}
