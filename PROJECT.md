# Project Map

## Purpose

DockBarHero is a native macOS menu-bar app with a passive desktop rail. Phase 1 adds deterministic idle combat, DPS, loot and equipment, durable saves, and a management window without weakening the Phase 0 overlay, fullscreen, focus, placement, or input behavior.

## Current Milestone

- Goal: design the schema-v2 Progression Safety, Heroes, and Classes milestone on the accepted Foundation branch.
- Current checkpoint: Foundation is accepted and pushed at `fc0ace0`; progression design decisions are approved and the written spec awaits owner review.
- Execution mode: inline parent design work; research dispatch is closed after exceeding the token guard.
- Remaining: owner review of the written spec, then a separate implementation plan. No production implementation is authorized yet.
- Acceptance: approved written spec and roadmap alignment before implementation planning begins.

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
- docs/superpowers/specs/2026-07-12-dockbarhero-progression-safety-design.md: approved progression recovery, classes, party, tiers, rewards, and schema-v2 design.
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

- Parent orchestrator: written progression spec and roadmap synchronization only; no gameplay edits.
- Focus safety: testing and live verification are cleared.
- Subagent routing: closed for this design after research runs materially exceeded the budget.
- Foundation branch is pushed but must not be merged, rebased, or force-pushed during design review.

## Last Verified State

- Date: 2026-07-12.
- Worktree: /Users/n3kr0/Projects/TBH/.worktrees/foundation-upgrade on `feature/foundation-upgrade` at pushed SHA `fc0ace0` before progression-design documentation.
- Foundation gate: 208 tests passed with zero failures and a clean Apple Silicon build.
- Phase 1 and Foundation acceptance evidence are committed and pushed without merge or force.

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
- Progression Safety is the first gate inside the schema-v2 Heroes and Classes milestone; schema v2 starts fresh because there are no released v1 player saves.
- The frontier and farming selection remain separate; three defeats retreat one full Boss segment and never auto-return to the frontier.
