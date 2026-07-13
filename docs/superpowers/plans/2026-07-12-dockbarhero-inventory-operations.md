# DockBarHero Inventory Operations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add deterministic equipment stacking, finite and purchasable inventory capacity, durable overflow, filters, sorting, quantity selection, and atomic salvage.

**Architecture:** Replace the flat item array with validated `InventoryState` collections for ordinary stacks, equipped/Unique instances, and overflow. Pure `InventoryResolver` and `SalvageResolver` return complete candidate state, while presentation uses transient query and selection models.

**Tech Stack:** Swift 6, SwiftUI, XCTest, XcodeGen, macOS arm64.

## Global Constraints

- Execute only after Item Depth passes its complete gate.
- Capacity counts stacks, equipped instances, and Unique instances; overflow does not count.
- Starting capacity 40, Boss 25 +10, Boss 100 +20, purchases +10, release cap 200.
- Purchase prices start at 500 gold and double; all prices remain `InventoryConfiguration` data for post-build tuning.
- Stack signatures include template, level, rarity, ordered affixes, and lock state; authored templates own slot and primary-stat semantics.
- Equipped and Unique items remain individual; Unique, equipped, and locked content is never salvageable.
- Every inventory/economy operation is checked and atomic; no item is silently deleted.

---

### Task 1: Inventory State, Stack Signatures, and Save Validation

**Files:**
- Modify: `DockBarHero/Game/GameModels.swift`
- Create: `DockBarHero/Game/InventoryConfiguration.swift`
- Create: `DockBarHero/Game/InventoryResolver.swift`
- Modify: `DockBarHero/Persistence/SaveDocument.swift`
- Create: `DockBarHeroTests/InventoryResolverTests.swift`
- Modify: `DockBarHeroTests/SaveDocumentTests.swift`

- [ ] **Step 1: Write failing stack equality and validation tests**

```swift
func testOnlyExactOrdinaryDescriptorsStack() throws {
    let resolver = InventoryResolver(configuration: .standard)
    let base = try ordinaryItem(level: 10, locked: false)
    XCTAssertTrue(resolver.canStack(base, with: base))
    XCTAssertFalse(resolver.canStack(base, with: try ordinaryItem(level: 10, locked: true)))
    XCTAssertFalse(resolver.canStack(base, with: try uniqueItem()))
}
```

- [ ] **Step 2: Run RED**

Run InventoryResolver and SaveDocument suites with `.build/InventoryStateRed`. Expected: inventory state types missing.

- [ ] **Step 3: Add exact state types**

```swift
struct InventoryStackID: RawRepresentable, Codable, Hashable, Sendable { let rawValue: UInt64 }
struct ItemStack: Identifiable, Codable, Equatable, Sendable {
    let id: InventoryStackID
    var descriptor: ItemDescriptor
    var quantity: UInt64
    let creationSequence: UInt64
}
struct InventoryState: Codable, Equatable, Sendable {
    var stacks: [ItemStack]
    var instances: [Item]
    var overflowStacks: [ItemStack]
    var overflowUniqueItems: [Item]
    var purchasedExpansionCount: Int
    var nextStackSequence: UInt64
    var nextItemSequence: UInt64
}
```

Move descriptor fields from `Item` into `ItemDescriptor`; `Item` becomes stable individual ID plus descriptor and creation sequence. Equipment references resolve only to `instances`.

- [ ] **Step 4: Validate canonical inventory state**

Require positive quantities, unique IDs/sequences, no stackable duplicate stack signatures within one location, ordinary-only stacks, Unique-only unstacked overflow, exact equipment references, nonnegative purchase count, derived capacity not exceeded, and next sequences greater than every allocated identity.

- [ ] **Step 5: Run GREEN and commit**

Repeat Step 2 with `.build/InventoryStateGreen`, then commit as `feat: add stacked inventory state`.

### Task 2: Drop Stacking, Capacity, and Overflow

**Files:**
- Modify: `DockBarHero/Game/InventoryResolver.swift`
- Modify: `DockBarHero/Game/LootSystem.swift`
- Modify: `DockBarHero/Game/RewardResolver.swift`
- Modify: `DockBarHeroTests/InventoryResolverTests.swift`
- Modify: `DockBarHeroTests/RewardResolverTests.swift`

- [ ] **Step 1: Write failing capacity and overflow tests**

```swift
func testFullInventoryJoinsMatchingStackOtherwiseUsesOverflow() throws {
    var state = try fullInventoryFixture(capacity: 40)
    let matching = try ordinaryItem(level: 5)
    let joined = try InventoryResolver().insertDrop(matching, into: state)
    XCTAssertEqual(joined.inventory.stacks.first(where: { $0.descriptor == matching.descriptor })?.quantity, 2)
    let different = try ordinaryItem(level: 6)
    let overflowed = try InventoryResolver().insertDrop(different, into: state)
    XCTAssertEqual(overflowed.inventory.overflowStacks.last?.descriptor, different.descriptor)
}
```

- [ ] **Step 2: Run RED**

Run resolver and reward tests with `.build/InventoryDropRed`. Expected: flat append ignores capacity.

- [ ] **Step 3: Implement capacity derivation and insertion**

`capacity(for:)` returns 40 plus milestone grants plus `10 * purchasedExpansionCount`, capped at 200. `occupiedSlots` counts stacks and instances. Insert ordinary drops into a matching inventory stack even when full, otherwise create inventory stack if capacity exists, otherwise merge/create overflow stack. Unique grants create an inventory instance or overflow Unique instance. Use checked identity and quantity increments.

- [ ] **Step 4: Route rewards atomically and run GREEN**

Replace flat append with `InventoryResolver.insertDrop`; keep XP, gold, unlock, and auto-equip within the same reward candidate. Repeat tests with `.build/InventoryDropGreen`, then commit as `feat: add inventory capacity and overflow`.

### Task 3: Equipment Extraction and Return

**Files:**
- Modify: `DockBarHero/Game/InventoryResolver.swift`
- Modify: `DockBarHero/Game/GameSimulation.swift`
- Modify: `DockBarHero/Game/PartyUnlockResolver.swift`
- Modify: `DockBarHeroTests/InventoryResolverTests.swift`
- Modify: `DockBarHeroTests/GameSimulationTests.swift`
- Modify: `DockBarHeroTests/PartyUnlockResolverTests.swift`

- [ ] **Step 1: Write failing extraction/final-capacity tests**

```swift
func testEquipExtractsOneAndReturnsReplacedDescriptorUsingFinalCapacity() throws {
    var state = try stackedEquipFixture(quantity: 2, capacityRemaining: 0)
    let result = try InventoryResolver().equip(stackID: state.inventory.stacks[0].id, heroSlot: 0, in: state)
    XCTAssertEqual(result.inventory.stacks[0].quantity, 1)
    XCTAssertNotNil(result.party.heroes[0].equipment.weaponID)
    XCTAssertEqual(try InventoryResolver().occupiedSlots(in: result), try InventoryResolver().capacity(for: result))
}
```

- [ ] **Step 2: Run RED**

Run inventory, simulation, and unlock tests with `.build/StackEquipRed`. Expected: equip accepts only flat item IDs.

- [ ] **Step 3: Implement final-layout transaction**

Support equip from stack ID or Unique instance ID. Build the complete candidate: extract one unit, allocate individual ID, return replaced ordinary descriptor to a matching/new stack, retain replaced Unique instance, update exclusive reference, apply ItemStatResolver health/timer changes, then validate final occupied slots. Reject rather than overflow when final layout exceeds capacity.

- [ ] **Step 4: Update newcomer equipment and run GREEN**

Score unused stacks and instances, extract strongest choices transactionally, and preserve slot/class tie rules. Repeat tests with `.build/StackEquipGreen`, then commit as `feat: equip items from stacks`.

### Task 4: Capacity Purchases and Overflow Movement

**Files:**
- Modify: `DockBarHero/Game/GameModels.swift`
- Modify: `DockBarHero/Game/InventoryResolver.swift`
- Modify: `DockBarHero/Game/GameSimulation.swift`
- Modify: `DockBarHeroTests/InventoryResolverTests.swift`
- Modify: `DockBarHeroTests/GameSimulationTests.swift`

- [ ] **Step 1: Write failing purchase and move tests**

```swift
func testPurchaseDeductsDoublingPriceAndAddsTenCapacity() throws {
    var state = try economyFixture(gold: 2_000)
    var simulation = GameSimulation(state: state)
    _ = try simulation.apply(.purchaseInventoryCapacity)
    XCTAssertEqual(simulation.state.economy.gold, 1_500)
    XCTAssertEqual(simulation.state.inventory.purchasedExpansionCount, 1)
    XCTAssertEqual(try InventoryResolver().capacity(for: simulation.state), 50)
}
```

Cover 500/1000/2000 price sequence, insufficient gold, checked doubling, 200 cap, Boss 25 pending grant, Boss 100 grant, matching-stack overflow moves at full capacity, and new-stack move rejection.

- [ ] **Step 2: Run RED**

Run resolver and simulation tests with `.build/CapacityPurchaseRed`. Expected: intents missing.

- [ ] **Step 3: Implement typed intents**

Add `.purchaseInventoryCapacity` and `.moveOverflow(stackID:quantity:)`. Purchase calculates checked price, validates final cap, subtracts gold, increments count, and emits capacity/gold events. Move decrements overflow and merges/creates inventory stack only when allowed. Successful changes request normal saves via existing state-difference flow.

- [ ] **Step 4: Run GREEN and commit**

Repeat with `.build/CapacityPurchaseGreen`, then commit as `feat: expand inventory and recover overflow`.

### Task 5: Atomic Salvage

**Files:**
- Create: `DockBarHero/Game/SalvageResolver.swift`
- Modify: `DockBarHero/Game/GameModels.swift`
- Modify: `DockBarHero/Game/GameSimulation.swift`
- Create: `DockBarHeroTests/SalvageResolverTests.swift`
- Modify: `DockBarHeroTests/GameSimulationTests.swift`

- [ ] **Step 1: Write failing eligibility/value/rollback tests**

```swift
func testBatchSalvageRemovesExactQuantitiesAndGrantsGoldOnce() throws {
    let state = try salvageFixture(commonLevel: 10, commonQuantity: 3, rareLevel: 5, rareQuantity: 2)
    let result = try SalvageResolver().salvage([
        .init(location: .inventory, stackID: .init(rawValue: 1), quantity: 2),
        .init(location: .overflow, stackID: .init(rawValue: 2), quantity: 1),
    ], in: state)
    XCTAssertEqual(result.goldGranted, 40) // 2*10*1 + 1*5*4
    XCTAssertEqual(result.state.economy.gold, state.economy.gold + 40)
}
```

Cover locked, equipped, Unique, duplicate selection, zero/excess quantity, multiplication overflow, gold overflow, partial-stack remainder, and whole-candidate rollback.

- [ ] **Step 2: Run RED**

Run salvage and simulation tests with `.build/SalvageRed`. Expected: resolver missing.

- [ ] **Step 3: Implement pure batch resolution**

Canonicalize selections by location and stack ID, reject duplicates, validate every selection before mutation, calculate `level * multiplier * quantity` with checked operations, remove quantities from a copy, add gold once, validate the resulting inventory, and return one `SalvageResult`.

- [ ] **Step 4: Add intent/events, run GREEN, and commit**

Add `.salvage([SalvageSelection])`, `.itemsSalvaged(quantity:gold:)`, and state replacement through `GameSimulation.apply`. Repeat with `.build/SalvageGreen`, then commit as `feat: add atomic item salvage`.

### Task 6: Filters, Sorting, Capacity, and Salvage UI

**Files:**
- Create: `DockBarHero/App/InventoryQuery.swift`
- Modify: `DockBarHero/App/InventoryView.swift`
- Modify: `DockBarHero/App/ManagementSupport.swift`
- Create: `DockBarHeroTests/InventoryQueryTests.swift`
- Modify: `DockBarHeroTests/ManagementViewTests.swift`

- [ ] **Step 1: Write failing pure query/confirmation tests**

```swift
func testQueryFiltersVisibleUpgradesAndUsesStableScoreTies() throws {
    let rows = try InventoryQuery(rarities: [.rare], upgradeOnly: true, sort: .heroScore).apply(to: fixtureRows(), heroSlot: 1)
    XCTAssertTrue(rows.allSatisfy { $0.rarity == .rare && $0.isUpgrade })
    XCTAssertEqual(rows, rows.sorted(by: InventoryRow.heroScoreOrder))
}

func testSelectSalvageableExcludesLockedEquippedAndUnique() {
    XCTAssertEqual(SalvageSelectionModel.selectSalvageable(from: fixtureRows()).map(\.entryID), [.stack(4)])
}
```

- [ ] **Step 2: Run RED**

Run query and management tests with `.build/InventoryUIRed`. Expected: query and selection models missing.

- [ ] **Step 3: Add transient query and selection models**

Implement rarity/slot/lock/equipped/upgrade/location filters and newest/level/rarity/hero-score sorts, each with stable ID final tie. Store selected quantities transiently. Confirmation derives exact unit count, affected entries, and checked gold without mutating game state.

- [ ] **Step 4: Build management controls**

Show `occupied/capacity`, milestone bonuses, next purchase price, purchase button, filter/sort controls, stack quantities, inventory/overflow sections, move controls, per-stack salvage quantity, Select Salvageable, and confirmation dialog. Disable actions with exact reasons and accessibility identifiers.

- [ ] **Step 5: Run GREEN and commit**

Repeat with `.build/InventoryUIGreen`, then commit as `feat: add inventory operations management`.

### Task 7: Inventory Operations Integrated Gate and Live QA

**Files:**
- Create: `DockBarHeroTests/InventoryOperationsIntegrationTests.swift`
- Create: `docs/qa/review-packets/inventory-operations.md`
- Modify: `PROJECT.md` after verification only.

- [ ] **Step 1: Add integrated deterministic scenarios**

Test 64-bit quantity edges, full capacity with matching/nonmatching drops, Boss grants, purchase sequence/cap, equip extraction/return, three exclusive heroes, save/reload overflow, partial/bulk salvage, filtered stable order, and failure injection rollback.

- [ ] **Step 2: Run focused, full, build, and context gates**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/InventoryFocused CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/InventoryOperationsIntegrationTests -only-testing:DockBarHeroTests/InventoryResolverTests -only-testing:DockBarHeroTests/SalvageResolverTests -only-testing:DockBarHeroTests/InventoryQueryTests -only-testing:DockBarHeroTests/SaveDocumentTests
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/InventoryFull CODE_SIGNING_ALLOWED=NO
xcodebuild clean build -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/InventoryBuild CODE_SIGNING_ALLOWED=NO
python3 /Users/n3kr0/.codex/skills/maintaining-project-context/scripts/context_guard.py check --root .
./script/build_and_run.sh --verify
git diff --check
```

- [ ] **Step 3: Run clean-save live QA**

Archive saves and hashes, preserve settings, fill 40 slots, verify stack merging, earn Boss 25/100 capacity, purchase at least two expansions, create/move/salvage overflow, filter/sort, partial salvage, bulk confirmation, exact gold, exclusive equipment, and relaunch durability without owner input.

- [ ] **Step 4: Record verified facts and commit**

Update QA and `PROJECT.md` under existing headings, keep line guards, commit as `docs: verify inventory operations milestone`, and leave a clean stacked feature branch. Push only after every gate succeeds; never merge or release.
