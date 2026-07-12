# DockBarHero Foundation Upgrade QA Checklist

Date: 2026-07-12
Branch: `feature/foundation-upgrade`
Base: `origin/feature/phase-1-playable-slice`
Implementation candidate before evidence: `adeacc97a94a89ec702e5d39c3ceb9795fead5ab`
Status: automated and proportional live gates complete.

## Automated Gate

- [x] Complete arm64 test suite passes.
  - Evidence: `.build/FoundationFull` reports 208 passed, 0 failed, 0 skipped.
- [x] Clean arm64 build succeeds.
  - Evidence: `.build/FoundationBuild` clean build exited 0 with signing disabled.
- [x] Project context is valid.
  - Evidence: `context_guard.py check --root .` returned `project context is valid`.
- [x] Phase 1-to-candidate diff is whitespace-clean.
  - Evidence: `git diff --check origin/feature/phase-1-playable-slice...HEAD` produced no output.

## Foundation Contracts

- [x] Combat, encounter, and reward boundaries preserve deterministic Phase 1 behavior.
  - Evidence: 56-test resolver closure gate passed after repairing the reviewed revive-countdown regression.
- [x] Save schema v1 is frozen and migration-ready.
  - Evidence: byte-stable golden v1 fixture plus 43 migration/document/store tests passed.
- [x] Overlay settings persist independently from game saves.
  - Evidence: 54 settings/model/overlay/save-store tests passed, including corrupt-settings game-save isolation.
- [x] Management navigation does not restart gameplay.
  - Evidence: 33 navigation/management/model tests passed.
- [x] Actor presentation uses deterministic pixel sprites.
  - Evidence: 36 sprite/scene/model tests passed; actors are stable named `SKSpriteNode` instances with nearest filtering.

## Live QA

- [x] Fresh build launches and remains alive.
  - Evidence: `./script/build_and_run.sh --verify` succeeded and reported PID 17400.
- [x] Pixel hero and enemy sprites render instead of blocks.
  - Evidence: both multicolor silhouettes were visible above the Dock with health bars, DPS, and enemy level.
- [x] Combat and DPS continue while management routes change.
  - Evidence: live enemy level advanced from 139 into the 170s while Overview, Inventory, and Settings were inspected.
- [x] Overview, Inventory, and Settings routes render their expected controls.
  - Evidence: Overview showed combat/DPS/equipment; Inventory showed the sortable table and auto-equip; Settings showed overlay, animation, and interaction toggles.
- [x] Settings survive clean relaunch independently of the game save.
  - Evidence: animation was set paused, clean quit completed, relaunch exposed `Resume Animation`, then the setting was restored to running. The settings document returned to running/passive/shown while `save-v1.json` remained present at 14,018 bytes.
- [x] Passive launch does not activate DockBarHero.
  - Evidence: the rail rendered while ChatGPT remained the active menu-bar application; the DockBarHero menu continued to offer `Enable Interaction`.
- [x] Existing fullscreen and click-through behavior remains covered.
  - Evidence: direct fullscreen/click-through QA was accepted in Phase 1; Foundation changed neither `OverlayPanel`, `OverlayWindowController`, `EnvironmentMonitor`, nor `FullscreenWindowClassifier`. Their regression tests pass in the 208-test gate. A redundant live fullscreen cycle was not run.

## Review

- [x] Inline Critical/Important review completed for each bounded slice.
- [x] No unresolved Critical or Important finding remains.
- [x] No additional Terra or Sol review was dispatched.
  - Evidence: prior worker/reviewer usage reached 288,699 tokens; the routing skill's budget stop applied and the user approved inline execution/review.
