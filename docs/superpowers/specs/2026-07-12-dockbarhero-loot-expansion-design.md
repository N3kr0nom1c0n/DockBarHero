# DockBarHero Loot Expansion Design

**Status:** Approved

**Date:** 2026-07-12

**Project:** DockBarHero

**Builds on:**

- `docs/superpowers/specs/2026-07-12-dockbarhero-heroes-and-party-design.md`
- `docs/superpowers/specs/2026-07-12-dockbarhero-class-actions-design.md`
- the completed Heroes and Party implementation

## 1. Scope and Slice Order

Loot Expansion ships as two independently testable vertical slices.

Slice 1, Item Depth, adds durable rarity, deterministic affixes, Unique item definitions, effective stat resolution, selected-hero comparisons and scoring, item locking, save validation, presentation, and live QA.

Slice 2, Inventory Operations, adds stacking, finite capacity, milestone and gold expansions, durable overflow, filters, sorting, quantity selection, atomic salvage, presentation, and live QA.

Class Action modifiers, random procs, critical hits, elemental damage, crafting, sockets, sets, trading, markets, remote balance, and authored quest or boss content that grants specific Unique items are outside these slices. Slice 1 defines the Unique grant contract so later authored content can use it.

## 2. Durable Item Model

An item descriptor contains:

- stable item template ID;
- item level;
- equipment slot;
- primary stat;
- rarity;
- ordered affixes;
- lock state.

Ordinary generated items use stable weapon and armor template IDs until authored templates expand. A Unique item uses an authored stable template ID, fixed display name, fixed stats and affixes, and an explicit equipment slot. Unique items never roll randomly, stack, or enter salvage eligibility. They start locked and cannot be unlocked during these slices.

`ItemRarity` has five values: Common, Uncommon, Rare, Epic, and Unique. Rarity order is stable domain data used for sorting and presentation, not localized text order.

An `ItemAffix` contains a stable `AffixID` and checked integer magnitude. Affixes are stored in ascending stable ID order. Slice 1 IDs are Might, Ward, Vitality, and Haste:

- Might adds flat effective attack;
- Ward adds flat effective defense;
- Vitality adds maximum health;
- Haste reduces the basic-attack interval in basis points.

Weapons may roll Might, Vitality, or Haste. Armor may roll Ward, Vitality, or Haste. One item never contains duplicate affix IDs.

## 3. Deterministic Generation

Ordinary drops retain the existing guaranteed weapon/armor alternation. A stable integer mixer derives rolls only from loot sequence, defeated level, enemy tier, and equipment slot. It never uses process randomness, collection iteration order, wall time, locale, animation state, or save timestamp. Replaying identical state produces byte-equivalent item content.

Rarity tables are:

| Enemy tier | Common | Uncommon | Rare | Epic |
|---|---:|---:|---:|---:|
| Normal | 60% | 30% | 9% | 1% |
| Elite | 25% | 45% | 25% | 5% |
| Boss | 0% | 25% | 55% | 20% |

Unique is absent from random tables. Common rolls no affixes, Uncommon one, Rare two, and Epic three.

Affix magnitude ranges are percentages of validated level baselines:

- Uncommon: 8% through 12%;
- Rare: 10% through 15%;
- Epic: 12% through 18%.

Might, Ward, and Vitality convert the rolled percentage to a checked integer stat with deterministic rounding up. Haste stores the equivalent integer basis-point reduction. Unique magnitudes are authored values. Generation failure rejects the complete victory reward transaction.

## 4. Effective Stats

`ItemStatResolver` derives a hero's effective attack, defense, maximum health, and basic-attack interval from class progression, equipped primary stats, and affixes.

Haste is additive across equipped items, capped at 4,000 basis points. It applies to the hero's base attack interval using checked integer arithmetic and cannot produce an interval below the existing minimum attack interval. An automatic attack resets its timer to the current effective interval.

When equipment changes during a countdown, remaining attack time is clamped to the new effective interval. It is not reset or proportionally rescaled.

Vitality equipment changes preserve missing health. If maximum health increases by 100, current health also increases by 100. If maximum health decreases, the same missing-health amount is subtracted from the new maximum and the result is clamped to the valid living range. Equipment changes cannot revive a downed hero.

All stat changes are part of the same equipment transaction. Overflow or invalid intervals reject the candidate without changing equipment, current health, maximum health, or timers.

## 5. Hero-Specific Scoring and Comparison

Auto-equip uses a normalized weighted score specific to the hero class:

| Class | Attack | Defense | Health | Haste |
|---|---:|---:|---:|---:|
| Tank | 10 | 40 | 40 | 10 |
| DPS | 45 | 10 | 15 | 30 |
| Healer | 10 | 20 | 40 | 30 |

Each candidate stat is normalized in integer basis points against the class's expected value at the item level before weights are applied. Raw health points therefore cannot dominate smaller attack or defense units. Haste uses its effective basis-point reduction. All products and sums are checked.

Auto-equip replaces the current item only for a strictly greater score. An equal score retains the current item. If one drop is evaluated against multiple eligible heroes, greatest positive score improvement wins, then ascending party slot. Deterministic candidate ordering for otherwise equal unequipped items is rarity, item level, lower creation sequence, then lower item ID.

Management comparisons always show exact effective attack, defense, maximum-health, and attack-interval deltas for the selected hero. The weighted score and “upgrade” label supplement rather than hide those deltas.

## 6. Locking

Ordinary unequipped items and stacks can be locked or unlocked. Equipped ordinary and Unique instances expose their locked state. Locking prevents single and bulk salvage only; it does not pin equipment, prevent unequip, or block auto-equip replacement.

Locking an ordinary stack applies to every unit in the stack because lock state is part of stack identity. An unequipped ordinary instance rejoins only a stack with identical lock state. Unique items start permanently locked for these slices.

Lock changes are durable and request a save. Unknown IDs, Unique unlock requests, equipped-reference corruption, and invalid stack transitions reject without mutation.

## 7. Inventory State and Stacking

Slice 1 establishes item descriptors and individual identities while retaining an independently playable inventory. Slice 2 replaces the flat inventory collection with `InventoryState` containing:

- ordinary `ItemStack` values;
- individual equipped item instances;
- individual Unique item instances;
- durable overflow stacks and Unique instances;
- purchased expansion count;
- the next stable stack and item identity sequences.

Ordinary items stack only when template, level, rarity, ordered affixes, and lock state are identical. Slot and primary stat remain descriptor data but are not independent stack-key fields because an authored template owns those properties. Quantity has no product-level maximum; checked integer storage overflow rejects the candidate. A stack consumes one inventory slot regardless of quantity.

Equipping one ordinary unit decrements or removes its source stack and creates one stable equipped instance. If the source stack retains other units, extraction increases occupied slots by one and therefore requires capacity. Replacing or unequipping that instance removes it and returns its descriptor to an identical stack or creates a new one if capacity permits. Equipment references remain exclusive per hero. Unique items always remain individual stable instances.

Equipping or unequipping never silently moves an item into overflow. Capacity is evaluated from the final candidate layout after extraction and replacement return, not from temporary intermediate steps. If that final layout exceeds capacity, the complete equip transaction rejects before removing the candidate item.

## 8. Capacity, Expansions, and Overflow

Inventory capacity counts ordinary stacks, equipped instances, and Unique instances. It does not count overflow entries. Capacity is derived from validated `InventoryConfiguration` and durable purchase count:

- 40 starting slots;
- 10 additional slots once Boss 25 rewards are earned;
- 20 additional slots once Boss 100 rewards are earned;
- 10 slots per gold purchase;
- 200-slot release maximum.

Boss capacity is derived from existing durable party milestone state so it cannot be granted twice. Boss 25 capacity is available as soon as its rewards and pending second-class choice are durable.

Expansion purchase costs begin at 500 gold and double per prior purchase: 500, 1,000, 2,000, 4,000, and so on. Checked arithmetic and the 200-slot cap bound purchases. Prices, grants, and cap live in `InventoryConfiguration`; expected post-build balance tuning changes configuration, not save structure or transaction semantics.

When inventory is full, a drop still joins an identical ordinary stack already in inventory. Otherwise the complete dropped descriptor and quantity enter durable overflow. Overflow is unlimited by product policy, subject only to checked storage. Combat, XP, gold, party unlocks, and subsequent rewards continue; no item is silently deleted.

Overflow items can be inspected and salvaged. They cannot be equipped or locked. Moving an overflow entry to inventory requires a matching existing stack or sufficient capacity and commits atomically.

## 9. Salvage

Salvage grants gold per unit:

```text
salvageGold = itemLevel * rarityMultiplier
```

Multipliers are Common 1, Uncommon 2, Rare 4, and Epic 8. Unique items cannot be salvaged. These values are validated `InventoryConfiguration` data.

A salvage selection identifies an entry and quantity. Equipped, locked, Unique, unknown, zero-quantity, and excessive-quantity selections are invalid. “Select salvageable” selects the full quantity of every eligible visible row; the player may reduce quantities before confirmation.

The confirmation displays total units, affected stacks or entries, and exact gold. Every multiplication, sum, inventory removal, and economy addition is checked. The complete batch either removes all selected quantities and grants all gold once, or exposes no mutation.

## 10. Filters and Sorting

Inventory filters are transient presentation state and include:

- one or more rarities;
- weapon or armor slot;
- locked or unlocked;
- equipped or unequipped;
- upgrade for the selected hero;
- inventory or overflow location.

Sorting options are newest, item level, rarity, and selected-hero weighted score. Every sort defines a complete deterministic tie order ending in stable entry ID. Bulk selection applies only to currently filtered visible rows.

Changing filters, sorting, selected rows, selected quantities, or comparison hero does not save. Locking, expanding, moving overflow, equipping, and salvaging do save.

## 11. Presentation

Inventory rows display rarity color and text, template or Unique name, level, slot, primary stat, affixes, quantity, lock, equipped owner, location, selected-hero score, and exact stat deltas. Color is never the only rarity or state indicator.

Slice 1 adds rarity and affix detail, lock controls, comparison hero selection, score, and exact deltas while preserving the shared party inventory.

Slice 2 adds capacity usage, next expansion price, purchase control, filters, sorting, stack quantities, salvage quantity selection, confirmation, and a clearly separated overflow section. Full-capacity and invalid-operation messages explain the exact blocking condition.

Unique items use authored names and a stable Unique treatment but remain accessible in high contrast and reduced motion. The rail may show concise notable-drop feedback; it never displays inventory controls or becomes loot authority.

## 12. Error and Data-Safety Rules

Item generation, stat resolution, scoring, equip extraction/return, locking, stacking, capacity purchase, overflow movement, and salvage use candidate-state transactions. Invalid content, unknown IDs, duplicate identities, malformed affixes, noncanonical ordering, rarity/affix-count mismatch, illegal slot-affix combination, arithmetic overflow, shared equipment, capacity errors, and corrupted quantities reject before caller-visible mutation.

Save validation checks every descriptor, stack signature, quantity, identity sequence, equipment reference, capacity derivation, overflow entry, purchase count, and Unique definition reference. Unsupported or unreadable saves retain existing preservation behavior. These are unreleased development saves, so implementation begins clean rather than adding retroactive migration.

## 13. Verification

Both slices use red-green-refactor TDD and coherent commits.

Slice 1 tests cover rarity boundaries, tier tables, stable mixing, replay equivalence, affix count/order/slot legality/ranges, Unique grants, effective stat arithmetic, Haste cap and timer clamping, Vitality missing-health preservation, class-weight scoring, auto-equip tie rules, locking, save round trips, management comparison, and full regression.

Slice 2 tests cover exact stack equality, checked quantities, equip extraction and return, exclusive references, capacity milestones, purchase price and cap, full-inventory stack joins, overflow durability, move failures, filters, stable sorting, selected quantities, salvage eligibility/value/rollback, confirmation models, save round trips, and full regression.

Each slice ends with the complete arm64 suite, clean unsigned arm64 build, context guard, exact feature-bundle launch, save archive, clean-save live QA, and a verified QA packet. Slice 1 live QA observes multiple rarities and affixes, comparisons, auto-equip, timer/health stat changes, locks, and relaunch. Slice 2 live QA fills capacity, stacks identical items, earns milestone capacity, purchases capacity, creates and clears overflow, filters/sorts, performs partial and bulk salvage, confirms gold, and relaunches durable state.

## 14. Completion Criteria

Item Depth is complete when deterministic ordinary and Unique item content, four always-on affixes, effective stats, class-specific scoring, comparisons, locking, persistence, presentation, and all gates pass.

Inventory Operations is complete when identical ordinary items stack, capacity and expansions are durable and tunable, overflow prevents loss, exclusive equipment identities remain correct, filtering/sorting work, salvage is atomic, persistence and presentation are accurate, and all gates pass.
