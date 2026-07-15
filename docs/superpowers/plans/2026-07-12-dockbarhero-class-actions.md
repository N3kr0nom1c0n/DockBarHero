# DockBarHero Class Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one deterministic, persisted, cooldown-only manual Class Action for Tank, DPS, and Healer with management and interactive-only rail controls.

**Architecture:** `ClassActionConfiguration` owns validated tuning, `ClassActionState` persists per hero, and a pure `AbilityResolver` resolves slot-addressed casts into complete candidate state plus domain events. `GameSimulation` remains the transaction boundary, advances cooldowns with active integer time, and routes lethal Power Strike results through the existing victory pipeline; SwiftUI and SpriteKit only submit intents and render state/events.

**Tech Stack:** Swift 6, SwiftUI, AppKit, SpriteKit, XCTest, XcodeGen, macOS arm64.

## Global Constraints

- Build on `feature/heroes-and-party`; do not merge to `main` during implementation.
- Preserve signed `Int64` nanosecond gameplay time and checked integer basis-point arithmetic.
- New heroes and new runs start ready; cooldowns carry across encounters and advance only for living heroes during active combat.
- Guard is 8 seconds and reduces the next redirected enemy attack to 50%; Power Strike is 6 seconds at 250% attack; Mend is 10 seconds at 35% maximum health.
- Passive overlay mode remains click-through; rail actions accept input only in interactive mode.
- No autocast, resources, upgrades, revival action, area damage, action affixes, release, or Class Action expansion.
- Every slice uses TDD, focused arm64 tests, transactional rollback checks, and a coherent commit.

## File Map

- Create `DockBarHero/Game/ClassActionConfiguration.swift`: stable definitions, tuning, lookup, and validation.
- Create `DockBarHero/Game/AbilityResolver.swift`: pure cast validation and Guard/Power Strike/Mend candidate resolution.
- Create `DockBarHero/App/ClassActionsView.swift`: party action cards, disabled reasons, and management cast controls.
- Modify `DockBarHero/Game/GameModels.swift`: action IDs/state, cast intent, action events, presentation state.
- Modify `DockBarHero/Game/GameSimulation.swift`: action transaction, cooldown consumption, victory reuse, state validation.
- Modify `DockBarHero/Game/CombatResolver.swift`: reusable scaled attack and Guard-adjusted enemy damage helper.
- Modify `DockBarHero/Game/PartyUnlockResolver.swift`: ready action state for newcomers.
- Verify `DockBarHero/Game/GameSession.swift` unchanged: its existing state-difference path requests saves for successful casts, while rejection-only events do not change state.
- Modify `DockBarHero/Persistence/SaveDocument.swift`: schema-v2 action validation without introducing a new schema version.
- Modify `DockBarHero/App/ManagementRootView.swift` and `ManagementSupport.swift`: activate Abilities route and format cooldown/rejection state.
- Modify `DockBarHero/App/AppModel.swift`: expose overlay interaction state to the scene and forward rail cast callbacks.
- Modify `DockBarHero/Rendering/PrototypeScene.swift` and `PrototypeSceneHost.swift`: action nodes, progress, click routing, and events.
- Add focused tests in `DockBarHeroTests/ClassActionConfigurationTests.swift`, `AbilityResolverTests.swift`, and `ClassActionsViewTests.swift`; extend simulation, persistence, session, model, and scene tests.

---

### Task 1: Stable Definitions and Persisted Action State

**Files:**
- Create: `DockBarHero/Game/ClassActionConfiguration.swift`
- Modify: `DockBarHero/Game/GameModels.swift`
- Modify: `DockBarHero/Game/PartyUnlockResolver.swift`
- Modify: `DockBarHero/Persistence/SaveDocument.swift`
- Create: `DockBarHeroTests/ClassActionConfigurationTests.swift`
- Modify: `DockBarHeroTests/SaveDocumentTests.swift`
- Modify: `DockBarHeroTests/PartyUnlockResolverTests.swift`

**Interfaces:**
- Produces: `ClassActionID`, `ClassActionState`, `ClassActionDefinition`, `ClassActionConfiguration.standard`, and `classAction` on `HeroState`.
- Produces: `ClassActionConfiguration.definition(for:) throws -> ClassActionDefinition` and `action(for:) -> ClassActionID`.
- Consumed by: Tasks 2-7.

- [ ] **Step 1: Write failing definition and default-state tests**

```swift
func testStandardDefinitionsMatchApprovedValues() throws {
    let config = ClassActionConfiguration.standard
    XCTAssertEqual(try config.definition(for: .guard).cooldown, .seconds(8)!)
    XCTAssertEqual(try config.definition(for: .guard).powerBasisPoints, 5_000)
    XCTAssertEqual(try config.definition(for: .powerStrike).cooldown, .seconds(6)!)
    XCTAssertEqual(try config.definition(for: .powerStrike).powerBasisPoints, 25_000)
    XCTAssertEqual(try config.definition(for: .mend).cooldown, .seconds(10)!)
    XCTAssertEqual(try config.definition(for: .mend).powerBasisPoints, 3_500)
}

func testNewHeroStartsWithClassActionReady() {
    let hero = GameState.newGame(classID: .healer, balance: .standard, progression: .standard).party.heroes[0]
    XCTAssertEqual(hero.classAction, ClassActionState(actionID: .mend, cooldownRemaining: .zero, guardActive: false))
}
```

- [ ] **Step 2: Run the focused tests and verify RED**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/ClassActionStateRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/ClassActionConfigurationTests -only-testing:DockBarHeroTests/SaveDocumentTests -only-testing:DockBarHeroTests/PartyUnlockResolverTests
```

Expected: compile failure because action types and `HeroState.classAction` do not exist.

- [ ] **Step 3: Add the exact domain and configuration types**

```swift
enum ClassActionID: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case guardAction = "guard"
    case powerStrike
    case mend
}

struct ClassActionState: Codable, Equatable, Sendable {
    let actionID: ClassActionID
    var cooldownRemaining: SimulationDuration
    var guardActive: Bool
}

struct ClassActionDefinition: Equatable, Sendable {
    let id: ClassActionID
    let heroClass: HeroClassID
    let cooldown: SimulationDuration
    let powerBasisPoints: Int64
}

struct ClassActionConfiguration: Sendable {
    static let standard = ClassActionConfiguration(definitions: [
        .init(id: .guardAction, heroClass: .tank, cooldown: .seconds(8)!, powerBasisPoints: 5_000),
        .init(id: .powerStrike, heroClass: .dps, cooldown: .seconds(6)!, powerBasisPoints: 25_000),
        .init(id: .mend, heroClass: .healer, cooldown: .seconds(10)!, powerBasisPoints: 3_500),
    ])

    let definitions: [ClassActionDefinition]

    func definition(for id: ClassActionID) throws -> ClassActionDefinition {
        let matches = definitions.filter { $0.id == id }
        guard matches.count == 1, let value = matches.first,
              value.cooldown >= .minimumAttackInterval,
              value.powerBasisPoints > 0 else { throw SimulationError.invalidBalance }
        return value
    }

    func action(for heroClass: HeroClassID) -> ClassActionID {
        switch heroClass {
        case .tank: .guardAction
        case .dps: .powerStrike
        case .healer: .mend
        }
    }
}
```

Add `var classAction: ClassActionState` to `HeroState`, seed it in every `GameState.newGame` and `PartyUnlockResolver.makeHero` construction, and update test fixtures explicitly rather than adding lossy decoding defaults.

- [ ] **Step 4: Validate exact action ownership and ranges in saves**

```swift
let actions = ClassActionConfiguration.standard
for hero in state.party.heroes {
    let expectedID = actions.action(for: hero.classID)
    let definition = try actions.definition(for: hero.classAction.actionID)
    guard hero.classAction.actionID == expectedID,
          definition.heroClass == hero.classID,
          hero.classAction.cooldownRemaining >= .zero,
          hero.classAction.cooldownRemaining <= definition.cooldown,
          !hero.classAction.guardActive || (
              hero.classID == .tank &&
              hero.combat.currentHealth > 0 &&
              state.encounter.phase == .active
          ) else { throw SaveValidationError.invalidClassAction }
}
```

Add `invalidClassAction` to `SaveValidationError`. Preserve schema version 2 because these are unreleased development saves and clean QA remains required.

- [ ] **Step 5: Run focused tests and verify GREEN**

Repeat Step 2 with `.build/ClassActionStateGreen`. Expected: selected suites pass with zero failures.

- [ ] **Step 6: Commit the state slice**

```bash
git add DockBarHero/Game/ClassActionConfiguration.swift DockBarHero/Game/GameModels.swift DockBarHero/Game/PartyUnlockResolver.swift DockBarHero/Persistence/SaveDocument.swift DockBarHeroTests/ClassActionConfigurationTests.swift DockBarHeroTests/SaveDocumentTests.swift DockBarHeroTests/PartyUnlockResolverTests.swift
git commit -m "feat: persist class action state"
```

### Task 2: Deterministic Cooldown Advancement

**Files:**
- Modify: `DockBarHero/Game/GameSimulation.swift`
- Create: `DockBarHeroTests/ClassActionCooldownTests.swift`
- Modify: `DockBarHeroTests/GameSimulationTests.swift`

**Interfaces:**
- Consumes: `HeroState.classAction.cooldownRemaining` and standard definitions from Task 1.
- Produces: living-hero active-time cooldown consumption and state validation used by ability casts.

- [ ] **Step 1: Write failing partition, carryover, and freeze tests**

```swift
func testLivingCooldownConsumesOnlyActiveCombatTimePartitionInvariant() throws {
    var state = try fixture(classID: .dps, cooldown: .seconds(6)!)
    var whole = GameSimulation(state: state)
    var chunks = GameSimulation(state: state)
    _ = try whole.advance(by: .seconds(2)!)
    _ = try chunks.advance(by: .seconds(1)!)
    _ = try chunks.advance(by: .seconds(1)!)
    XCTAssertEqual(whole.state, chunks.state)
    XCTAssertEqual(whole.state.party.heroes[0].classAction.cooldownRemaining, .seconds(4)!)
}

func testDownedHeroCooldownFreezesWhileLivingHeroCooldownAdvances() throws {
    var state = try twoHeroFixture()
    state.party.heroes[0].combat.currentHealth = 0
    state.party.heroes[0].classAction.cooldownRemaining = .seconds(5)!
    state.party.heroes[1].classAction.cooldownRemaining = .seconds(5)!
    var simulation = GameSimulation(state: state)
    _ = try simulation.advance(by: .seconds(1)!)
    XCTAssertEqual(simulation.state.party.heroes[0].classAction.cooldownRemaining, .seconds(5)!)
    XCTAssertEqual(simulation.state.party.heroes[1].classAction.cooldownRemaining, .seconds(4)!)
}
```

Also cover encounter transition carryover, revival freeze, awaiting-choice freeze, zero floor, and invalid cooldown rollback.

Add an event assertion that a cooldown crossing from positive to zero emits exactly one `.classActionReady(heroSlot:actionID:)`, including when the same elapsed time is split across advances.

- [ ] **Step 2: Run tests and verify RED**

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/ClassActionCooldownRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/ClassActionCooldownTests -only-testing:DockBarHeroTests/GameSimulationTests
```

Expected: cooldown remains unchanged during active time.

- [ ] **Step 3: Consume cooldown in the existing active-time transaction**

Change the helper to `consumeActiveTime(_ elapsed: SimulationDuration, into events: inout [GameEvent])`. For each living hero, subtract `min(elapsed, cooldownRemaining)` with the existing checked helper and emit readiness only on a positive-to-zero crossing:

```swift
let cooldownStep = min(elapsed, state.party.heroes[slot].classAction.cooldownRemaining)
let wasCoolingDown = state.party.heroes[slot].classAction.cooldownRemaining > .zero
state.party.heroes[slot].classAction.cooldownRemaining = try subtracting(
    cooldownStep,
    from: state.party.heroes[slot].classAction.cooldownRemaining
)
if wasCoolingDown, state.party.heroes[slot].classAction.cooldownRemaining == .zero {
    events.append(.classActionReady(
        heroSlot: slot,
        actionID: state.party.heroes[slot].classAction.actionID
    ))
}
```

Do not touch cooldown state in revive, victory, defeat, pending choice, or application lifecycle code. Extend `validateStateAndBalance` with the same ownership/range checks as `SaveCodec`.

- [ ] **Step 4: Run tests and verify GREEN**

Repeat Step 2 with `.build/ClassActionCooldownGreen`. Expected: all selected tests pass.

- [ ] **Step 5: Commit the cooldown slice**

```bash
git add DockBarHero/Game/GameSimulation.swift DockBarHeroTests/ClassActionCooldownTests.swift DockBarHeroTests/GameSimulationTests.swift
git commit -m "feat: advance class action cooldowns"
```

### Task 3: Guard Resolution and Enemy Interception

**Files:**
- Create: `DockBarHero/Game/AbilityResolver.swift`
- Modify: `DockBarHero/Game/GameModels.swift`
- Modify: `DockBarHero/Game/CombatResolver.swift`
- Modify: `DockBarHero/Game/GameSimulation.swift`
- Create: `DockBarHeroTests/AbilityResolverTests.swift`
- Modify: `DockBarHeroTests/GameSimulationTests.swift`

**Interfaces:**
- Produces: `GameIntent.castAction(heroSlot:actionID:)`, `ClassActionRejection`, and action events.
- Produces: `AbilityResolver.resolve(heroSlot:actionID:in:) throws -> AbilityResolution`.
- Consumed by: Tasks 4-7.

- [ ] **Step 1: Write failing Guard and rejection rollback tests**

```swift
func testGuardRedirectsNextEnemyAttackAndHalvesPostDefenseDamage() throws {
    var state = try partyFixture(classes: [.dps, .tank])
    var simulation = GameSimulation(state: state)
    XCTAssertEqual(try simulation.apply(.castAction(heroSlot: 1, actionID: .guardAction)), [
        .classActionCast(heroSlot: 1, actionID: .guardAction),
        .guardActivated(heroSlot: 1),
    ])
    let events = try simulation.advance(by: state.enemy.timeUntilNextAttack)
    XCTAssertTrue(events.contains(.guardIntercepted(heroSlot: 1, damage: 1)))
    XCTAssertFalse(simulation.state.party.heroes[1].classAction.guardActive)
}

func testDuplicateGuardRejectsWithoutMutation() throws {
    var simulation = GameSimulation(state: try guardedTankFixture())
    let before = simulation.state
    XCTAssertEqual(try simulation.apply(.castAction(heroSlot: 0, actionID: .guardAction)), [
        .classActionRejected(heroSlot: 0, actionID: .guardAction, reason: .alreadyActive)
    ])
    XCTAssertEqual(simulation.state, before)
}
```

Cover wrong class, invalid slot, downed caster, inactive phase, cooldown, Guard owner down, and encounter-resolution expiration.

- [ ] **Step 2: Run tests and verify RED**

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/GuardRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/AbilityResolverTests -only-testing:DockBarHeroTests/GameSimulationTests
```

Expected: cast intent and resolver types are missing.

- [ ] **Step 3: Add resolver contracts and validation**

```swift
enum ClassActionRejection: String, Equatable, Sendable {
    case invalidSlot, wrongClass, casterDown, encounterInactive, cooldown, alreadyActive, noValidTarget
}

struct AbilityResolution: Equatable, Sendable {
    var state: GameState
    var events: [GameEvent]
    var damageDealt: Int = 0
    var enemyDefeated: Bool = false
}

struct AbilityResolver: Sendable {
    let configuration: ClassActionConfiguration
    let combat: CombatResolver

    func resolve(heroSlot: Int, actionID: ClassActionID, in state: GameState) throws -> AbilityResolution
}
```

Typed gameplay rejections return a rejection event without mutation. Invalid definitions or arithmetic throw and rely on `GameSimulation.apply` candidate rollback.

- [ ] **Step 4: Implement Guard cast and enemy consumption**

Guard cast sets `guardActive = true` and the full 8-second cooldown. In `resolveEnemyAction`, choose the active living Tank before the normal lowest-living target, calculate normal post-defense damage, apply the configured 5,000 basis points with `.down` rounding, then `max(1, scaled)`. Atomically clear Guard and emit `guardIntercepted`; if the hit downs the Tank, keep existing `heroDown` and all-down defeat behavior. Clear every Guard during victory and defeat transition construction.

- [ ] **Step 5: Run tests and verify GREEN**

Repeat Step 2 with `.build/GuardGreen`. Expected: selected tests pass with zero failures.

- [ ] **Step 6: Commit Guard**

```bash
git add DockBarHero/Game/AbilityResolver.swift DockBarHero/Game/GameModels.swift DockBarHero/Game/CombatResolver.swift DockBarHero/Game/GameSimulation.swift DockBarHeroTests/AbilityResolverTests.swift DockBarHeroTests/GameSimulationTests.swift
git commit -m "feat: add tank guard action"
```

### Task 4: Power Strike and Victory Reuse

**Files:**
- Modify: `DockBarHero/Game/AbilityResolver.swift`
- Modify: `DockBarHero/Game/CombatResolver.swift`
- Modify: `DockBarHero/Game/GameSimulation.swift`
- Modify: `DockBarHeroTests/AbilityResolverTests.swift`
- Modify: `DockBarHeroTests/GameSimulationTests.swift`
- Create: `DockBarHeroTests/ClassActionVictoryTests.swift`

**Interfaces:**
- Consumes: `AbilityResolution.damageDealt` and `enemyDefeated` from Task 3.
- Produces: shared `completeVictory(defeatedLevel:events:)` used by automatic attacks and Power Strike.

- [ ] **Step 1: Write failing damage, DPS, overflow, and victory tests**

```swift
func testPowerStrikeUsesTwoHundredFiftyPercentAttackThenDefense() throws {
    var state = try actionFixture(classID: .dps)
    state.enemy.currentHealth = 100
    state.enemy = replacingDefense(5, in: state.enemy)
    var simulation = GameSimulation(state: state)
    let events = try simulation.apply(.castAction(heroSlot: 0, actionID: .powerStrike))
    XCTAssertTrue(events.contains(.powerStrike(heroSlot: 0, damage: 25)))
    XCTAssertEqual(simulation.state.enemy.currentHealth, 75)
    XCTAssertEqual(simulation.state.party.heroes[0].classAction.cooldownRemaining, .seconds(6)!)
    XCTAssertGreaterThan(simulation.presentation.rollingDPS, 0)
}

func testLethalPowerStrikeResolvesRewardsAndUnlockExactlyOnce() throws {
    var state = try boss25ReadyForActionFixture()
    state.enemy.currentHealth = 1
    var simulation = GameSimulation(state: state)
    let events = try simulation.apply(.castAction(heroSlot: 0, actionID: .powerStrike))
    XCTAssertEqual(events.filter(\.isVictory).count, 1)
    XCTAssertEqual(simulation.state.encounter.phase, .awaitingPartyChoice)
    XCTAssertNotNil(simulation.state.party.unlocks.pendingUnlock)
}
```

- [ ] **Step 2: Run tests and verify RED**

Run the Task 3 command plus `-only-testing:DockBarHeroTests/ClassActionVictoryTests` using `.build/PowerStrikeRed`. Expected: Power Strike is rejected or has no effect.

- [ ] **Step 3: Implement Power Strike in `AbilityResolver`**

Use `ProgressionConfiguration.standard.applying(.init(numerator: 25_000, denominator: 10_000), to: Int64(effectiveAttack), rounding: .down)`, validate `Int` conversion, subtract enemy defense with overflow checks, clamp actual damage to current health, update enemy health and `encounter.heroDamage`, set cooldown, and return `damageDealt` plus `enemyDefeated`.

- [ ] **Step 4: Extract one victory transaction in `GameSimulation`**

Move the code currently following a lethal automatic hero attack into:

```swift
private mutating func completeVictory(
    defeatedLevel: Int,
    into events: inout [GameEvent]
) throws {
    events.append(.victory(defeatedLevel: defeatedLevel))
    let reward = try rewardResolver.applyVictory(defeatedLevel: defeatedLevel, to: state, balance: balance)
    state = reward.state
    events.append(contentsOf: reward.events)
    state.party.heroes.indices.forEach {
        state.party.heroes[$0].classAction.guardActive = false
    }
    if defeatedLevel == 25, state.party.unlocks == .locked {
        state = try PartyUnlockResolver().beginSecondUnlock(afterDefeating: defeatedLevel, in: state)
        events.append(.partyUnlockPending(.boss25))
        damageMetrics.reset()
        return
    }
    state = try PartyUnlockResolver().addFinalHeroIfEarned(
        afterDefeating: defeatedLevel,
        in: state,
        balance: balance
    )
    let priorCampaign = state.campaign
    state = try encounterDirector.completeVictory(in: state, balance: balance)
    appendCampaignTransition(from: priorCampaign, into: &events)
    damageMetrics.reset()
}
```

Both automatic lethal attacks and lethal Power Strike call this helper. Record Power Strike actual damage in `DamageMetrics` at `simulationTime` before calling it.

- [ ] **Step 5: Run tests and verify GREEN**

Repeat Step 2 with `.build/PowerStrikeGreen`. Expected: all selected tests pass.

- [ ] **Step 6: Commit Power Strike**

```bash
git add DockBarHero/Game/AbilityResolver.swift DockBarHero/Game/CombatResolver.swift DockBarHero/Game/GameSimulation.swift DockBarHeroTests/AbilityResolverTests.swift DockBarHeroTests/GameSimulationTests.swift DockBarHeroTests/ClassActionVictoryTests.swift
git commit -m "feat: add dps power strike"
```

### Task 5: Mend Targeting and Healing

**Files:**
- Modify: `DockBarHero/Game/AbilityResolver.swift`
- Modify: `DockBarHeroTests/AbilityResolverTests.swift`
- Modify: `DockBarHeroTests/GameSimulationTests.swift`

**Interfaces:**
- Produces: deterministic lowest-health-ratio target selection and `.mended(casterSlot:targetSlot:amount:)`.

- [ ] **Step 1: Write failing targeting tests**

```swift
func testMendTargetsLowestLivingHealthRatioWithSlotTieBreak() throws {
    var state = try partyFixture(classes: [.healer, .tank, .dps])
    state.party.heroes[0].combat.currentHealth = 50 // 50/100
    state.party.heroes[1].combat.currentHealth = 100 // 50/100 after fixture max 200
    state.party.heroes[2].combat.currentHealth = 0
    var simulation = GameSimulation(state: state)
    XCTAssertEqual(try simulation.apply(.castAction(heroSlot: 0, actionID: .mend)), [
        .classActionCast(heroSlot: 0, actionID: .mend),
        .mended(casterSlot: 0, targetSlot: 0, amount: 35),
    ])
}

func testMendRejectsFullHealthPartyWithoutCooldown() throws {
    var simulation = GameSimulation(state: try fullHealthHealerFixture())
    let before = simulation.state
    XCTAssertEqual(try simulation.apply(.castAction(heroSlot: 0, actionID: .mend)), [
        .classActionRejected(heroSlot: 0, actionID: .mend, reason: .noValidTarget)
    ])
    XCTAssertEqual(simulation.state, before)
}
```

Also test downed exclusion, clamp to missing health, at-least-one healing, cross-product overflow rollback, and cooldown assignment.

- [ ] **Step 2: Run tests and verify RED**

Run AbilityResolver and GameSimulation suites with `.build/MendRed`. Expected: Mend has no implementation.

- [ ] **Step 3: Implement checked ratio selection and healing**

Filter living heroes with missing health. Compare `lhs.currentHealth * rhs.maxHealth` and `rhs.currentHealth * lhs.maxHealth` using `multipliedReportingOverflow`; on equality choose lower slot. Calculate `floor(maxHealth * 3_500 / 10_000)`, clamp between one and missing health, update only the target, set the caster's 10-second cooldown, and emit cast plus Mend events.

- [ ] **Step 4: Run tests and verify GREEN**

Repeat Step 2 with `.build/MendGreen`. Expected: all selected tests pass.

- [ ] **Step 5: Commit Mend**

```bash
git add DockBarHero/Game/AbilityResolver.swift DockBarHeroTests/AbilityResolverTests.swift DockBarHeroTests/GameSimulationTests.swift
git commit -m "feat: add healer mend action"
```

### Task 6: Management Class Actions Page

**Files:**
- Create: `DockBarHero/App/ClassActionsView.swift`
- Modify: `DockBarHero/App/ManagementRootView.swift`
- Modify: `DockBarHero/App/ManagementSupport.swift`
- Modify: `DockBarHeroTests/ManagementViewTests.swift`
- Create: `DockBarHeroTests/ClassActionsViewTests.swift`

**Interfaces:**
- Consumes: `GameIntent.castAction`, definitions, and action state from Tasks 1-5.
- Produces: `ClassActionCard` pure presentation model and SwiftUI cast controls.

- [ ] **Step 1: Write failing pure presentation tests**

```swift
func testCardsRemainInPartyOrderAndExposeCooldownReason() throws {
    var state = try partyFixture(classes: [.dps, .healer])
    state.party.heroes[0].classAction.cooldownRemaining = .seconds(2)!
    let cards = ClassActionCard.cards(for: state)
    XCTAssertEqual(cards.map(\.title), ["Power Strike", "Mend"])
    XCTAssertEqual(cards[0].disabledReason, "Ready in 2.0s")
    XCTAssertNil(cards[1].disabledReason)
}

func testMendCardExplainsNoValidTarget() throws {
    let state = try fullHealthHealerFixture()
    XCTAssertEqual(ClassActionCard.cards(for: state)[0].disabledReason, "Everyone is at full health")
}
```

- [ ] **Step 2: Run tests and verify RED**

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/ClassActionsViewRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/ClassActionsViewTests -only-testing:DockBarHeroTests/ManagementViewTests
```

Expected: `ClassActionCard` and `ClassActionsView` do not exist.

- [ ] **Step 3: Add pure card mapping and formatting**

```swift
struct ClassActionCard: Identifiable, Equatable {
    let id: Int
    let actionID: ClassActionID
    let heroLabel: String
    let title: String
    let effect: String
    let cooldownLabel: String
    let disabledReason: String?

    static func cards(for state: GameState) -> [ClassActionCard]
}

extension ManagementIntent {
    static func cast(heroSlot: Int, actionID: ClassActionID) -> GameIntent {
        .castAction(heroSlot: heroSlot, actionID: actionID)
    }
}
```

Use exact copy: Guard “Intercept the next enemy attack and take 50% reduced damage.”; Power Strike “Strike immediately for 250% attack.”; Mend “Heal the lowest-health living hero for 35% max health.”

- [ ] **Step 4: Replace the Abilities placeholder**

Render a `ScrollView` of cards and `Button("Cast")` controls. Disable using `disabledReason != nil`, show the reason directly below the button, and set `.accessibilityIdentifier("class-action-\(slot)-\(actionID.rawValue)")`. An encounter phase other than `.active` maps to “Encounter inactive”; the overlay animation preference is not consulted. Submit through `model.send(ManagementIntent.cast(...))`.

- [ ] **Step 5: Run tests and verify GREEN**

Repeat Step 2 with `.build/ClassActionsViewGreen`. Expected: selected tests pass.

- [ ] **Step 6: Commit management presentation**

```bash
git add DockBarHero/App/ClassActionsView.swift DockBarHero/App/ManagementRootView.swift DockBarHero/App/ManagementSupport.swift DockBarHeroTests/ClassActionsViewTests.swift DockBarHeroTests/ManagementViewTests.swift
git commit -m "feat: add class action management controls"
```

### Task 7: Interactive-Only Rail Actions

**Files:**
- Modify: `DockBarHero/Rendering/PrototypeScene.swift`
- Modify: `DockBarHero/Rendering/PrototypeSceneHost.swift`
- Modify: `DockBarHero/App/AppModel.swift`
- Modify: `DockBarHeroTests/PrototypeSceneHostTests.swift`
- Modify: `DockBarHeroTests/AppModelTests.swift`

**Interfaces:**
- Consumes: action state, action events, and `AppModel.send(_ intent:)`.
- Produces: `SceneControlling.onClassAction`, visible cooldown nodes, and interactive-only hit handling.

- [ ] **Step 1: Write failing rail node and input tests**

```swift
func testRailCreatesActionNodeForEveryHeroAndShowsCooldown() throws {
    let host = try PrototypeSceneHost()
    host.render(.active(try threeHeroActionPresentation()))
    XCTAssertEqual((host.scene.childNode(withName: "//heroAction") as? SKLabelNode)?.text, "PS 6.0")
    XCTAssertNotNil(host.scene.childNode(withName: "//hero-1Action"))
    XCTAssertNotNil(host.scene.childNode(withName: "//hero-2Action"))
}

func testPassiveRailDoesNotEmitCastButInteractiveRailDoes() throws {
    let host = try PrototypeSceneHost()
    var casts: [(Int, ClassActionID)] = []
    host.onClassAction = { casts.append(($0, $1)) }
    host.setInteractive(false)
    host.scene.activateClassActionForTesting(slot: 0)
    XCTAssertTrue(casts.isEmpty)
    host.setInteractive(true)
    host.scene.activateClassActionForTesting(slot: 0)
    XCTAssertEqual(casts.map(\.0), [0])
}
```

- [ ] **Step 2: Run tests and verify RED**

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/ClassActionRailRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/PrototypeSceneHostTests -only-testing:DockBarHeroTests/AppModelTests
```

Expected: action nodes and callback are missing.

- [ ] **Step 3: Extend the scene callback boundary**

```swift
@MainActor
protocol SceneControlling: AnyObject {
    var onClassAction: ((Int, ClassActionID) -> Void)? { get set }
    var view: SKView { get }
    func setAnimating(_ isAnimating: Bool)
    func setInteractive(_ isInteractive: Bool)
    func render(_ presentation: GamePresentation)
    func render(_ run: RunPresentation)
    func handle(_ events: [GameEvent])
}
```

`PrototypeSceneHost` forwards the closure to `PrototypeScene`. `AppModel.connect` installs a callback that sends `.castAction(heroSlot:actionID:)`; reconnect tests prove the callback is installed before interaction.

- [ ] **Step 4: Render and hit-test compact action nodes**

Create a stable label or sprite per hero named `<heroPrefix>Action`, positioned below its level label without overlapping health bars or the shared DPS label. Render abbreviations `G`, `PS`, and `M` plus one-decimal remaining seconds. Set alpha to indicate unavailable state. In `mouseDown`, accept action-node hits only while `isUserInteractionEnabled`; actor clicks keep their existing cosmetic behavior.

- [ ] **Step 5: Map events to exact visual feedback**

Handle `.powerStrike`, `.mended`, `.guardActivated`, `.guardIntercepted`, `.classActionRejected`, and `.classActionReady` with exact slot nodes. Use short SKActions/labels only; do not update gameplay state from animation completion.

- [ ] **Step 6: Run tests and verify GREEN**

Repeat Step 2 with `.build/ClassActionRailGreen`. Expected: selected tests pass and existing overlay interaction tests remain green.

- [ ] **Step 7: Commit rail actions**

```bash
git add DockBarHero/Rendering/PrototypeScene.swift DockBarHero/Rendering/PrototypeSceneHost.swift DockBarHero/App/AppModel.swift DockBarHeroTests/PrototypeSceneHostTests.swift DockBarHeroTests/AppModelTests.swift
git commit -m "feat: add interactive rail class actions"
```

### Task 8: Integrated Regression, Save Isolation, and Live QA

**Files:**
- Create: `DockBarHeroTests/ClassActionsIntegrationTests.swift`
- Create: `docs/qa/review-packets/class-actions.md`
- Modify: `PROJECT.md` only after verification.

**Interfaces:**
- Verifies: complete class-action behavior across simulation, persistence, UI, overlay, and relaunch.

- [ ] **Step 1: Add integrated transaction tests**

Create tests that compare partitioned cooldown advances, cast each action in a three-hero party, save/reload partial cooldown plus active Guard, kill Boss 25 and Boss 100 with Power Strike, preserve queued destination and unlock precedence, and inject overflow/failing transition fixtures to prove whole-candidate rollback.

```swift
func testThreeHeroActionsSaveReloadAndRemainPartitionInvariant() throws {
    var direct = GameSimulation(state: try threeHeroActionFixture())
    var partitioned = direct
    _ = try direct.apply(.castAction(heroSlot: 0, actionID: .guardAction))
    _ = try direct.apply(.castAction(heroSlot: 1, actionID: .powerStrike))
    _ = try direct.apply(.castAction(heroSlot: 2, actionID: .mend))
    partitioned = direct
    _ = try direct.advance(by: .seconds(2)!)
    _ = try partitioned.advance(by: .seconds(1)!)
    _ = try partitioned.advance(by: .seconds(1)!)
    XCTAssertEqual(direct.state, partitioned.state)
    let data = try SaveCodec().encode(state: direct.state, savedAt: Date(timeIntervalSince1970: 1))
    XCTAssertEqual(try SaveCodec().decode(data).state, direct.state)
}
```

- [ ] **Step 2: Run the focused milestone gate**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/ClassActionsFocused CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/ClassActionConfigurationTests -only-testing:DockBarHeroTests/ClassActionCooldownTests -only-testing:DockBarHeroTests/AbilityResolverTests -only-testing:DockBarHeroTests/ClassActionVictoryTests -only-testing:DockBarHeroTests/ClassActionsIntegrationTests -only-testing:DockBarHeroTests/SaveDocumentTests -only-testing:DockBarHeroTests/GameSessionTests -only-testing:DockBarHeroTests/ClassActionsViewTests -only-testing:DockBarHeroTests/PrototypeSceneHostTests -only-testing:DockBarHeroTests/AppModelTests
```

Expected: all selected tests pass with zero failures.

- [ ] **Step 3: Archive saves and run clean live QA**

Quit DockBarHero, archive only gameplay save files to a timestamped `class-actions-pre-qa-YYYYMMDD-HHMMSS` directory with SHA-256 hashes, preserve settings, and start a clean schema-v2 run. Perform all UI actions without owner input. Cast all three actions from management, cast from the interactive rail, verify passive mode rejects clicks, observe Guard interception, Power Strike DPS/damage, Mend targeting, cooldown carryover, and relaunch persistence.

- [ ] **Step 4: Run final machine gates**

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/ClassActionsFull CODE_SIGNING_ALLOWED=NO
xcodebuild clean build -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/ClassActionsBuild CODE_SIGNING_ALLOWED=NO
python3 /Users/n3kr0/.codex/skills/maintaining-project-context/scripts/context_guard.py check --root .
./script/build_and_run.sh --verify
git diff --check
```

Expected: full suite succeeds with zero failures, clean/build succeed, context is valid, exact feature app launches, and diff check is clean.

- [ ] **Step 5: Record verified facts and commit**

Write exact test counts, archive hashes, build identity, live checked/unchecked facts, and limitations to `docs/qa/review-packets/class-actions.md`. Update existing `PROJECT.md` headings with only fresh verified state and keep it below 150 lines.

```bash
git add DockBarHero DockBarHeroTests PROJECT.md docs/qa/review-packets/class-actions.md
git commit -m "docs: verify class actions milestone"
```

- [ ] **Step 6: Re-run report guards and preserve the branch**

```bash
python3 /Users/n3kr0/.codex/skills/maintaining-project-context/scripts/context_guard.py check --root .
git diff --check
git status --short --branch
git log --oneline --decorate feature/heroes-and-party..HEAD
```

Expected: clean named feature branch with coherent commits. Push or merge only under explicit owner instruction; do not start Loot Expansion implementation inside this milestone.
