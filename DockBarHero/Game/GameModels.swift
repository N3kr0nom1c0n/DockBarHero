import Foundation

enum HeroClassID: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case tank
    case dps
    case healer
}

enum EnemyTierID: String, Codable, CaseIterable, Equatable, Sendable {
    case normal
    case elite
    case boss
}

enum CombatantID: String, Codable, Equatable, Sendable { case hero, enemy }
enum EquipmentSlot: String, Codable, CaseIterable, Equatable, Sendable { case weapon, armor }

struct ItemID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: UInt64
}

struct Item: Identifiable, Codable, Equatable, Sendable {
    let id: ItemID
    let level: Int
    let slot: EquipmentSlot
    let primaryStat: Int
    let creationSequence: UInt64
}

struct EquipmentState: Codable, Equatable, Sendable {
    var weaponID: ItemID?
    var armorID: ItemID?

    subscript(slot: EquipmentSlot) -> ItemID? {
        get { slot == .weapon ? weaponID : armorID }
        set {
            if slot == .weapon { weaponID = newValue } else { armorID = newValue }
        }
    }
}

enum PartyUnlockMilestone: String, Codable, Equatable, Sendable {
    case boss25
    case boss100
}

struct PendingPartyUnlock: Codable, Equatable, Sendable {
    let milestone: PartyUnlockMilestone
    let choices: [HeroClassID]
}

enum PartyUnlockState: Codable, Equatable, Sendable {
    case locked
    case pendingSecond(PendingPartyUnlock)
    case secondUnlocked
    case complete

    var pendingUnlock: PendingPartyUnlock? {
        guard case let .pendingSecond(pending) = self else { return nil }
        return pending
    }
}

struct HeroState: Codable, Equatable, Sendable {
    let classID: HeroClassID
    var level: Int
    var currentXP: Int64
    var combat: CombatantState
    var equipment: EquipmentState
    var encounterAliveDuration: SimulationDuration = .zero
    var wasDownThisEncounter: Bool = false
    var consecutiveDeaths: Int = 0
}

struct PartyState: Codable, Equatable, Sendable {
    var heroes: [HeroState]
    var unlocks: PartyUnlockState

    init(heroes: [HeroState], unlocks: PartyUnlockState = .locked) {
        self.heroes = heroes
        self.unlocks = unlocks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let heroes = try container.decode([HeroState].self, forKey: .heroes)
        guard (1...3).contains(heroes.count) else {
            throw DecodingError.dataCorruptedError(
                forKey: .heroes,
                in: container,
                debugDescription: "A party must contain at least one hero."
            )
        }
        self.heroes = heroes
        self.unlocks = try container.decode(PartyUnlockState.self, forKey: .unlocks)
    }

    private enum CodingKeys: String, CodingKey {
        case heroes
        case unlocks
    }
}

enum CampaignMode: String, Codable, Equatable, Sendable {
    case push
    case farming
}

struct CampaignState: Codable, Equatable, Sendable {
    var highestUnlockedLevel: Int
    var selectedLevel: Int
    var queuedLevel: Int?
    var mode: CampaignMode
    var consecutiveDefeats: Int
}

struct EconomyState: Codable, Equatable, Sendable {
    var gold: Int64
}

struct CombatantState: Codable, Equatable, Sendable {
    let id: CombatantID
    var currentHealth: Int
    let maxHealth: Int
    let baseAttack: Int
    let baseDefense: Int
    let attackInterval: SimulationDuration
    var timeUntilNextAttack: SimulationDuration
}

enum EncounterPhase: String, Codable, Equatable, Sendable { case active, reviving, awaitingPartyChoice }

struct EncounterState: Codable, Equatable, Sendable {
    var enemyLevel: Int
    var tier: EnemyTierID
    var phase: EncounterPhase
    var activeElapsed: SimulationDuration
    var heroDamage: Int
    var reviveRemaining: SimulationDuration
}

struct GameState: Codable, Equatable, Sendable {
    var party: PartyState
    var enemy: CombatantState
    var encounter: EncounterState
    var campaign: CampaignState
    var economy: EconomyState
    var inventory: [Item]
    var autoEquipEnabled: Bool
    var lootSequence: UInt64

    var hero: CombatantState {
        get { party.heroes[0].combat }
        set { party.heroes[0].combat = newValue }
    }

    var equipment: EquipmentState {
        get { party.heroes[0].equipment }
        set { party.heroes[0].equipment = newValue }
    }
}

enum GameIntent: Equatable, Sendable {
    case setAutoEquip(Bool)
    case equip(ItemID)
    case selectLevel(Int)
    case returnToFrontier
}

enum GameEvent: Equatable, Sendable {
    case attack(attacker: CombatantID, defender: CombatantID, damage: Int)
    case victory(defeatedLevel: Int)
    case defeat(enemyLevel: Int)
    case revived(enemyLevel: Int)
    case loot(Item)
    case xpGained(classID: HeroClassID, amount: Int64)
    case heroLeveled(classID: HeroClassID, level: Int)
    case goldGained(amount: Int64)
    case equipped(slot: EquipmentSlot, itemID: ItemID)
    case autoEquipChanged(Bool)
    case destinationQueued(Int)
    case farmingStarted(Int)
    case returnedToFrontier(Int)
    case partyUnlockPending(PartyUnlockMilestone)
}

struct GamePresentation: Equatable, Sendable {
    let state: GameState
    let heroAttack: Int
    let heroDefense: Int
    let rollingDPS: Double
    let encounterDPS: Double
}
