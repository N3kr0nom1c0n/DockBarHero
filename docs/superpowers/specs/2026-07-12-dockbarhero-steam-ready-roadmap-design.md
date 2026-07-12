# DockBarHero Steam-Ready Roadmap Design

**Status:** Approved

**Date:** 2026-07-12

**Project:** DockBarHero

**Builds on:**

- `mac-taskbar-hero-project-outline.md`
- `docs/superpowers/specs/2026-07-10-dockbarhero-phase-0-design.md`
- `docs/superpowers/specs/2026-07-10-dockbarhero-phase-1-playable-slice-design.md`

## 1. Purpose

This roadmap takes the existing deterministic Phase 1 playable slice to a polished, Steam-ready, Apple-Silicon Mac release. Development remains code-first. Provisional pixel sprites replace block actors, while production art and animation polish remain later release-candidate work.

The target release is local-first and fully playable without Steam. Steam achievements, stats, and cloud saves are optional adapters. Tradable items, a market economy, multiplayer, live operations, and always-online behavior are separate future products and are not part of this roadmap.

## 2. Approved Product Decisions

- Use dependency-ordered vertical slices that keep the application runnable after every milestone.
- The player chooses Tank, DPS, or Healer at the beginning.
- Combat begins with one hero and unlocks up to three active party slots.
- The second slot unlocks after the first area boss. The player chooses one of the two remaining classes.
- The third slot unlocks after the second area boss and receives the remaining class.
- The second-class choice is permanent for the current run. Class respec and party reordering are deferred.
- Unlock requirements are content data, not hard-coded save semantics, so their levels and conditions can change later.
- Basic attacks are automatic.
- Each class initially has a manually activated class ability.
- Manual abilities are available in the management window and as compact icon controls only while the rail is explicitly interactive. Passive mode remains click-through.
- Automatic class-ability casting is a later progression unlock and is disabled by default.
- Offline progression has an initial eight-hour cap. The cap is balance data and may become upgradeable later.
- Pixel sprites are the provisional rendering direction. Asset quality can improve without changing gameplay identity or save data.
- The first release supports Apple Silicon only.
- The release target is Steam-ready without Steam Market or tradable inventory.

## 3. Current Baseline

Phase 0 established the passive Mac overlay, placement, fullscreen suppression, animation suspension, and menu-bar controls. Phase 1 established:

- checked fixed-point combat timing;
- deterministic attacks, victory, defeat, revive, and enemy-level progression;
- rolling and encounter DPS;
- deterministic weapon and armor drops;
- manual equipment and auto-equip;
- versioned atomic local saves with backup recovery;
- autosave and bounded clean termination;
- a management window and SpriteKit rail presentation.

The Phase 1 branch is automated-test and static-review clean, but its final push remains blocked on recorded live gameplay, relaunch, management, and Phase 0 observations.

## 4. Execution Strategy

Every milestone is a vertical release slice. A slice includes the domain contracts, deterministic behavior, persistence, management surface, rail presentation, tests, migration fixtures when required, manual evidence, and independent incremental review.

Gameplay systems are not built as a disconnected engine and integrated later. Mac product work is also not allowed to delay proving the expanded game loop. Each accepted checkpoint remains runnable and save-safe.

## 5. Target Architecture

### 5.1 Simulation Kernel

`GameSimulation` remains the deterministic clock owner and candidate-state transaction boundary. It coordinates smaller pure systems:

- `CombatResolver`: attack scheduling, damage, healing, targeting, death, and revive.
- `AbilityResolver`: availability, resources, cooldowns, manual activation, and later auto-cast policy.
- `EncounterDirector`: area, encounter, elite, boss, retry, and campaign transitions.
- `RewardResolver`: XP, currency, loot, hero-slot unlocks, and progression unlocks.
- `LootGenerator`: deterministic item templates, rarity, affixes, and stable item identity.
- `OfflineProgressCalculator`: bounded aggregate outcomes using the same balance and reward rules.

All gameplay time remains signed `Int64` nanoseconds through `SimulationDuration`. Floating point remains presentation-only. Candidate state commits only after a complete transition succeeds.

### 5.2 Deterministic Ordering

Party combat requires one explicit stable action order. Simultaneous candidates sort by:

1. simulation timestamp;
2. combat side;
3. party slot or enemy slot;
4. action priority;
5. stable ability identifier.

Hero-versus-enemy exact ties preserve the existing hero-first rule. No gameplay resolver may use process-global randomness, collection iteration order, animation state, wall-clock time, or localized content.

### 5.3 State Boundaries

The local-MVP state is divided into explicit value types:

- `PartyState`: active slots, hero records, selected starting class, and unlocked-slot state.
- `HeroState`: class ID, level, XP, combat values, equipment references, ability state, and progression unlocks.
- `CampaignState`: area, encounter, variant, boss state, and campaign milestones.
- `EconomyState`: currencies and durable reward counters.
- `InventoryState`: owned items, equipment references, lock state, filters independent of save identity, and salvage rules.
- `OfflineState`: last trusted checkpoint, consumed grant identity, and cap-related state.
- `ActivityHistory`: bounded aggregate victories, notable drops, recovery events, and offline summaries.

Transient DPS samples, animation queues, selected management rows, and window navigation are not game-save state.

### 5.4 Content Catalog

Classes, abilities, enemies, encounters, areas, bosses, item templates, affix tables, XP curves, costs, unlock requirements, and offline caps come from a validated bundled `ContentCatalog`.

Content uses stable coded identifiers. Startup validates referential integrity, ranges, duplicate IDs, campaign reachability, reward tables, and required class coverage. Invalid required content prevents a new simulation from starting and produces a clear diagnostic; it never partially mutates an existing save.

No remote balance configuration or live content download is included.

### 5.5 Persistence

The current Phase 1 save remains schema v1. Foundation work introduces the migration registry and locks a golden v1 fixture. The Heroes and Classes milestone introduces one coherent local-MVP schema v2, once `PartyState` and class identity exist, with a pure migration from v1. Internal tasks do not create artificial public schema versions for every code change.

The save envelope contains schema metadata, save identity, monotonic snapshot sequence, content version, and game state. Migration:

- decodes and validates the historical document;
- transforms it without wall-clock or locale dependence;
- validates the migrated state;
- preserves the original bytes until the migrated primary and backup are durable;
- never silently discards an unsupported future document.

Overlay placement, display selection, audio, animation, performance, accessibility, onboarding, and launch-at-login preferences live in a separate versioned settings document. Settings corruption may reset preferences but cannot affect progress.

### 5.6 Presentation And Services

`AppModel` publishes coherent gameplay presentation, activity summaries, save status, and management navigation. SwiftUI owns conventional management and settings surfaces. AppKit remains isolated to overlay/window, screen, input, and platform adapters.

SpriteKit renders snapshots and reacts to domain events. A `SpriteCatalog` maps stable content IDs to provisional pixel sprite sheets and returns a visible placeholder for missing assets. Rendering never schedules gameplay or grants rewards.

Audio, launch at login, crash reporting, telemetry, and Steam are optional service boundaries. Their failure cannot delay startup, gameplay, local saving, or termination.

## 6. Milestones

### 6.1 Phase 1 Closeout

- Complete the unchecked live QA checklist.
- Obtain an evidence-only Sol verdict.
- Record final evidence and push the feature branch without force.

### 6.2 Foundation Upgrade

- Extract deterministic resolver boundaries without changing Phase 1 outcomes.
- Add the save migration registry and golden v1 fixtures without changing the emitted schema.
- Add isolated settings persistence.
- Introduce management navigation.
- Add `SpriteCatalog`, sprite sequences, and placeholder fallback.

### 6.3 Heroes And Classes

- Add Tank, DPS, and Healer content definitions.
- Add first-run class choice and a one-slot `PartyState`.
- Add the local-MVP v2 save envelope and migrate the v1 hero into the selected/default one-slot party.
- Preserve automatic basic attacks.
- Add one manual active ability per class and deterministic targeting/cooldowns.
- Route manual casts through domain intents from management controls and interactive-only rail icons.
- Add party and ability management presentation.

### 6.4 Campaign And Party Unlocks

- Add data-driven areas, normal encounters, elites, and bosses.
- Add boss retry and campaign transition rules.
- Unlock slot two after the first area boss and present the remaining-class choice.
- Unlock slot three after the second area boss with the final class.
- Keep requirements data-driven for later tuning.

### 6.5 Progression And Economy

- Add hero XP, levels, encounter-boundary level application, currency, and upgrade costs.
- Add bounded recent activity and reward history.
- Add progression unlocks, including the later ability auto-cast unlock.
- Keep prestige and respec deferred until pacing evidence requires them.

### 6.6 Loot And Inventory

- Add stable equipment slots beyond weapon and armor only when class builds require them.
- Add rarity, deterministic affixes, item comparisons, filters, lock, and salvage.
- Preserve every owned item unless the player explicitly salvages it.
- Make salvage grants atomic and lock-protected.
- Keep crafting, sockets, sets, trading, and market inventory deferred.

### 6.7 Offline Progression

- Add an injected trusted clock policy and eight-hour cap.
- Aggregate complete deterministic transitions instead of replaying render frames.
- Micro-step only at state boundaries that cannot be aggregated safely.
- Atomically mark each offline grant consumed with the resulting save.
- Present time away, encounters completed, XP/currency earned, and notable loot.
- Treat clock rollback as zero elapsed time and record a local diagnostic.

### 6.8 Mac Product Polish

- Add display selection, manual offset, and resilient hot-plug behavior.
- Harden passive and interactive transitions without focus theft.
- Add audio, animation rate, low-power, hidden-render, and reduced-motion controls.
- Add onboarding, keyboard navigation, accessibility labels, and high-contrast support.
- Add launch-at-login through a replaceable system adapter.
- Expand live QA for Spaces, fullscreen, Stage Manager, Dock modes, mixed-scale displays, and sleep/wake.

### 6.9 Content Completion

Planning targets remain:

- three classes;
- three areas and one boss per area;
- eight to twelve normal enemy types with a small elite modifier set;
- thirty to fifty item templates with deterministic rolls;
- fifteen to twenty-five class abilities or upgrades total;
- provisional pixel sprites for every required combat identity and state.

Content ships in small playable packs during the earlier milestones. This milestone closes gaps, tunes pacing, and replaces no-code placeholders; it is not the first point at which content is playable.

### 6.10 Steam-Ready Release Candidate

- Add an optional `SteamService` with a complete local fake.
- Add stable achievement/stat mappings outside simulation code.
- Add Steam Cloud only after local migration and offline claims are stable.
- Preserve both local and remote copies on conflict and require an explicit choice.
- Add opt-in, privacy-reviewed crash reporting and aggregate telemetry.
- Complete Developer ID signing, hardened runtime, notarization, packaging, update delivery, and rollback validation.
- Complete the Apple Silicon hardware and supported-macOS QA matrix.

Current Steamworks, Apple signing/notarization, updater, privacy, and SDK requirements must be verified from primary vendor documentation when those milestones begin.

## 7. Error And Data-Safety Rules

- Invalid gameplay inputs fail before caller-visible mutation.
- Content validation fails closed before simulation start.
- Save and migration failures preserve the last valid primary, backup, and unreadable source bytes.
- Settings failures are isolated from game progress.
- Offline grants are idempotent across crashes and relaunches.
- Cloud conflicts never use silent last-write-wins behavior.
- Optional service failures are non-blocking and locally diagnosable.
- Telemetry never contains raw saves, inventories, user file paths, free-form content, or stable device identity without an approved need and consent.

## 8. Testing And Release Gates

Each vertical slice uses test-driven implementation and must pass:

1. focused domain and integration tests;
2. save/migration fixtures for changed persisted contracts;
3. complete unit test suite once at the integrated milestone gate;
4. clean Apple-Silicon build;
5. proportional live Mac QA;
6. incremental independent review with no unresolved Critical or Important finding;
7. a clean scoped commit and durable review packet.

Determinism tests compare complete state and event order across equivalent time partitions. Party tests cover exact ties and stable ordering. Offline tests compare aggregate and normal simulation over bounded reference windows. Persistence tests cover interrupted migration, unsupported future versions, corrupt primary/backup, idempotent grants, upgrades, and recovery.

Release-candidate gates additionally cover signed installation, Gatekeeper, upgrade/rollback preservation, cloud conflicts, no-Steam behavior, accessibility, energy use, and the hardware/display matrix.

## 9. Token-Bounded Agent Workflow

The parent model owns specifications, task boundaries, integration, backlog truth, and final decisions.

- Use at most two Luna implementers concurrently, only on independent paths.
- Use Spark for bounded inventories, fixture generation, summaries, and mechanical edits.
- Use Terra for incremental slice review and focused QA analysis.
- Use Sol only at the local-MVP architecture freeze and final release-candidate gate, except for the current evidence-only Phase 1 recheck.
- Only the parent updates `PROJECT.md` or shared roadmap state.

Before review, the parent writes a compact packet containing accepted base/candidate SHAs, changed contracts and paths, acceptance criteria, summarized test/build results, known risks, and manual evidence. Terra reads only that packet, changed tests, and the incremental diff. Review output is limited to actionable Critical and Important findings.

Reviewer sessions are reused for repair follow-up where practical. Reviewers do not rerun tests already executed by the parent. Documentation-only evidence does not trigger another code review. If actual usage materially exceeds the requested budget, further agent dispatch stops and the gate state is preserved for explicit review.

## 10. Explicitly Deferred

- Steam Market and tradable items.
- Server-authoritative economy and player trading.
- Multiplayer, PvP, guilds, chat, and leaderboards.
- Cross-platform and Intel Mac release support.
- Mobile companion applications.
- App Store distribution.
- Prestige unless progression testing demonstrates a need.
- Crafting, sockets, complex sets, and procedural enchantment systems.
- Seasons, daily quests, battle passes, rotating shops, and remote live balance.
- Production-quality art replacement before the release-candidate content pass.
- Generative runtime content.

## 11. Completion Criteria

The roadmap is complete when an Apple-Silicon Mac player can choose a starting role, unlock a three-role party, use class abilities, progress through three areas and bosses, build heroes through levels and loot, manage and salvage inventory, receive bounded offline progress, preserve progress across local and optional cloud workflows, and use the desktop companion without focus theft or unacceptable resource use.

The release must remain fully playable with Steam unavailable and must contain no tradable-item or always-online dependency.
