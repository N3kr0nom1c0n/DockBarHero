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

## Gate C Repair Cycle 1

### Files

- Updated `DockBarHero/Persistence/SaveCoordinator.swift` with a narrow mutable status-observation protocol while preserving the exact `SaveCoordinating` request/flush surface.
- Updated `DockBarHero/Game/GameSession.swift` to install status observation before load, reject late callbacks after stop, and replace retained request tasks with an outstanding-submission count plus zero-count waiters.
- Updated `DockBarHeroTests/GameSessionTests.swift` with production status-path, blocked-submission stop ordering, and 500-request steady-state release coverage.
- No AppDelegate, AppModel, UI, or project-file changes were made in this repair.

### RED Evidence

The production status-path test first ran with:

```text
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS' -derivedDataPath .build/Task8RepairStatusRed test -only-testing:DockBarHeroTests/GameSessionTests
```

Result: exit 65; 8 tests executed with 4 assertion failures in the new production-path test. Only `.recovered` arrived, proving `.saving`, `.saved`, and `.failed` were not wired from the real coordinator to the session.

The bounded-submission tests then ran before implementation with:

```text
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS' -derivedDataPath .build/Task8RepairBoundedRed test -only-testing:DockBarHeroTests/GameSessionTests
```

Result: exit 65 during compilation because `GameSession` had no `outstandingSaveSubmissionCount`, proving the release/bounded invariant was absent.

### Verification

- Status-path GREEN: 8 GameSession tests passed, 0 failures using `.build/Task8RepairStatusGreen`.
- Bounded-submission GREEN: 10 GameSession tests passed, 0 failures using `.build/Task8RepairBoundedGreen`.
- Final SaveCoordinator focused run: 2 tests passed, 0 failures using `.build/Task8RepairSaveCoordinatorFinal`.
- Final persistence-focused run: 47 tests passed, 0 failures across SaveCoordinator, GameSession, SaveDocument, and SaveStore using `.build/Task8RepairPersistenceFinal`.
- Final full suite: 139 tests passed, 0 failures using `.build/Task8RepairFullFinal`.
- `git diff --check` passed before the repair commit.

### Concurrency And Coalescing Decisions

- `SaveStatusObserving` is separate from the unchanged `SaveCoordinating` protocol. `GameSession` detects that capability and installs the MainActor handler before loading, so backup `.recovered` remains ordered before later coordinator save statuses.
- Status closures carry the startup generation. Stopping invalidates that generation before awaiting work, ignores statuses while stopping, and clears the installed handler after the terminal flush.
- A submission increments `outstandingSaveSubmissionCount` before creating its unretained task. Completion decrements the count and resumes zero-count waiters, so completed tasks and captured `GameState` snapshots are released instead of accumulating for the session lifetime.
- `stopAndSave()` disables new requests first, waits until all accepted submissions have returned from `request(_:)`, then snapshots current driver state and performs the final `flush(_:)`.
- The coordinator's serialized first-in-flight/latest-pending drain, failure recovery, and true flush behavior remain unchanged.

### Risks

- Status observation remains optional for test or alternate coordinators that implement only `SaveCoordinating`; production `SaveCoordinator` implements both protocols.
- Submission bookkeeping is MainActor-isolated and intentionally exposes only a read-only internal count for the steady-state regression test.
- Gate C was not dispatched; the controller retains ownership of that gate.

### Repair Commit

`3a5b99f86f076c94259abb15be7abaabfdcc5936` (`fix: bound session save coordination`)
