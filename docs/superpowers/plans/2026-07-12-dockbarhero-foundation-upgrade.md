# DockBarHero Foundation Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close Phase 1 and establish deterministic resolver, migration, settings, navigation, and provisional pixel-sprite foundations for the Steam-ready roadmap without changing gameplay outcomes.

**Architecture:** Keep `GameSimulation` as the deterministic transaction and clock owner while extracting pure combat, encounter, and reward collaborators. Preserve save schema v1 while adding a migration registry and frozen v1 fixture; the Heroes and Classes milestone will introduce schema v2. Persist current overlay preferences in a separate atomic settings document and replace block actors through a SpriteKit catalog with code-defined pixel fallback art.

**Tech Stack:** Swift 6.3.2, SwiftUI, AppKit, SpriteKit, XCTest, Xcode 26.5, XcodeGen 2.45.4, macOS 26, Apple Silicon.

## Global Constraints

- Preserve signed `Int64` nanosecond gameplay time and exact deterministic event ordering.
- Preserve every accepted Phase 1 simulation outcome, save, overlay, fullscreen, placement, focus, and input behavior.
- Do not change emitted save schema version 1 in this plan.
- Keep settings in a separate versioned document; settings failure must not affect game saves.
- SpriteKit remains presentation-only; missing sprites must remain visible through a deterministic placeholder.
- Add no third-party runtime dependency and no Steam, cloud, telemetry, offline progression, party, class, or ability behavior.
- Production art is deferred; provisional pixel silhouettes are sufficient.
- Only the parent orchestrator may update `PROJECT.md`, review packets, or shared progress files.
- Use the token-bounded review policy from `routing-coding-subagents`: incremental diffs, summarized evidence, no duplicate tests, no broad Sol rereview.

---

### Task 0: Close And Push Phase 1

**Owner/model:** Parent for evidence; Terra only if a defect is found; evidence-only Sol recheck.

**Files:**

- Modify: `docs/qa/phase-1-checklist.md`
- Create: `docs/qa/review-packets/phase-1-closeout.md`
- Modify: `PROJECT.md` (parent only)

**Interfaces:**

- Consumes: reviewed Phase 1 branch at or after `88f4a63`, automated evidence already recorded in the checklist.
- Produces: an accepted, pushed Phase 1 baseline SHA and a compact review packet for downstream plans.

- [ ] **Step 1: Confirm the branch is clean and rerun launch verification only**

Run:

```bash
git status --short --branch
./script/build_and_run.sh --verify
```

Expected: clean `feature/phase-1-playable-slice`, `BUILD SUCCEEDED`, and a live DockBarHero PID. Do not rerun the complete suite unless source code changed after the recorded 163-test gate.

- [ ] **Step 2: Complete the live gameplay observations**

Observe and record exact evidence for:

```text
enemy level advances after victory
defeat enters revive and retries the same enemy level
rolling DPS changes after attacks and resets on encounter transition
```

Expected: all three Gameplay checkboxes can be marked from direct observation. If any observation fails, leave it unchecked and stop for a focused defect task.

- [ ] **Step 3: Complete management and persistence observations**

Open the management window and verify:

```text
rolling and encounter DPS render
hero/enemy stats and current enemy level render
equipment and newest-first inventory render
manual equip changes the equipped reference
auto-equip toggle persists
clean quit creates a save
relaunch restores combat, inventory, equipment, and settings
```

Expected: the Management Window and Persistence checkboxes are backed by direct evidence, not unit-test inference.

- [ ] **Step 4: Complete Phase 0 regression observations**

Verify the rail remains passive and non-activating, correctly placed, fullscreen-suppressed/restored, and render-suspended while hidden or paused.

Expected: every Phase 0 Regression checkbox has direct evidence. Stop if the rail steals focus or intercepts passive clicks.

- [ ] **Step 5: Request an evidence-only Sol recheck**

Create `docs/qa/review-packets/phase-1-closeout.md` with this exact structure:

```markdown
# Phase 1 Closeout Review Packet

- Accepted static base: `563c85d`
- Candidate SHA source: `git rev-parse HEAD`
- Production changes since static review: none
- Automated gate: 20 affected tests; 163 full tests; clean arm64 build; live launch and normal termination
- Manual gate: all checked items and concise evidence from `docs/qa/phase-1-checklist.md`
- Known nonblocking issue: ISO-8601 save timestamps truncate fractional seconds
- Requested verdict: evidence-only APPROVE or BLOCK; do not reread the source tree or rerun tests
```

Expected: Sol evaluates only the packet and checklist. Maximum response: 400 words.

- [ ] **Step 6: Commit evidence and push without force**

```bash
git add docs/qa/phase-1-checklist.md docs/qa/review-packets/phase-1-closeout.md PROJECT.md
git commit -m "docs: close phase 1 playable slice"
git push -u origin feature/phase-1-playable-slice
```

Expected: push succeeds without merge, rebase, or force. Record the pushed SHA in the checklist.

- [ ] **Step 7: Create the isolated Foundation worktree**

Use `superpowers:using-git-worktrees`, then create the next branch from the pushed Phase 1 head:

```bash
git -C /Users/n3kr0/Projects/TBH fetch origin feature/phase-1-playable-slice
git -C /Users/n3kr0/Projects/TBH worktree add /Users/n3kr0/Projects/TBH/.worktrees/foundation-upgrade -b feature/foundation-upgrade origin/feature/phase-1-playable-slice
git -C /Users/n3kr0/Projects/TBH/.worktrees/foundation-upgrade status --short --branch
```

Expected: clean `feature/foundation-upgrade` worktree whose `HEAD` equals `origin/feature/phase-1-playable-slice`. Execute Tasks 1-7 only in this new worktree.

---

### Task 1: Extract Pure Combat Resolution

**Owner/model:** Luna implementer; Terra incremental review.

**Files:**

- Create: `DockBarHero/Game/CombatResolver.swift`
- Modify: `DockBarHero/Game/GameSimulation.swift`
- Create: `DockBarHeroTests/CombatResolverTests.swift`
- Modify: `DockBarHeroTests/GameSimulationTests.swift`
- Generate: `DockBarHero.xcodeproj/`

**Interfaces:**

- Consumes: `GameState`, `CombatantID`, `EquipmentSlot`, `SimulationError`.
- Produces:

```swift
struct CombatResolver: Sendable {
    func effectiveAttack(for combatant: CombatantID, in state: GameState) throws -> Int
    func effectiveDefense(for combatant: CombatantID, in state: GameState) throws -> Int
    func damage(attacker: CombatantID, defender: CombatantID, in state: GameState) throws -> Int
    func health(afterTaking damage: Int, from currentHealth: Int) throws -> Int
}
```

- [ ] **Step 1: Write failing resolver tests**

Create `CombatResolverTests.swift` with direct tests for base damage, equipped weapon/armor effects, minimum damage, missing/wrong-slot equipment, duplicate equipment IDs, stat overflow, and health clamping:

```swift
func testDamageUsesOwnedEquipmentAndMinimumOne() throws {
    var state = GameState.newGame(balance: .standard)
    let weapon = Item(id: ItemID(rawValue: 1), level: 1, slot: .weapon, primaryStat: 5, creationSequence: 1)
    let armor = Item(id: ItemID(rawValue: 2), level: 1, slot: .armor, primaryStat: 20, creationSequence: 2)
    state.inventory = [weapon, armor]
    state.equipment = EquipmentState(weaponID: weapon.id, armorID: armor.id)
    let resolver = CombatResolver()

    XCTAssertEqual(try resolver.damage(attacker: .hero, defender: .enemy, in: state), 15)
    XCTAssertEqual(try resolver.damage(attacker: .enemy, defender: .hero, in: state), 1)
}

func testHealthClampsAtZero() throws {
    XCTAssertEqual(try CombatResolver().health(afterTaking: 40, from: 30), 0)
}
```

- [ ] **Step 2: Run the tests and verify RED**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/CombatResolverRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/CombatResolverTests
```

Expected: compile failure because `CombatResolver` does not exist.

- [ ] **Step 3: Implement the pure resolver**

Move effective-stat, equipment lookup, checked subtraction, minimum-damage, and health-clamping logic from `GameSimulation` into `CombatResolver`. Use one private lookup that requires exactly one owned item in the expected slot:

```swift
private func equippedItem(in slot: EquipmentSlot, state: GameState) throws -> Item? {
    guard let id = state.equipment[slot] else { return nil }
    let matches = state.inventory.filter { $0.id == id }
    guard matches.count == 1,
          let item = matches.first,
          item.slot == slot,
          item.level >= 1,
          item.primaryStat >= 0 else {
        throw SimulationError.invalidState
    }
    return item
}
```

Every addition/subtraction uses reporting-overflow APIs. Preserve Phase 1 admission semantics: an effective-stat overflow caused by equipped state throws `.invalidState`; arithmetic overflow while resolving damage or health throws `.arithmeticOverflow`.

- [ ] **Step 4: Integrate without changing simulation behavior**

Add `private let combatResolver: CombatResolver` to both `GameSimulation` initializers. Replace private `damage`, `effectiveAttack`, `effectiveDefense`, `equippedItem`, and `health` calls with the resolver. Keep candidate-copy mutation and `DamageMetrics` ownership in `GameSimulation`.

- [ ] **Step 5: Verify GREEN and regression behavior**

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/CombatResolverGreen CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/CombatResolverTests -only-testing:DockBarHeroTests/GameSimulationTests -only-testing:DockBarHeroTests/BalanceConfigurationTests
```

Expected: all selected tests pass and existing complete-state chunk-invariance assertions remain unchanged.

- [ ] **Step 6: Commit**

```bash
git add DockBarHero/Game/CombatResolver.swift DockBarHero/Game/GameSimulation.swift DockBarHeroTests/CombatResolverTests.swift DockBarHeroTests/GameSimulationTests.swift DockBarHero.xcodeproj
git commit -m "refactor: extract deterministic combat resolver"
```

---

### Task 2: Extract Encounter And Victory Reward Boundaries

**Owner/model:** Luna implementer; Terra incremental review after Tasks 1-2 together.

**Files:**

- Create: `DockBarHero/Game/EncounterDirector.swift`
- Create: `DockBarHero/Game/RewardResolver.swift`
- Modify: `DockBarHero/Game/GameSimulation.swift`
- Create: `DockBarHeroTests/EncounterDirectorTests.swift`
- Create: `DockBarHeroTests/RewardResolverTests.swift`
- Modify: `DockBarHeroTests/GameSimulationTests.swift`
- Generate: `DockBarHero.xcodeproj/`

**Interfaces:**

- Produces:

```swift
struct EncounterDirector: Sendable {
    func beginNextEncounter(in state: GameState, balance: BalanceConfiguration) throws -> GameState
    func beginRevive(in state: GameState, balance: BalanceConfiguration) throws -> GameState
    func finishRevive(in state: GameState, balance: BalanceConfiguration) throws -> GameState
}

struct VictoryReward: Equatable, Sendable {
    let state: GameState
    let events: [GameEvent]
}

struct RewardResolver: Sendable {
    func applyVictory(
        defeatedLevel: Int,
        to state: GameState,
        balance: BalanceConfiguration
    ) throws -> VictoryReward
}
```

- [ ] **Step 1: Write failing encounter tests**

Cover next-level creation, hero restoration, same-level revive, timer resets, invalid balance, and enemy-level overflow:

```swift
func testFinishReviveRestoresSameEnemyAndTimers() throws {
    var state = GameState.newGame(balance: .standard)
    state.hero.currentHealth = 0
    state.encounter.phase = .reviving
    state.encounter.reviveRemaining = .zero

    let result = try EncounterDirector().finishRevive(in: state, balance: .standard)

    XCTAssertEqual(result.encounter.enemyLevel, 1)
    XCTAssertEqual(result.hero.currentHealth, result.hero.maxHealth)
    XCTAssertEqual(result.enemy.currentHealth, result.enemy.maxHealth)
    XCTAssertEqual(result.encounter.phase, .active)
}
```

- [ ] **Step 2: Write failing reward tests**

Cover exactly one deterministic drop, strict-upgrade auto-equip, disabled auto-equip, tie handling, inventory preservation, and invalid loot rollback:

```swift
func testVictoryRewardAddsOneItemAndPreservesOwnedInventory() throws {
    var state = GameState.newGame(balance: .standard)
    let existing = Item(id: ItemID(rawValue: 9), level: 1, slot: .armor, primaryStat: 1, creationSequence: 9)
    state.inventory = [existing]
    state.lootSequence = 9

    let result = try RewardResolver().applyVictory(defeatedLevel: 1, to: state, balance: .standard)

    XCTAssertEqual(result.state.inventory.first, existing)
    XCTAssertEqual(result.state.inventory.count, 2)
    XCTAssertEqual(result.events.filter { if case .loot = $0 { true } else { false } }.count, 1)
}
```

- [ ] **Step 3: Run both test classes and verify RED**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/EncounterRewardRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/EncounterDirectorTests -only-testing:DockBarHeroTests/RewardResolverTests
```

Expected: compile failure for missing types.

- [ ] **Step 4: Implement pure state transforms**

`EncounterDirector` returns a modified state and never owns `DamageMetrics`. Its private reset function sets phase, active elapsed, hero damage, revive remaining, and both attack countdowns. `RewardResolver` uses `LootSystem`, appends `.loot`, and appends `.equipped` only for a strict same-slot upgrade.

- [ ] **Step 5: Integrate into `GameSimulation`**

Keep domain event ordering exactly:

```swift
events.append(.victory(defeatedLevel: defeatedLevel))
let reward = try rewardResolver.applyVictory(
    defeatedLevel: defeatedLevel,
    to: state,
    balance: balance
)
state = reward.state
events.append(contentsOf: reward.events)
state = try encounterDirector.beginNextEncounter(in: state, balance: balance)
damageMetrics.reset()
```

Defeat appends `.defeat` before `beginRevive`; revive state is applied before `.revived` is appended. Do not reorder existing public events.

- [ ] **Step 6: Verify direct and integration tests**

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/EncounterRewardGreen CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/EncounterDirectorTests -only-testing:DockBarHeroTests/RewardResolverTests -only-testing:DockBarHeroTests/GameSimulationTests -only-testing:DockBarHeroTests/LootSystemTests
```

Expected: all selected tests pass with unchanged event arrays and complete `GameState` equality.

- [ ] **Step 7: Commit and request one incremental Terra review for Tasks 1-2**

```bash
git add DockBarHero/Game/EncounterDirector.swift DockBarHero/Game/RewardResolver.swift DockBarHero/Game/GameSimulation.swift DockBarHeroTests/EncounterDirectorTests.swift DockBarHeroTests/RewardResolverTests.swift DockBarHeroTests/GameSimulationTests.swift DockBarHero.xcodeproj
git commit -m "refactor: extract encounter and reward resolvers"
```

The review packet contains only the two commit SHAs, resolver interfaces, selected test result summary, and paths from `git diff --name-only origin/feature/phase-1-playable-slice..HEAD`. Terra does not rerun tests and returns at most 800 words.

---

### Task 3: Add The Save Migration Registry And Frozen V1 Fixture

**Owner/model:** Luna implementer; Terra reviews Tasks 3-4 together.

**Files:**

- Create: `DockBarHero/Persistence/SaveMigrationRegistry.swift`
- Modify: `DockBarHero/Persistence/SaveDocument.swift`
- Create: `DockBarHeroTests/SaveMigrationRegistryTests.swift`
- Create: `DockBarHeroTests/Fixtures/SaveV1GoldenFixture.swift`
- Modify: `DockBarHeroTests/SaveDocumentTests.swift`
- Generate: `DockBarHero.xcodeproj/`

**Interfaces:**

```swift
protocol SaveMigration: Sendable {
    var sourceVersion: Int { get }
    var targetVersion: Int { get }
    func migrate(_ data: Data) throws -> Data
}

enum SaveMigrationError: Error, Equatable {
    case duplicateSourceVersion(Int)
    case invalidStep(source: Int, target: Int)
    case missingStep(Int)
}

struct SaveMigrationRegistry: Sendable {
    init(currentVersion: Int, migrations: [any SaveMigration]) throws
    func migrateToCurrent(_ data: Data, from sourceVersion: Int) throws -> Data
}
```

- [ ] **Step 1: Freeze a deterministic v1 fixture**

Create `SaveV1GoldenFixture.data` as a raw UTF-8 JSON literal representing `.newGame(balance: .standard)` saved at `2026-07-10T00:00:00Z`. It must include sorted keys and exact integer timer values. Add a test that decodes it to the expected state and verifies re-encoding produces byte-for-byte equality.

```swift
enum SaveV1GoldenFixture {
    static let data = Data(#"{"savedAt":"2026-07-10T00:00:00Z","schemaVersion":1,"state":{"autoEquipEnabled":true,"encounter":{"activeElapsed":0,"enemyLevel":1,"heroDamage":0,"phase":"active","reviveRemaining":0},"enemy":{"attackInterval":1500000000,"baseAttack":3,"baseDefense":0,"currentHealth":30,"id":"enemy","maxHealth":30,"timeUntilNextAttack":1500000000},"equipment":{},"hero":{"attackInterval":1000000000,"baseAttack":10,"baseDefense":0,"currentHealth":100,"id":"hero","maxHealth":100,"timeUntilNextAttack":1000000000},"inventory":[],"lootSequence":0}}"#.utf8)
}

func testGoldenV1FixtureRemainsByteStable() throws {
    let codec = SaveCodec()
    let document = try codec.decode(SaveV1GoldenFixture.data)

    XCTAssertEqual(document.state, .newGame(balance: .standard))
    XCTAssertEqual(
        try codec.encode(state: document.state, savedAt: document.savedAt),
        SaveV1GoldenFixture.data
    )
}
```

- [ ] **Step 2: Write failing registry tests**

Use small test-only migrations that replace the header version. Cover zero-step current decode, sequential `0 -> 1`, duplicate source registration, non-incrementing target, missing step, and future source rejection by `SaveCodec`:

```swift
func testRegistryAppliesSequentialMigration() throws {
    let registry = try SaveMigrationRegistry(
        currentVersion: 1,
        migrations: [HeaderMigration(sourceVersion: 0, targetVersion: 1)]
    )
    let migrated = try registry.migrateToCurrent(Data(#"{"schemaVersion":0}"#.utf8), from: 0)
    XCTAssertTrue(String(decoding: migrated, as: UTF8.self).contains(#""schemaVersion":1"#))
}
```

- [ ] **Step 3: Verify RED**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/MigrationRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/SaveMigrationRegistryTests -only-testing:DockBarHeroTests/SaveDocumentTests
```

Expected: compile failure for missing registry and fixture.

- [ ] **Step 4: Implement and inject the registry**

`SaveCodec` receives a registry defaulted to an empty version-1 registry. Decode the lightweight header first. Reject versions above `SaveDocument.currentVersion` as `.unsupportedVersion`. For lower versions, call `migrateToCurrent`, then decode and validate the current document. Keep `SaveDocument.currentVersion == 1` and do not rewrite files during load in this task.

- [ ] **Step 5: Verify GREEN and recovery regressions**

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/MigrationGreen CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/SaveMigrationRegistryTests -only-testing:DockBarHeroTests/SaveDocumentTests -only-testing:DockBarHeroTests/SaveStoreTests
```

Expected: all selected tests pass; v1 encoding is byte-stable; future versions remain preserved and unsupported.

- [ ] **Step 6: Commit**

```bash
git add DockBarHero/Persistence/SaveMigrationRegistry.swift DockBarHero/Persistence/SaveDocument.swift DockBarHeroTests/SaveMigrationRegistryTests.swift DockBarHeroTests/Fixtures/SaveV1GoldenFixture.swift DockBarHeroTests/SaveDocumentTests.swift DockBarHero.xcodeproj
git commit -m "feat: add save migration registry"
```

---

### Task 4: Persist Current Overlay Preferences Separately

**Owner/model:** Luna implementer; Terra reviews Tasks 3-4 together.

**Files:**

- Modify: `DockBarHero/Core/OverlayState.swift`
- Create: `DockBarHero/Settings/AppSettings.swift`
- Create: `DockBarHero/Settings/SettingsStore.swift`
- Create: `DockBarHero/Settings/SettingsSession.swift`
- Modify: `DockBarHero/App/AppDelegate.swift`
- Modify: `DockBarHero/App/AppModel.swift`
- Create: `DockBarHeroTests/SettingsStoreTests.swift`
- Create: `DockBarHeroTests/SettingsSessionTests.swift`
- Modify: `DockBarHeroTests/AppModelTests.swift`
- Generate: `DockBarHero.xcodeproj/`

**Interfaces:**

```swift
struct AppSettings: Codable, Equatable, Sendable {
    static let currentVersion = 1
    let schemaVersion: Int
    var manualVisibility: ManualVisibility
    var animationMode: AnimationMode
    var inputMode: InputMode
    static let defaults = AppSettings(
        schemaVersion: 1,
        manualVisibility: .shown,
        animationMode: .running,
        inputMode: .passive
    )
}

protocol SettingsStoring: Sendable {
    func load() async -> AppSettings
    func save(_ settings: AppSettings) async throws
}

@MainActor
protocol SettingsControlling: AnyObject {
    var onSettings: ((AppSettings) -> Void)? { get set }
    func start()
    func update(_ settings: AppSettings)
    func stopAndSave() async
}
```

- [ ] **Step 1: Make persisted enums stable coded values**

Change `ManualVisibility`, `AnimationMode`, and `InputMode` to `String, Codable, Equatable, Sendable`. Keep current case names and defaults. Do not persist `EnvironmentVisibility`.

- [ ] **Step 2: Write failing store tests**

Cover missing-file defaults, round trip, deterministic sorted JSON, atomic replacement, corrupt-settings quarantine/default recovery, unsupported settings version, and game-save path isolation. The settings directory is `Application Support/com.n3kr0nom1c0n.DockBarHero/` and filename is `settings-v1.json`.

- [ ] **Step 3: Write failing session and model tests**

Prove settings load before overlay visibility becomes available, user overlay actions submit the latest settings, environment visibility is never persisted, duplicate starts are ignored, and clean termination awaits one final settings save:

```swift
func testLoadedPreferencesApplyBeforeOverlayBecomesVisible() async {
    let settings = AppSettings(
        schemaVersion: 1,
        manualVisibility: .hidden,
        animationMode: .paused,
        inputMode: .passive
    )
    let settingsController = SettingsControllerFake(initial: settings, startsBlocked: true)
    let dependencies = TestDependencies()
    let model = dependencies.makeModel(settingsController: settingsController)

    model.start()
    XCTAssertFalse(dependencies.window.visibility.contains(true))

    settingsController.releaseStart()
    await waitUntil { model.state.manualVisibility == .hidden }

    XCTAssertEqual(model.state.animationMode, .paused)
    XCTAssertFalse(dependencies.window.visibility.contains(true))
}
```

Extend the existing test fakes with `SettingsControllerFake`, `makeModel(settingsController:)`, and the existing bounded `waitUntil` helper; do not add sleeps.

- [ ] **Step 4: Verify RED**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/SettingsRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/SettingsStoreTests -only-testing:DockBarHeroTests/SettingsSessionTests -only-testing:DockBarHeroTests/AppModelTests
```

Expected: compile failure for missing settings types.

- [ ] **Step 5: Implement isolated atomic settings persistence**

Follow the primary/temp/backup pattern from `SaveStore` but use settings-specific URLs and codec. Invalid settings may be quarantined and replaced with defaults; this path must never read, move, replace, or remove `save-v1.json` or its backup.

- [ ] **Step 6: Integrate lifecycle and state gating**

Inject `SettingsSession` through `AppDelegate`. Add `hasResolvedSettings` to `AppModel`; overlay availability becomes:

```swift
let isAvailable = hasResolvedSettings && hasResolvedEnvironment && hasCurrentPlacement
```

When settings arrive, apply only manual visibility, animation, and input values, then call `applyState()`. User `OverlayAction` updates state immediately and submits `AppSettings` except for `.setEnvironmentVisibility`. `stopAndSave()` awaits both game and settings final saves without allowing one failure to skip the other.

- [ ] **Step 7: Verify GREEN and persistence isolation**

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/SettingsGreen CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/SettingsStoreTests -only-testing:DockBarHeroTests/SettingsSessionTests -only-testing:DockBarHeroTests/AppModelTests -only-testing:DockBarHeroTests/OverlayStateTests -only-testing:DockBarHeroTests/SaveStoreTests
```

Expected: all selected tests pass; corrupt settings cannot alter game-save fixtures.

- [ ] **Step 8: Commit and request one incremental Terra review for Tasks 3-4**

```bash
git add DockBarHero/Core/OverlayState.swift DockBarHero/Settings DockBarHero/App/AppDelegate.swift DockBarHero/App/AppModel.swift DockBarHeroTests/SettingsStoreTests.swift DockBarHeroTests/SettingsSessionTests.swift DockBarHeroTests/AppModelTests.swift DockBarHero.xcodeproj
git commit -m "feat: persist overlay preferences separately"
```

The review packet includes only persistence/settings contracts, migration and settings test summaries, exact changed paths, and the incremental diff. Terra does not inspect gameplay files outside changed hunks.

---

### Task 5: Add Management Navigation And Settings Surface

**Owner/model:** Luna implementer; focused Terra review with Task 6.

**Files:**

- Create: `DockBarHero/App/ManagementRoute.swift`
- Create: `DockBarHero/App/ManagementRootView.swift`
- Create: `DockBarHero/App/OverviewView.swift`
- Create: `DockBarHero/App/InventoryView.swift`
- Create: `DockBarHero/App/SettingsView.swift`
- Create: `DockBarHero/App/ManagementSupport.swift`
- Delete: `DockBarHero/App/ManagementView.swift`
- Modify: `DockBarHero/App/DockBarHeroApp.swift`
- Modify: `DockBarHero/App/AppModel.swift`
- Create: `DockBarHeroTests/ManagementNavigationTests.swift`
- Modify: `DockBarHeroTests/ManagementViewTests.swift`
- Generate: `DockBarHero.xcodeproj/`

**Interfaces:**

```swift
enum ManagementRoute: String, CaseIterable, Identifiable, Sendable {
    case overview
    case inventory
    case settings
    var id: String { rawValue }
}
```

`AppModel` publishes `var managementRoute: ManagementRoute` and provides `func selectManagementRoute(_ route: ManagementRoute)`.

- [ ] **Step 1: Write failing navigation tests**

Cover default overview, idempotent selection, route changes without game-session restart, and stable labels. Extend management tests so inventory ordering/equip helpers continue working after view extraction.

- [ ] **Step 2: Verify RED**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/NavigationRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/ManagementNavigationTests -only-testing:DockBarHeroTests/ManagementViewTests -only-testing:DockBarHeroTests/AppModelTests
```

Expected: compile failure for missing route/root views.

- [ ] **Step 3: Split existing management content by responsibility**

- `OverviewView`: combat grids, rolling/encounter DPS, equipped items, save status.
- `InventoryView`: native sortable table, equip action, auto-equip toggle.
- `SettingsView`: show/hide, run/pause, passive/interactive controls bound to existing overlay actions.
- `ManagementRootView`: `NavigationSplitView` sidebar with the three routes and one detail surface.
- `ManagementSupport`: unchanged `ManagementIntent`, `ManagementFormat`, and `InventoryRow` helpers moved from the deleted `ManagementView.swift`.

Keep accessibility identifiers `inventory-table` and `equip-selected-item`. Do not add empty Party or Accessibility routes before those surfaces exist.

- [ ] **Step 4: Replace the window root**

```swift
Window("DockBarHero", id: "management") {
    ManagementRootView(model: appDelegate.model)
}
.defaultSize(width: 860, height: 620)
```

Remove `ManagementView.swift` after its helpers move to `ManagementSupport.swift`; `ManagementRootView` is the only production management-window root.

- [ ] **Step 5: Verify GREEN**

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/NavigationGreen CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/ManagementNavigationTests -only-testing:DockBarHeroTests/ManagementViewTests -only-testing:DockBarHeroTests/AppModelTests
```

Expected: all selected tests pass; game session starts exactly once across route changes.

- [ ] **Step 6: Commit**

```bash
git add DockBarHero/App DockBarHeroTests/ManagementNavigationTests.swift DockBarHeroTests/ManagementViewTests.swift DockBarHeroTests/AppModelTests.swift DockBarHero.xcodeproj
git commit -m "feat: add management navigation"
```

---

### Task 6: Replace Block Actors With Provisional Pixel Sprites

**Owner/model:** Luna implementer for code; Spark may generate mechanical palette matrices; Terra verifies the integrated rendering diff.

**Files:**

- Create: `DockBarHero/Rendering/SpriteCatalog.swift`
- Create: `DockBarHero/Rendering/PixelSpriteDefinition.swift`
- Create: `DockBarHero/Rendering/BuiltinPixelSprites.swift`
- Modify: `DockBarHero/Rendering/PrototypeScene.swift`
- Modify: `DockBarHero/Rendering/PrototypeSceneHost.swift`
- Create: `DockBarHeroTests/SpriteCatalogTests.swift`
- Modify: `DockBarHeroTests/PrototypeSceneHostTests.swift`
- Generate: `DockBarHero.xcodeproj/`

**Interfaces:**

```swift
enum SpriteToken: Hashable, Sendable {
    case hero
    case enemy
}

enum SpriteAction: Hashable, Sendable {
    case idle
    case attack
    case hit
    case defeated
}

@MainActor
protocol SpriteCatalog: AnyObject {
    func textures(for token: SpriteToken, action: SpriteAction) -> [SKTexture]
}

struct PixelSpriteDefinition: Equatable, Sendable {
    let width: Int
    let height: Int
    let palette: [Character: UInt32]
    let rows: [String]
}
```

- [ ] **Step 1: Write failing catalog tests**

Cover palette validation, equal row width, transparent pixels, deterministic bitmap bytes, nearest-neighbor filtering, stable texture dimensions, distinct hero/enemy silhouettes, and missing-action fallback to idle:

```swift
@MainActor
func testBuiltinSpritesAreNotSolidRectangles() throws {
    let catalog = BuiltinSpriteCatalog()
    let hero = try XCTUnwrap(catalog.pixelData(for: .hero, action: .idle).first)

    XCTAssertTrue(hero.contains(0))
    XCTAssertGreaterThan(Set(hero).count, 3)
}
```

- [ ] **Step 2: Write failing scene tests**

Update scene-host assertions so `hero` and `enemy` are `SKSpriteNode`, retain stable names across renders, use nearest filtering, and preserve health/DPS labels. Event handling must select attack/hit/defeated sequences without invoking gameplay.

- [ ] **Step 3: Verify RED**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/SpritesRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/SpriteCatalogTests -only-testing:DockBarHeroTests/PrototypeSceneHostTests
```

Expected: compile failure for missing sprite catalog and existing shape-node assertions.

- [ ] **Step 4: Implement deterministic pixel texture generation**

Use 12-by-18 or 16-by-24 color-index matrices for hero and enemy idle/attack/hit/defeated frames. Generate an `NSBitmapImageRep` with alpha, create `SKTexture`, and set:

```swift
texture.filteringMode = .nearest
```

Hero and enemy definitions must include transparent background, readable head/body/weapon silhouettes, at least four visible palette colors, and asymmetric facing detail. Invalid definitions return a visible magenta-and-black fallback sprite and log once; they do not crash the scene.

- [ ] **Step 5: Integrate sprites without changing node identity**

Inject `any SpriteCatalog` into `PrototypeSceneHost` and `PrototypeScene`. Replace `actor(name:color:x:) -> SKShapeNode` with an `SKSpriteNode` created once in `didMove(to:)`. Keep names `hero` and `enemy`, current positions, health bars, label layout, event keys, focus/input behavior, and scene contract.

Idle and event animations change textures and position/alpha only. Repeated `render` calls do not recreate actor nodes or restart action sequences unnecessarily.

- [ ] **Step 6: Verify GREEN and frame stability**

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/SpritesGreen CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/SpriteCatalogTests -only-testing:DockBarHeroTests/PrototypeSceneHostTests -only-testing:DockBarHeroTests/AppModelTests
```

Expected: all selected tests pass; actor nodes are sprites, not solid shape blocks.

- [ ] **Step 7: Commit and request one incremental Terra review for Tasks 5-6**

```bash
git add DockBarHero/Rendering DockBarHero/App DockBarHeroTests/SpriteCatalogTests.swift DockBarHeroTests/PrototypeSceneHostTests.swift DockBarHeroTests/ManagementNavigationTests.swift DockBarHeroTests/ManagementViewTests.swift DockBarHero.xcodeproj
git commit -m "feat: add provisional pixel sprite presentation"
```

The review packet contains the navigation/sprite commit range, exact changed paths, selected test summary, screenshots if available, and no unrelated gameplay source.

---

### Task 7: Run The Foundation Milestone Gate

**Owner/model:** Parent executes; Terra incremental whole-milestone review; no Sol.

**Files:**

- Create: `docs/qa/review-packets/foundation-upgrade.md`
- Create: `docs/qa/foundation-upgrade-checklist.md`
- Modify: `PROJECT.md` (parent only)

**Interfaces:**

- Consumes: accepted commits from Tasks 1-6.
- Produces: reviewed foundation baseline for the Heroes and Classes plan.

- [ ] **Step 1: Run the complete automated gate once**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/FoundationFull CODE_SIGNING_ALLOWED=NO
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/FoundationBuild CODE_SIGNING_ALLOWED=NO clean build
python3 /Users/n3kr0/.codex/skills/maintaining-project-context/scripts/context_guard.py check --root .
PHASE1_SHA=$(git rev-parse origin/feature/phase-1-playable-slice)
git diff --check "$PHASE1_SHA"...HEAD
```

Expected: complete tests pass, clean arm64 build succeeds, context is valid, and diff check is empty.

- [ ] **Step 2: Run proportional live QA**

```bash
./script/build_and_run.sh --verify
```

Observe that pixel sprites render, combat/DPS continue, management navigation changes routes without pausing combat, settings survive relaunch, passive input remains click-through, fullscreen suppression remains correct, and clean termination preserves both settings and game save.

- [ ] **Step 3: Write the review packet**

`docs/qa/review-packets/foundation-upgrade.md` must contain:

```markdown
# Foundation Upgrade Review Packet

- Accepted base SHA source: `git rev-parse origin/feature/phase-1-playable-slice`
- Candidate SHA source: `git rev-parse HEAD`
- Changed contracts: CombatResolver, EncounterDirector, RewardResolver, SaveMigrationRegistry, AppSettings/SettingsStore, ManagementRoute, SpriteCatalog
- Production paths: exact `git diff --name-only` output
- Focused evidence: one result line per task
- Full evidence: test count, zero failures, clean arm64 build
- Manual evidence: sprites, navigation, settings relaunch, passive/fullscreen/termination
- Known risks: settings first-load gating; SpriteKit first texture upload
- Requested review: Critical/Important findings only; maximum 800 words; do not rerun tests
```

- [ ] **Step 4: Request one Terra milestone review**

Terra reads only the packet, changed tests, and `git diff origin/feature/phase-1-playable-slice...HEAD`. It checks deterministic equivalence, save compatibility, settings isolation, navigation lifecycle, SpriteKit presentation-only behavior, and missing focused tests.

Expected: no unresolved Critical or Important finding. A repair gets affected tests first and the full gate only if production behavior changes.

- [ ] **Step 5: Commit milestone evidence**

```bash
git add docs/qa/review-packets/foundation-upgrade.md docs/qa/foundation-upgrade-checklist.md PROJECT.md
git commit -m "docs: accept foundation upgrade milestone"
git status --short --branch
```

Expected: clean feature branch. Do not merge, rebase, force-push, or start the Heroes and Classes implementation until its detailed plan is generated against these accepted interfaces.
