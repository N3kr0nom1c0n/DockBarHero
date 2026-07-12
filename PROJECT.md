# Project Map

## Purpose

DockBarHero is a native macOS menu-bar app with a passive desktop rail. Phase 1 adds deterministic idle combat, DPS, loot and equipment, durable saves, and a management window without weakening the Phase 0 overlay, fullscreen, focus, placement, or input behavior.

## Current Milestone

- Goal: finish the Phase 1 playable slice on feature/phase-1-playable-slice.
- Current checkpoint: Task 10 management UI is implemented and automated Gate D verification is green.
- Remaining: Terra integration review, any bounded repair, Sol final review, QA evidence closeout, and feature-branch push.
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

- Parent orchestrator: Task 10 integration and final review gates.
- Focus safety: testing and live verification are cleared.
- Subagent routing: Spark for bounded reads or mechanical edits, Luna for implementation, Terra for required review or QA, Sol only for final deep review.
- Feature branch is local-only and must not be merged; final approved work may be pushed without force.

## Last Verified State

- Date: 2026-07-11.
- Worktree: /Users/n3kr0/Projects/TBH/.worktrees/phase-1-playable-slice at pre-review Task 10 state.
- Gate D: 34 focused tests and 162 full tests passed with zero failures; clean arm64 build and `build_and_run.sh --verify` succeeded.
- Live lifecycle: PID 16696 launched, accepted a normal Cocoa termination request, exited, and wrote a 2,333-byte primary save.
- Tasks 1-8 passed Gates A-C. Task 9 final static Terra review is clean.

## Decisions and Risks

- Gameplay time is signed Int64 nanoseconds; floating point is presentation-only.
- Save recovery preserves unreadable bytes and no workflow may force-push or merge.
- Known nonblocking limitation: ISO-8601 save timestamps truncate fractional seconds.
- Task 10 artifacts are not yet committed; manual visual observations, reviews, and push remain pending.
- Automated evidence must not be converted into manual visual evidence.
