# DockBarHero Phase 0 QA Checklist

**Build commit:**
**Tester:**
**Date:**
**Machine:** Apple M5 Max MacBook Pro, macOS 26.5.1

## Automated Gates

- [x] Clean command-line build succeeds.
- [x] Complete test suite succeeds.
- [x] `git diff --check` succeeds.

## Desktop Behavior

- [ ] Launch creates one menu bar item and no normal Dock icon.
- [ ] Rail is centered, 96 points tall, and uses the approved balanced width.
- [ ] Passive mode passes clicks and scrolling to underlying applications.
- [ ] Interactive actor clicks react without taking keyboard focus.
- [ ] Normal Space changes do not duplicate, lose, or jump the rail.
- [ ] Another application's fullscreen Space hides the rail.
- [ ] Returning to a normal Space restores the rail unless manually hidden.
- [ ] Auto-hidden Dock reveal and conceal do not move the rail.
- [ ] Hide/show, pause/resume, and input menu labels match actual state.
- [ ] Sleep/wake restores exactly one correctly placed rail.
- [ ] Relaunch returns to shown, running, passive defaults.
- [ ] Quit leaves no DockBarHero process or panel.

## Resource Gates

- [ ] Active five-minute average CPU is below 3 percent.
- [ ] Hidden five-minute average CPU is below 0.5 percent.
- [ ] Paused five-minute average CPU is below 0.5 percent.
- [ ] A 30-minute active run shows no monotonic memory growth.

## Recorded Evidence

Full test command and result: `xcodegen generate` completed successfully, then `xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS' -derivedDataPath .build/Phase0Verification clean test CODE_SIGNING_ALLOWED=NO` completed with `** CLEAN SUCCEEDED **`, `** TEST SUCCEEDED **`, and 28 tests passing with 0 failures. `git diff --check` completed with no output.

Script contract RED result: absent path invocation returned exit 127 (`no such file or directory`).

Script contract GREEN result: `scripts/measure-process.sh` with no PID printed `usage: scripts/measure-process.sh PID [DURATION_SECONDS] [INTERVAL_SECONDS]` and exited 64. A one-sample live-process run (`scripts/measure-process.sh <PID> 1 1`) produced `samples=1 average_cpu_percent=0.000 average_rss_mb=1.20`.

Active resource output: **PENDING PRIMARY-MODEL GUI QA**

Hidden resource output: **PENDING PRIMARY-MODEL GUI QA**

Paused resource output: **PENDING PRIMARY-MODEL GUI QA**

30-minute memory observations: **PENDING PRIMARY-MODEL GUI QA**

Failures, fixes, and retest evidence: No application-code changes made; primary-model GUI/resource verification remains pending.

## Decision

- [ ] PASS: Phase 0 meets every gate.
- [ ] NO-GO: One or more gate remains unresolved.

**Current status:** **PENDING PRIMARY-MODEL QA**. Manual and resource gates are intentionally not marked passed by the worker.
