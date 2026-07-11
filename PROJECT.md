# Project Map

## Purpose

DockBarHero is a native macOS menu-bar app with a passive desktop rail. Phase 1 adds deterministic idle combat, DPS, loot and equipment, durable saves, and a management window without weakening the Phase 0 overlay, fullscreen, focus, placement, or input behavior.

## Current Milestone

- Goal: finish the Phase 1 playable slice on feature/phase-1-playable-slice.
- Current checkpoint: Task 9 is accepted after a clean static Terra re-review; compact context is committed at 1f50dec.
- Remaining: implement Task 10 management UI, then pause for owner clearance before Gate D, Terra integration review, Sol final review, QA evidence, and feature-branch push.
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
- Focus hold: do not run generate, test, build, or live commands until the owner explicitly clears screen-focus-sensitive testing.

## Active Work

- Parent orchestrator: Task 10 code and test authoring only; execution remains blocked by the focus hold.
- Focus safety: static reads, reviews, and edits only. Do not launch DockBarHero, an XCTest host, Xcode UI, build_and_run.sh, UI automation, screenshots, or any command that may activate a window.
- Subagent routing: Spark for bounded reads or mechanical edits, Luna for implementation, Terra for required review or QA, Sol only for final deep review.
- Feature branch is local-only and must not be merged; final approved work may be pushed without force.

## Last Verified State

- Date: 2026-07-11.
- Worktree: /Users/n3kr0/Projects/TBH/.worktrees/phase-1-playable-slice, Task 9 reviewed code at 40027d1 and compact context commit at 1f50dec.
- Task 9 repair evidence in .superpowers/sdd/task-9-report.md: 41 focused tests, 156 full tests, and clean arm64 build passed before the pause.
- Tasks 1-8 passed Gates A-C. Task 9 final static Terra review is clean; runtime evidence remains the pre-pause 41 focused, 156 full, and clean arm64 build.

## Decisions and Risks

- Gameplay time is signed Int64 nanoseconds; floating point is presentation-only.
- Save recovery preserves unreadable bytes and no workflow may force-push or merge.
- Known nonblocking limitation: ISO-8601 save timestamps truncate fractional seconds.
- Task 10 artifacts are absent: ManagementView.swift and docs/qa/phase-1-checklist.md.
- Testing is intentionally blocked by the owner's focus-sensitive game session; stop before any potentially foregrounding command.
