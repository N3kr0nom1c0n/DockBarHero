# DockBarHero Item Depth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add deterministic rarity, affixes, Unique definitions, effective item stats, hero-specific comparisons and auto-equip scoring, and durable item locking.

**Architecture:** Enrich each durable item with canonical content fields, generate ordinary loot through a pure `LootGenerator`, derive hero combat values through `ItemStatResolver`, and compare equipment through `ItemScoreResolver`. `GameSimulation` and `RewardResolver` retain candidate-state transaction ownership; SwiftUI renders pure row models and submits typed intents.

**Tech Stack:** Swift 6, SwiftUI, XCTest, XcodeGen, macOS arm64.

## Global Constraints

- Execute after Class Actions on the same stacked branch; never merge to `main` during the overnight run.
- Preserve schema version 2 and start clean because development saves are unreleased.
- Use stable integer mixing only; never use runtime randomness, wall time, locale, or collection iteration order.
- Rarities and affix counts: Common 0, Uncommon 1, Rare 2, Epic 3; Unique is authored only.
- Affixes: Might, Ward, Vitality, Haste; no Class Action modifiers, procs, crits, elements, crafting, or salvage.
- Use checked integer arithmetic and transactional rollback for generation, stats, equip, locking, reward, and save operations.

---

### Task 1: Canonical Item Content and Validation

**Files:**
- Modify: `DockBarHero/Game/GameModels.swift`
- Create: `DockBarHero/Game/LootConfiguration.swift`
- Modify: `DockBarHero/Persistence/SaveDocument.swift`
- Create: `DockBarHeroTests/LootConfigurationTests.swift`
- Modify: `DockBarHeroTests/SaveDocumentTests.swift`

**Interfaces:**
- Produces: `ItemTemplateID`, `ItemRarity`, `AffixID`, `ItemAffix`, enriched `Item`, and `LootConfiguration.standard`.

- [ ] **Step 1: Write failing canonical-content tests**

```swift
func testRarityOrderAndAffixCountsAreStable() {
    XCTAssertEqual(ItemRarity.allCases, [.common, .uncommon, .rare, .epic, .unique])
    XCTAssertEqual(LootConfiguration.standard.affixCount(for: .common), 0)
    XCTAssertEqual(LootConfiguration.standard.affixCount(for: .epic), 3)
}

func testSaveRejectsDuplicateOrWrongSlotAffixes() throws {
    var state = GameState.newGame(balance: .standard)
    state.inventory = [try item(rarity: .rare, slot: .weapon, affixes: [
        .init(id: .might, magnitude: 10), .init(id: .might, magnitude: 12),
    ])]
    XCTAssertThrowsError(try SaveCodec().encode(state: state, savedAt: .distantPast))
}
```

- [ ] **Step 2: Run RED**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/ItemContentRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/LootConfigurationTests -only-testing:DockBarHeroTests/SaveDocumentTests
```

Expected: compile failure because content types are absent.

- [ ] **Step 3: Add exact durable types**

```swift
struct ItemTemplateID: RawRepresentable, Codable, Hashable, Sendable { let rawValue: String }
enum ItemRarity: String, Codable, CaseIterable, Comparable, Sendable {
    case common, uncommon, rare, epic, unique
    static func < (lhs: Self, rhs: Self) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}
enum AffixID: String, Codable, CaseIterable, Comparable, Sendable {
    case haste, might, vitality, ward
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}
struct ItemAffix: Codable, Equatable, Sendable { let id: AffixID; let magnitude: Int }
```

Extend `Item` with `templateID`, `rarity`, `affixes`, `isLocked`, and optional `uniqueName`. Ordinary templates are `ordinary.weapon` and `ordinary.armor`.

- [ ] **Step 4: Validate definitions and save content**

`LootConfiguration.validate(_:)` requires canonical affix ordering, positive magnitudes, exact rarity count, legal slot pools, Unique authored definition match, permanent Unique lock, and no ordinary `uniqueName`. Call it for every inventory item before equipment validation.

- [ ] **Step 5: Run GREEN and commit**

Repeat Step 2 with `.build/ItemContentGreen`, then:

```bash
git add DockBarHero/Game/GameModels.swift DockBarHero/Game/LootConfiguration.swift DockBarHero/Persistence/SaveDocument.swift DockBarHeroTests/LootConfigurationTests.swift DockBarHeroTests/SaveDocumentTests.swift
git commit -m "feat: add durable item content"
```

### Task 2: Deterministic Rarity and Affix Generation

**Files:**
- Create: `DockBarHero/Game/LootGenerator.swift`
- Modify: `DockBarHero/Game/LootSystem.swift`
- Create: `DockBarHeroTests/LootGeneratorTests.swift`
- Modify: `DockBarHeroTests/RewardResolverTests.swift`

**Interfaces:**
- Produces: `LootGenerator.generate(defeatedLevel:tier:sequence:slot:) throws -> Item`.

- [ ] **Step 1: Write failing boundary and replay tests**

```swift
func testTierTablesCoverExactlyTenThousandBasisPoints() {
    for tier in EnemyTierID.allCases {
        XCTAssertEqual(LootConfiguration.standard.rarityTable(for: tier).reduce(0) { $0 + $1.weight }, 10_000)
    }
}

func testIdenticalInputsProduceIdenticalCanonicalItem() throws {
    let generator = LootGenerator(configuration: .standard, balance: .standard)
    let a = try generator.generate(defeatedLevel: 25, tier: .boss, sequence: 41, slot: .weapon)
    let b = try generator.generate(defeatedLevel: 25, tier: .boss, sequence: 41, slot: .weapon)
    XCTAssertEqual(a, b)
    XCTAssertEqual(a.affixes, a.affixes.sorted { $0.id < $1.id })
}
```

Add fixture searches proving Normal/Elite/Boss can reach every nonzero rarity bucket, bosses never yield Common, affix counts match rarity, pools respect slot, values stay within approved ranges, and sequence overflow rolls back rewards.

- [ ] **Step 2: Run RED**

Run LootGenerator and RewardResolver tests with `.build/LootGeneratorRed`. Expected: generator missing.

- [ ] **Step 3: Implement stable mixing and generation**

Use a documented SplitMix64-style value mixer with fixed constants. Seed with sequence, level, tier ordinal, and slot ordinal; consume a new mixed value for rarity, affix permutation, and each magnitude. Map `roll % 10_000` through cumulative tables. Convert Might/Ward/Vitality percentages against validated level baselines with rounding up; Haste magnitude is the rolled percentage in basis points.

- [ ] **Step 4: Route `LootSystem.drop` through the generator**

Preserve sequence allocation, duplicate identity rejection, alternating slots, inventory append, and full reward rollback. Emit the enriched `.loot(Item)` event without presentation-side reconstruction.

- [ ] **Step 5: Run GREEN and commit**

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/LootGeneratorGreen CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/LootGeneratorTests -only-testing:DockBarHeroTests/RewardResolverTests
git add DockBarHero/Game/LootGenerator.swift DockBarHero/Game/LootSystem.swift DockBarHeroTests/LootGeneratorTests.swift DockBarHeroTests/RewardResolverTests.swift
git commit -m "feat: generate deterministic rarity and affixes"
```

### Task 3: Effective Affix Stats

**Files:**
- Create: `DockBarHero/Game/ItemStatResolver.swift`
- Modify: `DockBarHero/Game/CombatResolver.swift`
- Modify: `DockBarHero/Game/GameSimulation.swift`
- Create: `DockBarHeroTests/ItemStatResolverTests.swift`
- Modify: `DockBarHeroTests/GameSimulationTests.swift`

**Interfaces:**
- Produces: `HeroEffectiveStats` and `ItemStatResolver.stats(heroSlot:in:) throws`.

- [ ] **Step 1: Write failing stat behavior tests**

```swift
func testHasteAddsAcrossEquipmentCapsAndClampsCountdown() throws {
    var state = try equippedAffixFixture(hasteWeapon: 2_500, hasteArmor: 2_500)
    let stats = try ItemStatResolver().stats(heroSlot: 0, in: state)
    XCTAssertEqual(stats.hasteBasisPoints, 4_000)
    XCTAssertEqual(stats.attackInterval, .milliseconds(600)!)
}

func testVitalityEquipPreservesMissingHealthAndCannotRevive() throws {
    var simulation = GameSimulation(state: try vitalityEquipFixture(current: 70, maximum: 100, bonus: 40))
    _ = try simulation.apply(.equip(ItemID(rawValue: 2)))
    XCTAssertEqual(simulation.state.hero.maxHealth, 140)
    XCTAssertEqual(simulation.state.hero.currentHealth, 110)
}
```

- [ ] **Step 2: Run RED**

Run ItemStatResolver and GameSimulation tests with `.build/ItemStatsRed`. Expected: resolver missing and current combat ignores affixes.

- [ ] **Step 3: Implement resolver and combat integration**

`HeroEffectiveStats` contains attack, defense, maximumHealth, attackInterval, and hasteBasisPoints. Sum legal equipped affixes with checked operations, cap Haste at 4,000, apply it to base interval, and enforce `.minimumAttackInterval`. `CombatResolver` delegates attack/defense and timer resets to this resolver.

- [ ] **Step 4: Make equipment changes transactional**

Before/after equip, calculate effective stats. Preserve missing health when maximum changes; keep zero health zero; clamp a living hero to at least one. Clamp `timeUntilNextAttack` to the new interval. Any failure rejects the candidate.

- [ ] **Step 5: Run GREEN and commit**

Repeat Step 2 with `.build/ItemStatsGreen`, then commit `ItemStatResolver`, combat/simulation changes, and tests as `feat: apply item affix stats`.

### Task 4: Hero-Specific Item Scoring and Auto-Equip

**Files:**
- Create: `DockBarHero/Game/ItemScoreResolver.swift`
- Modify: `DockBarHero/Game/CombatResolver.swift`
- Modify: `DockBarHero/Game/RewardResolver.swift`
- Create: `DockBarHeroTests/ItemScoreResolverTests.swift`
- Modify: `DockBarHeroTests/RewardResolverTests.swift`

**Interfaces:**
- Produces: `ItemComparison`, `ItemScoreResolver.compare(item:heroSlot:in:) throws`.

- [ ] **Step 1: Write failing weight and tie tests**

```swift
func testDPSWeightsAttackAndHasteOverDefense() throws {
    let result = try ItemScoreResolver().compare(item: try mixedWeapon(), heroSlot: 0, in: try dpsFixture())
    XCTAssertGreaterThan(result.candidateScore, result.currentScore)
    XCTAssertEqual(result.deltas.attack, 12)
    XCTAssertLessThan(result.deltas.attackInterval.rawValue, 0)
}

func testEqualScoreKeepsCurrentItem() throws {
    XCTAssertFalse(try ItemScoreResolver().compare(item: try equalArmor(), heroSlot: 0, in: try tankFixture()).isStrictUpgrade)
}
```

- [ ] **Step 2: Run RED**

Run score and reward tests with `.build/ItemScoreRed`. Expected: scoring resolver missing.

- [ ] **Step 3: Implement normalized checked scoring**

Normalize attack, defense, health, and Haste to basis points against the class expected values at item level. Multiply by the approved weight matrix, sum with overflow checks, and return exact stat deltas. `isStrictUpgrade` is candidate score greater than current score.

- [ ] **Step 4: Replace primary-stat auto-equip selection**

For each eligible hero compare the dropped item. Choose greatest positive improvement, then lower party slot. Existing exclusive equipment and transaction rules remain. Newcomer strongest-unused selection uses score for that hero and the approved rarity/level/sequence/ID tie order.

- [ ] **Step 5: Run GREEN and commit**

Repeat Step 2 with `.build/ItemScoreGreen`, then commit as `feat: score loot by hero class`.

### Task 5: Durable Locking and Item-Depth Management

**Files:**
- Modify: `DockBarHero/Game/GameModels.swift`
- Modify: `DockBarHero/Game/GameSimulation.swift`
- Modify: `DockBarHero/App/InventoryView.swift`
- Modify: `DockBarHero/App/ManagementSupport.swift`
- Modify: `DockBarHeroTests/GameSimulationTests.swift`
- Modify: `DockBarHeroTests/ManagementViewTests.swift`

**Interfaces:**
- Produces: `GameIntent.setItemLocked(itemID:isLocked:)` and enriched `InventoryRow` comparison presentation.

- [ ] **Step 1: Write failing lock and row tests**

```swift
func testOrdinaryItemLockTogglesButUniqueUnlockRejects() throws {
    var simulation = GameSimulation(state: try lockFixture())
    XCTAssertEqual(try simulation.apply(.setItemLocked(itemID: .init(rawValue: 1), isLocked: true)), [.itemLockChanged(itemID: .init(rawValue: 1), isLocked: true)])
    let before = simulation.state
    XCTAssertThrowsError(try simulation.apply(.setItemLocked(itemID: .init(rawValue: 2), isLocked: false)))
    XCTAssertEqual(simulation.state, before)
}
```

- [ ] **Step 2: Run RED**

Run simulation and management tests with `.build/ItemLockRed`. Expected: intent and fields missing.

- [ ] **Step 3: Add lock transaction and presentation**

Resolve exactly one item ID, reject Unique unlock, mutate only `isLocked`, and emit `itemLockChanged`. Inventory rows show rarity text/color token, template/Unique name, affixes, lock state, selected-hero score, exact deltas, and equipped owner. Add accessible Lock/Unlock buttons; color is never the only state indicator.

- [ ] **Step 4: Run GREEN and commit**

Repeat Step 2 with `.build/ItemLockGreen`, then commit as `feat: add loot comparison and locking`.

### Task 6: Item Depth Integrated Gate and Live QA

**Files:**
- Create: `DockBarHeroTests/ItemDepthIntegrationTests.swift`
- Create: `docs/qa/review-packets/item-depth.md`
- Modify: `PROJECT.md` after verification only.

- [ ] **Step 1: Add integrated replay/save/equip tests**

Test a deterministic 100-drop sequence twice, all tier rarity boundaries, save/reload, three-class scoring, Haste partition invariance, Vitality equip health preservation, lock persistence, and injected overflow rollback.

- [ ] **Step 2: Run focused and full gates**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/ItemDepthFocused CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/ItemDepthIntegrationTests -only-testing:DockBarHeroTests/LootGeneratorTests -only-testing:DockBarHeroTests/ItemStatResolverTests -only-testing:DockBarHeroTests/ItemScoreResolverTests -only-testing:DockBarHeroTests/SaveDocumentTests -only-testing:DockBarHeroTests/ManagementViewTests
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/ItemDepthFull CODE_SIGNING_ALLOWED=NO
xcodebuild clean build -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/ItemDepthBuild CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 3: Run clean-save live QA and final guards**

Archive gameplay saves with hashes, preserve settings, launch the exact bundle, observe Common through Epic drops, compare all four deltas for three classes, verify auto-equip, Haste countdown, Vitality health, lock/relaunch, and Unique fixture presentation. Then run context guard, launch verify, and diff check.

- [ ] **Step 4: Record and commit verified evidence**

Update `PROJECT.md` and `docs/qa/review-packets/item-depth.md` with exact facts, keep context limits, commit as `docs: verify item depth milestone`, and leave the branch ready for Inventory Operations.
