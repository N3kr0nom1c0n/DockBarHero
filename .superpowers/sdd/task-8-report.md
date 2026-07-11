# Task 8 Report: Save Coalescing And Game Session

## Files

- `DockBarHero/Persistence/SaveCoordinator.swift`
- `DockBarHero/Game/GameSession.swift`
- `DockBarHeroTests/SaveCoordinatorTests.swift`
- `DockBarHeroTests/GameSessionTests.swift`
- `DockBarHero.xcodeproj/project.pbxproj`
- `.superpowers/sdd/task-8-report.md`

## RED Evidence

After adding the two focused test files and registering them in the project, the pre-implementation run was:

```text
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/Task8Red CODE_SIGNING_ALLOWED=NO test -only-testing:DockBarHeroTests/SaveCoordinatorTests -only-testing:DockBarHeroTests/GameSessionTests
```

It failed during test-target compilation because the production contracts were absent:

```text
Cannot find type 'GameSession' in scope
Cannot find type 'SaveCoordinating' in scope
Cannot find type 'SaveStatus' in scope
Testing cancelled because the build failed.
```

## Verification

Save coordinator focused run:

```text
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/Task8FocusedSave CODE_SIGNING_ALLOWED=NO test -only-testing:DockBarHeroTests/SaveCoordinatorTests
```

Result: 2 tests passed, 0 failures.

Game session focused run:

```text
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/Task8FocusedSession CODE_SIGNING_ALLOWED=NO test -only-testing:DockBarHeroTests/GameSessionTests
```

Result: 7 tests passed, 0 failures.

Full suite:

```text
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/Task8Full CODE_SIGNING_ALLOWED=NO test
```

Result: 136 tests passed, 0 failures. The expected App Intents/linkd test-host warnings remained non-fatal.

`git diff --check` passed before commit.

Gate C was not dispatched because the controller owns that review gate, per task instruction.

## Concurrency And Coalescing Decisions

- `SaveCoordinator` is an actor with one drain task, one in-flight `SaveStoring.save`, and one replaceable pending state. A drain saves the first accepted state and then the latest state observed while that write is in flight; superseded middle states are discarded.
- `flush(_:)` installs the final state, joins the current drain through actor-held continuations, and resumes only after both in-flight and pending work finish. Save failures publish `.failed`, complete that drain item, and leave the coordinator able to accept later requests.
- Save status callbacks are typed as `@MainActor @Sendable` and are invoked through `MainActor.run`.
- `GameSession` starts a single MainActor startup task. It awaits load, replaces the driver state, reports backup recovery, then starts the driver and one injected 30-second autosave loop.
- Startup and callback generation tokens, cancellation checks, and terminal stop state prevent late load/start/presentation/event callbacks from reviving a stopped session.
- Save-request tasks are retained and awaited before the final coordinator flush, preventing a queued event or intent request from arriving after the final state is flushed.
- Durable event saves match exactly `.victory`, `.loot`, `.equipped`, and `.autoEquipChanged`; attack, defeat, and revived events do not request event saves. Successful state-changing intents request saves, with event-triggered intent saves coalesced through the same coordinator.

## Risks

- The current session is terminal after `stopAndSave()`; restarting the same instance is intentionally suppressed.
- Autosave timing is injected for deterministic tests, while production uses `Task.sleep(for:)` and cancellation.
- Gate C integration review and live launch/persistence smoke checks remain outside this task and are owned by the controller/final phase.

## Commit

`feat: coordinate autosaves and game session`
