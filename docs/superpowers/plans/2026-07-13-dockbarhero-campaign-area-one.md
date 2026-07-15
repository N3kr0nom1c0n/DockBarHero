# DockBarHero Campaign Area One Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship one deterministic authored dungeon campaign for levels 1 through 25, including identity stat profiles and campaign presentation, while preserving procedural compatibility from level 26 onward.

**Architecture:** CampaignCatalog validates immutable content definitions, CampaignResolver selects authored or procedural encounters, and EnemyFactory applies checked identity profiles at encounter boundaries. GamePresentation carries transient identity to SwiftUI and SpriteKit; saves retain schema v2 and derive identity from level.

**Tech Stack:** Swift 6, SwiftUI, AppKit, SpriteKit, XCTest, XcodeGen, arm64 macOS.

## Global Constraints

- Work only in /Users/n3kr0/Projects/TBH/.worktrees/campaign-area-one on feature/campaign-area-one.
- Follow docs/superpowers/specs/2026-07-13-dockbarhero-campaign-area-one-design.md.
- Keep main and /Users/n3kr0/Projects/TBH/.worktrees/heroes-and-party untouched; that checkout contains concurrent sprite-pipeline work.
- Start caffeinate -dimsu before long work, record its PID, verify the assertion, and stop that exact PID during cleanup.
- Preserve schema-v2 encoding and accepted farming, queued destination, retreat, party, class-action, loot, inventory, overlay, focus, placement, fullscreen, and Passive click-through behavior.
- Use signed Int64 nanoseconds and checked integer/basis-point gameplay arithmetic; floating point remains presentation-only.
- Levels 1 through 25 are authored. Level 26 and above retain the current periodic schedule and generic enemy behavior.
- Boss 25 uses content ID unknownGuardian, display name Unknown Guardian, and generic sprite fallback. Do not add final boss art or mechanics.
- Exclude authored Unique rewards, quests, enemy-specific mechanics, Class Action modifiers, party-size scaling, Area 2, economy work, offline progression, merge, and release.
- Use TDD and one coherent commit per task. Update PROJECT.md only after fresh complete verification.
- Push only after every automated and live gate passes. If a gate is blocked, keep the branch local.

## File And Interface Map

- Create DockBarHero/Game/CampaignCatalog.swift for content IDs, definitions, exact Area 1 data, and validation.
- Create DockBarHero/Game/CampaignResolver.swift for authored lookup and procedural fallback.
- Create DockBarHero/Game/EnemyFactory.swift for checked identity-profile application.
- Modify EncounterDirector, GameSession, GameSimulation, and SaveDocument to consume the resolver.
- Add transient CampaignPresentation to GameModels; do not modify Codable game state.
- Modify ManagementSupport and OverviewView for authored copy.
- Extend SpriteCatalog and PrototypeScene for identity-specific enemy lookup with generic fallback.
- Create AreaTitleMarquee.swift and add local Interactive-only hover tracking in PrototypeSceneHost.
- Create focused tests for every new unit.
- Create docs/qa/review-packets/campaign-area-one.md and update PROJECT.md only after the final gate.

---

### Task 1: Validate The Authored Campaign Catalog

**Files:**
- Create: DockBarHero/Game/CampaignCatalog.swift
- Create: DockBarHeroTests/CampaignCatalogTests.swift

**Interfaces:**
- Consumes: EnemyTierID and existing checked progression conventions.
- Produces: AreaID, EnemyContentID, EnemySpriteID, EnemyStatProfile, AreaDefinition, EnemyDefinition, EncounterDefinition, CampaignCatalog.standard, validate(), and authoredEncounter(level:).

- [ ] **Step 1: Confirm isolation, start caffeinate, and run the baseline**

Run:

~~~bash
test "$(git branch --show-current)" = "feature/campaign-area-one"
test -z "$(git status --porcelain)"
git merge-base --is-ancestor c000d81 HEAD
caffeinate -dimsu >/tmp/dockbarhero-campaign-caffeinate.log 2>&1 &
echo $! >/tmp/dockbarhero-campaign-caffeinate.pid
ps -p "$(cat /tmp/dockbarhero-campaign-caffeinate.pid)" -o pid=,command=
pmset -g assertions | rg 'PreventUserIdleDisplaySleep|PreventUserIdleSystemSleep'
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/CampaignBaseline CODE_SIGNING_ALLOWED=NO
~~~

Expected: clean campaign branch; one live caffeinate process; display/system assertions active; at least the last verified 345 tests pass. Stop if the baseline is red.

- [ ] **Step 2: Write failing catalog tests**

Add exact sequence, copy, profile, sprite-ID, and validation tests:

~~~swift
func testStandardAreaOneHasExactAuthoredSequence() throws {
    let catalog = CampaignCatalog.standard
    try catalog.validate()
    XCTAssertEqual((1...25).compactMap { catalog.authoredEncounter(level: $0)?.enemyID }, [
        .slime, .bat, .goblin, .skeleton, .knight,
        .zombie, .bandit, .slime, .mimic, .frostWraith,
        .goblin, .bat, .skeleton, .zombie, .poisonNagaQueen,
        .bandit, .mimic, .goblin, .skeleton, .ancientGolem,
        .bat, .zombie, .bandit, .mimic, .unknownGuardian,
    ])
    XCTAssertEqual(catalog.area(id: .forgottenShallowDepths)?.fullName,
                   "The Forgotten Shallow Depths That Were Remembered")
    XCTAssertEqual(catalog.area(id: .forgottenShallowDepths)?.shortName, "Shallow Depths")
}

func testCatalogRejectsMissingAuthoredLevel() {
    var catalog = CampaignCatalog.standard
    catalog.encounters.removeAll { $0.level == 17 }
    XCTAssertThrowsError(try catalog.validate()) {
        XCTAssertEqual($0 as? CampaignCatalogError, .missingAuthoredLevel(17))
    }
}
~~~

Also test duplicate area/enemy IDs, duplicate levels, unknown references, tier disagreement, empty display/sprite IDs, zero health/interval basis points, negative attack basis points, and negative defense.

- [ ] **Step 3: Run RED**

~~~bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/CampaignCatalogRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/CampaignCatalogTests
~~~

Expected: compile failure because CampaignCatalog does not exist.

- [ ] **Step 4: Implement typed definitions and exact standard content**

Use these signatures:

~~~swift
struct AreaID: RawRepresentable, Hashable, Equatable, Sendable { let rawValue: String }
struct EnemyContentID: RawRepresentable, Hashable, Equatable, Sendable { let rawValue: String }
struct EnemySpriteID: RawRepresentable, Hashable, Equatable, Sendable { let rawValue: String }

struct EnemyStatProfile: Equatable, Sendable {
    let healthBasisPoints: Int64
    let attackBasisPoints: Int64
    let defenseBonus: Int
    let attackIntervalBasisPoints: Int64
}

struct AreaDefinition: Equatable, Sendable {
    let id: AreaID
    let fullName: String
    let shortName: String
    let levels: ClosedRange<Int>
}

struct EnemyDefinition: Equatable, Sendable {
    let id: EnemyContentID
    let displayName: String
    let tier: EnemyTierID
    let spriteID: EnemySpriteID
    let profile: EnemyStatProfile
}

struct EncounterDefinition: Equatable, Sendable {
    let level: Int
    let areaID: AreaID
    let enemyID: EnemyContentID
}
~~~

Define explicit static IDs on both `EnemyContentID` and `EnemySpriteID` for all twelve identities. `CampaignCatalog` exposes mutable `areas`, `enemies`, and `encounters` arrays so invalid fixtures can be constructed without separate test-only APIs. Build `CampaignCatalog.standard` with these exact definition tuples:

~~~swift
// id, display name, tier, health bp, attack bp, defense, interval bp
(.goblin, "Goblin", .normal, 10_000, 10_000, 0, 10_000),
(.bandit, "Bandit", .normal, 8_500, 11_500, 0, 8_000),
(.slime, "Slime", .normal, 13_000, 7_500, 0, 13_000),
(.mimic, "Mimic", .normal, 12_500, 11_500, 2, 11_500),
(.skeleton, "Skeleton", .normal, 10_500, 9_000, 1, 10_500),
(.bat, "Bat", .normal, 7_000, 8_000, 0, 6_000),
(.zombie, "Zombie", .normal, 14_000, 9_000, 0, 13_500),
(.knight, "Knight", .elite, 12_500, 10_000, 3, 11_000),
(.frostWraith, "Frost Wraith", .elite, 8_500, 11_500, 1, 7_000),
(.poisonNagaQueen, "Poison Naga Queen", .elite, 11_000, 12_000, 2, 8_500),
(.ancientGolem, "Ancient Golem", .elite, 16_000, 11_000, 4, 15_000),
(.unknownGuardian, "Unknown Guardian", .boss, 10_000, 10_000, 0, 10_000),
~~~

Each identity normally uses its same-named sprite ID; Unknown Guardian uses `EnemySpriteID(rawValue: "generic.enemy")`.

Use these error cases consistently across catalog and resolver tests:

~~~swift
enum CampaignCatalogError: Error, Equatable {
    case invalidLevel(Int)
    case duplicateAreaID(AreaID)
    case duplicateEnemyID(EnemyContentID)
    case duplicateEncounterLevel(Int)
    case missingAuthoredLevel(Int)
    case unknownAreaReference(AreaID)
    case unknownEnemyReference(EnemyContentID)
    case tierMismatch(level: Int, expected: EnemyTierID, actual: EnemyTierID)
    case invalidArea(AreaID)
    case invalidEnemy(EnemyContentID)
}
~~~

validate() must require unique IDs/levels, exact Set(1...25) coverage, valid references, EncounterSchedule tier agreement, nonempty copy/IDs, positive health/attack/interval ratios, and nonnegative defense. A syntactically valid sprite ID does not require installed artwork.

- [ ] **Step 5: Run GREEN and commit**

~~~bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/CampaignCatalogGreen CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/CampaignCatalogTests
git diff --check
git add DockBarHero/Game/CampaignCatalog.swift DockBarHeroTests/CampaignCatalogTests.swift DockBarHero.xcodeproj
git commit -m "feat: add authored campaign catalog"
~~~

Expected: catalog tests pass; only catalog code/tests and generated project references are committed.

---

### Task 2: Resolve And Construct Authored Encounters

**Files:**
- Create: DockBarHero/Game/CampaignResolver.swift
- Create: DockBarHero/Game/EnemyFactory.swift
- Modify: DockBarHero/Game/EncounterDirector.swift
- Modify: DockBarHero/Game/GameSession.swift
- Create: DockBarHeroTests/CampaignResolverTests.swift
- Create: DockBarHeroTests/EnemyFactoryTests.swift
- Modify: DockBarHeroTests/EncounterDirectorTests.swift
- Modify: DockBarHeroTests/GameSessionTests.swift

**Interfaces:**
- Consumes: CampaignCatalog, BalanceConfiguration, ProgressionConfiguration, and EncounterSchedule for fallback.
- Produces: ResolvedCampaignEncounter, CampaignResolver.resolve(level:), EnemyFactory.makeEnemy(for:balance:progression:), and EncounterDirector.prepareNewGame(in:balance:).

- [ ] **Step 1: Write failing resolver/factory tests**

~~~swift
func testResolverUsesAuthoredContentThenProceduralFallback() throws {
    let resolver = CampaignResolver()
    let one = try resolver.resolve(level: 1)
    XCTAssertEqual(one.area?.id, .forgottenShallowDepths)
    XCTAssertEqual(one.enemy?.id, .slime)
    XCTAssertEqual(one.tier, .normal)

    let twentySix = try resolver.resolve(level: 26)
    XCTAssertNil(twentySix.area)
    XCTAssertNil(twentySix.enemy)
    XCTAssertEqual(twentySix.tier, .normal)
    XCTAssertEqual(try resolver.resolve(level: 50).tier, .boss)
    XCTAssertEqual(try resolver.resolve(level: 192).tier, .normal)
}

func testFactoryAppliesSlimeProfileWithCheckedRounding() throws {
    let resolved = try CampaignResolver().resolve(level: 1)
    let enemy = try EnemyFactory().makeEnemy(
        for: resolved,
        balance: .standard,
        progression: .standard
    )
    XCTAssertEqual(enemy.maxHealth, 39)
    XCTAssertEqual(enemy.baseAttack, 3)
    XCTAssertEqual(enemy.baseDefense, 0)
    XCTAssertEqual(enemy.attackInterval, .nanoseconds(1_950_000_000))
}
~~~

Cover elite 5/10/15/20, Boss 25, procedural 26/50/100/192, nonpositive levels, minimum interval, overflow, and prior-state rollback. Require a selected-class run to begin with authored Slime stats.

- [ ] **Step 2: Run RED**

Run the new suites plus EncounterDirectorTests and GameSessionTests with derived data .build/CampaignResolveRed.

Expected: compile failure for resolver/factory APIs.

- [ ] **Step 3: Implement resolver and factory**

~~~swift
struct ResolvedCampaignEncounter: Equatable, Sendable {
    let level: Int
    let tier: EnemyTierID
    let area: AreaDefinition?
    let enemy: EnemyDefinition?
}

struct CampaignResolver: Sendable {
    let catalog: CampaignCatalog
    init(catalog: CampaignCatalog = .standard) { self.catalog = catalog }

    func resolve(level: Int) throws -> ResolvedCampaignEncounter {
        guard level >= 1 else { throw CampaignCatalogError.invalidLevel(level) }
        try catalog.validate()
        guard let encounter = catalog.authoredEncounter(level: level) else {
            guard let tier = EncounterSchedule.standard.tier(for: level) else {
                throw CampaignCatalogError.invalidLevel(level)
            }
            return .init(level: level, tier: tier, area: nil, enemy: nil)
        }
        guard let area = catalog.area(id: encounter.areaID) else {
            throw CampaignCatalogError.unknownAreaReference(encounter.areaID)
        }
        guard let enemy = catalog.enemy(id: encounter.enemyID) else {
            throw CampaignCatalogError.unknownEnemyReference(encounter.enemyID)
        }
        return .init(level: level, tier: enemy.tier, area: area, enemy: enemy)
    }
}
~~~

EnemyFactory begins with balance.enemy(level:tier:progression:). Procedural resolution returns that state unchanged. Authored resolution applies ProgressionConfiguration.applying with rounding .up to max health, base attack, and attack-interval raw nanoseconds; adds defense with addingReportingOverflow; creates one complete CombatantState; and rejects nonpositive health or intervals below minimumAttackInterval.

- [ ] **Step 4: Route encounter boundaries and new-game selection**

Inject CampaignResolver and EnemyFactory into EncounterDirector with standard defaults. In activate(), resolve level, use resolved.tier, and build state.enemy through EnemyFactory.

Add:

~~~swift
func prepareNewGame(in state: GameState, balance: BalanceConfiguration) throws -> GameState {
    guard state.campaign.highestUnlockedLevel == 1,
          state.campaign.selectedLevel == 1,
          state.encounter.enemyLevel == 1 else {
        throw SimulationError.invalidState
    }
    return try activate(
        level: 1,
        mode: .push,
        resetDefeats: true,
        in: state,
        balance: balance
    )
}
~~~

In GameSession.chooseStartingClass, pass the new class state through prepareNewGame before replaceRun. Preserve the nonthrowing GameState.newGame API used by existing fixtures and hidden class-selection presentation.

- [ ] **Step 5: Run GREEN and commit**

~~~bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/CampaignResolveGreen CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/CampaignResolverTests -only-testing:DockBarHeroTests/EnemyFactoryTests -only-testing:DockBarHeroTests/EncounterDirectorTests -only-testing:DockBarHeroTests/GameSessionTests -only-testing:DockBarHeroTests/ProgressionSafetyTests -only-testing:DockBarHeroTests/HeroesAndPartyTests
git diff --check
git add DockBarHero/Game/CampaignResolver.swift DockBarHero/Game/EnemyFactory.swift DockBarHero/Game/EncounterDirector.swift DockBarHero/Game/GameSession.swift DockBarHeroTests/CampaignResolverTests.swift DockBarHeroTests/EnemyFactoryTests.swift DockBarHeroTests/EncounterDirectorTests.swift DockBarHeroTests/GameSessionTests.swift DockBarHero.xcodeproj
git commit -m "feat: resolve authored campaign encounters"
~~~

Expected: authored stats apply at encounter boundaries; procedural and party suites remain green.

---

### Task 3: Preserve Save Validation And Determinism

**Files:**
- Modify: DockBarHero/Game/GameSimulation.swift
- Modify: DockBarHero/Persistence/SaveDocument.swift
- Modify: DockBarHeroTests/SaveDocumentTests.swift
- Modify: DockBarHeroTests/GameSimulationTests.swift
- Create: DockBarHeroTests/CampaignAreaOneIntegrationTests.swift

**Interfaces:**
- Consumes: CampaignResolver.resolve(level:).
- Produces: resolver-backed runtime/save validation and authored determinism coverage.

- [ ] **Step 1: Write failing compatibility tests**

~~~swift
func testAuthoredSaveRoundTripPreservesInProgressEnemyState() throws {
    var state = try authoredState(level: 9)
    state.enemy.currentHealth = state.enemy.maxHealth - 3
    state.enemy.timeUntilNextAttack = .nanoseconds(123_456_789)
    let data = try SaveCodec().encode(state: state, savedAt: Date(timeIntervalSince1970: 0))
    XCTAssertEqual(try SaveCodec().decode(data).state, state)
}

func testAuthoredEncounterIsDeterministicAcrossTimePartitions() throws {
    let state = try authoredState(level: 15)
    var single = GameSimulation(state: state)
    var split = GameSimulation(state: state)
    let singleEvents = try single.advance(by: .nanoseconds(3_000_000_000))
    var splitEvents: [GameEvent] = []
    for _ in 0..<3 {
        splitEvents += try split.advance(by: .nanoseconds(1_000_000_000))
    }
    XCTAssertEqual(single.state, split.state)
    XCTAssertEqual(singleEvents, splitEvents)
}
~~~

Also prove schemaVersion remains 2, procedural level-192 round-trip, wrong authored tier rejection, overflow rollback, farming repeat, queued return, and third-death retreat.

- [ ] **Step 2: Run RED**

Run CampaignAreaOneIntegrationTests, SaveDocumentTests, GameSimulationTests, and EncounterDirectorTests with .build/CampaignCompatibilityRed.

Expected: schedule validation is still duplicated and authored fixtures expose mismatches.

- [ ] **Step 3: Replace schedule-only validation**

In GameSimulation.validateStateAndBalance and SaveCodec.validate, resolve the stored enemy level and require the resolved tier to equal state.encounter.tier. SaveCodec throws `SaveValidationError.invalidCampaign`; GameSimulation throws `SimulationError.invalidState` for a mismatch:

~~~swift
guard let resolved = try? CampaignResolver().resolve(level: state.encounter.enemyLevel),
      resolved.tier == state.encounter.tier else {
    throw SaveValidationError.invalidCampaign // use .invalidState in GameSimulation
}
~~~

Validate that the next positive level resolves, but do not compare stored current/max health, attack, defense, or timers to a reconstructed enemy. Save decode must preserve the in-progress state exactly. Runtime failure remains transactional through GameSimulation candidate-copy semantics.

- [ ] **Step 4: Run GREEN and commit**

~~~bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/CampaignCompatibilityGreen CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/CampaignAreaOneIntegrationTests -only-testing:DockBarHeroTests/SaveDocumentTests -only-testing:DockBarHeroTests/GameSimulationTests -only-testing:DockBarHeroTests/EncounterDirectorTests -only-testing:DockBarHeroTests/ProgressionSafetyTests -only-testing:DockBarHeroTests/HeroesAndPartyTests
git diff --check
git add DockBarHero/Game/GameSimulation.swift DockBarHero/Persistence/SaveDocument.swift DockBarHeroTests/CampaignAreaOneIntegrationTests.swift DockBarHeroTests/SaveDocumentTests.swift DockBarHeroTests/GameSimulationTests.swift DockBarHero.xcodeproj
git commit -m "test: preserve authored campaign compatibility"
~~~

Expected: schema v2 and both authored/procedural compatibility paths pass.

---

### Task 4: Present Area And Enemy Identity

**Files:**
- Modify: DockBarHero/Game/GameModels.swift
- Modify: DockBarHero/Game/GameSimulation.swift
- Modify: DockBarHero/App/ManagementSupport.swift
- Modify: DockBarHero/App/OverviewView.swift
- Modify: DockBarHeroTests/ManagementViewTests.swift
- Modify: DockBarHeroTests/GameSimulationTests.swift

**Interfaces:**
- Consumes: ResolvedCampaignEncounter.
- Produces: CampaignPresentation, GamePresentation.campaign, and named authored farming choices.

- [ ] **Step 1: Write failing projection/format tests**

~~~swift
func testGamePresentationCarriesAuthoredIdentityWithoutSavingIt() throws {
    let state = try authoredState(level: 15)
    let campaign = try XCTUnwrap(GameSimulation(state: state).presentation.campaign)
    XCTAssertEqual(campaign.areaFullName, "The Forgotten Shallow Depths That Were Remembered")
    XCTAssertEqual(campaign.areaShortName, "Shallow Depths")
    XCTAssertEqual(campaign.enemyName, "Poison Naga Queen")
    XCTAssertEqual(campaign.enemySpriteID, .poisonNagaQueen)
    let json = String(data: try JSONEncoder().encode(state), encoding: .utf8)!
    XCTAssertFalse(json.contains("Poison Naga Queen"))
}

func testManagementFormatsAuthoredAndProceduralDestinations() {
    XCTAssertEqual(ManagementFormat.destination(level: 9), "Mimic · Enemy Lv. 9")
    XCTAssertEqual(ManagementFormat.destination(level: 26), "Enemy Lv. 26")
}
~~~

- [ ] **Step 2: Run RED**

Run ManagementViewTests and GameSimulationTests with .build/CampaignPresentationRed.

Expected: CampaignPresentation and destination(level:) do not exist.

- [ ] **Step 3: Add the transient projection and management copy**

~~~swift
struct CampaignPresentation: Equatable, Sendable {
    let areaID: AreaID
    let areaFullName: String
    let areaShortName: String
    let enemyID: EnemyContentID
    let enemyName: String
    let enemySpriteID: EnemySpriteID
    let tier: EnemyTierID
    let level: Int
}
~~~

Add var campaign: CampaignPresentation? = nil to GamePresentation. GameSimulation.presentation maps authored resolver data to this value; procedural fallback returns nil.

Overview shows the full area name, enemy name, tier, and explicit enemy level. The farming menu calls ManagementFormat.destination(level:), which resolves names for 1...25 and preserves Enemy Lv. N for procedural levels. Keep all existing Hero Lv., Enemy Lv., and Item Lv. copy.

- [ ] **Step 4: Run GREEN and commit**

Run ManagementViewTests, GameSimulationTests, AppModelTests, and SaveDocumentTests with .build/CampaignPresentationGreen, then:

~~~bash
git add DockBarHero/Game/GameModels.swift DockBarHero/Game/GameSimulation.swift DockBarHero/App/ManagementSupport.swift DockBarHero/App/OverviewView.swift DockBarHeroTests/ManagementViewTests.swift DockBarHeroTests/GameSimulationTests.swift
git commit -m "feat: present authored campaign identity"
~~~

Expected: management exposes authored identity while encoded save shape remains unchanged.

---

### Task 5: Resolve Enemy Sprites With Generic Fallback

**Files:**
- Modify: DockBarHero/Rendering/SpriteCatalog.swift
- Modify: DockBarHero/Rendering/PrototypeScene.swift
- Modify: DockBarHeroTests/SpriteCatalogTests.swift
- Modify: DockBarHeroTests/PrototypeSceneHostTests.swift

**Interfaces:**
- Consumes: GamePresentation.campaign?.enemySpriteID.
- Produces: SpriteCatalog.textures(forEnemy:action:) and stable enemy identity transitions.

- [ ] **Step 1: Write failing sprite tests**

~~~swift
func testMissingEnemyIdentityUsesGenericEnemy() {
    let catalog = BuiltinSpriteCatalog()
    XCTAssertEqual(
        catalog.pixelData(forEnemy: EnemySpriteID(rawValue: "missing.enemy"), action: .attack),
        catalog.pixelData(for: .enemy, action: .attack)
    )
}
~~~

Also test identity action, missing action to identity idle, invalid identity pixels to magenta diagnostic fallback, and presentation identity change updating the enemy idle texture.

- [ ] **Step 2: Run RED**

Run SpriteCatalogTests and PrototypeSceneHostTests with .build/CampaignSpriteRed.

Expected: forEnemy APIs do not exist.

- [ ] **Step 3: Extend sprite resolution without adding Area 1 art**

Preserve the existing hero/token API and add:

~~~swift
@MainActor
protocol SpriteCatalog: AnyObject {
    func textures(for token: SpriteToken, action: SpriteAction) -> [SKTexture]
    func textures(forEnemy spriteID: EnemySpriteID, action: SpriteAction) -> [SKTexture]
}
~~~

Add a default protocol extension that routes `textures(forEnemy:action:)` to `.enemy`, preserving existing test fakes and alternate catalogs. `BuiltinSpriteCatalog` then overrides it and accepts an optional identity definition dictionary. Resolution order is identity action, identity idle, generic enemy action, generic enemy idle, magenta fallback.

PrototypeScene stores renderedEnemySpriteID. render(_:) updates idle texture only when the ID changes. Enemy attack, hit, and defeated actions use the stored ID. Procedural presentation uses generic.enemy.

- [ ] **Step 4: Run GREEN and commit**

~~~bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/CampaignSpriteGreen CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/SpriteCatalogTests -only-testing:DockBarHeroTests/PrototypeSceneHostTests
git diff --check
git add DockBarHero/Rendering/SpriteCatalog.swift DockBarHero/Rendering/PrototypeScene.swift DockBarHeroTests/SpriteCatalogTests.swift DockBarHeroTests/PrototypeSceneHostTests.swift
git commit -m "feat: resolve authored enemy sprites"
~~~

Expected: all authored IDs use generic fallback until later assets arrive; procedural behavior is unchanged.

---

### Task 6: Add The Area Marquee And Interactive Hover Replay

**Files:**
- Create: DockBarHero/Rendering/AreaTitleMarquee.swift
- Modify: DockBarHero/Rendering/PrototypeScene.swift
- Modify: DockBarHero/Rendering/PrototypeSceneHost.swift
- Create: DockBarHeroTests/AreaTitleMarqueeTests.swift
- Modify: DockBarHeroTests/PrototypeSceneHostTests.swift

**Interfaces:**
- Consumes: CampaignPresentation, animation state, and local pointer location.
- Produces: AreaTitleMarqueeState, clipped areaTitleCrop/areaTitle nodes, and Interactive-only hover replay.

- [ ] **Step 1: Write failing pure-state tests**

~~~swift
func testInteractiveHoverReplaysOnceAfterThreeSecondsAndRequiresReentry() {
    var state = AreaTitleMarqueeState()
    state.present(
        areaID: .forgottenShallowDepths,
        fullName: "The Forgotten Shallow Depths That Were Remembered",
        shortName: "Shallow Depths",
        animationsEnabled: true
    )
    state.completeScroll()
    XCTAssertFalse(state.advanceHover(by: 2.999, inside: true, interactive: true, animationsEnabled: true))
    XCTAssertTrue(state.advanceHover(by: 0.001, inside: true, interactive: true, animationsEnabled: true))
    state.completeScroll()
    XCTAssertFalse(state.advanceHover(by: 3, inside: true, interactive: true, animationsEnabled: true))
    _ = state.advanceHover(by: 0, inside: false, interactive: true, animationsEnabled: true)
    XCTAssertTrue(state.advanceHover(by: 3, inside: true, interactive: true, animationsEnabled: true))
}
~~~

Also test initial pass, same-area stability, area change, class/party hiding, disabled-animation settlement, 2.999-second rejection, early leave reset, and Passive rejection.

- [ ] **Step 2: Run RED**

Run AreaTitleMarqueeTests and PrototypeSceneHostTests with .build/CampaignMarqueeRed.

Expected: marquee state and nodes do not exist.

- [ ] **Step 3: Implement the pure state machine**

Use phases hidden, scrolling(fullName:shortName:), and settled(shortName:). Track areaID, continuous hover duration, and requiresPointerExit. present restarts only for a different area. completeScroll settles. advanceHover returns true once when replay should begin.

- [ ] **Step 4: Build the clipped center title lane**

In didMove, create SKCropNode areaTitleCrop with a shape mask and child SKLabelNode areaTitle. Center at x = size.width / 2 and y = 84. Clamp lane width between 180 and 300 points to avoid hero actions and the enemy/farming column.

Scroll the full title right-to-left at 30 points per second, then settle to Shallow Depths. When animation is disabled, show the short title immediately. Hide and reset title nodes for class selection, party selection, and procedural presentations where `GamePresentation.campaign` is nil. Keep DPS centered at y = 70 and preserve the orange farming line.

- [ ] **Step 5: Add local hover tracking**

Create private RailTrackingView: SKView in PrototypeSceneHost.swift. Add a local tracking area with mouseMoved, mouseEnteredAndExited, activeInKeyWindow, and inVisibleRect. Convert points into scene coordinates. Do not use a global NSEvent monitor.

setInteractive(false) disables tracking and clears the pointer. PrototypeScene.update(_:) accumulates hover only when interactive, animations enabled, and inside the title crop. Add advanceMarqueeForTesting(by:pointerInside:) so tests never sleep.

- [ ] **Step 6: Run GREEN and commit**

~~~bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/CampaignMarqueeGreen CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/AreaTitleMarqueeTests -only-testing:DockBarHeroTests/PrototypeSceneHostTests -only-testing:DockBarHeroTests/OverlayWindowControllerTests -only-testing:DockBarHeroTests/OverlayStateTests
git diff --check
git add DockBarHero/Rendering/AreaTitleMarquee.swift DockBarHero/Rendering/PrototypeScene.swift DockBarHero/Rendering/PrototypeSceneHost.swift DockBarHeroTests/AreaTitleMarqueeTests.swift DockBarHeroTests/PrototypeSceneHostTests.swift DockBarHero.xcodeproj
git commit -m "feat: animate authored area title"
~~~

Expected: marquee passes without changing Passive click-through or overlay behavior.

---

### Task 7: Balance, Full Verification, Disposable Live QA, And Push Gate

**Files:**
- Modify: DockBarHeroTests/CampaignAreaOneIntegrationTests.swift
- Create: docs/qa/review-packets/campaign-area-one.md
- Modify: PROJECT.md only after all gates pass.

**Interfaces:**
- Consumes: the complete authored campaign slice.
- Produces: three-class balance proof, clean-save live evidence, restored user data, verified context, and optionally the pushed branch.

- [ ] **Step 1: Complete deterministic three-class balance coverage**

For Tank, DPS, and Healer, simulate a clean authored campaign from level 1 through Boss 25 using ordinary deterministic drops, auto-equip, existing farming/retreat rules, and no injected items or stats. Each class must reach the durable Boss 25 party-choice state within a generous deterministic step cap.

If a class cannot complete, tune only EnemyStatProfile values in CampaignCatalog.standard, assert the exact adjusted values, and rerun catalog/factory/balance suites. Do not change class growth, item formulas, tier ratios, rewards, or combat rules.

- [ ] **Step 2: Run focused and full gates**

~~~bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/CampaignFocused CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/CampaignCatalogTests -only-testing:DockBarHeroTests/CampaignResolverTests -only-testing:DockBarHeroTests/EnemyFactoryTests -only-testing:DockBarHeroTests/CampaignAreaOneIntegrationTests -only-testing:DockBarHeroTests/EncounterDirectorTests -only-testing:DockBarHeroTests/SaveDocumentTests -only-testing:DockBarHeroTests/HeroesAndPartyTests -only-testing:DockBarHeroTests/ManagementViewTests -only-testing:DockBarHeroTests/SpriteCatalogTests -only-testing:DockBarHeroTests/AreaTitleMarqueeTests -only-testing:DockBarHeroTests/PrototypeSceneHostTests
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/CampaignFull CODE_SIGNING_ALLOWED=NO
xcodebuild clean build -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/CampaignBuild CODE_SIGNING_ALLOWED=NO
python3 /Users/n3kr0/.codex/skills/maintaining-project-context/scripts/context_guard.py check --root .
git diff --check
~~~

Expected: focused/full tests and clean build succeed, context is valid, and diff check is clean. Record exact counts and paths.

- [ ] **Step 3: Archive current saves and settings**

~~~bash
SAVE_DIR="$HOME/Library/Application Support/com.n3kr0nom1c0n.DockBarHero"
STAMP="$(date +%Y%m%d-%H%M%S)"
ARCHIVE="$SAVE_DIR/campaign-area-one-pre-qa-$STAMP"
mkdir -p "$ARCHIVE"
for name in save-v2.json save-v2.backup.json save-v2.pending.json settings-v1.json settings-v1.backup.json; do
  if test -f "$SAVE_DIR/$name"; then
    cp -p "$SAVE_DIR/$name" "$ARCHIVE/$name"
    cmp "$SAVE_DIR/$name" "$ARCHIVE/$name"
    shasum -a 256 "$ARCHIVE/$name"
  fi
done
rm -f "$SAVE_DIR/save-v2.json" "$SAVE_DIR/save-v2.backup.json" "$SAVE_DIR/save-v2.pending.json"
~~~

Expected: every copy passes cmp; active gameplay saves are absent; settings remain in place.

- [ ] **Step 4: Launch the exact bundle and perform clean DPS QA**

~~~bash
pkill -x DockBarHero 2>/dev/null || true
./script/build_and_run.sh --verify
ps -axo pid=,command= | awk '/DockBarHero\.app\/Contents\/MacOS\/DockBarHero$/ {print}'
~~~

Expected: exactly one process from the campaign worktree bundle.

Using the unlocked UI, select DPS and progress naturally through level 25 without editing saves. Verify:

1. Full title scrolls once and settles on Shallow Depths.
2. Three-second hover replay works in Interactive mode and not Passive mode.
3. The seven normals and four elites appear at exact authored levels.
4. Management shows visible health/attack/defense/interval tendencies.
5. Generic enemy sprite fallback has no missing-texture failure.
6. Farming identity and orange frontier status remain correct through queued Return to Frontier.
7. Unknown Guardian appears at Boss 25.
8. Rewards and the durable second-class choice survive relaunch.
9. Choosing the second class begins procedural level 26 with the generic label.
10. Placement, party layout, DPS, focus, fullscreen suppression, and Passive click-through remain accepted.

If UI control, exact process identity, or an observation is unavailable, stop and do not push.

- [ ] **Step 5: Delete disposable state and restore originals**

~~~bash
pkill -x DockBarHero 2>/dev/null || true
rm -f "$SAVE_DIR/save-v2.json" "$SAVE_DIR/save-v2.backup.json" "$SAVE_DIR/save-v2.pending.json"
for name in save-v2.json save-v2.backup.json save-v2.pending.json settings-v1.json settings-v1.backup.json; do
  if test -f "$ARCHIVE/$name"; then
    cp -p "$ARCHIVE/$name" "$SAVE_DIR/$name"
    cmp "$ARCHIVE/$name" "$SAVE_DIR/$name"
    shasum -a 256 "$SAVE_DIR/$name"
  fi
done
~~~

Expected: disposable saves are gone; originals are restored byte-identically. Retain the archive.

- [ ] **Step 6: Record evidence and commit**

Create docs/qa/review-packets/campaign-area-one.md containing scope, exclusions, commits, focused/full/build evidence, save hashes, exact process path, every live observation, any profile tuning, and open manual items. Update PROJECT.md under existing headings, keep it at or below 150 lines, and include only fresh verified facts.

~~~bash
python3 /Users/n3kr0/.codex/skills/maintaining-project-context/scripts/context_guard.py check --root .
git diff --check
git add docs/qa/review-packets/campaign-area-one.md PROJECT.md
git add DockBarHero/Game/CampaignCatalog.swift DockBarHeroTests/CampaignCatalogTests.swift DockBarHeroTests/CampaignAreaOneIntegrationTests.swift
git commit -m "docs: verify authored campaign area one"
~~~

Only stage the catalog/test files if final verified balance tuning changed them after Task 6.

- [ ] **Step 7: Stop caffeinate and push only on complete success**

~~~bash
CAFFEINATE_PID="$(cat /tmp/dockbarhero-campaign-caffeinate.pid)"
kill "$CAFFEINATE_PID"
while kill -0 "$CAFFEINATE_PID" 2>/dev/null; do sleep 1; done
rm -f /tmp/dockbarhero-campaign-caffeinate.pid
test -z "$(git status --porcelain)"
git log --oneline --decorate -10
git push -u origin feature/campaign-area-one
~~~

Expected: the recorded assertion is stopped, worktree is clean, and upstream becomes origin/feature/campaign-area-one. Do not merge or release.

If any gate remains unproven, still restore user files and stop the recorded caffeinate PID, but skip the push and report the exact local commit and blocker.
