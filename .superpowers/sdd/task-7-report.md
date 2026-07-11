# Task 7 Report: Atomic Save Store And Recovery

## Files

- `DockBarHero/Persistence/SaveStore.swift`
- `DockBarHeroTests/SaveStoreTests.swift`
- `DockBarHero/Support/AppLog.swift`
- `DockBarHero.xcodeproj/project.pbxproj`

## Red Evidence

The first focused command was:

```text
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS' -only-testing:DockBarHeroTests/SaveStoreTests
```

It failed during test-target compilation with `cannot find type 'SaveStore' in scope`, before the production implementation existed.

## Verification

- Focused SaveStore suite: 10 tests passed, 0 failures.
- Full `DockBarHero` scheme: 121 tests passed, 0 failures.
- `git diff --check`: clean.

## Atomicity And Recovery Decisions

- `SaveStore` is an actor conforming to the exact `SaveStoring` contract.
- `SaveURLs` uses `Application Support/com.n3kr0nom1c0n.DockBarHero/` with the required primary, backup, and pending filenames.
- Save encoding and validation occur before the pending write. The pending file is written with `.atomic` in the save directory.
- A prior primary is copied to a uniquely named staging file before the backup is replaced, so a backup-copy failure leaves the existing primary and backup untouched.
- The pending file replaces the primary only after backup staging succeeds. A deferred cleanup removes stale or failed pending data without changing valid saves.
- Load attempts primary, then backup, then the supplied new-game state. Invalid or unsupported candidates are moved, not deleted, to `.invalid-<UTC timestamp>-<UUID>` names.
- Logging uses gameplay and persistence categories and hashes paths with OSLog privacy. Save data and inventory contents are never logged.

## Risks

- Filesystem failures during quarantine are logged and leave the original unreadable file in place; recovery then continues to the next source or new game.
- The current task intentionally does not include save coalescing, session coordination, UI save status, or offline progress.

## Final Commit

`feat: add atomic save recovery`
