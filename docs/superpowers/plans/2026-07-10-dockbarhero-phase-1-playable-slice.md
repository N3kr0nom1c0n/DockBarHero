# DockBarHero Phase 1 Playable Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a deterministic one-hero idle-combat loop with live DPS, guaranteed weapon and armor progression, durable local saves, and a native management window without regressing the Phase 0 rail.

**Architecture:** Pure Swift gameplay values and `GameSimulation` own all combat, loot, equipment, and DPS rules. A monotonic `SimulationDriver` advances that state independently from SpriteKit, `GameSession` coordinates saves and autosaves, and the existing `AppModel` publishes presentation state to the rail and SwiftUI management window. AppKit remains limited to the established overlay and lifecycle bridges.

**Tech Stack:** Swift 6.3.2, SwiftUI, AppKit, SpriteKit, Foundation, OSLog, XCTest, Xcode 26.5, XcodeGen 2.45.4 as a development-only generator.

**Approved Design:** [DockBarHero Phase 1 Playable Slice Design](../specs/2026-07-10-dockbarhero-phase-1-playable-slice-design.md)

## Global Constraints

- Target the current Apple M5 Max MacBook Pro running macOS 26.5.1 on `arm64`.
- Keep the macOS deployment target at 26.0 and `SWIFT_STRICT_CONCURRENCY` at `complete`.
- Use only Apple frameworks and no third-party runtime dependency.
- Preserve the Phase 0 panel, placement, passive-input default, fullscreen suppression, no-focus-theft behavior, and 30 FPS render cap.
- Gameplay advances from elapsed active time, never from rendered frames.
- Use `SimulationDuration` signed `Int64` nanoseconds for every gameplay-time value; clamp one integer-monotonic driver callback to at most 1,000,000,000 nanoseconds and discard excess as suspension time.
- Use one hero, automatic basic attacks, hero-first exact-timestamp ties, and `max(1, attack - defense)` damage.
- Reject attack intervals below 1,000,000 nanoseconds, elapsed values outside `0...10_000_000_000` nanoseconds, and checked timing overflow before state mutation. Retry the same enemy after a 3,000,000,000-nanosecond revive delay and lose no progression on defeat.
- Grant exactly one deterministic item per victory, alternating weapon then armor.
- Keep all owned items in unlimited inventory; equipment slots reference item identifiers.
- Enable auto-equip by default and equip only strict primary-stat upgrades from new drops.
- Persist schema version 1 through atomic primary/backup files; do not calculate offline progress.
- Save after victories, equipment changes, auto-equip changes, every 30 seconds, and clean quit.
- Expose rolling five-second DPS on the rail and rolling plus encounter-average DPS in the management window.
- Defer abilities, accessories, salvage, item affixes, inventory limits, additional heroes, bosses, offline progress, Steamworks, and online systems.
- Follow test-first development. Every production behavior begins with a focused failing test.
- Run the focused test class and complete test suite before each task commit.
- Use fresh `gpt-5.6-luna` implementers for bounded tasks, `gpt-5.6-terra` for slice integration reviews, and `gpt-5.6-sol` only for final whole-branch review or architecture-sensitive escalation.
- A slice gate gets at most two focused repair cycles. Preserve the feature branch and stop if the same gate still fails.
- Work in an isolated worktree on branch `feature/phase-1-playable-slice`. Do not merge, rebase, force-push, or modify `main` during execution.
- Push the feature branch only after the final gate passes.

## Standard Commands

Regenerate the committed Xcode project after adding or removing files:

```bash
xcodegen generate
```

Run one focused test class:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/DerivedData -only-testing:DockBarHeroTests/TEST_CLASS test CODE_SIGNING_ALLOWED=NO
```

Run the complete test suite:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/DerivedData test CODE_SIGNING_ALLOWED=NO
```

Every test command must exit 0. A focused red step must fail for the stated missing behavior, not for an unrelated project-generation or compiler problem.

## File Structure

```text
DockBarHero/
  App/
    AppDelegate.swift                 # Live dependency construction and bounded clean quit
    AppModel.swift                    # Overlay plus gameplay presentation coordination
    DockBarHeroApp.swift              # MenuBarExtra and management Window scene
    ManagementView.swift              # Native stats, equipment, inventory, and save UI
    MenuBarContent.swift              # Rail commands and management-window command
  Game/
    ActionPolicy.swift                # Future-safe basic-action selection boundary
    BalanceConfiguration.swift        # Initial stats and deterministic scaling formulas
    DamageMetrics.swift               # Rolling and encounter-average DPS calculations
    GameModels.swift                  # Codable domain values, intents, events, presentation
    GameSimulation.swift              # Chronological combat and encounter transitions
    LootSystem.swift                  # Deterministic drops and equipment decisions
    SimulationDriver.swift            # Monotonic active-time loop and 4 Hz publication
    GameSession.swift                 # Load/start, event saves, autosave, and flush
  Persistence/
    SaveDocument.swift                # Version envelope, codec, and domain validation
    SaveStore.swift                   # Application Support URLs, atomic write, recovery
    SaveCoordinator.swift             # Serialized coalescing and save status
  Rendering/
    PrototypeScene.swift              # Snapshot rendering and domain-event reactions
    PrototypeSceneHost.swift          # Scene lifecycle plus presentation forwarding
  Support/
    AppLog.swift                      # Adds gameplay and persistence categories
DockBarHeroTests/
  BalanceConfigurationTests.swift
  DamageMetricsTests.swift
  GameSessionTests.swift
  GameSimulationTests.swift
  LootSystemTests.swift
  ManagementViewTests.swift
  SaveCoordinatorTests.swift
  SaveDocumentTests.swift
  SaveStoreTests.swift
  SimulationDriverTests.swift
  AppModelTests.swift
  PrototypeSceneHostTests.swift
docs/qa/phase-1-checklist.md
project.yml
DockBarHero.xcodeproj/
```

---

### Task 1: Domain Values And Balance Configuration

**Owner/model:** Fresh `gpt-5.6-luna` implementer.

**Files:**

- Create: `DockBarHero/Game/GameModels.swift`
- Create: `DockBarHero/Game/BalanceConfiguration.swift`
- Create: `DockBarHeroTests/BalanceConfigurationTests.swift`
- Generate: `DockBarHero.xcodeproj/`

**Interfaces:**

- Produces: `CombatantID`, `EquipmentSlot`, `ItemID`, `Item`, `EquipmentState`, `CombatantState`, `EncounterPhase`, `EncounterState`, `GameState`, `GameIntent`, `GameEvent`, and `GamePresentation`.
- Produces: `BalanceConfiguration.standard`, `enemy(level:) -> CombatantState?`, and `itemPrimaryStat(level:slot:) -> Int?`; scaling failures are represented as `nil` rather than trapping or converting an out-of-range floating value.
- Consumes: no new Phase 1 interface.

- [ ] **Step 1: Write the failing balance and new-game tests**

Create `DockBarHeroTests/BalanceConfigurationTests.swift` with tests that compile against the exact contracts below:

```swift
import XCTest
@testable import DockBarHero

final class BalanceConfigurationTests: XCTestCase {
    func testStandardNewGameStartsAtEnemyOneWithAutoEquip() {
        let state = GameState.newGame(balance: .standard)

        XCTAssertEqual(state.hero.maxHealth, 100)
        XCTAssertEqual(state.hero.baseAttack, 10)
        XCTAssertEqual(state.enemy.maxHealth, 30)
        XCTAssertEqual(state.encounter.enemyLevel, 1)
        XCTAssertEqual(state.encounter.phase, .active)
        XCTAssertTrue(state.autoEquipEnabled)
        XCTAssertTrue(state.inventory.isEmpty)
        XCTAssertEqual(state.lootSequence, 0)
    }

    func testStandardScalingMatchesApprovedFormulas() {
        let balance = BalanceConfiguration.standard

        XCTAssertEqual(balance.enemy(level: 1)?.maxHealth, 30)
        XCTAssertEqual(balance.enemy(level: 2)?.maxHealth, 32)
        XCTAssertEqual(balance.itemPrimaryStat(level: 1, slot: .weapon), 1)
        XCTAssertEqual(balance.itemPrimaryStat(level: 2, slot: .armor), 1)
    }
}
```

- [ ] **Step 2: Regenerate and verify the focused test fails**

Run the standard focused command with `TEST_CLASS=BalanceConfigurationTests`.

Expected: FAIL because `GameState` and `BalanceConfiguration` do not exist.

- [ ] **Step 3: Implement the exact domain value shape**

Create `GameModels.swift` with these public-to-the-target declarations and synthesized `Codable`, `Equatable`, and `Sendable` conformances:

```swift
import Foundation

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
```

Create `BalanceConfiguration.swift` with immutable standard values, checked formula helpers, `enemy(level:) -> CombatantState?`, `itemPrimaryStat(level:slot:) -> Int?`, and `GameState.newGame(balance:)`. Both helpers return `nil` for a level below one, invalid inputs, nonfinite scaling, or a result outside `Int` range. Do not use `precondition`, force unwrap, or direct `Int` conversion of an unchecked floating value. Apply the approved rates only after confirming the rounded result is finite and representable:

```swift
enemyHealth = checkedRounded(30.0 * pow(1.06, Double(level - 1)))
enemyAttack = checkedRounded(3.0 * pow(1.04, Double(level - 1)))
weaponBonus = checkedCeiling(10.0 * (pow(1.06, Double(level)) - 1.0))
armorBonus = checkedCeiling(3.0 * (pow(1.04, Double(level)) - 1.0))
```

`newGame` must create full-health combatants, initialize each attack countdown to its full interval, set active encounter metrics to zero, enable auto-equip, and start with empty inventory/equipment and loot sequence zero.

- [ ] **Step 4: Run focused and full tests**

Run `BalanceConfigurationTests`, then the complete test suite.

Expected: PASS, including all 37 Phase 0 tests.

- [ ] **Step 5: Commit the domain foundation**

```bash
git add DockBarHero/Game/GameModels.swift DockBarHero/Game/BalanceConfiguration.swift DockBarHeroTests/BalanceConfigurationTests.swift DockBarHero.xcodeproj
git commit -m "feat: add gameplay domain foundation"
```

### Task 2: Deterministic Combat And Encounter Transitions

**Owner/model:** Fresh `gpt-5.6-luna` implementer.

**Files:**

- Create: `DockBarHero/Game/SimulationDuration.swift`
- Create: `DockBarHero/Game/ActionPolicy.swift`
- Create: `DockBarHero/Game/GameSimulation.swift`
- Create: `DockBarHeroTests/SimulationDurationTests.swift`
- Create: `DockBarHeroTests/GameSimulationTests.swift`

**Interfaces:**

- Consumes: `GameState`, `GameEvent`, and `BalanceConfiguration` from Task 1.
- Produces: `CombatAction`, `ActionPolicy`, `BasicAttackPolicy`, `SimulationError`, and `GameSimulation.advance(by:)`.
- Produces: `GameSimulation.state`, which later persistence and presentation tasks consume.

- [ ] **Step 1: Write focused failing simulation tests**

Create `SimulationDuration` tests for checked construction, ordering, Codable round-trip, and overflow. Create simulation tests using `.milliseconds(...)`, `.seconds(...)`, or exact nanoseconds for independent schedules, exact chunk invariance, hero-first ties, victory, defeat, and revive. Include a 999,999,999-nanosecond no-early-fire boundary, a one-nanosecond enemy-before-hero ordering boundary, rejected 999,999-nanosecond interval and out-of-range elapsed inputs, and rejected checked overflow before mutation.

```swift
func testIndependentAttackSchedulesAdvanceChronologically() throws {
    var simulation = GameSimulation()

    let events = try simulation.advance(by: .milliseconds(2_100)!)

    XCTAssertEqual(simulation.state.enemy.currentHealth, 10)
    XCTAssertEqual(simulation.state.hero.currentHealth, 97)
    XCTAssertEqual(events.filter(\.isAttack).count, 3)
}

func testThreeSecondVictoryTieResolvesHeroBeforeEnemy() throws {
    var simulation = GameSimulation()

    let events = try simulation.advance(by: .seconds(3)!)

    XCTAssertTrue(events.contains(.victory(defeatedLevel: 1)))
    XCTAssertEqual(simulation.state.encounter.enemyLevel, 2)
    XCTAssertEqual(simulation.state.hero.currentHealth, 100)
}
```

Add an internal test-only computed property on `GameEvent` in the test file:

```swift
private extension GameEvent {
    var isAttack: Bool {
        if case .attack = self { return true }
        return false
    }
}
```

For chunk-size invariance, compare complete `GameState` equality and events after 2,100 milliseconds once against 700 milliseconds three times, and after 1,200,000 nanoseconds once against 400,000 nanoseconds three times. For defeat, inject a valid state with hero health 1 and both attack countdowns one second, confirm `.defeat`, advance 2,900 milliseconds with no revive, then 100 milliseconds and confirm `.revived` with the same enemy level and both combatants full.

- [ ] **Step 2: Verify the focused test fails for missing simulation types**

Run `GameSimulationTests`.

Expected: FAIL because `GameSimulation` and action-policy types do not exist.

- [ ] **Step 3: Implement action selection and chronological advancement**

Create `ActionPolicy.swift`:

```swift
enum CombatAction: Equatable, Sendable { case basicAttack }

protocol ActionPolicy: Sendable {
    func action(for combatant: CombatantID, in state: GameState) -> CombatAction
}

struct BasicAttackPolicy: ActionPolicy {
    func action(for combatant: CombatantID, in state: GameState) -> CombatAction {
        .basicAttack
    }
}
```

Create `GameSimulation.swift` as a value type with this interface:

```swift
enum SimulationError: Error, Equatable {
    case invalidElapsed
    case invalidTimer
    case invalidState
    case invalidBalance
    case arithmeticOverflow
}

struct GameSimulation {
    private(set) var state: GameState
    let balance: BalanceConfiguration
    private let policy: any ActionPolicy

    init(balance: BalanceConfiguration = .standard, policy: any ActionPolicy = BasicAttackPolicy()) {
        self.state = .newGame(balance: balance)
        self.balance = balance
        self.policy = policy
    }

    init(state: GameState, balance: BalanceConfiguration = .standard, policy: any ActionPolicy = BasicAttackPolicy()) {
        self.state = state
        self.balance = balance
        self.policy = policy
    }

    mutating func advance(by elapsed: SimulationDuration) throws -> [GameEvent]
}
```

`advance(by:)` must reject elapsed values outside `0...10_000_000_000` nanoseconds. While active, repeatedly advance by the exact minimum of remaining elapsed time and both attack countdowns, then resolve ready actors. Resolve the hero first when both are ready. Reset an actor's countdown to its full interval after acting. Stop enemy retaliation if the hero's same-timestamp attack wins. Validate intervals at or above one million nanoseconds and nonnegative countdowns/revive values; active state requires both current health values above zero and zero revive remaining, while reviving state requires a dead hero, live enemy, and revive remaining in `0...balance.reviveDelay`. Return `invalidState`, `invalidBalance`, or `arithmeticOverflow` as applicable and use checked integer arithmetic on a candidate copy so errors leave caller-visible state unchanged.

Use these exact transition operations:

```swift
private mutating func beginNextEncounter() throws {
    let (enemyLevel, overflow) = state.encounter.enemyLevel.addingReportingOverflow(1)
    guard !overflow else { throw SimulationError.arithmeticOverflow }
    guard let enemy = balance.enemy(level: enemyLevel) else {
        throw SimulationError.invalidBalance
    }
    state.encounter.enemyLevel = enemyLevel
    state.hero.currentHealth = state.hero.maxHealth
    state.enemy = enemy
    resetEncounterMetrics(phase: .active, reviveRemaining: .zero)
}

private mutating func beginRevive() throws {
    guard balance.reviveDelay >= .zero, balance.reviveDelay <= .maximumAdvance else {
        throw SimulationError.invalidBalance
    }
    state.encounter.phase = .reviving
    state.encounter.reviveRemaining = balance.reviveDelay
}

private mutating func finishRevive() throws {
    guard let enemy = balance.enemy(level: state.encounter.enemyLevel) else {
        throw SimulationError.invalidBalance
    }
    state.hero.currentHealth = state.hero.maxHealth
    state.enemy = enemy
    resetEncounterMetrics(phase: .active, reviveRemaining: .zero)
}
```

Compute effective attack/defense by resolving equipment IDs against `state.inventory`, adding weapon primary stat to hero attack and armor primary stat to hero defense. Damage is `max(1, attack - defense)`. Clamp health at zero. Revive time changes only `reviveRemaining`; it never increments `activeElapsed`.

- [ ] **Step 4: Run focused and full tests**

Run `GameSimulationTests`, then the complete suite.

Expected: PASS with identical state and event ordering for equivalent elapsed chunks.

- [ ] **Step 5: Commit deterministic combat**

```bash
git add DockBarHero/Game/ActionPolicy.swift DockBarHero/Game/GameSimulation.swift DockBarHeroTests/GameSimulationTests.swift DockBarHero.xcodeproj
git commit -m "feat: add deterministic combat simulation"
```

### Task 3: Rolling And Encounter DPS

**Owner/model:** Fresh `gpt-5.6-luna` implementer.

**Files:**

- Create: `DockBarHero/Game/DamageMetrics.swift`
- Modify: `DockBarHero/Game/GameSimulation.swift`
- Create: `DockBarHeroTests/DamageMetricsTests.swift`
- Modify: `DockBarHeroTests/GameSimulationTests.swift`

**Interfaces:**

- Consumes: hero attack events and encounter elapsed time from Task 2.
- Produces: `DamageMetrics.record(damage:at:)`, `rollingDPS(at:encounterElapsed:)`, `encounterAverage(totalDamage:elapsed:)`, and `reset()`.
- Produces: `GameSimulation.presentation`, consumed by the driver and UI.

- [ ] **Step 1: Write failing DPS tests**

Create tests for startup zero, partial-window denominator, five-second eviction, encounter average, and reset. All metric timestamps and elapsed inputs use `SimulationDuration`; only the derived DPS result is `Double`.

```swift
func testRollingDPSUsesPartialWindowThenEvictsOldDamage() {
    var metrics = DamageMetrics()
    metrics.record(damage: 10, at: .seconds(1)!)
    metrics.record(damage: 20, at: .seconds(4)!)

    XCTAssertEqual(metrics.rollingDPS(at: .seconds(4)!, encounterElapsed: .seconds(4)!), 7.5, accuracy: 0.001)
    XCTAssertEqual(metrics.rollingDPS(at: .milliseconds(6_100)!, encounterElapsed: .milliseconds(6_100)!), 4.0, accuracy: 0.001)
}

func testEncounterAverageExcludesZeroDuration() {
    XCTAssertEqual(DamageMetrics.encounterAverage(totalDamage: 30, elapsed: .zero), 0)
    XCTAssertEqual(DamageMetrics.encounterAverage(totalDamage: 30, elapsed: .seconds(3)!), 10)
}
```

Add simulation assertions that presentation DPS becomes nonzero after an attack and resets on victory and defeat.

- [ ] **Step 2: Verify focused tests fail**

Run `DamageMetricsTests` and `GameSimulationTests` separately.

Expected: FAIL because `DamageMetrics` and `GameSimulation.presentation` do not exist.

- [ ] **Step 3: Implement metrics and simulation integration**

Create `DamageMetrics` with a private ordered sample array containing `SimulationDuration` timestamps and integer damage. `rollingDPS` is nonmutating: it sums only samples whose timestamp is greater than `now - 5_000_000_000` nanoseconds, divides by the lesser of 5,000,000,000 nanoseconds and encounter elapsed time, and returns zero when that denominator is zero. Convert that exact duration to `Double` only to derive the presentation DPS. `record` may prune expired samples to keep storage bounded, and `reset` removes every sample.

Add to `GameSimulation`:

```swift
private var simulationTime: SimulationDuration = .zero
private var damageMetrics = DamageMetrics()

var presentation: GamePresentation {
    GamePresentation(
        state: state,
        heroAttack: effectiveAttack(for: .hero),
        heroDefense: effectiveDefense(for: .hero),
        rollingDPS: damageMetrics.rollingDPS(
            at: simulationTime,
            encounterElapsed: state.encounter.activeElapsed
        ),
        encounterDPS: DamageMetrics.encounterAverage(
            totalDamage: state.encounter.heroDamage,
            elapsed: state.encounter.activeElapsed
        )
    )
}
```

Advance `simulationTime` by active and revive steps, record actual hero damage after health clamping, increment `encounter.heroDamage`, and reset metrics during victory, defeat, and completed revive transitions. A newly initialized or restored simulation begins with an empty rolling window.

- [ ] **Step 4: Run focused and full tests**

Run `DamageMetricsTests`, `GameSimulationTests`, then the complete suite.

Expected: PASS.

- [ ] **Step 5: Commit DPS metrics**

```bash
git add DockBarHero/Game/DamageMetrics.swift DockBarHero/Game/GameSimulation.swift DockBarHeroTests/DamageMetricsTests.swift DockBarHeroTests/GameSimulationTests.swift DockBarHero.xcodeproj
git commit -m "feat: add real-time damage metrics"
```

### Task 4: Monotonic Simulation Driver

**Owner/model:** Fresh `gpt-5.6-luna` implementer.

**Files:**

- Create: `DockBarHero/Game/SimulationDriver.swift`
- Create: `DockBarHeroTests/SimulationDriverTests.swift`

**Interfaces:**

- Consumes: `GameSimulation.advance(by:)`, `presentation`, events, state, and intents.
- Produces: `SimulationDriving`, `SimulationDriver.start()`, `stop()`, `step(at:)`, `replaceState(_:)`, `currentState`, `onPresentation`, and `onEvents`.
- Later tasks add intent forwarding without changing timing contracts.

- [ ] **Step 1: Write failing driver tests**

Create `@MainActor` tests with an injected integer monotonic-nanosecond closure. Cover initial publication, one-second suspension cap, 250-millisecond publication throttle, immediate event delivery, and idempotent start/stop. Use explicit time steps:

```swift
func testLargeClockGapAdvancesOnlyOneSecond() throws {
    var now: UInt64 = 10_000_000_000
    let driver = SimulationDriver(now: { now })
    driver.start(startLoop: false)

    now = 20_000_000_000
    driver.step(at: now)

    XCTAssertEqual(driver.currentState.enemy.currentHealth, 20)
}
```

The enemy loses exactly one 10-point hero attack because the ten-second callback gap is clamped to one simulated second.

- [ ] **Step 2: Verify the focused test fails**

Run `SimulationDriverTests`.

Expected: FAIL because `SimulationDriver` does not exist.

- [ ] **Step 3: Implement the driver**

Define this MainActor protocol and concrete surface:

```swift
@MainActor
protocol SimulationDriving: AnyObject {
    var onPresentation: ((GamePresentation) -> Void)? { get set }
    var onEvents: (([GameEvent]) -> Void)? { get set }
    var currentState: GameState { get }
    func start()
    func stop()
    func replaceState(_ state: GameState)
}
```

`SimulationDriver` owns a `GameSimulation`, stores `lastTick` and `lastPublish` as monotonic nanoseconds, and accepts `now: @escaping @MainActor () -> UInt64`, defaulting to `DispatchTime.now().uptimeNanoseconds`. `start(startLoop:)` is internal for tests; production `start()` passes `true` and creates one MainActor `Task` that sleeps 100 milliseconds between `step(at:)` calls.

In `step(at:)`:

```swift
guard now >= lastTick else { return }
let rawDelta = now - lastTick
let elapsed = SimulationDuration.nanoseconds(Int64(min(rawDelta, 1_000_000_000)))
let events = try simulation.advance(by: elapsed)
if !events.isEmpty { onEvents?(events) }
if now - lastPublish >= 250_000_000 {
    lastPublish = now
    onPresentation?(simulation.presentation)
}
lastTick = now
```

`replaceState` creates a fresh simulation from the restored state, clears transient rolling DPS, resets `lastTick` to the injected current time, and immediately publishes once. `stop` cancels the loop task and is idempotent.

- [ ] **Step 4: Run focused and full tests**

Run `SimulationDriverTests`, then the complete suite.

Expected: PASS.

- [ ] **Step 5: Run Combat Slice Gate A**

Run all Phase 1 combat classes, the complete suite, and this arm64 build:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/GateADerivedData CODE_SIGNING_ALLOWED=NO clean build
```

Dispatch one `gpt-5.6-terra` reviewer to compare Tasks 1-4 against Sections 5-7 and 12.1-12.2 of the approved design. Fix Critical and Important findings, rerun the same commands, and allow no more than two repair cycles.

- [ ] **Step 6: Commit the simulation driver**

```bash
git add DockBarHero/Game/SimulationDriver.swift DockBarHeroTests/SimulationDriverTests.swift DockBarHero.xcodeproj
git commit -m "feat: drive combat from monotonic time"
```

### Task 5: Deterministic Loot, Inventory, And Equipment

**Owner/model:** Fresh `gpt-5.6-luna` implementer.

**Files:**

- Create: `DockBarHero/Game/LootSystem.swift`
- Modify: `DockBarHero/Game/GameSimulation.swift`
- Modify: `DockBarHero/Game/SimulationDriver.swift`
- Create: `DockBarHeroTests/LootSystemTests.swift`
- Modify: `DockBarHeroTests/GameSimulationTests.swift`
- Modify: `DockBarHeroTests/SimulationDriverTests.swift`

**Interfaces:**

- Consumes: item, inventory, equipment, balance, victory, and driver contracts.
- Produces: `LootSystem.drop(defeatedLevel:state:)` and `GameSimulation.apply(_:)`.
- Extends: `SimulationDriving.send(_:)` for management-window intents.

- [ ] **Step 1: Write failing loot and equipment tests**

Cover guaranteed drops, weapon/armor alternation, deterministic IDs/stat values, strict auto-equip, tie rejection, disabled auto-equip, item preservation, manual equip, incompatible/missing IDs, and non-retroactive enabling of auto-equip.

Use this deterministic sequence assertion:

```swift
func testDropsAlternateSlotsAndUseStableSequenceIDs() {
    var state = GameState.newGame(balance: .standard)
    var loot = LootSystem(balance: .standard)

    let first = loot.drop(defeatedLevel: 1, state: &state)
    let second = loot.drop(defeatedLevel: 2, state: &state)

    XCTAssertEqual(first.id, ItemID(rawValue: 1))
    XCTAssertEqual(first.slot, .weapon)
    XCTAssertEqual(second.id, ItemID(rawValue: 2))
    XCTAssertEqual(second.slot, .armor)
    XCTAssertEqual(state.inventory, [first, second])
}
```

Add a simulation victory test asserting event order `.victory`, `.loot`, optional `.equipped`, and next encounter. Add driver tests proving `.setAutoEquip(false)` and `.equip(id)` forward to the simulation and publish immediately.

- [ ] **Step 2: Verify focused tests fail**

Run `LootSystemTests`, `GameSimulationTests`, and `SimulationDriverTests`.

Expected: FAIL because loot generation and intent application are absent.

- [ ] **Step 3: Implement loot and equipment rules**

`LootSystem.drop` must use current `state.lootSequence` before incrementing it, choose `.weapon` for even zero-based sequence and `.armor` for odd, assign `ItemID(rawValue: sequence + 1)`, request `balance.itemPrimaryStat(level:slot:)`, append the item once, and return it. A `nil` primary-stat result is `SimulationError.invalidBalance`; do not force unwrap it.

Add `GameIntentError: Error, Equatable` with `.itemNotFound` and `.slotMismatch`. Implement:

```swift
mutating func apply(_ intent: GameIntent) throws -> [GameEvent]
```

`.setAutoEquip` changes the preference and emits only when the value changes. `.equip(id)` resolves an owned item, sets its matching equipment reference, and emits `.equipped`. Enabling auto-equip does not scan old inventory; it affects subsequent drops.

During victory, generate one drop before incrementing enemy level. If auto-equip is enabled and the drop's primary stat is strictly greater than the equipped same-slot item's stat, update the reference and emit `.equipped`. Preserve every item in `state.inventory`.

Extend `SimulationDriving` with `func send(_ intent: GameIntent) throws`, publish resulting events immediately, and publish the updated presentation immediately after a successful intent.

- [ ] **Step 4: Run focused and full tests**

Run the three focused classes, then the complete suite.

Expected: PASS.

- [ ] **Step 5: Run Loot Slice Gate B**

Dispatch one `gpt-5.6-terra` reviewer to compare Task 5 against Sections 5.5, 6.3, 8.2, and 12.3 of the design. Require deterministic replay, no item loss, and no accessory/salvage work. Fix and rerun with the two-cycle limit.

- [ ] **Step 6: Commit loot and equipment**

```bash
git add DockBarHero/Game/LootSystem.swift DockBarHero/Game/GameSimulation.swift DockBarHero/Game/SimulationDriver.swift DockBarHeroTests/LootSystemTests.swift DockBarHeroTests/GameSimulationTests.swift DockBarHeroTests/SimulationDriverTests.swift DockBarHero.xcodeproj
git commit -m "feat: add deterministic loot and equipment"
```

### Task 6: Versioned Save Document And Validation

**Owner/model:** Fresh `gpt-5.6-luna` implementer.

**Files:**

- Create: `DockBarHero/Persistence/SaveDocument.swift`
- Create: `DockBarHeroTests/SaveDocumentTests.swift`

**Interfaces:**

- Consumes: complete `GameState` after Task 5.
- Produces: `SaveDocument`, `SaveCodec`, `SaveValidationError`, `SaveDecodingError`, `encode(state:savedAt:)`, and `decode(_:)`.

- [ ] **Step 1: Write failing codec and validation tests**

Cover round trip for active and reviving states, schema version 1, timestamp preservation, future-version rejection before body decoding, negative or unsupported fixed-point timers, invalid health, enemy level below one, duplicate item IDs, missing or wrong-slot equipment references, and inconsistent revive state.

Use this future-version fixture so the header is tested independently:

```swift
let data = Data(#"{"schemaVersion":2,"savedAt":"2026-07-10T00:00:00Z","state":{}}"#.utf8)
XCTAssertThrowsError(try SaveCodec().decode(data)) { error in
    XCTAssertEqual(error as? SaveDecodingError, .unsupportedVersion(2))
}
```

- [ ] **Step 2: Verify the focused test fails**

Run `SaveDocumentTests`.

Expected: FAIL because save types do not exist.

- [ ] **Step 3: Implement schema-first decoding and validation**

Define:

```swift
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
    case invalidTimer
    case duplicateItemID(ItemID)
    case missingEquipment(ItemID)
    case equipmentSlotMismatch(ItemID)
    case inconsistentEncounter
}
```

`SaveCodec.decode` first decodes a private `{ schemaVersion: Int }` header, rejects every version other than 1, then decodes and validates the full document. Configure encoder/decoder dates as ISO 8601 and encoder output as sorted keys. Validation must require attack intervals at or above one million nanoseconds, nonnegative countdowns, current health within `0...maxHealth`, unique positive item IDs, positive item levels/stats, and valid equipment references. Active state additionally requires both combatants alive and revive remaining equal to zero; reviving state requires a dead hero, live enemy, and revive remaining within `0...balance.reviveDelay`.

- [ ] **Step 4: Run focused and full tests**

Run `SaveDocumentTests`, then the complete suite.

Expected: PASS.

- [ ] **Step 5: Commit the save schema**

```bash
git add DockBarHero/Persistence/SaveDocument.swift DockBarHeroTests/SaveDocumentTests.swift DockBarHero.xcodeproj
git commit -m "feat: add versioned save schema"
```

### Task 7: Atomic Save Store And Recovery

**Owner/model:** Fresh `gpt-5.6-luna` implementer.

**Files:**

- Create: `DockBarHero/Persistence/SaveStore.swift`
- Create: `DockBarHeroTests/SaveStoreTests.swift`
- Modify: `DockBarHero/Support/AppLog.swift`

**Interfaces:**

- Consumes: `SaveCodec` and valid `GameState`.
- Produces: `SaveURLs`, `SaveLoadSource`, `SaveLoadResult`, `SaveStoring`, `SaveStore.load(newGame:)`, and `save(_:)`.

- [ ] **Step 1: Write failing temporary-directory store tests**

Every test uses a unique `FileManager.default.temporaryDirectory` child and removes it in `tearDown`. Cover first save, second save preserving prior primary as backup, primary load, corrupt-primary backup recovery, both-invalid new game, diagnostic preservation, and unsupported future primary recovery from valid backup.

Assert these filenames:

```swift
XCTAssertEqual(urls.primary.lastPathComponent, "save-v1.json")
XCTAssertEqual(urls.backup.lastPathComponent, "save-v1.backup.json")
XCTAssertEqual(urls.temporary.lastPathComponent, "save-v1.pending.json")
```

- [ ] **Step 2: Verify the focused test fails**

Run `SaveStoreTests`.

Expected: FAIL because `SaveStore` does not exist.

- [ ] **Step 3: Implement actor-isolated file storage**

Define the storage contract exactly:

```swift
protocol SaveStoring: Sendable {
    func load(newGame: GameState) async -> SaveLoadResult
    func save(_ state: GameState) async throws
}

enum SaveLoadSource: Equatable, Sendable { case primary, backup, newGame }

struct SaveLoadResult: Equatable, Sendable {
    let state: GameState
    let source: SaveLoadSource
}
```

`SaveURLs.applicationSupport` resolves `Application Support/com.n3kr0nom1c0n.DockBarHero/` and the three filenames above. The concrete actor accepts injected URLs, `FileManager`, `SaveCodec`, and `now` for deterministic tests.

On save:

1. Create the directory with intermediate directories.
2. Encode and validate the new state.
3. Write the pending file in the same directory using `.atomic`.
4. If a primary exists, remove an older backup and copy the primary to backup.
5. Replace an existing primary with the pending file, or move pending to primary on first save.
6. Remove a leftover pending file on failure without changing a valid primary or backup.

On load, return `.primary`, `.backup`, or `.newGame`. When a candidate is unreadable, move it to a unique filename containing `.invalid-<UTC timestamp>-<UUID>` before continuing. Never delete unreadable user data.

Add `AppLog.gameplay` and `AppLog.persistence` categories. Log paths using OSLog privacy defaults and never log save JSON or inventory contents.

- [ ] **Step 4: Run focused and full tests**

Run `SaveStoreTests`, then the complete suite.

Expected: PASS.

- [ ] **Step 5: Commit atomic persistence**

```bash
git add DockBarHero/Persistence/SaveStore.swift DockBarHeroTests/SaveStoreTests.swift DockBarHero/Support/AppLog.swift DockBarHero.xcodeproj
git commit -m "feat: add atomic save recovery"
```

### Task 8: Save Coalescing And Game Session

**Owner/model:** Fresh `gpt-5.6-luna` implementer.

**Files:**

- Create: `DockBarHero/Persistence/SaveCoordinator.swift`
- Create: `DockBarHero/Game/GameSession.swift`
- Create: `DockBarHeroTests/SaveCoordinatorTests.swift`
- Create: `DockBarHeroTests/GameSessionTests.swift`

**Interfaces:**

- Consumes: `SimulationDriving`, `SaveStoring`, game events/intents, and presentation.
- Produces: `SaveStatus`, `SaveCoordinating`, `SaveCoordinator.request(_:)`, `flush(_:)`, and `GameSessionControlling`.
- Produces: `GameSession.start()`, `send(_:)`, and `stopAndSave()` for `AppModel`.

- [ ] **Step 1: Write failing coalescing and session tests**

Use actor fakes that record saved states and controllable continuations. Verify that three requests during one in-flight write save the first state and latest state, never the superseded middle state. Verify status order `.saving` then `.saved` or `.failed(message)`.

For `GameSession`, use fake driver/store/coordinator contracts and assert:

- Load completes before driver start.
- Backup load reports `.recovered`.
- Victory, loot/equip, manual equip, and auto-equip changes request event saves.
- Ordinary attack events do not request event saves.
- A 30-second injected autosave tick requests the latest state.
- `stopAndSave()` stops the driver, cancels autosave, and awaits a final flush.

- [ ] **Step 2: Verify focused tests fail**

Run `SaveCoordinatorTests` and `GameSessionTests`.

Expected: FAIL because coordination/session types do not exist.

- [ ] **Step 3: Implement serialized coalescing**

Define UI-facing status:

```swift
enum SaveStatus: Equatable, Sendable {
    case notLoaded
    case saving
    case saved(Date)
    case recovered
    case failed(String)
}
```

`SaveCoordinator` is an actor with one in-flight drain. `request(_:)` replaces `pendingState` and starts a drain only when none is active. The drain repeatedly takes the latest pending value and calls `store.save`. `flush(_:)` installs the supplied latest state and does not return until pending and in-flight work have completed. Expose status changes through an `@Sendable` callback delivered to MainActor.

Use this exact protocol so `GameSession` tests can inject an actor fake:

```swift
protocol SaveCoordinating: Sendable {
    func request(_ state: GameState) async
    func flush(_ state: GameState) async
}
```

- [ ] **Step 4: Implement GameSession lifecycle and save triggers**

Define:

```swift
@MainActor
protocol GameSessionControlling: AnyObject {
    var onPresentation: ((GamePresentation) -> Void)? { get set }
    var onEvents: (([GameEvent]) -> Void)? { get set }
    var onSaveStatus: ((SaveStatus) -> Void)? { get set }
    func start()
    func send(_ intent: GameIntent) throws
    func stopAndSave() async
}
```

`GameSession.start()` launches one task that loads state, replaces driver state, forwards callbacks, starts the driver, and starts one 30-second autosave loop. Ignore duplicate starts. Event-save matching is exactly `.victory`, `.loot`, `.equipped`, and `.autoEquipChanged`; coalescing handles multiple events from one victory. `send(_:)` forwards the intent and requests a save after successful state change. `stopAndSave()` is idempotent and flushes the current driver state.

- [ ] **Step 5: Run focused and full tests**

Run both focused classes, then the complete suite.

Expected: PASS.

- [ ] **Step 6: Run Persistence Slice Gate C**

Dispatch one `gpt-5.6-terra` reviewer to compare Tasks 6-8 against Sections 5.6, 8, 11, and 12.4 of the design. Require schema-first decoding, no offline advancement, atomic primary preservation, corrupt-file retention, exact event triggers, coalescing, and final flush. Fix and rerun with the two-cycle limit.

- [ ] **Step 7: Commit persistence coordination**

```bash
git add DockBarHero/Persistence/SaveCoordinator.swift DockBarHero/Game/GameSession.swift DockBarHeroTests/SaveCoordinatorTests.swift DockBarHeroTests/GameSessionTests.swift DockBarHero.xcodeproj
git commit -m "feat: coordinate autosaves and game session"
```

### Task 9: AppModel And Rail Integration

**Owner/model:** Fresh `gpt-5.6-luna` implementer.

**Files:**

- Modify: `DockBarHero/App/AppModel.swift`
- Modify: `DockBarHero/App/AppDelegate.swift`
- Modify: `DockBarHero/Rendering/PrototypeScene.swift`
- Modify: `DockBarHero/Rendering/PrototypeSceneHost.swift`
- Modify: `DockBarHeroTests/AppModelTests.swift`
- Modify: `DockBarHeroTests/PrototypeSceneHostTests.swift`

**Interfaces:**

- Consumes: `GameSessionControlling`, `GamePresentation`, `GameEvent`, and `SaveStatus`.
- Produces: published `AppModel.game`, `saveStatus`, `send(_ intent:)`, and `stopAndSave()`.
- Extends: `SceneControlling.render(_:)` and `handle(_:)`.

- [ ] **Step 1: Write failing coordinator and scene tests**

Extend `FakeScene` and add `FakeGameSession`. Verify game session starts even when overlay dependencies are absent, presentations update `AppModel.game` and render to the scene, events forward to scene reactions, intents forward once, save status publishes, and `stopAndSave()` stops overlay services and awaits session flush.

Extend scene-host tests to render a known presentation and assert named nodes:

```swift
let enemyLevel = host.scene.childNode(withName: "//enemyLevel") as? SKLabelNode
let rollingDPS = host.scene.childNode(withName: "//rollingDPS") as? SKLabelNode

XCTAssertEqual(enemyLevel?.text, "Lv. 7")
XCTAssertEqual(rollingDPS?.text, "12.3 DPS")
XCTAssertNotNil(host.scene.childNode(withName: "//heroHealthFill"))
XCTAssertNotNil(host.scene.childNode(withName: "//enemyHealthFill"))
```

Compare label text and health-fill width after rendering. Send an attack event and assert a transient node is added. Remove the old repeated mock-attack expectation.

- [ ] **Step 2: Verify focused tests fail**

Run `AppModelTests` and `PrototypeSceneHostTests`.

Expected: FAIL because gameplay coordination and scene rendering methods are absent.

- [ ] **Step 3: Integrate gameplay without weakening overlay startup**

Add these published defaults to `AppModel`:

```swift
@Published private(set) var game = GameSimulation().presentation
@Published private(set) var saveStatus: SaveStatus = .notLoaded
```

Add optional `GameSessionControlling` connection independent of overlay connection. `start()` starts gameplay when present and starts overlay only when all four overlay dependencies are connected. Preserve every existing environment-resolution guard. A scene or screen failure must not prevent gameplay/session startup.

Wire callbacks on MainActor: presentation updates `game` then calls `scene?.render`; events call `scene?.handle`; save status updates the published property. `send(_ intent:)` forwards and logs errors without crashing. `stopAndSave()` stops the monitor/rail, then awaits the session.

- [ ] **Step 4: Replace mock animation timing with snapshot rendering**

Extend `SceneControlling`:

```swift
func render(_ presentation: GamePresentation)
func handle(_ events: [GameEvent])
```

In `PrototypeScene`, remove the repeating attack action. Create stable named health backgrounds/fills and labels once in `didMove(to:)`. `render` updates health-fill scale from clamped health fractions, enemy-level text as `Lv. N`, and rolling DPS as one decimal place using a fixed-width monospaced font. `handle` maps attack events to lunge/hit actions, victory to a brief enemy fade, defeat to a hero fade, and revived to restored opacity. These actions never call gameplay code.

- [ ] **Step 5: Construct live gameplay dependencies and bounded quit**

In `AppDelegate`, construct `SaveStore` with application-support URLs, `SaveCoordinator`, `SimulationDriver`, and `GameSession`, then connect gameplay before attempting scene creation. Keep the menu-bar app available if scene construction throws.

Implement `applicationShouldTerminate` to return `.terminateLater` once, launch a MainActor task, race `model.stopAndSave()` against a five-second sleep, log timeout or completion, and call `sender.reply(toApplicationShouldTerminate: true)`. Make subsequent termination callbacks idempotent.

- [ ] **Step 6: Run focused and full tests**

Run `AppModelTests`, `PrototypeSceneHostTests`, `GameSessionTests`, then the complete suite.

Expected: PASS and all existing Phase 0 startup/fullscreen tests remain unchanged in meaning.

- [ ] **Step 7: Commit app and rail integration**

```bash
git add DockBarHero/App/AppModel.swift DockBarHero/App/AppDelegate.swift DockBarHero/Rendering/PrototypeScene.swift DockBarHero/Rendering/PrototypeSceneHost.swift DockBarHeroTests/AppModelTests.swift DockBarHeroTests/PrototypeSceneHostTests.swift DockBarHero.xcodeproj
git commit -m "feat: connect gameplay to the desktop rail"
```

### Task 10: Management Window, Final QA, And Push

**Owner/model:** Fresh `gpt-5.6-luna` implementer; `gpt-5.6-terra` integration reviewer; `gpt-5.6-sol` final reviewer.

**Files:**

- Create: `DockBarHero/App/ManagementView.swift`
- Modify: `DockBarHero/App/DockBarHeroApp.swift`
- Modify: `DockBarHero/App/MenuBarContent.swift`
- Create: `docs/qa/phase-1-checklist.md`
- Modify: `DockBarHeroTests/AppModelTests.swift`
- Create: `DockBarHeroTests/ManagementViewTests.swift`
- Generate: `DockBarHero.xcodeproj/`

**Interfaces:**

- Consumes: published `AppModel.game`, `saveStatus`, and `send(_ intent:)`.
- Produces: management `Window` scene, menu command, native inventory table, equipment controls, DPS/status presentation, and durable QA evidence.

- [ ] **Step 1: Write failing presentation/intent tests**

Create `DockBarHeroTests/ManagementViewTests.swift` with tests for inventory row ordering newest first, equipped-state derivation by ID, one-decimal DPS formatting, save-status labels, auto-equip binding intent, and selected-item manual equip intent. Keep formatting in small pure helpers inside `ManagementView.swift` so XCTest can validate it without a third-party view-inspection dependency.

Use exact expected strings:

```swift
XCTAssertEqual(ManagementFormat.dps(12.34), "12.3")
XCTAssertEqual(ManagementFormat.saveStatus(.recovered), "Recovered from backup")
XCTAssertEqual(ManagementFormat.saveStatus(.notLoaded), "Loading")
```

Implement and test these exact pure helpers, then use them from the SwiftUI controls:

```swift
enum ManagementIntent {
    static func autoEquip(_ enabled: Bool) -> GameIntent { .setAutoEquip(enabled) }
    static func equip(_ selection: ItemID?) -> GameIntent? {
        selection.map(GameIntent.equip)
    }
}

enum ManagementFormat {
    static func dps(_ value: Double) -> String { String(format: "%.1f", value) }

    static func saveStatus(_ status: SaveStatus) -> String {
        switch status {
        case .notLoaded: "Loading"
        case .saving: "Saving"
        case .saved: "Saved"
        case .recovered: "Recovered from backup"
        case .failed(let message): "Save error: \(message)"
        }
    }
}
```

Add an `InventoryRow` value with item ID, slot, level, primary stat, and `isEquipped`. Its factory maps every owned item and sorts by descending `creationSequence`, using descending `id.rawValue` as the stable tie-breaker.

- [ ] **Step 2: Verify focused tests fail**

Run `ManagementViewTests` and `AppModelTests`.

Expected: FAIL because management formatting and row derivation do not exist.

- [ ] **Step 3: Build the management window**

Create `ManagementView` as a standard SwiftUI macOS view with an `@ObservedObject AppModel`, `@State private var selection: ItemID?`, and these full-width sections:

- Hero and enemy stat grids for health, attack, defense, interval, and enemy level.
- Rolling DPS and encounter-average DPS values.
- Equipped weapon and armor rows.
- `Toggle("Auto-equip upgrades", isOn:)` that sends `.setAutoEquip`.
- Native `Table` sorted newest first with columns Slot, Level, Stat, and Equipped.
- `Button("Equip", systemImage: "arrow.up.circle")` enabled only for a selected owned item and sending `.equip(id)`.
- Save status using the exact helper text; `.failed` uses `Color.red` and every other status uses `.secondary`.

Use a minimum window size of 720 by 520 points, native spacing, no nested cards, and no custom rounded text controls. Give the table and equip button stable accessibility identifiers `inventory-table` and `equip-selected-item`.

- [ ] **Step 4: Add the window and menu command**

In `DockBarHeroApp`, add:

```swift
Window("DockBarHero", id: "management") {
    ManagementView(model: appDelegate.model)
}
.defaultSize(width: 860, height: 620)
```

In `MenuBarContent`, read `@Environment(\.openWindow)` and add `Open Management Window` before rail controls. Its action calls `openWindow(id: "management")` and `NSApplication.shared.activate()` so the conventional window becomes visible without changing overlay input mode.

- [ ] **Step 5: Write the Phase 1 QA checklist**

Create `docs/qa/phase-1-checklist.md` with dated checkboxes and evidence fields for:

- Clean arm64 build and complete test count.
- Continuous level advancement and same-level retry after defeat.
- Rail rolling DPS changes and resets.
- Management rolling/encounter DPS, stats, equipment, inventory, manual equip, and toggle.
- Save created, clean relaunch restored, and automated corrupt-primary recovery passed.
- Rail remains passive, non-activating, correctly placed, hidden fullscreen, and restored afterward.
- Hidden/paused rendering behavior remains Phase 0 compliant.
- Deferred features are absent.
- Terra findings/resolutions and Sol final verdict.
- Feature branch and reviewed implementation commit; the final pushed HEAD is reported in the overnight report.

Unchecked manual observations must remain unchecked and be reported; do not convert automated coverage into manual evidence.

- [ ] **Step 6: Run UI Slice Gate D**

Run focused management/app/scene tests, the complete suite, and:

```bash
xcodegen generate
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/FinalDerivedData CODE_SIGNING_ALLOWED=NO clean build
./script/build_and_run.sh --verify
```

Expected: all commands exit 0 and `--verify` prints a live DockBarHero PID. Keep the launched process available for the checklist, then terminate it cleanly.

Dispatch `gpt-5.6-terra` for whole-slice integration review against Sections 9-12 of the design. Fix Critical and Important findings with at most two repair cycles and rerun the complete gate.

- [ ] **Step 7: Commit final integration and QA evidence**

```bash
git add DockBarHero/App/ManagementView.swift DockBarHero/App/DockBarHeroApp.swift DockBarHero/App/MenuBarContent.swift DockBarHeroTests/AppModelTests.swift DockBarHeroTests/ManagementViewTests.swift docs/qa/phase-1-checklist.md DockBarHero.xcodeproj
git commit -m "feat: add gameplay management window"
```

- [ ] **Step 8: Run final whole-branch review**

Dispatch one `gpt-5.6-sol` reviewer with the approved design, this plan, `git diff main...HEAD`, test/build output, and QA checklist. The review must check gameplay determinism, Swift 6 concurrency, persistence safety, Phase 0 regressions, deferred-scope leakage, and missing tests. Resolve every blocking finding and rerun Gate D. Stop rather than push if any blocking finding remains.

Commit review corrections separately with a message naming the correction. After Sol approves, record its verdict in the QA checklist and commit that documentation-only evidence update. Do not change production code after the approving review without rerunning Gate D and obtaining another Sol verdict.

- [ ] **Step 9: Verify branch scope and push**

Run:

```bash
git status --short
git diff --check main...HEAD
git log --oneline --decorate main..HEAD
git diff --stat main...HEAD
```

Expected: clean worktree, no diff-check output, and only Phase 1 files/commits. Push the dedicated feature branch without force:

```bash
git push -u origin HEAD
```

Do not merge. Write the overnight report with branch, commit, completed tasks, test/build commands and counts, review findings and resolutions, QA evidence, known limitations, and every unchecked observation.

## Stop Conditions

Stop immediately and preserve the worktree when any of these occurs:

- The same slice gate still fails after two focused repair cycles.
- A required fix would add a deferred feature or materially change the approved design.
- Save recovery would require deleting or overwriting unreadable user data.
- Phase 0 fullscreen, focus, passive-input, placement, or startup behavior regresses.
- A destructive Git action, force push, rebase, or merge would be required.
- A product decision cannot be answered by conservative project-consistent behavior and existing tests.
- Sol reports an unresolved blocking finding.

On stop, do not push a completion claim. Record the current branch and commit, failing command, relevant output, attempted repairs, unresolved issue, and the safest next action.
