# DockBarHero Progression Safety, Heroes, and Classes Design

**Status:** Approved

**Date:** 2026-07-12

**Project:** DockBarHero

**Builds on:**

- `docs/superpowers/specs/2026-07-12-dockbarhero-steam-ready-roadmap-design.md`
- `docs/superpowers/specs/2026-07-10-dockbarhero-phase-1-playable-slice-design.md`
- the accepted Foundation Upgrade at `fc0ace0`

## 1. Purpose

The Phase 1 loop can permanently stall: victory alone advances the enemy and grants loot, while defeat revives the unchanged 100-health hero against the same full-health enemy. Deterministic lower-level loot cannot solve the wall because duplicate items eventually stop improving equipment.

This design makes progression recovery a prerequisite gate inside the schema-v2 Heroes and Classes milestone. It adds hero XP and levels, class-dependent stat growth, selectable farming, deterministic enemy tiers, gold, party unlocks, and automatic fallback without using save reset as progression recovery.

## 2. Chosen Milestone Shape

The milestone remains one coherent schema-v2 change with internal vertical gates:

1. **Progression Safety:** fresh schema v2, first-run class choice, XP and levels, gold earning, deterministic tiers, Push/Farm controls, queued encounter selection, automatic retreat, and New Game.
2. **Heroes and Party:** class presentation, party combat, slot-two and slot-three unlocks, and newcomer level seeding.
3. **Class Actions:** one manual ability per class and the management/interactive-rail controls already required by the roadmap.

No public or merged checkpoint may expose a recorded party unlock that the player cannot use. The complete milestone ships all three gates together, although each gate receives its own internal test and review checkpoint.

A separate progression schema followed immediately by another classes schema was rejected because it would create avoidable v2-to-v3 migration churn. Quietly extending schema v1 was rejected because it would invalidate the frozen v1 contract.

## 3. Schema-v2 State

`PartyState` owns the chosen classes, active hero slots, and unlock state. Each `HeroState` owns a stable class ID, level, current XP within that level, current combat state, and equipment references.

`CampaignState` persists these values separately:

- `highestUnlockedLevel`: the frontier the player may push;
- `selectedLevel`: the level used by the active encounter loop;
- `queuedLevel`: an optional player destination applied at the next encounter boundary;
- `mode`: `push` or `farming`;
- `consecutiveDefeats`;
- completed Boss and party-slot milestones.

The selected farming level never overwrites or lowers the frontier. Tier identity comes from the validated encounter schedule for the selected level. The save also contains a shared `EconomyState.gold` balance.

The project has no released player saves. Schema v2 therefore begins fresh during development rather than reconstructing XP, gold, classes, or unlocks from v1. If old development bytes are encountered, they remain preserved as diagnostics and the app starts the schema-v2 class-selection flow.

## 4. XP and Hero Levels

For hero level `H >= 1` and defeated enemy level `E >= 1`:

```text
XPNext(H) = 100 * H * H
BaseXP(E) = 25 * E * E
Gap = max(H - E - 5, 0)
PenaltyPercent = max(25, 100 - 15 * Gap)
RewardXP = floor(BaseXP(E) * tierXPMultiplier * PenaltyPercent / 100)
```

Tier multipliers use exact rational integers rather than gameplay floating point. Every multiplication and subtraction is checked before commit.

Enemies at or above the hero level, and enemies up to five levels below it, grant full tier-adjusted XP. Older enemies lose 15 percentage points per additional level of difference, with a permanent 25% floor. Old encounters therefore remain useful but cannot remain the best source indefinitely.

Each active hero receives the full encounter XP; rewards are not divided by party size. While current XP is at least `XPNext(level)`, the resolver subtracts the threshold and applies another level. Multiple level-ups from one reward are valid. Rewards and level-ups resolve after victory and before the next encounter is constructed. Defeat grants no XP.

## 5. Class Growth and Party Rules

Level bonuses use basis points:

```text
bonus = 10_000 + growthPerLevel * (heroLevel - 1)
effectiveStat = floor(rawStat * bonus / 10_000)
```

For health, `rawStat` is class base health. For attack and defense, it is class base stat plus the equipped item stat. Initial playtest data is:

| Class | Base HP | Base attack | Base defense | HP growth | Attack growth | Defense growth |
|---|---:|---:|---:|---:|---:|---:|
| Tank | 130 | 8 | 2 | 150 bp/level | 25 bp/level | 100 bp/level |
| DPS | 100 | 12 | 0 | 75 bp/level | 125 bp/level | 40 bp/level |
| Healer | 110 | 9 | 1 | 100 bp/level | 60 bp/level | 75 bp/level |

These coefficients are validated balance data, not save semantics. Tank, DPS, and Healer must each progress solo through the first Boss using only baseline obtainable equipment; no class may depend on a future party slot or manual ability to escape the early campaign.

New Game requires one starting-class choice. Defeating Boss 25 unlocks slot two and a permanent choice between the two remaining classes. Defeating Boss 100 unlocks slot three and the final class. A newly unlocked hero starts at the current highest hero level with zero XP toward the next level. Every active hero continues receiving full encounter XP.

### 5.1 Party Combat and Equipment

Every active hero owns an independent automatic attack timer and attacks the single active enemy. Same-timestamp hero actions resolve by ascending party slot, preserving the roadmap's hero-before-enemy rule. The enemy targets the lowest-numbered living party slot. A defeated hero remains down for the encounter; party defeat occurs only when every active hero is down. Victory and completed revive restore every active hero to full health and reset all action timers.

Inventory is party-shared, while equipment references belong to individual heroes. Manual equip identifies both hero and item. Auto-equip evaluates every eligible active hero, chooses the strict same-slot upgrade with the largest effective-stat increase, and breaks equal improvements by ascending party slot. Replaced and unused items remain owned.

## 6. Deterministic Enemy Tiers

The provisional schedule is ordered content data:

1. Boss every 25th enemy level;
2. Elite every fifth non-Boss level;
3. Normal otherwise.

Boss precedence prevents level 25, 50, and later boundaries from also resolving as Elites. The initial tier definitions are:

| Tier | Health | Post-defense damage | XP | Item stat | Gold |
|---|---:|---:|---:|---:|---:|
| Normal | 1.00x | 1.00x | 1.00x | 1.00x | 1.00x |
| Elite | 1.40x | 1.40x | 1.75x | 1.10x | 1.50x |
| Boss | 2.50x | 2.25x | 3.50x | 1.20x | 2.00x |

Enemy maximum health uses checked ceiling after the health ratio. Tier damage applies after defense:

```text
baseDamage = max(1, enemyAttack - heroDefense)
tierDamage = ceil(baseDamage * tierDamageRatio)
```

Applying the ratio after defense prevents a tier boundary from invalidating armor and producing an unintended one-shot spike. Item-stat bonuses also use checked ceiling so a premium tier never rounds down to the Normal value.

## 7. Gold and Future Spending

For enemy level `L`:

```text
BaseGold(L) = 20 + 4L + floor(L * L / 40)
EliteGold(L) = floor(BaseGold(L) * 3 / 2)
BossGold(L) = BaseGold(L) * 2
```

Gold is a shared persisted wallet awarded only on victory. It does not use the hero-level XP penalty; older levels already pay less through the level formula. Boss gold remains below its 2.5x health burden so repeatable Boss farming is not permanently superior gold per combat effort.

Progression Safety earns and displays gold but does not invent purchases. The later default permanent-upgrade cost family is:

```text
UpgradeCost(rank) = 100 + 8 * rank + floor(rank * rank / 2)
```

Individual upgrades and unlocks may supply a different data-defined base cost while retaining checked quadratic growth.

## 8. Push, Farming, and Queued Selection

Push mode fights `highestUnlockedLevel`. A Push victory grants rewards, increments the frontier, selects the new frontier, and immediately prepares that encounter.

Farming mode repeatedly fights one selected defeated level. Victory grants normal tier-adjusted XP, gold, and exactly one deterministic item, but neither the selected level nor frontier changes.

The player may choose any defeated level or request Return to Frontier during combat. That request never abandons the current fight. It becomes `queuedLevel`, is shown as the next destination, and applies after the current victory or after the defeat/revive boundary. A queued player choice takes precedence over automatic retreat. Applying a manual destination resets the consecutive-defeat count.

## 9. Automatic Retreat and Anti-Lock Guarantees

Victory resets the defeat streak. After three consecutive defeats with no queued player destination, the game enters Farming mode at the prior campaign checkpoint and resets the streak.

For a failed level in a segment ending at Boss boundary `B`, where `B` is the smallest multiple of 25 greater than or equal to the failed level:

```text
fallback = B <= 25 ? highest defeated Normal below the failed level : B - 26
```

Required examples are:

- Boss 25 -> level 24;
- Boss 50 -> level 24;
- Boss 75 -> level 49;
- level 174 -> level 149.

Automatic retreat never returns to the frontier by itself. Return requires an explicit player request. The fallback grants nonzero XP and gold, and deterministic duplicate-quality loot cannot be the only recovery mechanism because hero levels and the future gold economy provide independent power growth.

Every class must defeat level 1 from a valid new-game state. Model-based balance tests must also prove that the fallback examples are defeatable under baseline valid equipment and class progression. Deliberate player sabotage such as unequipping all gear is not treated as a balance guarantee, but level selection remains available for manual recovery.

## 10. Rewards and Event Order

Victory commits atomically in this order:

1. emit victory;
2. calculate tier-adjusted XP and gold;
3. apply XP and all resulting level-ups to each active hero;
4. generate exactly one deterministic tier-adjusted item;
5. apply auto-equip when the item is a strict same-slot upgrade;
6. apply Boss and party-unlock milestones;
7. apply a queued player destination if present, otherwise apply Push or Farming transition rules;
8. restore combatants and begin the next encounter.

If any checked calculation, content lookup, reward, unlock, or next-encounter construction fails, the candidate state and all rewards roll back together.

## 11. Management and Presentation

The Overview displays explicit `Hero Lv.`, `Enemy Lv.`, and `Item Lv.` labels, XP progress, enemy tier, gold, frontier, selected farming level, Push/Farming mode, and queued destination. It provides a defeated-level picker and Return to Frontier. No rail or management label may present equipment level as hero level.

The Progression Safety gate introduces three intentional empty-state routes:

- **Abilities:** future class actions, cooldowns, and loadout controls;
- **Skills:** future passive and permanent character upgrades;
- **Shop:** future gold purchases and unlocks, while already displaying the current gold balance.

These are real navigation routes, not fake gameplay. They add no fabricated abilities, purchases, or dormant save fields before their owning gate. The Class Actions gate in this milestone replaces the Abilities empty state with the approved manual class actions. Skills and Shop remain explicit empty states until the Upgrades and Economy milestone.

## 12. Start New Game

Start New Game lives in the Settings Danger Zone and preserves overlay and application preferences. The confirmation explains that heroes, XP, gold, frontier, inventory, equipment, and unlocks will be replaced. The destructive action remains disabled until the player enters exactly:

```text
GAME OVER MAN!
```

The app constructs and durably writes the new class-selection state before replacing the running campaign. A write failure leaves the existing run active. The old run cannot remain eligible as the automatic recovery backup, preventing it from reappearing after a later primary-save failure.

## 13. Persistence and Failure Rules

Schema v2 persists all durable progression and encounter-selection state. XP, gold, level-ups, frontier changes, queued selections, mode changes, unlocks, and automatic retreat trigger durable save requests in addition to periodic autosave and clean termination.

Invalid content or arithmetic fails before caller-visible mutation. Save failures preserve the last valid run. Old development bytes and unsupported future versions remain preserved diagnostically rather than being silently overwritten. Settings failures remain isolated from gameplay progress.

## 14. Verification

Focused tests cover:

- XP thresholds, safe-zone penalties, the 25% floor, multiple level-ups, and overflow;
- gold formulas and tier ratios;
- Normal/Elite/Boss scheduling and Boss precedence;
- post-defense tier damage and checked health/item rounding;
- complete-state and event-order determinism across time partitions;
- Push, Farming, queued switching after victory and defeat, and Return to Frontier;
- retreat examples 25->24, 50->24, 75->49, and 174->149;
- manual destination precedence over retreat;
- each class solo through Boss 25 with baseline obtainable gear;
- slot unlocks at Boss 25 and Boss 100, newcomer level seeding, and full XP per active hero;
- party-slot action ordering, lowest-living-slot enemy targeting, downed-hero behavior, and all-heroes-down defeat;
- deterministic per-hero manual equipment and auto-equip improvement/tie ordering;
- no rewards on defeat and atomic rollback on reward failure;
- schema-v2 active/revive/queued round trips;
- reset-write failure preserving the old run and old backup exclusion after successful reset;
- explicit level labels and Overview, Inventory, Abilities, Skills, Shop, and Settings routes.

The integrated gate requires the complete test suite, a clean Apple Silicon build, proportional live QA, valid project context, and a clean worktree.

## 15. Roadmap Impact and Completion Criteria

Hero XP, levels, gold earning, enemy tiers, and party-unlock foundations move forward from later milestones because they are required for save safety and the agreed class loop. The later economy milestone now owns gold spending, permanent stat upgrades, skills, unlock purchases, and Shop behavior rather than initial currency earning.

This design is complete when no valid run can remain in an involuntary same-enemy defeat loop; the player can farm any defeated level, recover power through XP and gold, return explicitly to an unchanged frontier, distinguish hero/enemy/item levels, unlock the agreed party slots, and start a deliberately confirmed new run without using reset as the normal recovery path.
