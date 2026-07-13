# Project Map

## Purpose

DockBarHero is a native macOS menu-bar idle RPG with a passive desktop rail, deterministic combat and progression, durable local runs, and a management window that preserves the accepted overlay, fullscreen, focus, placement, and input behavior.

## Current Milestone

- Goal: verify and push Heroes and Party on the integrated Foundation and schema-v2 Progression Safety systems without merging to `main`.
- Current checkpoint: Heroes and Party is implemented, verified, and pushed in six vertical slices on `feature/heroes-and-party`.
- Integration: the owner lifted the internal hold and the feature branch was fast-forwarded and pushed to `main` on 2026-07-12.
- Remaining: owner review of the pushed feature branch; Class Actions remain a later milestone and this is not release-ready.

## Architecture

- GameSimulation: deterministic fixed-point combat, tiered rewards, XP/levels, farming, retreat, loot, equipment, and presentation snapshots.
- SimulationDriver: MainActor monotonic advancement and throttled presentation/event delivery.
- GameSession: explicit class-selection/active lifecycle, autosave triggers, safe run replacement, status propagation, and final flush.
- SaveCodec, SaveStore, SaveCoordinator: schema-v2 validation, v2-only atomic recovery/replacement, quarantine, and coalescing.
- AppModel: run presentation, management navigation, first-run window requests, gameplay snapshots, and existing overlay state.
- PrototypeScene: snapshot-only SpriteKit rendering and event-only visual reactions.
- AppDelegate: production dependency construction and bounded termination save.

## Key Paths

- docs/superpowers/plans/2026-07-10-dockbarhero-phase-1-playable-slice.md: authoritative task plan.
- docs/superpowers/specs/2026-07-10-dockbarhero-phase-1-playable-slice-design.md: approved design.
- docs/superpowers/specs/2026-07-12-dockbarhero-steam-ready-roadmap-design.md: approved code-first roadmap through Steam-ready release.
- docs/superpowers/specs/2026-07-12-dockbarhero-progression-safety-design.md: approved progression recovery, classes, party, tiers, rewards, and schema-v2 design.
- docs/superpowers/plans/2026-07-12-dockbarhero-foundation-upgrade.md: next executable milestone plan.
- docs/superpowers/plans/2026-07-12-dockbarhero-progression-safety.md: executable first-gate plan for XP, tiers, gold, farming, retreat, schema v2, reset, and management empty states.
- docs/superpowers/specs/2026-07-12-dockbarhero-heroes-and-party-design.md: approved party lifecycle, combat, rewards, equipment, and presentation behavior.
- docs/superpowers/plans/2026-07-12-dockbarhero-heroes-and-party.md: executable six-slice Heroes and Party plan.
- docs/qa/review-packets/heroes-and-party.md: focused, integrated, save-isolation, and live-QA evidence.
- docs/qa/review-packets/progression-safety.md: current automated evidence, manual QA list, and integration hold.
- .superpowers/sdd/progress.md: detailed task and gate ledger.
- .superpowers/sdd/task-9-report.md: latest Task 9 evidence.
- DockBarHero/Game/: simulation, driver, session, loot, and metrics.
- DockBarHero/Persistence/: save schema, store, and coordinator.
- DockBarHero/App/: delegate, model, app scenes, and menu.
- DockBarHero/Rendering/: SpriteKit rail.
- DockBarHeroTests/: focused unit and integration tests.

## Commands

- Generate: xcodegen generate
- Focused test: xcodebuild with platform=macOS,arch=arm64 and one TEST_CLASS.
- Full test: xcodebuild test with platform=macOS,arch=arm64.
- Clean build: xcodebuild clean build with CODE_SIGNING_ALLOWED=NO.
- Live verify: ./script/build_and_run.sh --verify
- Context check: python3 /Users/n3kr0/.codex/skills/maintaining-project-context/scripts/context_guard.py check --root .
- Verification hold: cleared by the owner on 2026-07-11.

## Active Work

- Parent orchestrator: preserve the pushed Heroes and Party worktree for owner review without merging.
- Next design work after owner review: Tank, DPS, and Healer actions.
- Manual QA items not explicitly exercised remain open in the Progression Safety review packet.

## Last Verified State

- Date: 2026-07-12.
- Checkout: `/Users/n3kr0/Projects/TBH/.worktrees/heroes-and-party` on `feature/heroes-and-party`.
- Final gate: 290 arm64 tests passed with zero failures; clean unsigned arm64 build, context guard, and exact-worktree launch all succeeded.
- Live clean-save QA selected DPS, persisted/relaunched the Boss 25 Tank/Healer choice, selected Healer, and observed Tank auto-add at Boss 100 with uninterrupted level 101-plus combat.
- Live management showed ordered party summaries and shared inventory ownership; the verified worktree rail showed three class-distinct sprites, health bars, level labels, and centered rolling DPS.

## Decisions and Risks

- Gameplay time is signed Int64 nanoseconds; floating point is presentation-only.
- Save recovery preserves unreadable bytes; schema v2 uses only v2 paths and starts fresh because no player saves were released.
- Known nonblocking limitation: ISO-8601 save timestamps truncate fractional seconds.
- Terra repair covers quit-during-load persistence, unsupported-version status precedence, and sortable inventory creation order.
- Foundation changes must preserve all accepted Phase 1 gameplay and Mac behavior.
- Implementation stayed inline; only approved Terra and Sol review checkpoints are allowed.
- Automated evidence must not be converted into manual visual evidence.
- Provisional graphics use pixel sprites; production art polish is deferred behind code systems.
- The release target is Apple Silicon and Steam-ready without tradable-item economy.
- Progression Safety is the first gate inside the schema-v2 Heroes and Classes milestone and is not independently release-eligible.
- The frontier and farming selection remain separate; three defeats retreat one full Boss segment and never auto-return to the frontier.
- A loaded class-selection run opens the singleton management window; active runs retain menu-bar access to that same window.
- Boss 25 rewards and the pending second-class choice are durable before combat pauses; Boss 100 adds the final unique class without pausing.
- Inventory is party-shared, equipped item IDs are exclusive per hero, and newcomers take the strongest unused weapon and armor.
- Party combat uses independent hero timers, ascending slot ties, lowest-living targeting, time-alive XP, and per-hero death streaks.
