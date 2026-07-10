# DockBarHero Phase 0 QA Checklist

**Build commit:** 134c947
**Tester:** Codex primary QA with owner-assisted physical sleep/wake and Dock checks.
**Date:** 2026-07-10
**Machine:** Apple M5 Max MacBook Pro, macOS 26.5.1

## Automated Gates

- [x] Clean command-line build succeeds.
- [x] Complete test suite succeeds: 37/37 tests passed.
- [x] `git diff --check` succeeds.

## Desktop Behavior

- [x] Launch creates one menu bar item and no normal Dock icon: `LSUIElement` true, one panel.
- [x] Rail is centered, 96 points tall, and uses the approved balanced width: stable frame `293,931,1141,96` (or `293,927,1141,96` with visible Dock geometry), centered and eight points above the stable available bottom.
- [x] Passive mode passes clicks and scrolling to underlying applications: Calculator changed 7 to -7 after a real Quartz click; TextEdit scrollbar changed 0.0 to 0.588235 after a real scroll; underlying focus was retained.
- [x] Interactive actor clicks react without taking keyboard focus: the click reached `SKView`, `PrototypeScene.mouseDown`, and the hero node; video bounds increased from about 45x69 to 56x86 (about 1.25x), with no keyboard focus theft.
- [x] Normal Space changes do not duplicate, lose, or jump the rail: switching from Space ID 1 to normal Space ID 3 left one unchanged `293,931,1141,96` panel; returned to ID 1.
- [x] Another application's fullscreen Space hides the rail: final type-4 fullscreen test had zero layer-3 DockBarHero panels.
- [x] Returning to a normal Space restores the rail unless manually hidden: return had exactly one panel; manual hide survived the fullscreen round trip and show restored it.
- [ ] Auto-hidden Dock reveal and conceal do not move the rail.
- [x] Hide/show, pause/resume, and input menu labels match actual state: pixel crops were unchanged while paused and changed after resume; hide/show and enable/disable interaction labels matched state; quit was present.
- [x] Sleep/wake restores exactly one correctly placed rail: software sleep logged at 12:02:41 for 9 seconds, full wake at 12:02:50, same PID 83106, exactly one `1141x96` panel.
- [x] Relaunch returns to shown, running, passive defaults.
- [x] Quit leaves no DockBarHero process or panel: zero process and zero AX process remained.

## Resource Gates

- [x] Active five-minute average CPU is below 5 percent: first 60 samples over five minutes averaged 4.060% CPU and 85.54 MB RSS.
- [ ] Hidden five-minute average CPU is below 0.5 percent.
- [ ] Paused five-minute average CPU is below 0.5 percent.
- [ ] A 30-minute active run shows no monotonic memory growth.

## Recorded Evidence

Full test command and result: `xcodegen generate` completed successfully, then `xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS' -derivedDataPath .build/Phase0Verification clean test CODE_SIGNING_ALLOWED=NO` completed with `** CLEAN SUCCEEDED **`, `** TEST SUCCEEDED **`, and 37 tests passing with 0 failures. Focused startup `AppModel` verification passed 13/13; focused fullscreen classifier verification passed 7/7. QA build commit was `134c947`. `git diff --check` completed with no output.

Script contract RED result: absent path invocation returned exit 127 (`no such file or directory`).

Script contract GREEN result: `scripts/measure-process.sh` with no PID printed `usage: scripts/measure-process.sh PID [DURATION_SECONDS] [INTERVAL_SECONDS]` and exited 64. A one-sample live-process run (`scripts/measure-process.sh <PID> 1 1`) produced `samples=1 average_cpu_percent=0.000 average_rss_mb=1.20`.

Active resource output: first 60 samples over five minutes averaged 4.060% CPU and 85.54 MB RSS; this passes the revised below-5% active CPU requirement.

Hidden resource output: **ACCEPTED DEFERRAL**. The five-minute hidden measurement was not run.

Paused resource output: **ACCEPTED DEFERRAL**. The five-minute paused measurement was not run.

30-minute memory observations: **ACCEPTED DEFERRAL**. The clean run stopped after 135 samples / 673 seconds. RSS was 85.38 MB initially and 85.59 MB finally, with min 85.38 MB, max 85.62 MB, and fitted slope 0.491 MB/hour. This is stable over about 11m13s but does not satisfy the 30-minute gate.

Dock auto-hide evidence: switching to auto-hide moved the panel once to stable `293,1013,1141,96`; 20 one-second samples during a physical-reveal attempt were identical. The 20-second video did not visibly capture the Dock itself appearing, so this checkbox remains unresolved unless separately confirmed by the owner.

Startup review/fix: final Sol review found a launch-in-fullscreen visibility risk. `e4781aa` gated outputs until the initial non-nil environment result; `134c947` restored and expanded regression coverage; independent task review approved.

Live launch gate: the app launched while Preview was already in true type-4 fullscreen. WindowServer was sampled at 100 Hz for 3 seconds; the maximum layer-3 panel count was 0 with 0 positive samples. Return restored one `1141x96` panel.

Fullscreen evidence: the original classifier failed with macOS menu-bar-visible fullscreen geometry. Commits `1055289` and `1bd1e8e` fixed it with TDD and independent approval; final type-4 verification had zero fullscreen panels and exactly one panel after return.

Final whole-branch Sol review approved range `3a8fe29..134c947` with no blocking or important findings. The residual exact-screen false positive is owner accepted; initially nil evaluation safely remains hidden until another monitored event. These entries are evidence of review and retest, not a claim that every strict gate has passed.

## Decision

- [ ] PASS: Phase 0 meets every gate.
- [ ] NO-GO: One or more gate remains unresolved and development is blocked.
- [x] CONDITIONAL/DEFERRED GO: Desktop viability is accepted; development may proceed while unresolved checks remain listed as accepted deferrals.

**Current status:** **OWNER-ACCEPTED CONDITIONAL/DEFERRED GO**. The Dock reveal observation, hidden and paused five-minute measurements, and 30-minute memory gate remain unchecked. They are accepted deferrals, not passed checks. The revised active CPU gate is below 5 percent; hidden/paused and 30-minute requirements remain unchanged.
