# DockBarHero Heroes and Party Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add durable one-to-three-hero unlocks, deterministic party combat and rewards, exclusive per-hero equipment over shared inventory, and complete management/rail presentation.

**Architecture:** Extend the existing schema-v2 `GameState` rather than introducing a new save version. Keep simulation changes transactional by mutating candidate copies, isolate unlock construction in `PartyUnlockResolver`, and make Boss 25 a persisted `awaitingPartyChoice` encounter boundary that `GameSession` flushes before publishing its choice screen.

**Tech Stack:** Swift 6, SwiftUI, SpriteKit, Foundation concurrency, XCTest, XcodeGen, `xcodebuild` on Apple Silicon macOS.

## Global Constraints

- Work only in `/Users/n3kr0/Projects/TBH/.worktrees/heroes-and-party` on `feature/heroes-and-party`; do not merge to `main`.
- Use red-green-refactor for every production behavior and commit each coherent slice.
- Preserve deterministic integer nanosecond timing, checked arithmetic, candidate-state rollback, queued player destination precedence, settings, and overlay behavior.
- Existing development saves require no migration; archive current saves and use a clean save for end-to-end QA.
- Do not add party-size enemy scaling, Class Actions, abilities, skills, purchases, or releases.
- The parent agent alone updates `PROJECT.md`, and only after fresh verification.

## File and Interface Map

- `DockBarHero/Game/GameModels.swift`: party unlock, per-hero encounter fields, slot-addressed intents/events, and presentation values.
- `DockBarHero/Game/PartyUnlockResolver.swift`: Boss milestone detection, pending choice completion, final-class addition, newcomer construction, and deterministic unused equipment selection.
- `DockBarHero/Game/CombatResolver.swift`: slot-specific effective stats, damage, ownership lookup, and upgrade deltas.
- `DockBarHero/Game/RewardResolver.swift`: per-hero time-alive XP, level-ups, shared gold/loot, death-streak updates, and party auto-equip.
- `DockBarHero/Game/EncounterDirector.swift`: full-party restoration, deferred Boss 25 transition, queued/retreat precedence, and streak reset.
- `DockBarHero/Game/GameSimulation.swift`: independent timers, slot-order actions, lowest-living targeting, down/all-down behavior, unlock boundary, and slot-addressed equip.
- `DockBarHero/Persistence/SaveDocument.swift`: one-to-three-hero, pending unlock, exclusive equipment, timer, phase, and encounter validation.
- `DockBarHero/Persistence/SaveCoordinator.swift`: explicit durable flush result used by the Boss 25 UI gate.
- `DockBarHero/Game/GameSession.swift`: pending-choice startup, durable gate/retry, class-choice replacement, and save-trigger lifecycle.
- `DockBarHero/App/PartySelectionView.swift`: persisted two-class Boss 25 choice UI.
- `DockBarHero/App/{AppModel,ManagementRootView,OverviewView,InventoryView,ManagementSupport}.swift`: choice routing, hero cards, hero-targeted equipment, and ownership labels.
- `DockBarHero/Rendering/{PrototypeScene,BuiltinPixelSprites,SpriteCatalog}.swift`: slot-addressed party nodes, class-distinct sprites, health/level labels, and events.
- `DockBarHeroTests/*`: focused domain, persistence, session, view-model, and rail regression tests.
- `docs/qa/review-packets/heroes-and-party.md`: final automated and live evidence.
- `PROJECT.md`: compact verified current truth after the complete gate.

---

### Task 1: Party State and Persistence

**Files:**
- Modify: `DockBarHero/Game/GameModels.swift`
- Modify: `DockBarHero/Game/BalanceConfiguration.swift`
- Modify: `DockBarHero/Persistence/SaveDocument.swift`
- Modify: `DockBarHeroTests/BalanceConfigurationTests.swift`
- Modify: `DockBarHeroTests/SaveDocumentTests.swift`

**Interfaces:**
- Produces: `PartyUnlockMilestone`, `PendingPartyUnlock`, `PartyUnlockState`, `HeroState.encounterAliveDuration`, `HeroState.wasDownThisEncounter`, `HeroState.consecutiveDeaths`, and `EncounterPhase.awaitingPartyChoice`.
- Invariant: one to three uniquely classed heroes; pending slot-two choice only after defeated Boss 25 with one hero; every equipped item is unique across heroes.

- [ ] **Step 1: Write failing party-domain fixture tests**

Add tests that construct a new game and assert the default party metadata, then construct two and three heroes and round-trip them. Add malformed cases for duplicate classes, four heroes, negative streak/alive duration, an invalid pending choice, and one item referenced by two heroes.

```swift
func testNewGameSeedsPartyLifecycleFields() {
    let state = GameState.newGame(classID: .tank, balance: .standard, progression: .standard)
    XCTAssertEqual(state.party.heroes.count, 1)
    XCTAssertEqual(state.party.unlocks, .locked)
    XCTAssertEqual(state.party.heroes[0].encounterAliveDuration, .zero)
    XCTAssertFalse(state.party.heroes[0].wasDownThisEncounter)
    XCTAssertEqual(state.party.heroes[0].consecutiveDeaths, 0)
}

func testSaveRejectsEquipmentSharedByTwoHeroes() throws {
    var state = try partyFixture(heroClasses: [.tank, .dps])
    state.party.heroes[0].equipment.weaponID = state.inventory[0].id
    state.party.heroes[1].equipment.weaponID = state.inventory[0].id
    XCTAssertThrowsError(try SaveCodec().encode(state: state, savedAt: Date()))
}
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/HeroesStateRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/BalanceConfigurationTests -only-testing:DockBarHeroTests/SaveDocumentTests
```

Expected: FAIL because party lifecycle types and per-hero fields do not exist and save validation still requires exactly one hero.

- [ ] **Step 3: Add the minimal state model and validation**

Use these domain shapes and add the fields to `HeroState` and `PartyState`:

```swift
enum PartyUnlockMilestone: String, Codable, Equatable, Sendable { case boss25, boss100 }

struct PendingPartyUnlock: Codable, Equatable, Sendable {
    let milestone: PartyUnlockMilestone
    let choices: [HeroClassID]
}

enum PartyUnlockState: Codable, Equatable, Sendable {
    case locked
    case pendingSecond(PendingPartyUnlock)
    case secondUnlocked
    case complete
}

struct HeroState: Codable, Equatable, Sendable {
    let classID: HeroClassID
    var level: Int
    var currentXP: Int64
    var combat: CombatantState
    var equipment: EquipmentState
    var encounterAliveDuration: SimulationDuration
    var wasDownThisEncounter: Bool
    var consecutiveDeaths: Int
}
```

Update new-game construction and validate class uniqueness, counts, XP, timers, pending choice contents, encounter phase coherence, and exclusive equipment references without compatibility migration.

- [ ] **Step 4: Run focused tests and verify GREEN**

Repeat the Step 2 command with `.build/HeroesStateGreen`. Expected: all selected tests pass with zero failures.

- [ ] **Step 5: Commit the state/persistence slice**

```bash
git add DockBarHero/Game/GameModels.swift DockBarHero/Game/BalanceConfiguration.swift DockBarHero/Persistence/SaveDocument.swift DockBarHeroTests/BalanceConfigurationTests.swift DockBarHeroTests/SaveDocumentTests.swift
git commit -m "feat: persist party lifecycle state"
```

### Task 2: Unlock Lifecycle and Durable Session Gate

**Files:**
- Create: `DockBarHero/Game/PartyUnlockResolver.swift`
- Modify: `DockBarHero/Game/GameModels.swift`
- Modify: `DockBarHero/Game/GameSimulation.swift`
- Modify: `DockBarHero/Game/EncounterDirector.swift`
- Modify: `DockBarHero/Persistence/SaveCoordinator.swift`
- Modify: `DockBarHero/Game/GameSession.swift`
- Modify: `DockBarHero/App/AppModel.swift`
- Create: `DockBarHero/App/PartySelectionView.swift`
- Modify: `DockBarHero/App/ManagementRootView.swift`
- Modify: `DockBarHeroTests/GameSimulationTests.swift`
- Modify: `DockBarHeroTests/SaveCoordinatorTests.swift`
- Modify: `DockBarHeroTests/GameSessionTests.swift`
- Modify: `DockBarHeroTests/AppModelTests.swift`
- Modify: `DockBarHeroTests/ManagementViewTests.swift`

**Interfaces:**
- Consumes: Task 1 lifecycle state and existing `SaveStore.replaceRun` transaction.
- Produces: `PartyUnlockResolver.beginSecondUnlock`, `completeSecondUnlock`, `addFinalHeroIfEarned`; `SaveFlushResult`; `SaveCoordinating.flushResult(_:)`; `RunPresentation.partySelection`; `GameSessionControlling.choosePartyClass(_:)`.
- Test support: `OrderedFlushCoordinator` records `.flushStarted` and `.flushCompleted`, blocks until `completeFlush(with:)`, and exposes a queued `SaveFlushResult` without sleeping.

- [ ] **Step 1: Write failing unlock and durability tests**

Cover rewards committed before Boss 25 pause, no level 26 combat before choice, exactly the two remaining classes, flush-before-presentation ordering, flush failure hiding buttons and retrying, relaunch directly into choice, failed replacement preserving pending state, successful choice resuming once, and Boss 100 adding the final class without `partySelection`.

```swift
func testBoss25PausesAfterRewardsWithPersistedRemainingChoices() throws {
    var state = try victoryFixture(level: 25, heroClasses: [.tank])
    var simulation = GameSimulation(state: state)
    let events = try simulation.advance(by: .zero)
    XCTAssertTrue(events.contains(.partyUnlockPending(.boss25)))
    XCTAssertEqual(simulation.state.encounter.phase, .awaitingPartyChoice)
    XCTAssertEqual(simulation.state.party.pendingUnlock?.choices, [.dps, .healer])
    XCTAssertGreaterThan(simulation.state.economy.gold, state.economy.gold)
}

func testSessionPublishesChoiceOnlyAfterPendingCheckpointIsDurable() async throws {
    let coordinator = OrderedFlushCoordinator()
    let session = makeStartedSessionAtBoss25(coordinator: coordinator)
    var presentations: [RunPresentation] = []
    session.onRunState = { presentations.append($0) }

    try triggerBoss25Victory(in: session)
    await coordinator.waitUntilFlushStarts()
    XCTAssertFalse(presentations.contains(where: \.isPartySelection))

    coordinator.completeFlush(with: .saved)
    await waitUntil { presentations.contains(where: \.isPartySelection) }
}
```

- [ ] **Step 2: Run the unlock-focused suite and verify RED**

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/HeroesUnlockRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/GameSimulationTests -only-testing:DockBarHeroTests/SaveCoordinatorTests -only-testing:DockBarHeroTests/GameSessionTests -only-testing:DockBarHeroTests/AppModelTests -only-testing:DockBarHeroTests/ManagementViewTests
```

Expected: FAIL on missing unlock resolver, phase, event, durable result, session method, and presentation route.

- [ ] **Step 3: Implement milestone construction and deferred transition**

Create a resolver with exact candidate-state methods:

```swift
struct PartyUnlockResolver: Sendable {
    func beginSecondUnlock(afterDefeating level: Int, in state: GameState) throws -> GameState
    func completeSecondUnlock(classID: HeroClassID, in state: GameState, balance: BalanceConfiguration) throws -> GameState
    func addFinalHeroIfEarned(afterDefeating level: Int, in state: GameState, balance: BalanceConfiguration) throws -> GameState
}
```

Boss 25 records `.pendingSecond`, changes only the encounter phase after rewards/streaks, and preserves `queuedLevel`. Choice completion adds the hero, clears pending state, and calls a new `EncounterDirector.completeDeferredVictory`. Boss 100 adds the missing class once and proceeds normally.

- [ ] **Step 4: Implement the durable session barrier and choice view**

Add:

```swift
enum SaveFlushResult: Equatable, Sendable { case saved; case failed(String) }
func flushResult(_ runState: RunState) async -> SaveFlushResult

enum RunPresentation: Equatable, Sendable {
    case classSelection
    case partySelection(PendingPartyUnlock, GamePresentation)
    case active(GamePresentation)
}
```

When the driver emits `.partyUnlockPending`, synchronously stop it, retain `.active(pendingState)`, suppress active presentation, await `flushResult`, and publish the choice only for `.saved`. Retry an identical failed checkpoint after injected autosave sleep. Loaded pending states never start the driver. `choosePartyClass` uses `store.replaceRun` before restarting combat.

- [ ] **Step 5: Run unlock-focused tests and verify GREEN**

Repeat Step 2 with `.build/HeroesUnlockGreen`. Expected: all selected tests pass with zero failures.

- [ ] **Step 6: Commit the unlock lifecycle slice**

```bash
git add DockBarHero DockBarHeroTests
git commit -m "feat: add durable party unlock lifecycle"
```

### Task 3: Party Combat, Time-Alive Rewards, and Death-Streak Retreat

**Files:**
- Modify: `DockBarHero/Game/GameModels.swift`
- Modify: `DockBarHero/Game/CombatResolver.swift`
- Modify: `DockBarHero/Game/RewardResolver.swift`
- Modify: `DockBarHero/Game/EncounterDirector.swift`
- Modify: `DockBarHero/Game/GameSimulation.swift`
- Modify: `DockBarHero/Game/DamageMetrics.swift`
- Modify: `DockBarHeroTests/CombatResolverTests.swift`
- Modify: `DockBarHeroTests/RewardResolverTests.swift`
- Modify: `DockBarHeroTests/EncounterDirectorTests.swift`
- Modify: `DockBarHeroTests/GameSimulationTests.swift`
- Modify: `DockBarHeroTests/ProgressionSafetyTests.swift`

**Interfaces:**
- Produces: `CombatActor.hero(slot:)`, `CombatActor.enemy`, slot-specific attack events, `CombatResolver.damageFromHero(at:)`, `enemyDamage(targetingHeroAt:)`, and per-hero presentation stats.
- Invariant: all timing and XP math uses checked integers; `GameSimulation.advance` remains candidate-copy transactional.
- Test support: add private `partyFixture`, `victoryFixture`, `advanceOnce`, `attackActors`, `VictoryReward.xp(for:)`, and `VictoryReward.fullXP(for:)` helpers in the test files where used; helpers only construct state or filter public events and contain no production behavior.

- [ ] **Step 1: Write failing independent-timer and targeting tests**

Add tests for chronological different intervals, same-timestamp ascending slot attacks, hero-before-enemy, stopping remaining attacks after victory, enemy targeting the lowest living slot, downed heroes staying down, all-down defeat, and all-party restoration after victory/revival.

```swift
func testReadyHeroesAttackInAscendingPartySlotBeforeEnemy() throws {
    var state = try partyFixture(heroClasses: [.tank, .dps, .healer])
    state.party.heroes.indices.forEach { state.party.heroes[$0].combat.timeUntilNextAttack = .zero }
    state.enemy.timeUntilNextAttack = .zero
    let events = try GameSimulation(state: state).advancedOnce()
    XCTAssertEqual(events.attackActors.prefix(3), [.hero(slot: 0), .hero(slot: 1), .hero(slot: 2)])
}
```

- [ ] **Step 2: Write failing XP, streak, precedence, and rollback tests**

Cover floor division, minimum 1 for positive alive time, zero for zero alive time, multiplication overflow rollback, dead-on-victory streak increment, survivor reset, all-down increments, any streak of three causing whole-party fallback, all streaks reset on fallback, rewards preceding fallback, and queued destination preceding retreat.

```swift
func testVictoryXPIsProportionalToEachHeroAliveDuration() throws {
    var state = try victoryFixture(level: 10, heroClasses: [.tank, .dps])
    state.encounter.activeElapsed = try XCTUnwrap(.seconds(10))
    state.party.heroes[0].encounterAliveDuration = try XCTUnwrap(.seconds(10))
    state.party.heroes[1].encounterAliveDuration = try XCTUnwrap(.seconds(3))
    let reward = try RewardResolver().applyVictory(defeatedLevel: 10, to: state, balance: .standard)
    XCTAssertEqual(reward.xp(for: .tank), reward.fullXP(for: .tank))
    XCTAssertEqual(reward.xp(for: .dps), reward.fullXP(for: .dps) * 3 / 10)
}
```

- [ ] **Step 3: Run combat/reward tests and verify RED**

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/HeroesCombatRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/CombatResolverTests -only-testing:DockBarHeroTests/RewardResolverTests -only-testing:DockBarHeroTests/EncounterDirectorTests -only-testing:DockBarHeroTests/GameSimulationTests -only-testing:DockBarHeroTests/ProgressionSafetyTests
```

Expected: FAIL because combat and rewards still assume one hero and one timer.

- [ ] **Step 4: Implement slot-addressed resolver and simulation loop**

Replace single-hero timer selection with the minimum of enemy plus all living heroes, consume elapsed for every living hero, resolve ready slots in ascending order, and target `firstIndex { currentHealth > 0 }`. Set `wasDownThisEncounter` on death and begin defeat only when no hero lives. Keep `state.hero` only as a compatibility accessor for first-hero tests, not party logic.

- [ ] **Step 5: Implement proportional rewards and streak transitions**

Use checked quotient construction:

```swift
let product = try checkedMultiply(fullXP, hero.encounterAliveDuration.rawValue)
let proportional = product / state.encounter.activeElapsed.rawValue
let xp = hero.encounterAliveDuration > .zero ? max(1, proportional) : 0
```

Update each hero's XP and level independently, apply shared gold/loot once, update only that hero's streak, and let `EncounterDirector` apply queued destination before streak fallback. Restore all heroes and timers only at encounter resolution.

- [ ] **Step 6: Run combat/reward tests and verify GREEN**

Repeat Step 3 with `.build/HeroesCombatGreen`. Expected: all selected tests pass with zero failures and partition-determinism tests remain equal.

- [ ] **Step 7: Commit the party combat and rewards slice**

```bash
git add DockBarHero/Game DockBarHeroTests
git commit -m "feat: resolve deterministic party combat"
```

### Task 4: Shared Inventory and Exclusive Per-Hero Equipment

**Files:**
- Modify: `DockBarHero/Game/GameModels.swift`
- Modify: `DockBarHero/Game/CombatResolver.swift`
- Modify: `DockBarHero/Game/PartyUnlockResolver.swift`
- Modify: `DockBarHero/Game/RewardResolver.swift`
- Modify: `DockBarHero/Game/GameSimulation.swift`
- Modify: `DockBarHero/Game/SimulationDriver.swift`
- Modify: `DockBarHeroTests/CombatResolverTests.swift`
- Modify: `DockBarHeroTests/RewardResolverTests.swift`
- Modify: `DockBarHeroTests/GameSimulationTests.swift`
- Modify: `DockBarHeroTests/SimulationDriverTests.swift`

**Interfaces:**
- Changes: `GameIntent.equip(heroSlot: Int, itemID: ItemID)` and `GameEvent.equipped(heroSlot: Int, slot: EquipmentSlot, itemID: ItemID)`.
- Produces: deterministic `PartyUnlockResolver.strongestUnusedItem`, `CombatResolver.upgradeAmount`, and party-wide auto-equip selection.

- [ ] **Step 1: Write failing newcomer and manual-equip tests**

Cover highest-party-level/zero-XP seeding, strongest unused weapon/armor ordering, no sharing, empty eligible slot, exact hero-targeted equip, unknown hero, wrong slot, already-used item, and rollback.

```swift
func testNewHeroEquipsStrongestUnusedItemsDeterministically() throws {
    let result = try PartyUnlockResolver().completeSecondUnlock(classID: .dps, in: pendingFixture(), balance: .standard)
    XCTAssertEqual(result.party.heroes[1].equipment.weaponID, ItemID(rawValue: 4))
    XCTAssertEqual(result.party.heroes[1].equipment.armorID, ItemID(rawValue: 7))
}
```

- [ ] **Step 2: Write failing party auto-equip tests**

Cover greatest effective-stat increase, ascending slot tie, strict improvement only, another hero's item ineligible, and existing item retained on ties.

- [ ] **Step 3: Run equipment-focused tests and verify RED**

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/HeroesEquipmentRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/CombatResolverTests -only-testing:DockBarHeroTests/RewardResolverTests -only-testing:DockBarHeroTests/GameSimulationTests -only-testing:DockBarHeroTests/SimulationDriverTests
```

Expected: FAIL because equip and auto-equip still target the first hero.

- [ ] **Step 4: Implement exclusive equipment selection and intents**

Reject an item if any other hero references it. For newcomer selection, sort eligible same-slot items by primary stat descending, level descending, creation sequence ascending, ID ascending. For drop auto-equip, calculate the strict effective-stat delta for each eligible hero and select maximum delta then minimum slot.

- [ ] **Step 5: Run equipment-focused tests and verify GREEN**

Repeat Step 3 with `.build/HeroesEquipmentGreen`. Expected: all selected tests pass with zero failures.

- [ ] **Step 6: Commit the equipment slice**

```bash
git add DockBarHero/Game DockBarHeroTests
git commit -m "feat: add exclusive party equipment"
```

### Task 5: Management and Rail Presentation

**Files:**
- Modify: `DockBarHero/App/AppModel.swift`
- Modify: `DockBarHero/App/ManagementRootView.swift`
- Modify: `DockBarHero/App/OverviewView.swift`
- Modify: `DockBarHero/App/InventoryView.swift`
- Modify: `DockBarHero/App/ManagementSupport.swift`
- Modify: `DockBarHero/Rendering/PrototypeScene.swift`
- Modify: `DockBarHero/Rendering/BuiltinPixelSprites.swift`
- Modify: `DockBarHero/Rendering/SpriteCatalog.swift`
- Modify: `DockBarHeroTests/AppModelTests.swift`
- Modify: `DockBarHeroTests/ManagementNavigationTests.swift`
- Modify: `DockBarHeroTests/ManagementViewTests.swift`
- Modify: `DockBarHeroTests/PrototypeSceneHostTests.swift`
- Modify: `DockBarHeroTests/SpriteCatalogTests.swift`

**Interfaces:**
- Consumes: slot-addressed presentation, choice, equip, and event APIs.
- Produces: `HeroOverviewRow`, `InventoryRow.equippedHeroLabel`, selected hero binding, stable node names `hero-0` through `hero-2`, and class sprite tokens.

- [ ] **Step 1: Write failing management presentation tests**

Cover three ordered hero cards with class/level/XP/health/effective stats/streak/down label, party-selection buttons limited to persisted choices with accessibility IDs, selected-hero equip intent, shared inventory owner labels, and unchanged Abilities placeholder copy.

```swift
func testInventoryRowsNameEquippedHero() throws {
    let rows = InventoryRow.rows(for: try partyFixture(heroClasses: [.tank, .dps]))
    XCTAssertEqual(rows.first(where: { $0.id == ItemID(rawValue: 1) })?.equippedHeroLabel, "Hero 2 · DPS")
}
```

- [ ] **Step 2: Write failing rail tests**

Cover one/two/three hero nodes, non-overlapping ordered positions, per-slot health/level labels, class-distinct textures, exact slot attack/hit/down events, whole-party revive restoration, and pending-choice combat freeze.

- [ ] **Step 3: Run presentation tests and verify RED**

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/HeroesPresentationRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/AppModelTests -only-testing:DockBarHeroTests/ManagementNavigationTests -only-testing:DockBarHeroTests/ManagementViewTests -only-testing:DockBarHeroTests/PrototypeSceneHostTests -only-testing:DockBarHeroTests/SpriteCatalogTests
```

Expected: FAIL because the views and scene only present hero slot zero.

- [ ] **Step 4: Implement management party presentation**

Render hero cards from `state.party.heroes.enumerated()`, use slot-specific effective stats from `GamePresentation`, add an Inventory hero picker, route `.equip(heroSlot:itemID:)`, and show each item's owner. Reuse class-button copy in `PartySelectionView`; do not add ability controls.

- [ ] **Step 5: Implement rail party nodes and events**

Create/remove nodes to match active slots, place heroes within the left 44% of rail width, retain one enemy on the right, and address every hero node/bar/label by slot. Map class IDs to distinct built-in sprite tokens and preserve nearest-neighbor filtering.

- [ ] **Step 6: Run presentation tests and verify GREEN**

Repeat Step 3 with `.build/HeroesPresentationGreen`. Expected: all selected tests pass with zero failures.

- [ ] **Step 7: Commit the management and rail slice**

```bash
git add DockBarHero/App DockBarHero/Rendering DockBarHeroTests
git commit -m "feat: present heroes across management and rail"
```

### Task 6: Integrated Balance and Regression Gate

**Files:**
- Modify: `DockBarHeroTests/ProgressionSafetyTests.swift`
- Create: `DockBarHeroTests/HeroesAndPartyTests.swift`
- Modify as required by a failing regression: only the already listed `DockBarHero/Game`, `DockBarHero/Persistence`, `DockBarHero/App`, or `DockBarHero/Rendering` milestone files.

**Interfaces:**
- Verifies: complete milestone behavior across time partitions and one/two/three-hero campaign boundaries.

- [ ] **Step 1: Add failing integrated model tests**

Add deterministic model tests that run each class solo through Boss 25 with obtainable equipment, choose each possible second class, cover two-hero levels 26–100 and automatic final unlock, construct level 101 with three heroes, compare one large advance with partitioned advances, and assert enemy stats are identical for equal level/tier regardless of party size.

- [ ] **Step 2: Run the integrated tests and verify RED for uncovered behavior**

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/HeroesIntegratedRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/HeroesAndPartyTests -only-testing:DockBarHeroTests/ProgressionSafetyTests
```

Expected: each new test must either fail for its named missing behavior or be mutation-checked by temporarily reversing the exact condition it protects, observing that test fail, restoring the implementation, and observing it pass.

- [ ] **Step 3: Make only the minimal requirement-backed corrections**

Correct production behavior one failing test at a time. Do not tune enemy stats dynamically, add class actions, or refactor unrelated overlay/session code.

- [ ] **Step 4: Run the focused milestone gate**

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/HeroesFocusedGate CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/HeroesAndPartyTests -only-testing:DockBarHeroTests/GameSimulationTests -only-testing:DockBarHeroTests/GameSessionTests -only-testing:DockBarHeroTests/SaveDocumentTests -only-testing:DockBarHeroTests/SaveStoreTests -only-testing:DockBarHeroTests/SaveCoordinatorTests -only-testing:DockBarHeroTests/ManagementViewTests -only-testing:DockBarHeroTests/PrototypeSceneHostTests
```

Expected: all selected tests pass with zero failures.

- [ ] **Step 5: Commit the integrated regression gate**

```bash
git add DockBarHero DockBarHeroTests
git commit -m "test: verify heroes and party milestone"
```

### Task 7: Save Archive and Live QA

**Files:**
- Create: `docs/qa/review-packets/heroes-and-party.md`
- Modify: `PROJECT.md` only after final verification.

**Interfaces:**
- Uses: `SaveURLs.applicationSupport`, existing app preferences, `script/build_and_run.sh`, and UI accessibility identifiers.
- Produces: timestamped diagnostic save archive and explicit pass/fail QA evidence.

- [ ] **Step 1: Locate and archive gameplay saves without changing settings**

Quit DockBarHero, resolve the application-support directory from `SaveStore.swift`, and copy every `save-v2*` file into a timestamped `heroes-and-party-pre-qa-YYYYMMDD-HHMMSS` subdirectory. Record filenames and hashes in the QA packet. Do not move or edit `settings-v1*` files.

- [ ] **Step 2: Start from a clean gameplay save**

Remove only the active `save-v2.json`, `save-v2.backup.json`, and `save-v2.pending.json` after the archive is verified. Launch the feature build and choose the starting class through the management window.

- [ ] **Step 3: Exercise the required unlock lifecycle**

Use deterministic test acceleration only if it is implemented as temporary launch/test state outside tracked source. Reach Boss 25, verify rewards occur before pause, quit with the choice pending, relaunch into the choice automatically, click one of the two choices, and verify combat resumes with two heroes. Reach Boss 100 and verify the remaining class is added automatically with no choice pause.

- [ ] **Step 4: Exercise management, inventory, and rail**

Verify hero ordering, down/revival presentation, distinct health bars, shared inventory ownership, per-hero equip selection, no item sharing, queued destination precedence, remedial retreat, Abilities placeholder, and preservation of overlay/application preferences. Perform every class-selection, unlock, and confirmation click without owner input.

- [ ] **Step 5: Record exact live evidence**

Write checked/unchecked QA items, app/build identity, archive path, save hashes, and any limitations to `docs/qa/review-packets/heroes-and-party.md`. Do not convert automated assertions into visual evidence.

### Task 8: Full Verification, Context, and Push

**Files:**
- Modify: `docs/qa/review-packets/heroes-and-party.md`
- Modify: `PROJECT.md`

**Interfaces:**
- Produces: final branch evidence and remote `feature/heroes-and-party`; never merges or releases.

- [ ] **Step 1: Generate and inspect project changes**

```bash
xcodegen generate
git diff --check
git status --short
```

Expected: XcodeGen succeeds, diff check is clean, and only milestone files are modified.

- [ ] **Step 2: Run the complete arm64 test suite**

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/HeroesFull CODE_SIGNING_ALLOWED=NO
```

Expected: `** TEST SUCCEEDED **`, zero failures.

- [ ] **Step 3: Run a clean unsigned arm64 build**

```bash
xcodebuild clean build -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/HeroesBuild CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Run context and launch verification**

```bash
python3 /Users/n3kr0/.codex/skills/maintaining-project-context/scripts/context_guard.py check --root .
./script/build_and_run.sh --verify
```

Expected: context guard reports valid `AGENTS.md`/`PROJECT.md`; the script builds, launches, and finds the DockBarHero process.

- [ ] **Step 5: Update verified docs and re-run their guards**

Update `PROJECT.md` tersely under its existing headings with only facts proven by Steps 1–4 and live QA. Complete the QA packet with exact counts and commands, then run:

```bash
python3 /Users/n3kr0/.codex/skills/maintaining-project-context/scripts/context_guard.py check --root .
git diff --check
```

Expected: both commands exit zero; `AGENTS.md` is at most 100 lines and `PROJECT.md` at most 150 lines.

- [ ] **Step 6: Commit the verified milestone report**

```bash
git add PROJECT.md docs/qa/review-packets/heroes-and-party.md
git commit -m "docs: record heroes and party verification"
```

- [ ] **Step 7: Re-run final branch evidence and push only on success**

```bash
git status --short --branch
git log --oneline --decorate main..HEAD
git push -u origin feature/heroes-and-party
```

Expected: clean feature branch, coherent milestone commits, and successful push. Do not merge to `main`, create a release, or begin Class Actions.
