# Task 4 Report: Monotonic Simulation Driver

## Files changed

- `DockBarHero/Game/SimulationDriver.swift`
- `DockBarHeroTests/SimulationDriverTests.swift`
- `DockBarHero.xcodeproj/project.pbxproj`
- `.superpowers/sdd/task-4-report.md`

No Task 3 or unrelated source files were changed. The Xcode project update only adds the Task 4 production and test sources to their existing groups and source phases.

## Pre-implementation failing-test evidence

Command:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/Task4Red CODE_SIGNING_ALLOWED=NO test -only-testing:DockBarHeroTests/SimulationDriverTests
```

Result: failed before implementation because the newly wired production input was absent:

```text
error: Build input file cannot be found: '.../DockBarHero/Game/SimulationDriver.swift'
Testing cancelled because the build failed.
```

## Verification

Focused command:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/Task4FocusedFinal CODE_SIGNING_ALLOWED=NO test -only-testing:DockBarHeroTests/SimulationDriverTests
```

Result: `SimulationDriverTests` passed, 7 tests, 0 failures.

Full command:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/Task4FullFinal CODE_SIGNING_ALLOWED=NO test
```

Result: all tests passed, 77 tests, 0 failures.

`git diff --check` also passed. The cross-task Terra Gate A was not run, as requested.

## Implementation notes and risks

- `SimulationDriver` is MainActor-isolated and uses the injected monotonic `UInt64` source, defaulting to `DispatchTime.now().uptimeNanoseconds`.
- Each callback clamps elapsed time to exactly `1_000_000_000` nanoseconds before converting to signed `SimulationDuration`.
- Backward timestamps are ignored without mutating simulation or timing state.
- Presentation publication is immediate on start and state replacement, then throttled to 250 milliseconds; events are delivered immediately after each successful advance.
- The loop is a single cancellable MainActor task with 100 millisecond sleeps. `start` and `stop` are idempotent.
- `replaceState` creates a fresh `GameSimulation`, which resets transient DPS metrics, and resets both timing markers to the injected current time.
- Invalid simulation advancement reports an assertion failure and leaves the driver timing markers unchanged. Phase 1 callers are expected to provide validated state and balance data.

## Final commit hash

ea0bfb4
