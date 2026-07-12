# DockBarHero Phase 1 QA Checklist

Date opened: 2026-07-11
Worktree: `/Users/n3kr0/Projects/TBH/.worktrees/phase-1-playable-slice`
Status: Phase 1 approved and pushed; Foundation Upgrade may begin.

## Automated Gate

- [x] Clean arm64 build completes.
  - Evidence: `xcodebuild clean build` succeeded with `platform=macOS,arch=arm64` and `CODE_SIGNING_ALLOWED=NO` using `.build/FinalDerivedData`.
- [x] Complete test suite passes; test count recorded.
  - Evidence: 163 tests passed with 0 failures using `.build/RepairFull` after the Terra repair.
- [x] Focused management, app, and scene tests pass.
  - Evidence: initial 34-test UI slice passed; 20 directly affected GameSession and management tests passed after repair.
- [x] Automated corrupt-primary save recovery passes.
  - Evidence: the passing full suite includes `SaveStoreTests.testCorruptPrimaryLoadsBackupAndQuarantinesPrimary` and the related mutation-failure recovery coverage.

## Gameplay

- [x] Continuous level advancement is observed.
  - Evidence: owner directly observed enemy levels advancing during the 2026-07-12 closeout run.
- [x] Defeat revives and retries the same enemy level.
  - Evidence: owner equipped weak armor, observed defeat and revive, and confirmed the retry retained the same enemy level on 2026-07-12.
- [x] Rail rolling DPS changes during combat and resets at encounter boundaries.
  - Evidence: owner directly observed live DPS changes and the next-encounter reset during the 2026-07-12 closeout run.

## Management Window

- [x] Management rolling and encounter-average DPS are shown.
  - Evidence: owner confirmed both values in the live management window on 2026-07-12.
- [x] Hero and enemy health, attack, defense, and interval plus current enemy level are shown.
  - Evidence: owner confirmed the live stat surfaces on 2026-07-12.
- [x] Equipped weapon and armor are shown.
  - Evidence: owner confirmed both equipment rows on 2026-07-12.
- [x] Inventory is newest first and preserves owned items.
  - Evidence: owner confirmed newest-first ordering and retained inventory after clean relaunch on 2026-07-12; the pre-quit save contained 75 items.
- [x] Manual equip changes the selected item.
  - Evidence: owner selected and equipped an inventory item successfully on 2026-07-12.
- [x] Auto-equip toggle changes the persisted setting.
  - Evidence: owner toggled the setting during the live run and confirmed it restored enabled after clean relaunch.

## Persistence

- [x] A save is created during normal gameplay.
  - Evidence: the owner exercised gameplay/equipment controls; the live primary save updated at 2026-07-12 15:03:44 to 4,905 bytes with enemy level 59 and 58 inventory items.
- [x] Clean relaunch restores combat, inventory, equipment, and settings.
  - Evidence: normal Cocoa termination saved enemy level 76, 75 inventory items, weapon 75, armor 74, and auto-equip enabled; owner confirmed the relaunched management window resumed that state.

## Phase 0 Regression

- [x] Rail remains passive and non-activating in passive mode.
  - Evidence: owner confirmed clicks passed through without DockBarHero activation while the menu offered Enable Interaction.
- [x] Rail remains correctly placed.
  - Evidence: owner confirmed correct placement above the Dock during the 2026-07-12 closeout run.
- [x] Rail hides in fullscreen and restores afterward.
  - Evidence: owner entered/exited another app's fullscreen mode and confirmed suppression/restoration.
- [x] Hidden and paused rendering behavior remains Phase 0 compliant.
  - Evidence: owner confirmed gameplay advanced while hidden and while animation was paused; rendering visibility/motion responded correctly.

## Scope And Reviews

- [x] Deferred features are absent.
  - Evidence: Sol's whole-branch static review found no blocking static correctness or deferred-scope issue.
- [x] Terra findings and resolutions are recorded.
  - Evidence: Terra found a quit-during-load save race, unsupported-version status overwrite, and missing inventory sort/creation-order support. The repair now awaits the pending load and flushes its state, preserves unsupported-version precedence, and wires native table sorting with a Created column. The 163-test full gate and clean build passed afterward.
- [x] Sol final verdict is recorded.
  - Evidence: evidence-only Sol recheck returned `APPROVE` after every previously missing live observation was recorded; the valid bounded check used 3,796 tokens and did not inspect source or rerun tests.
- [x] Feature branch and reviewed implementation commit are recorded.
  - Evidence: branch `feature/phase-1-playable-slice`; Task 10 implementation `bc7a536`; Terra repair `f4c8c5b`.
- [x] Final pushed HEAD is reported in the overnight report.
  - Evidence: approved Phase 1 head `2349f2f` was pushed to `origin/feature/phase-1-playable-slice`; the final documentation-only evidence SHA is reported in the closeout response.

## Executed Automated Commands

The owner cleared the focus hold on 2026-07-11. These commands completed successfully:

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/Task10Focused CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/ManagementViewTests -only-testing:DockBarHeroTests/AppModelTests -only-testing:DockBarHeroTests/PrototypeSceneHostTests
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/Task10Full CODE_SIGNING_ALLOWED=NO
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/FinalDerivedData CODE_SIGNING_ALLOWED=NO clean build
./script/build_and_run.sh --verify
```
