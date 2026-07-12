# Project Map

## Purpose

DockBarHero is a native macOS menu-bar app with a passive desktop rail. Phase 1 adds deterministic idle combat, DPS, loot and equipment, durable saves, and a management window without weakening the Phase 0 overlay, fullscreen, focus, placement, or input behavior.

## Current Milestone

- Goal: complete the Foundation Upgrade on `feature/foundation-upgrade` without changing accepted Phase 1 behavior.
- Current checkpoint: Tasks 1-2 resolver extraction is implemented through `c01066e`; Terra's one Important revive-countdown finding is repaired and 36 affected tests pass.
- Remaining: choose a lower-cost execution/review mode before Task 3, then migration registry, settings persistence, management navigation, pixel sprites, and milestone QA.
- Acceptance: clean worktree; required tests and arm64 build pass after the focus hold is cleared; live verification succeeds; no blocking findings; push without merge or force.

## Architecture

- GameSimulation: deterministic fixed-point combat, encounter transitions, loot, equipment, and presentation snapshots.
- SimulationDriver: MainActor monotonic advancement and throttled presentation/event delivery.
- GameSession: load/start lifecycle, autosave triggers, bounded request submission, status propagation, and final flush.
- SaveCodec, SaveStore, SaveCoordinator: schema validation, atomic primary/backup recovery, quarantine, and coalescing.
- AppModel: app-wide coordinator for gameplay presentation plus existing overlay state.
- PrototypeScene: snapshot-only SpriteKit rendering and event-only visual reactions.
- AppDelegate: production dependency construction and bounded termination save.

## Key Paths

- docs/superpowers/plans/2026-07-10-dockbarhero-phase-1-playable-slice.md: authoritative task plan.
- docs/superpowers/specs/2026-07-10-dockbarhero-phase-1-playable-slice-design.md: approved design.
- docs/superpowers/specs/2026-07-12-dockbarhero-steam-ready-roadmap-design.md: approved code-first roadmap through Steam-ready release.
- docs/superpowers/plans/2026-07-12-dockbarhero-foundation-upgrade.md: next executable milestone plan.
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

- Parent orchestrator: review-budget stop after Tasks 1-2; no further subagent dispatch until owner selects the lower-cost mode.
- Focus safety: testing and live verification are cleared.
- Subagent routing: Spark for bounded reads or mechanical edits, Luna for implementation, Terra for required review or QA, Sol only for final deep review.
- Foundation branch is local-only and must not be merged, rebased, or force-pushed.

## Last Verified State

- Date: 2026-07-11.
- Worktree: /Users/n3kr0/Projects/TBH/.worktrees/foundation-upgrade at `4da81dd` before Foundation code.
- Baseline: 163 tests passed with zero failures after XcodeGen regeneration on 2026-07-12.
- Phase 1: approved by evidence-only Sol review and pushed through `4da81dd`.

## Decisions and Risks

- Gameplay time is signed Int64 nanoseconds; floating point is presentation-only.
- Save recovery preserves unreadable bytes and no workflow may force-push or merge.
- Known nonblocking limitation: ISO-8601 save timestamps truncate fractional seconds.
- Terra repair covers quit-during-load persistence, unsupported-version status precedence, and sortable inventory creation order.
- Foundation changes must preserve all accepted Phase 1 gameplay and Mac behavior.
- Subagent usage for Tasks 1-2 was materially over budget (91,213 + 128,469 implementation tokens; 69,017 review tokens), so the routing skill's mandatory dispatch stop is active.
- Automated evidence must not be converted into manual visual evidence.
- Provisional graphics use pixel sprites; production art polish is deferred behind code systems.
- The release target is Apple Silicon and Steam-ready without tradable-item economy.
