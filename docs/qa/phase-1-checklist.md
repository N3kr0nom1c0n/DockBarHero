# DockBarHero Phase 1 QA Checklist

Date opened: 2026-07-11
Worktree: `/Users/n3kr0/Projects/TBH/.worktrees/phase-1-playable-slice`
Status: Automated Gate D complete; integration reviews active; manual observations pending.

## Automated Gate

- [x] Clean arm64 build completes.
  - Evidence: `xcodebuild clean build` succeeded with `platform=macOS,arch=arm64` and `CODE_SIGNING_ALLOWED=NO` using `.build/FinalDerivedData`.
- [x] Complete test suite passes; test count recorded.
  - Evidence: 162 tests passed with 0 failures using `.build/Task10Full`.
- [x] Focused management, app, and scene tests pass.
  - Evidence: 34 tests passed with 0 failures using `.build/Task10Focused`.
- [x] Automated corrupt-primary save recovery passes.
  - Evidence: the passing full suite includes `SaveStoreTests.testCorruptPrimaryLoadsBackupAndQuarantinesPrimary` and the related mutation-failure recovery coverage.

## Gameplay

- [ ] Continuous level advancement is observed.
  - Evidence:
- [ ] Defeat revives and retries the same enemy level.
  - Evidence:
- [ ] Rail rolling DPS changes during combat and resets at encounter boundaries.
  - Evidence:

## Management Window

- [ ] Management rolling and encounter-average DPS are shown.
  - Evidence:
- [ ] Hero and enemy health, attack, defense, and interval plus current enemy level are shown.
  - Evidence:
- [ ] Equipped weapon and armor are shown.
  - Evidence:
- [ ] Inventory is newest first and preserves owned items.
  - Evidence:
- [ ] Manual equip changes the selected item.
  - Evidence:
- [ ] Auto-equip toggle changes the persisted setting.
  - Evidence:

## Persistence

- [ ] A save is created during normal gameplay.
  - Evidence: automated live verification launched PID 16696 and a normal Cocoa termination produced `save-v1.json` (2,333 bytes); manual gameplay observation is still pending.
- [ ] Clean relaunch restores combat, inventory, equipment, and settings.
  - Evidence:

## Phase 0 Regression

- [ ] Rail remains passive and non-activating in passive mode.
  - Evidence:
- [ ] Rail remains correctly placed.
  - Evidence:
- [ ] Rail hides in fullscreen and restores afterward.
  - Evidence:
- [ ] Hidden and paused rendering behavior remains Phase 0 compliant.
  - Evidence:

## Scope And Reviews

- [ ] Deferred features are absent.
  - Evidence:
- [ ] Terra findings and resolutions are recorded.
  - Evidence:
- [ ] Sol final verdict is recorded.
  - Evidence:
- [ ] Feature branch and reviewed implementation commit are recorded.
  - Evidence:
- [ ] Final pushed HEAD is reported in the overnight report.
  - Evidence:

## Executed Automated Commands

The owner cleared the focus hold on 2026-07-11. These commands completed successfully:

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/Task10Focused CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/ManagementViewTests -only-testing:DockBarHeroTests/AppModelTests -only-testing:DockBarHeroTests/PrototypeSceneHostTests
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/Task10Full CODE_SIGNING_ALLOWED=NO
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/FinalDerivedData CODE_SIGNING_ALLOWED=NO clean build
./script/build_and_run.sh --verify
```
