# Project Map

## Purpose

DockBarHero is a native macOS menu-bar idle RPG with a passive desktop rail, deterministic combat and progression, durable local runs, and a management window that preserves the accepted overlay, fullscreen, focus, placement, and input behavior.

## Current Milestone

- Goal: build Heroes and Party on the integrated Foundation and schema-v2 Progression Safety systems.
- Current checkpoint: Foundation and Progression Safety are integrated to `main`; review repair, automated verification, launch-window recovery, and visible New Game confirmation are complete.
- Integration: the owner lifted the internal hold and the feature branch was fast-forwarded and pushed to `main` on 2026-07-12.
- Remaining: unchecked manual interaction QA, Heroes and Party, and the three class actions; this is not a release-ready milestone.

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

- Parent orchestrator: begin the Heroes and Party design/plan from `main` when requested.
- Next design work: Heroes and Party, then Tank, DPS, and Healer actions.
- Manual QA items not explicitly exercised remain open in the Progression Safety review packet.

## Last Verified State

- Date: 2026-07-12.
- Checkout: /Users/n3kr0/Projects/TBH on `main`.
- Progression gate: 255 tests passed with zero failures on 2026-07-12 after launch-window and Danger Zone repairs.
- Clean unsigned Apple Silicon Debug build succeeded; `./script/build_and_run.sh --verify` launched DockBarHero.
- Owner visually accepted the rounded New Game confirmation field; other unchecked manual QA remains pending.

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
