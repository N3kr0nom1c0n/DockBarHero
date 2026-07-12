import Foundation

enum RunState: Codable, Equatable, Sendable {
    case classSelection
    case active(GameState)

    private enum CodingKeys: String, CodingKey {
        case kind
        case game
    }

    private enum Kind: String, Codable {
        case classSelection
        case active
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .classSelection:
            guard !container.contains(.game) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .game,
                    in: container,
                    debugDescription: "Class selection cannot contain an active game."
                )
            }
            self = .classSelection
        case .active:
            self = .active(try container.decode(GameState.self, forKey: .game))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .classSelection:
            try container.encode(Kind.classSelection, forKey: .kind)
        case let .active(game):
            try container.encode(Kind.active, forKey: .kind)
            try container.encode(game, forKey: .game)
        }
    }
}

struct SaveDocument: Codable, Equatable, Sendable {
    static let currentVersion = 2

    let schemaVersion: Int
    let savedAt: Date
    let runState: RunState

    var state: GameState {
        guard case let .active(state) = runState else {
            preconditionFailure("Class-selection documents do not contain game state.")
        }
        return state
    }
}

enum SaveDecodingError: Error, Equatable {
    case unsupportedVersion(Int)
}

enum SaveValidationError: Error, Equatable {
    case invalidEnemyLevel
    case invalidHero
    case invalidCampaign
    case invalidEconomy
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

    init(
        balance: BalanceConfiguration = .standard,
        migrationRegistry: SaveMigrationRegistry = .empty(
            currentVersion: SaveDocument.currentVersion
        )
    ) {
        self.balance = balance
        _ = migrationRegistry
    }

    func encode(runState: RunState, savedAt: Date) throws -> Data {
        try validate(runState)
        let document = SaveDocument(
            schemaVersion: SaveDocument.currentVersion,
            savedAt: savedAt,
            runState: runState
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(document)
    }

    func encode(state: GameState, savedAt: Date) throws -> Data {
        try encode(runState: .active(state), savedAt: savedAt)
    }

    func decode(_ data: Data) throws -> SaveDocument {
        let header = try JSONDecoder().decode(VersionHeader.self, from: data)
        guard header.schemaVersion == SaveDocument.currentVersion else {
            throw SaveDecodingError.unsupportedVersion(header.schemaVersion)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(SaveDocument.self, from: data)
        try validate(document.runState)
        return document
    }

    private func validate(_ runState: RunState) throws {
        guard case let .active(state) = runState else { return }
        guard state.party.heroes.count == 1 else {
            throw SaveValidationError.invalidHero
        }
        let heroState = state.party.heroes[0]
        guard heroState.level >= 1,
              heroState.currentXP >= 0,
              heroState.currentXP < (try progressionValue {
                  try ProgressionConfiguration.standard.xpRequired(for: heroState.level)
              }) else {
            throw SaveValidationError.invalidHero
        }
        guard state.economy.gold >= 0 else {
            throw SaveValidationError.invalidEconomy
        }
        guard state.campaign.highestUnlockedLevel >= 1,
              state.campaign.selectedLevel >= 1,
              state.campaign.selectedLevel <= state.campaign.highestUnlockedLevel,
              state.campaign.consecutiveDefeats >= 0,
              state.campaign.queuedLevel.map({
                  $0 >= 1 && $0 <= state.campaign.highestUnlockedLevel
              }) ?? true,
              state.encounter.enemyLevel == state.campaign.selectedLevel,
              EncounterSchedule.standard.tier(for: state.encounter.enemyLevel) == state.encounter.tier else {
            throw SaveValidationError.invalidCampaign
        }

        guard heroState.combat.id == .hero, state.enemy.id == .enemy else {
            throw SaveValidationError.inconsistentEncounter
        }
        try validateHealth(heroState.combat)
        try validateHealth(state.enemy)
        try validateCombatStats(heroState.combat)
        try validateCombatStats(state.enemy)

        guard balance.enemy(
            level: state.encounter.enemyLevel,
            tier: state.encounter.tier,
            progression: .standard
        ) != nil else {
            throw SaveValidationError.invalidEnemyLevel
        }
        guard heroState.combat.attackInterval >= .minimumAttackInterval,
              state.enemy.attackInterval >= .minimumAttackInterval,
              heroState.combat.timeUntilNextAttack >= .zero,
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
            guard let itemID = heroState.equipment[slot] else { continue }
            let matches = state.inventory.filter { $0.id == itemID }
            guard let item = matches.first else {
                throw SaveValidationError.missingEquipment(itemID)
            }
            guard matches.count == 1, item.slot == slot else {
                throw SaveValidationError.equipmentSlotMismatch(itemID)
            }
            let baseStat = slot == .weapon ? heroState.combat.baseAttack : heroState.combat.baseDefense
            let (_, overflow) = baseStat.addingReportingOverflow(item.primaryStat)
            guard !overflow else {
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
            let (_, damageOverflow) = state.encounter.heroDamage.addingReportingOverflow(
                state.enemy.currentHealth
            )
            guard heroState.combat.currentHealth > 0,
                  state.enemy.currentHealth > 0,
                  state.encounter.reviveRemaining == .zero,
                  !damageOverflow else {
                throw SaveValidationError.inconsistentEncounter
            }
        case .reviving:
            guard heroState.combat.currentHealth == 0,
                  state.enemy.currentHealth > 0,
                  state.encounter.reviveRemaining <= balance.reviveDelay else {
                throw SaveValidationError.inconsistentEncounter
            }
        }
    }

    private func progressionValue<T>(_ body: () throws -> T) throws -> T {
        do { return try body() }
        catch { throw SaveValidationError.invalidHero }
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
