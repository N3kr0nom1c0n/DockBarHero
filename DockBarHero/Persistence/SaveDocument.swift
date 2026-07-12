import Foundation

struct SaveDocument: Codable, Equatable, Sendable {
    static let currentVersion = 1

    let schemaVersion: Int
    let savedAt: Date
    let state: GameState
}

enum SaveDecodingError: Error, Equatable {
    case unsupportedVersion(Int)
}

enum SaveValidationError: Error, Equatable {
    case invalidEnemyLevel
    case invalidHealth(CombatantID)
    case invalidCombatStats(CombatantID)
    case invalidTimer
    case invalidItem(ItemID)
    case invalidLootSequence
    case duplicateItemID(ItemID)
    case missingEquipment(ItemID)
    case equipmentSlotMismatch(ItemID)
    case inconsistentEncounter
}

struct SaveCodec: Sendable {
    private struct VersionHeader: Decodable {
        let schemaVersion: Int
    }

    private let balance: BalanceConfiguration
    private let migrationRegistry: SaveMigrationRegistry

    init(
        balance: BalanceConfiguration = .standard,
        migrationRegistry: SaveMigrationRegistry = .empty(
            currentVersion: SaveDocument.currentVersion
        )
    ) {
        self.balance = balance
        self.migrationRegistry = migrationRegistry
    }

    func encode(state: GameState, savedAt: Date) throws -> Data {
        try validate(state)

        let document = SaveDocument(
            schemaVersion: SaveDocument.currentVersion,
            savedAt: savedAt,
            state: state
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(document)
    }

    func decode(_ data: Data) throws -> SaveDocument {
        let headerDecoder = JSONDecoder()
        let header = try headerDecoder.decode(VersionHeader.self, from: data)
        guard header.schemaVersion <= SaveDocument.currentVersion else {
            throw SaveDecodingError.unsupportedVersion(header.schemaVersion)
        }

        let currentData = if header.schemaVersion < SaveDocument.currentVersion {
            try migrationRegistry.migrateToCurrent(data, from: header.schemaVersion)
        } else {
            data
        }
        let currentHeader = try headerDecoder.decode(VersionHeader.self, from: currentData)
        guard currentHeader.schemaVersion == SaveDocument.currentVersion else {
            throw SaveDecodingError.unsupportedVersion(currentHeader.schemaVersion)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(SaveDocument.self, from: currentData)
        try validate(document.state)
        return document
    }

    private func validate(_ state: GameState) throws {
        guard state.hero.id == .hero, state.enemy.id == .enemy else {
            throw SaveValidationError.inconsistentEncounter
        }

        try validateHealth(state.hero)
        try validateHealth(state.enemy)
        try validateCombatStats(state.hero)
        try validateCombatStats(state.enemy)

        guard state.encounter.enemyLevel >= 1 else {
            throw SaveValidationError.invalidEnemyLevel
        }
        guard balance.enemy(level: state.encounter.enemyLevel) != nil else {
            throw SaveValidationError.invalidEnemyLevel
        }
        let (nextEnemyLevel, enemyLevelOverflow) = state.encounter.enemyLevel.addingReportingOverflow(1)
        guard !enemyLevelOverflow, balance.enemy(level: nextEnemyLevel) != nil else {
            throw SaveValidationError.invalidEnemyLevel
        }
        guard state.hero.attackInterval >= .minimumAttackInterval,
              state.enemy.attackInterval >= .minimumAttackInterval,
              state.hero.timeUntilNextAttack >= .zero,
              state.enemy.timeUntilNextAttack >= .zero,
              state.encounter.activeElapsed >= .zero,
              state.encounter.reviveRemaining >= .zero,
              state.encounter.reviveRemaining <= .maximumAdvance else {
            throw SaveValidationError.invalidTimer
        }

        var itemIDs = Set<ItemID>()
        var creationSequences = Set<UInt64>()
        for item in state.inventory {
            guard item.id.rawValue > 0,
                  item.level > 0,
                  item.primaryStat > 0,
                  item.creationSequence > 0 else {
                throw SaveValidationError.invalidItem(item.id)
            }
            guard itemIDs.insert(item.id).inserted else {
                throw SaveValidationError.duplicateItemID(item.id)
            }
            guard creationSequences.insert(item.creationSequence).inserted else {
                throw SaveValidationError.invalidItem(item.id)
            }
        }

        for slot in EquipmentSlot.allCases {
            guard let itemID = state.equipment[slot] else { continue }
            let matches = state.inventory.filter { $0.id == itemID }
            guard let item = matches.first else {
                throw SaveValidationError.missingEquipment(itemID)
            }
            guard matches.count == 1, item.slot == slot else {
                throw SaveValidationError.equipmentSlotMismatch(itemID)
            }
            let baseStat = slot == .weapon ? state.hero.baseAttack : state.hero.baseDefense
            let (_, effectiveStatOverflow) = baseStat.addingReportingOverflow(item.primaryStat)
            guard !effectiveStatOverflow else {
                throw SaveValidationError.invalidCombatStats(.hero)
            }
        }

        let (nextItemID, itemIDOverflow) = state.lootSequence.addingReportingOverflow(1)
        guard !itemIDOverflow,
              !state.inventory.contains(where: {
                  $0.id.rawValue == nextItemID || $0.creationSequence == nextItemID
              }) else {
            throw SaveValidationError.invalidLootSequence
        }

        guard state.encounter.heroDamage >= 0 else {
            throw SaveValidationError.inconsistentEncounter
        }

        switch state.encounter.phase {
        case .active:
            let (_, damageCapacityOverflow) = state.encounter.heroDamage.addingReportingOverflow(
                state.enemy.currentHealth
            )
            guard state.hero.currentHealth > 0,
                  state.enemy.currentHealth > 0,
                  state.encounter.reviveRemaining == .zero,
                  !damageCapacityOverflow else {
                throw SaveValidationError.inconsistentEncounter
            }
        case .reviving:
            guard state.hero.currentHealth == 0,
                  state.enemy.currentHealth > 0,
                  state.encounter.reviveRemaining <= balance.reviveDelay else {
                throw SaveValidationError.inconsistentEncounter
            }
        }
    }

    private func validateHealth(_ combatant: CombatantState) throws {
        guard combatant.maxHealth > 0,
              combatant.currentHealth >= 0,
              combatant.currentHealth <= combatant.maxHealth else {
            throw SaveValidationError.invalidHealth(combatant.id)
        }
    }

    private func validateCombatStats(_ combatant: CombatantState) throws {
        guard combatant.baseAttack >= 0, combatant.baseDefense >= 0 else {
            throw SaveValidationError.invalidCombatStats(combatant.id)
        }
    }
}
