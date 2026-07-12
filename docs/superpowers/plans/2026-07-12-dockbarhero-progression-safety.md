# DockBarHero Progression Safety Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first schema-v2 Progression Safety gate with one chosen hero, deterministic XP and levels, enemy tiers, gold, farming/frontier controls, automatic retreat, durable onboarding/reset, and intentional management empty states.

**Architecture:** Keep `GameSimulation` as the checked candidate-state transaction boundary. Add pure collaborators for progression math and encounter scheduling, use new schema-v2 save paths without consuming unreleased v1 files, and let `GameSession` own class-selection versus active-run lifecycle. This plan stops before multi-hero combat and filled abilities; this internal checkpoint must not merge or ship alone.

**Tech Stack:** Swift 6.3.2, SwiftUI, AppKit, SpriteKit, XCTest, Xcode 26.5, XcodeGen 2.45.4, macOS 26, Apple Silicon.

## Global Constraints

- Preserve signed `Int64` nanosecond gameplay time and exact hero-before-enemy ordering.
- Use checked integer arithmetic and exact integer ratios for all gameplay math.
- Keep frozen v1 fixtures and `save-v1*` files untouched; schema v2 uses new `save-v2*` paths and starts fresh.
- Persist frontier, selected level, queued destination, mode, and defeat streak separately.
- A level-change request never abandons the active fight.
- Three defeats use the approved full-segment fallback and never auto-return to the frontier.
- Defeat grants no XP, gold, or loot. Victory grants hero XP, shared gold, and exactly one item.
- Tier damage applies after defense. Boss scheduling takes precedence over Elite scheduling.
- Add no third-party dependency, wall-clock gameplay rule, randomness, remote balance, offline progress, multi-hero combat, filled ability, skill purchase, or shop purchase.
- Abilities, Skills, and Shop are intentional empty states in this gate; Shop may show current gold.
- Only the parent updates `PROJECT.md`, roadmap state, review packets, or shared progress files.

---

## File Structure

**Create:**

- `DockBarHero/Game/ProgressionConfiguration.swift`: XP, gold, and class-growth formulas.
- `DockBarHero/Game/EncounterSchedule.swift`: ordered tier schedule and definitions.
- `DockBarHero/App/ClassSelectionView.swift`: first-run class choice.
- `DockBarHero/App/DeferredFeatureView.swift`: Abilities, Skills, and Shop empty states.
- `DockBarHeroTests/ProgressionConfigurationTests.swift`: formula and overflow coverage.
- `DockBarHeroTests/EncounterScheduleTests.swift`: schedule precedence coverage.
- `DockBarHeroTests/ProgressionSafetyTests.swift`: recovery-loop regression coverage.

**Modify:** `GameModels`, balance, combat, encounter, reward, loot, simulation, driver, session, persistence, AppModel, management views, settings, rail rendering, and their focused tests as named below.

---

### Task 1: Progression and Encounter Balance Data

**Files:**

- Create: `DockBarHero/Game/ProgressionConfiguration.swift`
- Create: `DockBarHero/Game/EncounterSchedule.swift`
- Create: `DockBarHeroTests/ProgressionConfigurationTests.swift`
- Create: `DockBarHeroTests/EncounterScheduleTests.swift`
- Modify: `DockBarHero/Game/GameModels.swift`

**Interfaces:**

- Produces: `HeroClassID`, `EnemyTierID`, `Ratio`, `HeroClassDefinition`, `EnemyTierDefinition`, `ProgressionConfiguration.standard`, and `EncounterSchedule.standard`.
- Produces: `xpRequired(for:)`, `xpReward(enemyLevel:heroLevel:tier:)`, `goldReward(enemyLevel:tier:)`, `scaledStat(raw:level:growthBasisPoints:)`, and `tier(for:)`.

- [ ] **Step 1: Write the failing formula tests**

```swift
final class ProgressionConfigurationTests: XCTestCase {
    func testApprovedXPAndGoldFormulas() throws {
        let config = ProgressionConfiguration.standard
        XCTAssertEqual(try config.xpRequired(for: 10), 10_000)
        XCTAssertEqual(try config.xpReward(enemyLevel: 10, heroLevel: 10, tier: .normal), 2_500)
        XCTAssertEqual(try config.xpReward(enemyLevel: 10, heroLevel: 16, tier: .normal), 2_125)
        XCTAssertEqual(try config.xpReward(enemyLevel: 10, heroLevel: 99, tier: .normal), 625)
        XCTAssertEqual(try config.goldReward(enemyLevel: 100, tier: .normal), 670)
        XCTAssertEqual(try config.goldReward(enemyLevel: 100, tier: .elite), 1_005)
        XCTAssertEqual(try config.goldReward(enemyLevel: 100, tier: .boss), 1_340)
    }

    func testInvalidLevelsAndOverflowFail() {
        let config = ProgressionConfiguration.standard
        XCTAssertThrowsError(try config.xpRequired(for: 0))
        XCTAssertThrowsError(try config.xpRequired(for: .max))
        XCTAssertThrowsError(try config.goldReward(enemyLevel: .max, tier: .boss))
    }
}

final class EncounterScheduleTests: XCTestCase {
    func testBossPrecedesElite() {
        let schedule = EncounterSchedule.standard
        XCTAssertEqual(schedule.tier(for: 1), .normal)
        XCTAssertEqual(schedule.tier(for: 5), .elite)
        XCTAssertEqual(schedule.tier(for: 24), .normal)
        XCTAssertEqual(schedule.tier(for: 25), .boss)
        XCTAssertEqual(schedule.tier(for: 50), .boss)
    }
}
```

- [ ] **Step 2: Run focused tests to verify RED**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/ProgressionDataRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/ProgressionConfigurationTests -only-testing:DockBarHeroTests/EncounterScheduleTests
```

Expected: FAIL because the progression and schedule types do not exist.

- [ ] **Step 3: Implement the data contracts and formulas**

```swift
enum HeroClassID: String, Codable, CaseIterable, Equatable, Sendable { case tank, dps, healer }
enum EnemyTierID: String, Codable, CaseIterable, Equatable, Sendable { case normal, elite, boss }

struct Ratio: Codable, Equatable, Sendable {
    let numerator: Int64
    let denominator: Int64
}

struct HeroClassDefinition: Equatable, Sendable {
    let id: HeroClassID
    let baseHealth: Int
    let baseAttack: Int
    let baseDefense: Int
    let healthGrowthBasisPoints: Int64
    let attackGrowthBasisPoints: Int64
    let defenseGrowthBasisPoints: Int64
}

struct EnemyTierDefinition: Equatable, Sendable {
    let id: EnemyTierID
    let healthRatio: Ratio
    let damageRatio: Ratio
    let xpRatio: Ratio
    let itemStatRatio: Ratio
    let goldRatio: Ratio
}

struct EncounterSchedule: Sendable {
    static let standard = EncounterSchedule()
    func tier(for level: Int) -> EnemyTierID? {
        guard level >= 1 else { return nil }
        if level.isMultiple(of: 25) { return .boss }
        if level.isMultiple(of: 5) { return .elite }
        return .normal
    }
}
```

`ProgressionConfiguration.standard` contains the exact approved class and tier tables. Implement checked `100*H²`, `25*E²`, the five-level safe zone, 15-point penalty steps, 25% floor, `20 + 4L + floor(L²/40)`, and basis-point stat scaling. Apply tier ratios with floor division for XP/gold and reject invalid ratios or overflow.

- [ ] **Step 4: Run focused tests to verify GREEN**

Run Step 2 with derived data path `.build/ProgressionDataGreen`.

Expected: both focused classes pass.

- [ ] **Step 5: Commit**

```bash
git add DockBarHero/Game/GameModels.swift DockBarHero/Game/ProgressionConfiguration.swift DockBarHero/Game/EncounterSchedule.swift DockBarHeroTests/ProgressionConfigurationTests.swift DockBarHeroTests/EncounterScheduleTests.swift
git commit -m "feat: add progression balance data"
```

---

### Task 2: Schema-v2 One-Hero Domain State and Class Scaling

**Files:**

- Modify: `DockBarHero/Game/GameModels.swift`
- Modify: `DockBarHero/Game/BalanceConfiguration.swift`
- Modify: `DockBarHero/Game/CombatResolver.swift`
- Modify: `DockBarHero/App/ManagementSupport.swift`
- Test: `DockBarHeroTests/BalanceConfigurationTests.swift`
- Test: `DockBarHeroTests/CombatResolverTests.swift`
- Update: existing fixtures that call `GameState.newGame`

**Interfaces:**

- Consumes Task 1 definitions.
- Produces: `HeroState`, one-entry `PartyState`, `CampaignState`, `EconomyState`, `CampaignMode`, and `GameState.newGame(classID:balance:progression:)`.

- [ ] **Step 1: Write failing schema and scaling tests**

```swift
func testNewTankUsesSchemaV2State() throws {
    let state = try GameState.newGame(classID: .tank, balance: .standard, progression: .standard)
    XCTAssertEqual(state.party.heroes.count, 1)
    XCTAssertEqual(state.party.heroes[0].classID, .tank)
    XCTAssertEqual(state.party.heroes[0].level, 1)
    XCTAssertEqual(state.party.heroes[0].currentXP, 0)
    XCTAssertEqual(state.party.heroes[0].combat.maxHealth, 130)
    XCTAssertEqual(state.campaign, CampaignState(highestUnlockedLevel: 1, selectedLevel: 1, queuedLevel: nil, mode: .push, consecutiveDefeats: 0))
    XCTAssertEqual(state.economy.gold, 0)
}

func testDPSLevelGrowthScalesEquippedAttack() throws {
    var state = try GameState.newGame(classID: .dps, balance: .standard, progression: .standard)
    state.party.heroes[0].level = 10
    let weapon = Item(id: ItemID(rawValue: 1), level: 1, slot: .weapon, primaryStat: 88, creationSequence: 1)
    state.inventory = [weapon]
    state.party.heroes[0].equipment.weaponID = weapon.id
    XCTAssertEqual(try CombatResolver().effectiveAttack(forHeroAt: 0, in: state), 111)
}
```

- [ ] **Step 2: Run focused tests to verify RED**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/SchemaV2DomainRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/BalanceConfigurationTests -only-testing:DockBarHeroTests/CombatResolverTests
```

Expected: FAIL because schema-v2 state is absent.

- [ ] **Step 3: Replace the active state shape**

```swift
struct HeroState: Codable, Equatable, Sendable {
    let classID: HeroClassID
    var level: Int
    var currentXP: Int64
    var combat: CombatantState
    var equipment: EquipmentState
}
struct PartyState: Codable, Equatable, Sendable { var heroes: [HeroState] }
enum CampaignMode: String, Codable, Equatable, Sendable { case push, farming }
struct CampaignState: Codable, Equatable, Sendable {
    var highestUnlockedLevel: Int
    var selectedLevel: Int
    var queuedLevel: Int?
    var mode: CampaignMode
    var consecutiveDefeats: Int
}
struct EconomyState: Codable, Equatable, Sendable { var gold: Int64 }
```

`GameState` contains party, enemy, encounter, campaign, economy, inventory, auto-equip, and loot sequence. `newGame` requires an explicit class and constructs its level-one stats; no default class is permitted. Update fixtures to pass `.dps` explicitly.

- [ ] **Step 4: Route effective stats through hero index zero**

Implement `effectiveAttack(forHeroAt:in:)` and `effectiveDefense(forHeroAt:in:)`. Require exactly one hero and index zero in this gate, add equipped primary stat to class base stat, then apply Task 1 growth. Update simulation, loot comparison, presentation, save validation, and inventory equipped lookup callers.

- [ ] **Step 5: Run focused tests to verify GREEN**

Run Step 2 with `.build/SchemaV2DomainGreen`, adding `LootSystemTests` and `ManagementViewTests`.

Expected: all selected classes pass.

- [ ] **Step 6: Commit**

```bash
git add DockBarHero/Game/GameModels.swift DockBarHero/Game/BalanceConfiguration.swift DockBarHero/Game/CombatResolver.swift DockBarHero/App/ManagementSupport.swift DockBarHeroTests
git commit -m "feat: add schema v2 hero state"
```

---

### Task 3: Tier-Aware Rewards, Gold, and Level-Ups

**Files:**

- Modify: `DockBarHero/Game/BalanceConfiguration.swift`
- Modify: `DockBarHero/Game/CombatResolver.swift`
- Modify: `DockBarHero/Game/LootSystem.swift`
- Modify: `DockBarHero/Game/RewardResolver.swift`
- Modify: `DockBarHero/Game/GameModels.swift`
- Test: `DockBarHeroTests/CombatResolverTests.swift`
- Test: `DockBarHeroTests/LootSystemTests.swift`
- Test: `DockBarHeroTests/RewardResolverTests.swift`

**Interfaces:**

- Consumes Tasks 1-2.
- Produces: tier-aware enemy health/damage/items and events `.xpGained`, `.heroLeveled`, and `.goldGained`.

- [ ] **Step 1: Write failing tier/reward tests**

```swift
func testBossDamageMultiplierAppliesAfterDefense() throws {
    var state = try GameState.newGame(classID: .tank, balance: .standard, progression: .standard)
    state.enemy = CombatantState(
        id: .enemy, currentHealth: 30, maxHealth: 30, baseAttack: 12, baseDefense: 0,
        attackInterval: .nanoseconds(1_500_000_000), timeUntilNextAttack: .nanoseconds(1_500_000_000)
    )
    let armor = Item(id: ItemID(rawValue: 1), level: 1, slot: .armor, primaryStat: 6, creationSequence: 1)
    state.inventory = [armor]
    state.party.heroes[0].equipment.armorID = armor.id
    XCTAssertEqual(try CombatResolver().enemyDamage(in: state, tier: .boss), 9)
}

func testEliteVictoryAwardsLevelGoldAndOneItem() throws {
    var state = try GameState.newGame(classID: .dps, balance: .standard, progression: .standard)
    state.campaign = .init(highestUnlockedLevel: 5, selectedLevel: 5, queuedLevel: nil, mode: .push, consecutiveDefeats: 0)
    state.encounter.enemyLevel = 5
    state.encounter.tier = .elite
    state.party.heroes[0].level = 5
    state.party.heroes[0].currentXP = 1_407
    let result = try RewardResolver().applyVictory(defeatedLevel: 5, tier: .elite, to: state, balance: .standard)
    XCTAssertEqual(result.state.party.heroes[0].level, 6)
    XCTAssertEqual(result.state.party.heroes[0].currentXP, 0)
    XCTAssertEqual(result.state.economy.gold, 60)
    XCTAssertEqual(result.state.inventory.count, 1)
}
```

- [ ] **Step 2: Run focused tests to verify RED**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/TierRewardsRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/CombatResolverTests -only-testing:DockBarHeroTests/LootSystemTests -only-testing:DockBarHeroTests/RewardResolverTests
```

Expected: FAIL because tier damage and progression rewards are absent.

- [ ] **Step 3: Implement tier-aware construction**

Add `tier: EnemyTierID` to `EncounterState`. `BalanceConfiguration.enemy(level:tier:progression:)` applies health ratio with checked ceiling. `CombatResolver.enemyDamage(in:tier:)` computes `max(1, attack - effectiveDefense)` before checked-ceiling tier multiplication. `LootSystem.drop(defeatedLevel:tier:state:)` applies item ratio with checked ceiling and still emits exactly one sequence-driven item.

- [ ] **Step 4: Implement the atomic reward transaction**

Add these exact durable events to `GameEvent`:

```swift
case xpGained(classID: HeroClassID, amount: Int64)
case heroLeveled(classID: HeroClassID, level: Int)
case goldGained(amount: Int64)
```

```swift
let xp = try progression.xpReward(enemyLevel: defeatedLevel, heroLevel: hero.level, tier: tier)
let gold = try progression.goldReward(enemyLevel: defeatedLevel, tier: tier)
hero.currentXP = try checkedAdd(hero.currentXP, xp)
events.append(.xpGained(classID: hero.classID, amount: xp))
while hero.currentXP >= progression.xpRequired(for: hero.level) {
    hero.currentXP -= try progression.xpRequired(for: hero.level)
    hero.level = try checkedIncrement(hero.level)
    events.append(.heroLeveled(classID: hero.classID, level: hero.level))
}
state.economy.gold = try checkedAdd(state.economy.gold, gold)
events.append(.goldGained(amount: gold))
```

After each level increment, reconstruct the hero combat value with the new class-scaled maximum health, preserving attack interval/timer and clamping current health to the new maximum; the following encounter transition restores full health. Then generate one item and apply existing strict-upgrade auto-equip. Candidate-state rollback remains the transaction guarantee.

- [ ] **Step 5: Run focused tests to verify GREEN**

Run Step 2 with `.build/TierRewardsGreen`.

Expected: all selected tests pass.

- [ ] **Step 6: Commit**

```bash
git add DockBarHero/Game DockBarHeroTests/CombatResolverTests.swift DockBarHeroTests/LootSystemTests.swift DockBarHeroTests/RewardResolverTests.swift
git commit -m "feat: add tiered progression rewards"
```

---

### Task 4: Push, Farming, Queued Destinations, and Retreat

**Files:**

- Modify: `DockBarHero/Game/GameModels.swift`
- Modify: `DockBarHero/Game/EncounterDirector.swift`
- Test: `DockBarHeroTests/EncounterDirectorTests.swift`

**Interfaces:**

- Produces intents `.selectLevel(Int)` and `.returnToFrontier`.
- Produces events `.destinationQueued(Int)`, `.farmingStarted(Int)`, and `.returnedToFrontier(Int)`.
- Produces pure queue, victory, defeat, revive, and fallback transitions.

- [ ] **Step 1: Write failing transition tests**

```swift
func testFarmingVictoryRepeatsSelectionWithoutLoweringFrontier() throws {
    let state = try fixture(frontier: 50, selected: 24, mode: .farming)
    let result = try EncounterDirector().completeVictory(in: state, balance: .standard)
    XCTAssertEqual(result.campaign.highestUnlockedLevel, 50)
    XCTAssertEqual(result.campaign.selectedLevel, 24)
}

func testQueuedChoiceOverridesThirdDefeatFallback() throws {
    var state = try fixture(frontier: 174, selected: 174, mode: .push)
    state.campaign.consecutiveDefeats = 2
    state = try EncounterDirector().queue(level: 100, in: state)
    XCTAssertEqual(state.campaign.selectedLevel, 174)
    state = try EncounterDirector().beginDefeat(in: state, balance: .standard)
    state = try EncounterDirector().finishRevive(in: state, balance: .standard)
    XCTAssertEqual(state.campaign.selectedLevel, 100)
    XCTAssertEqual(state.campaign.mode, .farming)
}

func testApprovedFallbacks() throws {
    XCTAssertEqual(try EncounterDirector().fallback(afterFailing: 25), 24)
    XCTAssertEqual(try EncounterDirector().fallback(afterFailing: 50), 24)
    XCTAssertEqual(try EncounterDirector().fallback(afterFailing: 75), 49)
    XCTAssertEqual(try EncounterDirector().fallback(afterFailing: 174), 149)
}
```

Add this fixture in `EncounterDirectorTests.swift` so every transition begins from a valid scheduled enemy:

```swift
private func fixture(frontier: Int, selected: Int, mode: CampaignMode) throws -> GameState {
    var state = try GameState.newGame(classID: .dps, balance: .standard, progression: .standard)
    let tier = try XCTUnwrap(EncounterSchedule.standard.tier(for: selected))
    state.campaign = CampaignState(
        highestUnlockedLevel: frontier,
        selectedLevel: selected,
        queuedLevel: nil,
        mode: mode,
        consecutiveDefeats: 0
    )
    state.encounter.enemyLevel = selected
    state.encounter.tier = tier
    state.enemy = try XCTUnwrap(BalanceConfiguration.standard.enemy(level: selected, tier: tier, progression: .standard))
    return state
}
```

- [ ] **Step 2: Run encounter tests to verify RED**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/CampaignRecoveryRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/EncounterDirectorTests
```

Expected: FAIL because queueing and fallback do not exist.

- [ ] **Step 3: Implement queueing and victory rules**

Add these exact cases:

```swift
// GameIntent
case selectLevel(Int)
case returnToFrontier

// GameEvent
case destinationQueued(Int)
case farmingStarted(Int)
case returnedToFrontier(Int)
```

`queue(level:)` accepts only `1..<highestUnlockedLevel`, changes only `queuedLevel`, and leaves the active fight untouched. `queueFrontier` stores the frontier. At victory, consume a queue first; otherwise Push increments frontier/selection and Farming repeats selection. A frontier queue sets Push; other queues set Farming. Victory resets defeats.

- [ ] **Step 4: Implement defeat/revive fallback**

At defeat, checked-increment the streak without changing levels. At completed revive, apply a queued destination first. Otherwise, at streak three set Farming and use: for failed levels through 25, `max(1, level-1)` constrained to a defeated Normal; later compute checked `B = ceil(level/25)*25` and return `B-26`. Reset the streak only after a queue, victory, or retreat applies.

- [ ] **Step 5: Run encounter tests to verify GREEN**

Run Step 2 with `.build/CampaignRecoveryGreen`.

Expected: all encounter tests pass, including 25→24, 50→24, 75→49, and 174→149.

- [ ] **Step 6: Commit**

```bash
git add DockBarHero/Game/GameModels.swift DockBarHero/Game/EncounterDirector.swift DockBarHeroTests/EncounterDirectorTests.swift
git commit -m "feat: add farming and automatic retreat"
```

---

### Task 5: Simulation Integration and Event Order

**Files:**

- Modify: `DockBarHero/Game/GameSimulation.swift`
- Modify: `DockBarHero/Game/SimulationDriver.swift`
- Modify: `DockBarHero/Game/GameModels.swift`
- Test: `DockBarHeroTests/GameSimulationTests.swift`
- Test: `DockBarHeroTests/SimulationDriverTests.swift`
- Create: `DockBarHeroTests/ProgressionSafetyTests.swift`

**Interfaces:**

- Consumes Tasks 3-4.
- Produces the approved victory order and immediate management-intent publication without changing simulation timing.

- [ ] **Step 1: Write failing integrated tests**

```swift
func testVictoryOrdersProgressionBeforeLootAndTransition() throws {
    var simulation = try lethalHeroSimulation(level: 5, tier: .elite)
    let events = try simulation.advance(by: .zero)
    XCTAssertEqual(events.map(\.kind), [.attack, .victory, .xpGained, .heroLeveled, .goldGained, .loot, .equipped])
    XCTAssertEqual(simulation.state.campaign.highestUnlockedLevel, 6)
}

func testThreeLevel174DefeatsRetreatTo149() throws {
    var simulation = try doomedSimulation(frontier: 174)
    for _ in 0..<3 { try resolveOneDefeatAndRevive(&simulation) }
    XCTAssertEqual(simulation.state.campaign.highestUnlockedLevel, 174)
    XCTAssertEqual(simulation.state.campaign.selectedLevel, 149)
    XCTAssertEqual(simulation.state.campaign.mode, .farming)
}

func testSelectingFarmLevelDoesNotInterruptFight() throws {
    var simulation = try activeSimulation(frontier: 10)
    let health = simulation.state.enemy.currentHealth
    XCTAssertEqual(try simulation.apply(.selectLevel(5)), [.destinationQueued(5)])
    XCTAssertEqual(simulation.state.enemy.currentHealth, health)
    XCTAssertEqual(simulation.state.campaign.selectedLevel, 10)
    XCTAssertEqual(simulation.state.campaign.queuedLevel, 5)
}
```

Define the test-only helpers in `ProgressionSafetyTests.swift` rather than adding production shortcuts:

```swift
private enum EventKind: Equatable { case attack, victory, xpGained, heroLeveled, goldGained, loot, equipped }

private func lethalHeroSimulation(level: Int, tier: EnemyTierID) throws -> GameSimulation {
    var state = try activeState(frontier: level)
    state.encounter.tier = tier
    state.party.heroes[0].level = level
    let reward = try ProgressionConfiguration.standard.xpReward(enemyLevel: level, heroLevel: level, tier: tier)
    state.party.heroes[0].currentXP = try ProgressionConfiguration.standard.xpRequired(for: level) - reward
    state.enemy.currentHealth = 1
    state.party.heroes[0].combat.timeUntilNextAttack = .zero
    return GameSimulation(state: state)
}

private func doomedSimulation(frontier: Int) throws -> GameSimulation {
    var state = try activeState(frontier: frontier)
    state.party.heroes[0].combat.currentHealth = 1
    state.party.heroes[0].combat.timeUntilNextAttack = .nanoseconds(1_000_000_000)
    state.enemy.timeUntilNextAttack = .nanoseconds(1_000_000_000)
    return GameSimulation(state: state)
}

private func activeSimulation(frontier: Int) throws -> GameSimulation {
    GameSimulation(state: try activeState(frontier: frontier))
}
```

Add a test-only `GameEvent.kind: EventKind` exhaustive switch and `resolveOneDefeatAndRevive` that advances one second, then exactly `balance.reviveDelay`; after each revive it restores the one-health doomed fixture while preserving campaign state. `activeSimulation(frontier:)` uses the same valid scheduled state as Task 4's fixture.

- [ ] **Step 2: Run simulation tests to verify RED**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/ProgressionSafetyRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/GameSimulationTests -only-testing:DockBarHeroTests/SimulationDriverTests -only-testing:DockBarHeroTests/ProgressionSafetyTests
```

Expected: FAIL because the integrated loop is absent.

- [ ] **Step 3: Integrate victory atomically**

After a lethal hero action, append victory, apply `RewardResolver`, append XP/level/gold/loot/equip events, then apply `EncounterDirector.completeVictory`. Frontier mutation never belongs in `RewardResolver`. Reset DPS only after the complete candidate transition succeeds.

- [ ] **Step 4: Integrate defeat/revive and intents**

Defeat calls `beginDefeat`; completed revive calls `finishRevive`. Emit `.farmingStarted` only when retreat changes selection. Queue intents forward through `SimulationDriver.send`, publish immediately, and never alter active health, timers, DPS, or enemy identity.

- [ ] **Step 5: Verify integrated GREEN and chunk invariance**

Run Step 2 with `.build/ProgressionSafetyGreen`, adding `DamageMetricsTests`.

Expected: all selected tests pass and existing time-partition comparisons remain equal.

- [ ] **Step 6: Commit**

```bash
git add DockBarHero/Game/GameSimulation.swift DockBarHero/Game/SimulationDriver.swift DockBarHero/Game/GameModels.swift DockBarHeroTests/GameSimulationTests.swift DockBarHeroTests/SimulationDriverTests.swift DockBarHeroTests/ProgressionSafetyTests.swift
git commit -m "feat: integrate progression safety loop"
```

---

### Task 6: Schema-v2 Persistence, Class Selection, and Safe New Game

**Files:**

- Modify: `DockBarHero/Persistence/SaveDocument.swift`
- Modify: `DockBarHero/Persistence/SaveStore.swift`
- Modify: `DockBarHero/Persistence/SaveCoordinator.swift`
- Modify: `DockBarHero/Game/GameSession.swift`
- Modify: `DockBarHero/Game/SimulationDriver.swift`
- Modify: `DockBarHero/App/AppDelegate.swift`
- Test: `DockBarHeroTests/SaveDocumentTests.swift`
- Test: `DockBarHeroTests/SaveStoreTests.swift`
- Test: `DockBarHeroTests/SaveCoordinatorTests.swift`
- Test: `DockBarHeroTests/GameSessionTests.swift`

**Interfaces:**

- Produces: `RunState.classSelection`, `RunState.active(GameState)`, schema-v2 `SaveDocument`, `SaveStoring.replaceRun(with:)`, `chooseStartingClass(_:)`, and `startNewGame()`.
- Preserves save coalescing, backup recovery, future-version handling, quit-during-load safety, and bounded termination flush.

- [ ] **Step 1: Write failing persistence/lifecycle tests**

```swift
func testSaveURLsUseV2Names() {
    let urls = SaveURLs(directory: directory)
    XCTAssertEqual(urls.primary.lastPathComponent, "save-v2.json")
    XCTAssertEqual(urls.backup.lastPathComponent, "save-v2.backup.json")
    XCTAssertEqual(urls.temporary.lastPathComponent, "save-v2.pending.json")
}

func testAbsentV2RequiresClassSelection() async {
    let result = await store.load()
    XCTAssertEqual(result.runState, .classSelection)
    XCTAssertEqual(result.source, .newGame)
}

func testFailedReplaceKeepsOldRunLoadable() async throws {
    try await store.save(.active(oldState))
    fileSystem.failNextPrimaryReplacement = true
    do {
        try await store.replaceRun(with: .classSelection)
        XCTFail("Expected replacement failure")
    } catch {
        XCTAssertEqual(error as? ControlledSaveError, .replacementFailed)
    }
    XCTAssertEqual((await store.load()).runState, .active(oldState))
}

func testSuccessfulResetCannotRecoverOldBackup() async throws {
    try await store.save(.active(oldState))
    try await store.save(.active(newerOldState))
    try await store.replaceRun(with: .classSelection)
    fileSystem.corrupt(urls.primary)
    XCTAssertEqual((await store.load()).runState, .classSelection)
}
```

- [ ] **Step 2: Run persistence tests to verify RED**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/ProgressionPersistenceRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/SaveDocumentTests -only-testing:DockBarHeroTests/SaveStoreTests -only-testing:DockBarHeroTests/SaveCoordinatorTests -only-testing:DockBarHeroTests/GameSessionTests
```

Expected: FAIL because run lifecycle and v2 paths do not exist.

- [ ] **Step 3: Add the explicit schema-v2 envelope**

```swift
enum RunState: Codable, Equatable, Sendable {
    case classSelection
    case active(GameState)
}

struct SaveDocument: Codable, Equatable, Sendable {
    static let currentVersion = 2
    let schemaVersion: Int
    let savedAt: Date
    let runState: RunState
}
```

Give `RunState` custom stable `kind` values `classSelection` and `active`, requiring a `game` body only for active. Validate one hero, level/current-XP bounds, campaign relationships, scheduled tier, nonnegative gold, equipment ownership, timers, and health. Register no v1→v2 migration.

- [ ] **Step 4: Add v2 storage and replace-run ordering**

Use only `save-v2.json`, `save-v2.backup.json`, and `save-v2.pending.json`; do not read/move/delete v1 files. `replaceRun` encodes and atomically stages the new run, removes/quarantines the eligible v2 backup, then atomically replaces primary. A primary-replace failure leaves old primary loadable. After success, no old-run backup is eligible. Change `SaveCoordinator` to coalesce `RunState`.

- [ ] **Step 5: Add class-selection/reset lifecycle**

```swift
enum RunPresentation: Equatable, Sendable {
    case classSelection
    case active(GamePresentation)
}

var onRunState: ((RunPresentation) -> Void)? { get set }
func chooseStartingClass(_ classID: HeroClassID) async throws
func startNewGame() async throws
```

On class selection, publish selection and do not run driver/autosave. Choosing a class constructs active state, durably replaces the run, then starts driver/autosave. New Game stops driver, waits for save submissions, durably replaces with class selection, and only then publishes it. On failure, retain/restart the old active state and publish save failure. Add all progression/campaign events to durable save matching.

- [ ] **Step 6: Run focused tests to verify GREEN**

Run Step 2 with `.build/ProgressionPersistenceGreen`.

Expected: all selected persistence/session tests pass.

- [ ] **Step 7: Commit**

```bash
git add DockBarHero/Persistence DockBarHero/Game/GameSession.swift DockBarHero/Game/SimulationDriver.swift DockBarHeroTests/SaveDocumentTests.swift DockBarHeroTests/SaveStoreTests.swift DockBarHeroTests/SaveCoordinatorTests.swift DockBarHeroTests/GameSessionTests.swift
git commit -m "feat: add schema v2 run lifecycle"
```

---

### Task 7: Management UI, Labels, Empty States, and Danger Zone

**Files:**

- Create: `DockBarHero/App/ClassSelectionView.swift`
- Create: `DockBarHero/App/DeferredFeatureView.swift`
- Modify: `DockBarHero/App/AppModel.swift`
- Modify: `DockBarHero/App/ManagementRoute.swift`
- Modify: `DockBarHero/App/ManagementRootView.swift`
- Modify: `DockBarHero/App/ManagementSupport.swift`
- Modify: `DockBarHero/App/OverviewView.swift`
- Modify: `DockBarHero/App/InventoryView.swift`
- Modify: `DockBarHero/App/SettingsView.swift`
- Test: `DockBarHeroTests/AppModelTests.swift`
- Test: `DockBarHeroTests/ManagementNavigationTests.swift`
- Test: `DockBarHeroTests/ManagementViewTests.swift`

**Interfaces:**

- Consumes Task 6 lifecycle APIs and Task 5 intents.
- Produces six stable routes, class choice, explicit labels, farming controls, gold display, and exact reset confirmation.

- [ ] **Step 1: Write failing management tests**

```swift
func testRoutesIncludeDeferredDestinations() {
    XCTAssertEqual(ManagementRoute.allCases, [.overview, .inventory, .abilities, .skills, .shop, .settings])
}

func testLevelLabelsAreExplicit() {
    XCTAssertEqual(ManagementFormat.heroLevel(12), "Hero Lv. 12")
    XCTAssertEqual(ManagementFormat.enemyLevel(34), "Enemy Lv. 34")
    XCTAssertEqual(ManagementFormat.itemLevel(56), "Item Lv. 56")
}

func testCampaignIntentFactories() {
    XCTAssertEqual(ManagementIntent.selectLevel(24), .selectLevel(24))
    XCTAssertEqual(ManagementIntent.returnToFrontier, .returnToFrontier)
}

func testResetPhraseIsExact() {
    XCTAssertTrue(ManagementFormat.isNewGameConfirmationValid("GAME OVER MAN!"))
    XCTAssertFalse(ManagementFormat.isNewGameConfirmationValid("Game Over Man!"))
}
```

- [ ] **Step 2: Run management tests to verify RED**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/ProgressionUIRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/AppModelTests -only-testing:DockBarHeroTests/ManagementNavigationTests -only-testing:DockBarHeroTests/ManagementViewTests
```

Expected: FAIL because lifecycle UI, routes, labels, and controls are absent.

- [ ] **Step 3: Add class-selection presentation**

`AppModel` publishes `runPresentation`, derives optional active `game`, forwards class choice and New Game asynchronously, and renders the scene only for an active run. `ClassSelectionView` presents Tank, DPS, and Healer buttons and disables duplicate submission until durable replacement finishes.

- [ ] **Step 4: Add routes and empty states**

```swift
case overview   // gauge.with.dots.needle.67percent
case inventory  // shippingbox
case abilities  // bolt.circle
case skills     // point.3.connected.trianglepath.dotted
case shop       // storefront
case settings   // gearshape
```

Abilities names the later Class Actions gate. Skills names Upgrades and Economy. Shop displays current gold and states purchases are inactive. Do not add dormant gameplay fields.

- [ ] **Step 5: Add Overview controls and labels**

Show hero level/XP, enemy tier/level, gold, frontier, selected level, mode, and queued destination. Picker range is `1..<highestUnlockedLevel`; selection queues without changing active combat. Return to Frontier queues frontier. Inventory and equipment use `Item Lv.`.

- [ ] **Step 6: Add exact Danger Zone behavior**

Explain that heroes, XP, gold, frontier, inventory, equipment, and unlocks are replaced. Enable the destructive button only when text equals `GAME OVER MAN!`. Await reset; dismiss only on success; preserve the old run and entered text on failure.

- [ ] **Step 7: Run focused tests to verify GREEN**

Run Step 2 with `.build/ProgressionUIGreen`.

Expected: all selected tests pass with stable routes and exact copy.

- [ ] **Step 8: Commit**

```bash
git add DockBarHero/App DockBarHeroTests/AppModelTests.swift DockBarHeroTests/ManagementNavigationTests.swift DockBarHeroTests/ManagementViewTests.swift
git commit -m "feat: add progression management surfaces"
```

---

### Task 8: Rail Presentation and Integrated Internal Gate

**Files:**

- Modify: `DockBarHero/Rendering/PrototypeScene.swift`
- Modify: `DockBarHero/Rendering/PrototypeSceneHost.swift`
- Modify: `DockBarHeroTests/PrototypeSceneHostTests.swift`
- Create: `docs/qa/review-packets/progression-safety.md` (parent only)
- Modify: `PROJECT.md` after fresh verification (parent only)

**Interfaces:**

- Produces snapshot-only hero/enemy/tier labels and a verified internal checkpoint.
- Does not authorize merge, push, or release before Heroes and Party plus Class Actions complete.

- [ ] **Step 1: Write failing rail tests**

```swift
func testRailUsesExplicitHeroEnemyAndTierLabels() throws {
    let host = try PrototypeSceneHost()
    var simulation = GameSimulation(state: try activeState(heroLevel: 12, enemyLevel: 25, tier: .boss))
    host.render(simulation.presentation)
    XCTAssertEqual((host.scene.childNode(withName: "//heroLevel") as? SKLabelNode)?.text, "Hero Lv. 12")
    XCTAssertEqual((host.scene.childNode(withName: "//enemyLevel") as? SKLabelNode)?.text, "Boss · Enemy Lv. 25")
}

func testClassSelectionHidesCombatPresentation() throws {
    let host = try PrototypeSceneHost()
    host.render(.classSelection)
    XCTAssertTrue(host.scene.childNode(withName: "//hero")?.isHidden == true)
    XCTAssertTrue(host.scene.childNode(withName: "//enemy")?.isHidden == true)
}
```

The test-only `activeState(heroLevel:enemyLevel:tier:)` starts from `.dps`, sets the hero level, campaign frontier/selection, scheduled tier, and a valid tier-built enemy. Add `PrototypeSceneHost.render(_ run: RunPresentation)` as the production entry point used by both assertions.

- [ ] **Step 2: Run rendering tests to verify RED**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/ProgressionRailRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/PrototypeSceneHostTests
```

Expected: FAIL because explicit tier/hero labels and class-selection rendering are absent.

- [ ] **Step 3: Implement snapshot-only rail state**

Add stable hero/enemy label nodes. Active snapshots render `Hero Lv. N` and `<Tier> · Enemy Lv. N`. Class selection hides actors, bars, DPS, and labels without invoking gameplay. Existing event-only animations remain unchanged.

- [ ] **Step 4: Run the focused progression gate**

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/ProgressionFocusedGate CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/ProgressionConfigurationTests -only-testing:DockBarHeroTests/EncounterScheduleTests -only-testing:DockBarHeroTests/ProgressionSafetyTests -only-testing:DockBarHeroTests/GameSimulationTests -only-testing:DockBarHeroTests/GameSessionTests -only-testing:DockBarHeroTests/SaveDocumentTests -only-testing:DockBarHeroTests/SaveStoreTests -only-testing:DockBarHeroTests/ManagementViewTests -only-testing:DockBarHeroTests/PrototypeSceneHostTests
```

Expected: every selected test passes with zero failures.

- [ ] **Step 5: Run the complete automated gate**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/ProgressionFull CODE_SIGNING_ALLOWED=NO
xcodebuild clean build -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/ProgressionBuild CODE_SIGNING_ALLOWED=NO
python3 /Users/n3kr0/.codex/skills/maintaining-project-context/scripts/context_guard.py check --root .
git diff --check
```

Expected: complete suite and clean Apple Silicon build pass; context and diff are clean.

- [ ] **Step 6: Perform proportional live QA**

Run `./script/build_and_run.sh --verify` and record: class selection before combat; explicit Hero/Enemy/Item labels; queued switching without interruption; Farming repeat and Return to Frontier; 174→149 fallback preserving frontier; XP/gold/queue relaunch; reset failure/success behavior; intentional Abilities/Skills/Shop states; and unchanged overlay placement, passive input, fullscreen suppression, and focus.

- [ ] **Step 7: Commit evidence**

```bash
git add DockBarHero/Rendering DockBarHeroTests/PrototypeSceneHostTests.swift docs/qa/review-packets/progression-safety.md PROJECT.md
git commit -m "docs: accept progression safety gate"
```

- [ ] **Step 8: Stop at the internal checkpoint**

Do not merge, push, or call schema v2 complete. Write the separate Heroes and Party implementation plan next, then define and plan the three class abilities. The milestone becomes release-eligible only after those gates pass.
