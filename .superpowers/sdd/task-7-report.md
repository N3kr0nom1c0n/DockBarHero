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

## Repair Cycle 1

### Finding And Red Evidence

The durability finding against `4f6f41c` was reproduced with a deterministic filesystem failure while saving valid new state over a corrupt primary and valid backup. The first behavioral red run executed 11 focused tests and failed because the backup had been replaced with corrupt primary bytes and no primary diagnostic file existed. A second red test showed that an unreadable existing backup was replaced without diagnostic preservation.

Foundation's `FileManager.replaceItemAt` is non-overridable, so the repair adds a narrow actor-isolated `SaveFileSystem` seam while preserving the production `SaveStore` initializer and exact `SaveStoring` contract.

### Durability Decisions

- New state is encoded and validated before the pending write, as before.
- Existing primary bytes are read once and decoded through `SaveCodec`; only those exact validated bytes may be staged for backup.
- A corrupt or unreadable primary is quarantined before primary installation. If quarantine fails, the save aborts, pending is cleaned, and primary/backup remain untouched.
- An unreadable backup is quarantined before validated primary bytes replace it. If quarantine fails, the save aborts without deleting the backup.
- Staging and backup-replacement failures occur while the valid primary remains in place. A backup replacement uses the single-path atomic Foundation replacement operation.
- Primary replacement occurs only after the backup contains validated prior-primary bytes. If replacement fails, the prior primary remains valid in both durable slots.
- A corrupt-primary quarantine followed by primary-install failure leaves the original valid backup loadable and preserves the corrupt primary under its diagnostic name.
- There is no claim of cross-file transaction atomicity. The ordering guarantees that every mutation either preserves an existing valid durable save or installs bytes already validated by `SaveCodec`.

### Repair Verification

- Focused `SaveStoreTests`: 16 tests passed, 0 failures.
- Full `DockBarHero` scheme: 127 tests passed, 0 failures.
- Pending cleanup and byte preservation were asserted for validation, quarantine, staging, backup replacement, and both primary-install paths.
- `git diff --check`: clean.

### Repair Commit

`5e7d4f605bf8b4e6747c33e034dad13b6c3f73a2 fix: preserve valid saves during recovery`
