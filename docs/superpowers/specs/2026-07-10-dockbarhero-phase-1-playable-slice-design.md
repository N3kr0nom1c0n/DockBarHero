# DockBarHero Phase 1 Playable Slice Design

**Status:** Approved

**Date:** 2026-07-10

**Project:** DockBarHero

**Related outline:** [mac-taskbar-hero-project-outline.md](../../../mac-taskbar-hero-project-outline.md)

**Depends on:** [Phase 0 technical prototype design](2026-07-10-dockbarhero-phase-0-design.md)

## 1. Purpose

Phase 1 turns the validated macOS rail into a small but complete idle-RPG loop. The slice must let one hero fight continuously, gain and equip deterministic loot, preserve progress across launches, and expose useful combat and inventory details in a conventional management window.

The goal is not content breadth. It is to prove that gameplay simulation, rendering, persistence, and macOS window behavior can operate together without weakening the Phase 0 overlay guarantees.

## 2. Success Criteria

The slice succeeds when a player can:

1. Launch DockBarHero and watch one hero automatically fight an enemy.
2. See the hero and enemy act on independent real-time attack schedules.
3. Watch victories advance through progressively stronger enemy levels without manual input.
4. Recover from defeat after a short delay and retry the same enemy without losing progression.
5. See rolling damage per second on the rail and both rolling and encounter-average damage per second in the management window.
6. Receive one weapon or armor item after every victory.
7. Let upgrades auto-equip by default, disable auto-equip, and equip items manually.
8. Close and reopen the app without losing combat, equipment, inventory, or settings state.
9. Continue using the Phase 0 rail without focus theft, click blocking in passive mode, fullscreen leakage, or placement regressions.

## 3. Scope

### 3.1 Included

- One hero.
- Fully automatic basic attacks.
- Independent hero and enemy attack timers.
- Deterministic enemy-level progression.
- Victory, defeat, revive, and retry behavior.
- Rolling five-second and encounter-average DPS metrics.
- One guaranteed item drop per victory.
- Weapon and armor equipment slots.
- Damage-only weapons and defense-only armor.
- Unlimited inventory.
- Auto-equip enabled by default with a user toggle.
- Manual equipment changes.
- A standard management window.
- Versioned, atomic local saves with backup recovery.
- Event-driven saves plus a 30-second fallback autosave.
- Unit, integration, persistence, launch, and Phase 0 regression tests.

### 3.2 Explicitly Deferred

- Hero abilities and automatic ability-use rules.
- Additional heroes, parties, classes, and party composition.
- Accessories and additional item-stat types.
- Item rarity, random affixes, lock, discard, salvage, and salvage currency.
- Inventory capacity limits.
- Experience, hero levels, skill trees, prestige, and manual upgrades.
- Enemy families, elites, bosses, areas, acts, and authored campaigns.
- Offline progress or simulation while the app is closed or the machine is asleep.
- Currency, shops, crafting, quests, achievements, and activity history.
- Audio, production art, onboarding, and content polish.
- Steamworks, cloud saves, market items, trading, multiplayer, accounts, networking, and live operations.
- Merging the overnight feature branch into `main`.

The deferred systems remain in the broader roadmap. Phase 1 introduces narrow extension points for abilities, accessories, additional stats, and save migrations without implementing those features now.

## 4. Chosen Delivery Approach

Phase 1 uses gated vertical slices:

1. Combat and DPS.
2. Loot and equipment.
3. Persistence and recovery.
4. Rail and management-window integration.

Each slice must be implemented, tested, reviewed, and integrated before its dependent slice begins. This keeps every accepted checkpoint coherent and prevents a failure late in the overnight run from invalidating unrelated completed work.

Two alternatives were considered:

- Building every domain system before any UI would maximize early unit-test coverage but delay integration feedback and a playable checkpoint.
- Building the UI against mock data first would show visible progress sooner but create likely rework when real simulation and persistence contracts arrive.

## 5. Architecture

### 5.1 Domain Boundary

Gameplay rules must remain independent from AppKit, SwiftUI, SpriteKit, wall-clock time, and rendered frame rate. Domain types use plain Swift values and deterministic inputs so they can be tested without launching the application.

`GameSimulation` owns:

- Current hero and enemy combat state.
- Encounter phase and enemy level.
- Independent attack countdowns.
- Chronological combat-event resolution.
- Victory, defeat, revive, and next-encounter transitions.
- Loot sequence state.
- Equipment and inventory.
- DPS calculations.

The simulation accepts elapsed active time through `advance(by:)` and returns a snapshot plus ordered domain events. It never reads a global clock itself. `SimulationDuration` is the sole gameplay-time value: its canonical representation is signed `Int64` nanoseconds, with checked nanosecond, millisecond, and whole-second construction. Combatant intervals and countdowns, encounter elapsed time, revive time, balance timers, and combat timestamps use this type; floating-point conversion is presentation-only.

### 5.2 Simulation Driver

A `SimulationDriver` uses an integer monotonic-nanosecond source to calculate elapsed active time and advances the simulation independently from SpriteKit rendering. Normal timer delays are caught up deterministically. A single elapsed interval is capped at one billion nanoseconds (one second), inside the simulation's ten-billion-nanosecond advance limit; excess time is discarded as suspension time so machine sleep does not become accidental offline progress.

Gameplay continues while the rail is hidden or visual animation is paused. The simulation stops only during application shutdown. Offline progress will later replace the suspension-discard policy through a separately approved design.

The driver publishes UI snapshots no more than four times per second. Domain events may trigger visual reactions immediately, but animation completion never changes simulation state.

### 5.3 Action Policy

An `ActionPolicy` protocol selects an action when a combatant becomes ready. Phase 1 supplies only `BasicAttackPolicy`, which always chooses a basic attack.

This boundary is the future insertion point for abilities, cooldowns, resource checks, priorities, and the requested unlockable automatic ability behavior. Those rules and data are not present in this slice.

### 5.4 Combat State

`CombatantState` contains:

- Stable identifier.
- Current and maximum health.
- Base attack damage.
- Base defense.
- Attack interval.
- Time remaining until the next action.

Effective hero attack and defense are derived from base stats plus equipped items. Equipment changes never mutate base stats.

`EncounterState` contains:

- Enemy level.
- Encounter phase: active or reviving.
- Active encounter elapsed time.
- Total hero damage dealt in the encounter.
- Remaining revive time when applicable.

Every gameplay-time field is a `SimulationDuration`. Negative raw values remain representable only so validation can reject malformed state without trapping. Attack intervals must be at least one million nanoseconds (one millisecond); one `advance(by:)` accepts `0...10_000_000_000` nanoseconds; revive delay and remaining revive time must be `0...10_000_000_000` nanoseconds. Countdown and active-elapsed arithmetic is checked `Int64` arithmetic, and an overflow fails the advance before caller-visible state mutation.

### 5.5 Loot And Equipment

`LootSystem` receives the defeated enemy level and a persisted drop sequence number. It produces exactly one deterministic item. Drop slots alternate weapon, armor, weapon, armor, beginning with a weapon.

`EquipmentSlot` is a stable coded value. Phase 1 recognizes `weapon` and `armor`; the representation permits a future `accessory` value through an explicit save migration.

`Item` contains:

- Stable identifier.
- Item level.
- Equipment slot.
- One primary-stat value.
- Creation sequence number for stable ordering.

Weapons add attack damage. Armor adds defense. Every owned item remains in the inventory collection, and equipment slots reference item identifiers from that collection. Auto-equip compares only items in the same slot and equips a drop only when its primary stat is strictly greater than the currently equipped item. Ties remain unequipped. Replacing gear changes the equipment reference without removing either item. Manual equip remains available regardless of the auto-equip setting.

Inventory has no capacity limit and performs no automatic disposal.

### 5.6 Persistence

`SaveStore` owns encoding, validation, atomic replacement, backup recovery, and save status. Simulation and UI code request saves through this boundary rather than writing files directly.

The initial schema is version 1. Decoding first reads the schema version and dispatches through a migration boundary. Version 1 needs no migration, but unsupported future versions are rejected rather than decoded optimistically.

Save encoding and file I/O run serially away from rendering. The store coalesces overlapping save requests and reports completion or failure back to `AppModel`.

### 5.7 Application Coordination

The existing `AppModel` remains the application coordinator. Phase 1 separates its responsibilities into focused collaborators instead of placing gameplay and persistence logic directly in the coordinator:

- Existing overlay state and environment monitoring remain unchanged in ownership.
- `SimulationDriver` owns active-time advancement.
- `GameSimulation` owns gameplay state and rules.
- `SaveStore` owns durable state.
- A presentation snapshot supplies the rail and management window.

`AppModel` starts and stops services, routes user intents, publishes presentation state, and applies existing overlay visibility rules.

## 6. Gameplay Rules

### 6.1 Initial Values

Initial balance values live in a `BalanceConfiguration` value rather than being scattered through simulation code:

- Hero maximum health: 100.
- Hero base attack damage: 10.
- Hero base defense: 0.
- Hero attack interval: 1,000,000,000 nanoseconds (1 second).
- Enemy base maximum health: 30.
- Enemy base attack damage: 3.
- Enemy base defense: 0.
- Enemy attack interval: 1,500,000,000 nanoseconds (1.5 seconds).
- Revive delay: 3,000,000,000 nanoseconds (3 seconds).

For enemy level `L`, where `L` begins at 1:

- Enemy maximum health is `round(30 * 1.06^(L - 1))`.
- Enemy attack damage is `round(3 * 1.04^(L - 1))`.
- Enemy defense and attack interval remain unchanged.

For an item dropped from enemy level `L`:

- A weapon's damage bonus is `ceil(10 * (1.06^L - 1))`.
- Armor's defense bonus is `ceil(3 * (1.04^L - 1))`.

These formulas keep the first deterministic progression loop moving while exercising meaningful equipment upgrades. Balance constants may be tuned later without altering simulation contracts or save shape.

### 6.2 Attack Resolution

Hero and enemy actions are scheduled independently. `advance(by:)` resolves every due event in exact integer-nanosecond timestamp order within the supplied interval. It runs against a candidate simulation and commits only on success; there is no epsilon, rounding, readiness clamp, or event-count budget.

When attack times are identical, the hero resolves first. If that attack defeats the enemy, the enemy does not retaliate at the same timestamp.

Damage is:

```text
max(1, attacker effective attack - defender effective defense)
```

Health cannot fall below zero. No critical hits, misses, evasion, healing, abilities, damage types, or randomness apply in Phase 1.

### 6.3 Victory

When the enemy reaches zero health:

1. Emit a victory event.
2. Generate exactly one deterministic drop.
3. Apply auto-equip when enabled and the drop is a strict upgrade.
4. Preserve all unequipped items in inventory.
5. Increment the enemy level by one.
6. Restore the hero to full health.
7. Create the next enemy at full health.
8. Reset both attack countdowns and encounter DPS state.
9. Begin the next encounter immediately.

### 6.4 Defeat

When the hero reaches zero health:

1. Emit a defeat event.
2. Enter a three-second revive phase.
3. Stop attacks and exclude revive time from encounter metrics.
4. At the end of the delay, restore the hero and same-level enemy to full health.
5. Reset both attack countdowns and encounter DPS state.
6. Retry the same enemy without removing inventory, equipment, or enemy-level progress.

Defeat does not grant loot.

## 7. Damage Metrics

`DamageMetrics` records timestamped hero damage events as `SimulationDuration` values in simulation time. It may convert a duration to a floating-point result only when deriving the presentation-only DPS value.

Rolling DPS:

- Uses only damage events in the current encounter and trailing five active seconds.
- Divides by the lesser of five seconds and current active encounter duration, with zero returned before time advances.
- Refreshes in presentation snapshots approximately four times per second.
- Resets to zero on victory, defeat, retry, and application launch.

Encounter-average DPS:

- Divides total hero damage by active encounter elapsed time.
- Excludes revive time.
- Resets when a new encounter or retry begins.

The rail displays rolling DPS. The management window displays both values. DPS is derived diagnostic state and is not persisted.

## 8. Save Format And Recovery

### 8.1 Persisted State

The save document contains:

- Schema version and save timestamp.
- Hero current health and base combat values.
- Enemy level, current health, and combat values.
- Encounter phase, active elapsed time, accumulated hero damage, and remaining revive time.
- Hero and enemy attack countdowns.
- Equipment references for weapon and armor.
- Complete owned-item inventory, including equipped items.
- Auto-equip preference.
- Deterministic drop sequence number.

The timestamp is informational in Phase 1. Launch never converts elapsed wall-clock time into rewards or combat progress.

### 8.2 Save Triggers

A save is requested:

- After every victory and generated drop.
- After manual equipment changes.
- After the auto-equip preference changes.
- Every 30 seconds while the application is running.
- During clean application termination.

Closely spaced requests are coalesced after capturing the latest coherent snapshot.

Clean termination is deferred until the final save completes. If it cannot complete within five seconds, termination proceeds with the last valid save preserved and the timeout logged.

### 8.3 Atomic Write

The save lives in the app's Application Support directory. A write:

1. Encodes and validates the new document.
2. Writes it to a temporary file in the same directory.
3. Preserves the current valid primary as the backup.
4. Atomically replaces the primary with the temporary file.

The application must not report a successful save until replacement completes.

### 8.4 Load And Recovery

Loading follows this order:

1. Decode and validate the primary save.
2. If it is missing or invalid, decode and validate the backup.
3. If the backup succeeds, resume from it and report recovered status.
4. If neither succeeds, preserve unreadable files with diagnostic suffixes and start a new game.

Validation rejects negative timers, intervals below one million nanoseconds, elapsed advances or revive values above ten billion nanoseconds, invalid health ranges, duplicate item identifiers, unknown required equipment slots, unsupported schema versions, and structurally inconsistent encounter state.

Save failures are logged and shown as a non-blocking management-window status. Gameplay may continue. A repeated failure during overnight QA fails the persistence gate.

## 9. Rail Presentation

The rail preserves the Phase 0 panel, placement, passive-input default, visibility, fullscreen, and animation-suspension behavior.

The SpriteKit scene adds:

- Hero and enemy representations.
- Compact health bars.
- Enemy level.
- Rolling five-second DPS.
- Attack and hit reactions driven by domain events.
- Brief victory, defeat, and revival reactions.

The scene renders snapshots and reacts to events. It never calculates damage, schedules attacks, generates loot, or decides encounters.

Pausing rail animation suspends visual animation only. Gameplay continues. Hiding the rail also leaves gameplay active while keeping rendering suspended according to Phase 0 behavior.

## 10. Management Window

The menu bar adds an `Open Management Window` command. It opens a standard SwiftUI macOS window without changing the rail's passive-input state.

The window contains:

- Hero health, attack, defense, and attack interval.
- Current enemy level, health, attack, defense, and attack interval.
- Rolling DPS and encounter-average DPS.
- Equipped weapon and armor.
- Auto-equip toggle, enabled by default for a new game.
- A sortable native inventory table.
- Manual equip action for the selected compatible item.
- Save status: saved, saving, recovered from backup, or save error.

Inventory rows show slot, item level, primary stat, creation order, and equipped state. The initial sort is newest first, with stable secondary ordering by creation sequence. The native list remains lazy so an unlimited inventory does not require constructing every row eagerly.

Closing the management window does not pause combat or quit the menu-bar application.

## 11. Error Handling

- Invalid elapsed values are rejected by the simulation rather than mutating state.
- Domain invariants are validated at construction, save, and load boundaries.
- A rendering or management-window failure must not corrupt gameplay or save data.
- A save failure preserves the last valid primary and backup whenever possible.
- An unavailable rail screen keeps the overlay hidden through existing Phase 0 behavior while simulation continues.
- Unsupported future save versions produce an explicit status and preserve the file.
- No recovery path deletes user data automatically.

## 12. Testing Strategy

### 12.1 Combat Unit Tests

- Independent attack schedules across uneven elapsed intervals.
- Identical outcomes for one large step and equivalent smaller steps.
- Hero-first exact-timestamp tie resolution.
- One-nanosecond no-early-fire and one-nanosecond ordering boundaries.
- Rejection before mutation for unsupported intervals, elapsed values, and checked arithmetic overflow.
- Minimum damage and health clamping.
- Victory ordering and immediate next encounter.
- Defeat, three-second revive, and same-enemy retry.
- Enemy scaling at representative levels.
- Suspension-gap cap behavior.
- Basic-attack policy integration.

### 12.2 DPS Tests

- Rolling five-second eviction and denominator behavior.
- Approximately four-Hz publication throttling without lost damage.
- Encounter-average calculation.
- Revive-time exclusion.
- Reset behavior on victory, defeat, retry, and launch.

### 12.3 Loot And Equipment Tests

- Exactly one drop per victory.
- Deterministic slot alternation and stat generation.
- Strict-upgrade auto-equip behavior.
- Auto-equip disabled behavior.
- Tie handling.
- Equipment-reference changes without owned-item loss.
- Manual equip behavior.
- Stable identifiers and inventory ordering.

### 12.4 Persistence Tests

- Save/load round trip for active and reviving encounters.
- Atomic replacement behavior.
- Backup creation and corrupt-primary recovery.
- New-game recovery when both files are invalid.
- Unsupported future-version rejection.
- Domain validation failures.
- Coalesced event saves and 30-second autosave.
- Clean-quit save.
- No closed-time progression on reload.

### 12.5 UI And Regression Tests

- Presentation snapshots map correctly to rail and management values.
- Menu command opens the management window.
- Manual equip and auto-equip toggle route through domain intents.
- Rail animation events do not mutate simulation state.
- Existing Phase 0 overlay, environment, placement, window, and startup tests remain green.
- Clean arm64 build and app launch/relaunch smoke test.
- Live observation confirms combat advances, rolling DPS changes, encounter DPS resets, saves persist, and fullscreen suppression still works.

## 13. Overnight Execution Contract

### 13.1 Source Control

- Start from the reviewed `main` commit in an isolated worktree.
- Use a dedicated Phase 1 feature branch.
- Make focused commits at accepted slice boundaries.
- Push the feature branch to GitHub only after the complete final gate passes.
- Do not merge, rebase, force-push, or modify `main` overnight.
- Do not discard or rewrite user-authored changes.

### 13.2 Agent Roles

- Luna-level, low-cost coding agents implement focused tasks with tests first.
- Terra-level integration and review checks each completed slice.
- Sol performs the final whole-branch review.
- Use the cheapest available coding-capable model consistent with the agreed ladder; model unavailability must not lower QA requirements.

The main planning model owns the specification, implementation plan, integration decisions, backlog state, and final report. Review agents report findings; implementation agents make fixes. A reviewer does not silently rewrite the code it is reviewing.

### 13.3 Per-Slice Gate

For each vertical slice:

1. Write or update focused failing tests.
2. Implement the smallest code needed to pass them.
3. Run focused tests.
4. Run the complete existing test suite.
5. Build the application for arm64.
6. Request independent integration and code review.
7. Address concrete findings and rerun the gate.
8. Commit only after the gate passes.

A failing gate receives at most two focused repair attempts. If it still fails, stop the overnight run, preserve the branch and worktree, and write a failure report containing the failing command, relevant logs, attempted fixes, current commit, and remaining issue. Dependent slices do not continue.

Agents may choose conservative, project-consistent defaults for low-risk implementation details when tests make the behavior explicit. They must stop for unresolved product ambiguity, destructive action, security-sensitive expansion, a required scope increase, or a conflict with this design.

### 13.4 Final Gate

Before pushing the feature branch:

- All focused and full-suite tests pass from a clean state.
- A clean arm64 build succeeds.
- Save/load, corrupt-primary recovery, launch, and relaunch smoke checks pass.
- Live combat and both DPS metrics are observed.
- Phase 0 placement, fullscreen suppression, passive input, and no-focus-theft behavior receive regression checks.
- Sol completes a whole-branch review with no unresolved blocking findings.
- The branch contains no unrelated changes, generated clutter, secrets, or deferred features.

The overnight report records the branch name, pushed commit, completed slices, commands run, test counts, review findings and resolutions, manual QA evidence, known limitations, and any skipped work.

## 14. Approval Boundaries

This document pre-approves implementation of the four listed slices and conservative details inside their defined contracts. It does not authorize:

- Adding a deferred feature to solve an implementation problem.
- Weakening or deleting a QA gate to make the branch pass.
- Changing Phase 0's accepted overlay behavior.
- Destructive Git operations.
- Pushing a failing branch as completed work.
- Merging to `main`.

If the final gate passes, the branch may be pushed for owner review. Merge approval remains a separate explicit decision.
