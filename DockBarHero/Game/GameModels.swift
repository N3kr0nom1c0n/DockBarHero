import Foundation

enum HeroClassID: String, Codable, CaseIterable, Equatable, Sendable {
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

struct CombatantState: Codable, Equatable, Sendable {
    let id: CombatantID
    var currentHealth: Int
    let maxHealth: Int
    let baseAttack: Int
    let baseDefense: Int
    let attackInterval: SimulationDuration
    var timeUntilNextAttack: SimulationDuration
}

enum EncounterPhase: String, Codable, Equatable, Sendable { case active, reviving }

struct EncounterState: Codable, Equatable, Sendable {
    var enemyLevel: Int
    var phase: EncounterPhase
    var activeElapsed: SimulationDuration
    var heroDamage: Int
    var reviveRemaining: SimulationDuration
}

struct GameState: Codable, Equatable, Sendable {
    var hero: CombatantState
    var enemy: CombatantState
    var encounter: EncounterState
    var inventory: [Item]
    var equipment: EquipmentState
    var autoEquipEnabled: Bool
    var lootSequence: UInt64
}

enum GameIntent: Equatable, Sendable {
    case setAutoEquip(Bool)
    case equip(ItemID)
}

enum GameEvent: Equatable, Sendable {
    case attack(attacker: CombatantID, defender: CombatantID, damage: Int)
    case victory(defeatedLevel: Int)
    case defeat(enemyLevel: Int)
    case revived(enemyLevel: Int)
    case loot(Item)
    case equipped(slot: EquipmentSlot, itemID: ItemID)
    case autoEquipChanged(Bool)
}

struct GamePresentation: Equatable, Sendable {
    let state: GameState
    let heroAttack: Int
    let heroDefense: Int
    let rollingDPS: Double
    let encounterDPS: Double
}
