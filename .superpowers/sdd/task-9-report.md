# Task 9 Report: AppModel And Rail Integration

## Files

- `DockBarHero/App/AppModel.swift`
- `DockBarHero/App/AppDelegate.swift`
- `DockBarHero/Rendering/PrototypeScene.swift`
- `DockBarHero/Rendering/PrototypeSceneHost.swift`
- `DockBarHeroTests/AppModelTests.swift`
- `DockBarHeroTests/PrototypeSceneHostTests.swift`
- `.superpowers/sdd/task-9-report.md`

Base HEAD: `6d15e51e63f750b50b4f3e2f320e187f90189756`

## RED Evidence

After adding the focused coordinator and scene tests, the first run was:

```text
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/AppModelTests -only-testing:DockBarHeroTests/PrototypeSceneHostTests
```

It failed during test-target compilation because the scene contracts were absent:

```text
value of type 'PrototypeScene' has no member 'render'
value of type 'PrototypeScene' has no member 'handle'
```

This was the intended pre-implementation failure for the new snapshot and event assertions.

## Implementation

- `AppModel` now publishes `game` and `saveStatus`, wires all `GameSessionControlling` callbacks, forwards presentation and events to the scene, forwards gameplay intents with logged error handling, and awaits `stopAndSave()` after stopping overlay services.
- Gameplay startup is independent of overlay dependencies. Separate gameplay and overlay startup flags preserve the Phase 0 ability to connect the rail after an unconnected start.
- `AppDelegate` constructs `SaveStore -> SaveCoordinator -> SimulationDriver -> GameSession` before scene creation. Gameplay starts before the host is created, and a host construction failure leaves the menu-bar application and gameplay session available.
- Termination returns `.terminateLater` only for the first request, races `model.stopAndSave()` against five seconds through a one-shot MainActor-safe continuation, logs only completion or timeout, replies once, and makes later callbacks idempotent.
- `SceneControlling` now exposes snapshot `render` and event `handle` methods. The scene creates stable named health bars and labels once, clamps fills, uses `Lv. N`, and formats rolling DPS with a POSIX monospaced one-decimal string.
- The repeating mock attack was removed. Attack, victory, defeat, and revive reactions are driven only by `GameEvent`; they do not call gameplay code.

## Verification

Focused AppModel, PrototypeSceneHost, and GameSession tests:

```text
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/Task9Focused CODE_SIGNING_ALLOWED=NO -resultBundlePath .build/Task9Focused.xcresult -only-testing:DockBarHeroTests/AppModelTests -only-testing:DockBarHeroTests/PrototypeSceneHostTests -only-testing:DockBarHeroTests/GameSessionTests
```

Result: 36 tests passed, 0 failures.

Full suite:

```text
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/Task9Full CODE_SIGNING_ALLOWED=NO -resultBundlePath .build/Task9Full.xcresult
```

Result: 151 tests passed, 0 failures.

Clean arm64 build:

```text
xcodebuild clean build -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/Task9CleanBuild CODE_SIGNING_ALLOWED=NO
```

Result: clean succeeded and build succeeded. Xcode emitted the existing non-fatal App Intents/linkd and accessibility test-host warnings.

`git diff --check` passed.

## Lifecycle And Rendering Decisions

- AppModel retains the existing overlay environment-resolution guard and applies it only to window visibility, input, and SpriteKit animation. The gameplay session remains active when screen, scene, or overlay dependencies are unavailable.
- The scene owns all SpriteKit nodes and actions. The model owns presentation state and event routing; the scene never computes combat or schedules attacks.
- Health fills use fixed 150 by 5 point geometry with an origin-anchored path and `xScale`, so changing health changes only fill width. Labels and bars are placed on separate fixed y bands within the existing 1,140 by 96 rail.
- Timeout cancellation is deliberately bounded at the caller. The losing task is canceled after the one-shot race completes; no save contents are logged.

## Risks

- The timeout path permits the underlying save task to be canceled when the app must continue termination. The last valid durable save remains the persistence boundary, as specified by the plan.
- The verification is unit and integration coverage plus a clean build; no manual installed-app fullscreen smoke run was performed in this task.
- The existing Xcode test host reports unavailable App Intents/linkd services and accessibility shield messages. They did not affect test outcomes.

## Hashes

The source hashes below are SHA-256 values for the Task 9 implementation files at report creation time:

```text
04c76d9d3a38cf2523a75f22bfeda675ee08156218014b3079b4fa1fe4746821  DockBarHero/App/AppModel.swift
26a9df3cd2af71f3802128d560d8aa27257feb416ca06918c188060d099bcba7  DockBarHero/App/AppDelegate.swift
8ff988b1642dfa51dec3ea2a13b7e47c9188ba57113ca22cdc6d53c6bf8a39cb  DockBarHero/Rendering/PrototypeScene.swift
d4dc14dcaebdc5327fea2f5202ceab607fc9d31a8434473428bd152bc9a6515d  DockBarHero/Rendering/PrototypeSceneHost.swift
b03f629e8cf9e50132032ee39c99ae04d5bc8c179f975de7eba2488528d16600  DockBarHeroTests/AppModelTests.swift
289a8370e09248a2bbb112994ed5b80645c3fd0c2200dbc75c6a6edb7dbe3aeb  DockBarHeroTests/PrototypeSceneHostTests.swift
```

The final commit hash is recorded by `git rev-parse HEAD` after the required commit.
