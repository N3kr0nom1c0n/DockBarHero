# DockBarHero Worktree Integration Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Combine the current class-actions/sprite, manga Book, recorded voiceover, and Area One campaign work into one verified branch, then merge that result into local `main` without deleting the source worktrees.

**Architecture:** Use `codex/lore-manga-vertical-slice` as the integration base because it already contains the earlier sprite/game merge plus the newest manga fixes. Layer the remaining class-action contrast fixes, recorded-audio runtime, and campaign overlay in that order. Preserve the manga reader's current ordered-cue and stale-callback safety, use recorded audio only while the Book is active/open, and preserve both campaign rendering and production-sprite contrast behavior.

**Tech Stack:** Swift 6, AppKit, SwiftUI, SpriteKit, AVFoundation, XCTest, XcodeGen, Python sprite-pipeline tests.

---

### Task 1: Establish and record the integration baseline

**Files:**
- Create: `docs/superpowers/plans/2026-07-15-dockbarhero-worktree-integration.md`
- Modify later: `PROJECT.md`

- [ ] Confirm the integration branch starts at `codex/lore-manga-vertical-slice` commit `11ef72f` and every source worktree is clean.
- [ ] Record `git status --short --branch`, `git worktree list`, and branch heads before merging.
- [ ] Commit this plan by itself.

Run:

```bash
git status --short --branch
git worktree list
git add docs/superpowers/plans/2026-07-15-dockbarhero-worktree-integration.md
git commit -m "docs: plan current worktree integration"
```

### Task 2: Merge the class-actions and sprite refinements

**Files:**
- Merge: `DockBarHero/Rendering/PrototypeScene.swift`
- Merge: `DockBarHero/Rendering/SpriteCatalog.swift`
- Merge: `DockBarHeroTests/PrototypeSceneHostTests.swift`
- Merge: `DockBarHeroTests/SpriteCatalogTests.swift`

- [ ] Merge `feature/class-actions-and-loot` with a merge commit.
- [ ] Confirm the merge is conflict-free and includes commits through `722367d`.
- [ ] Run focused sprite catalog and scene host tests.
- [ ] Inspect the diff to confirm manga files were not regressed.

Run:

```bash
git merge --no-ff feature/class-actions-and-loot -m "merge: integrate class actions and sprite refinements"
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/SpriteCatalogTests -only-testing:DockBarHeroTests/PrototypeSceneHostTests
git diff 11ef72f...HEAD --stat
```

### Task 3: Merge recorded Book voiceover without weakening manga speech safety

**Files:**
- Merge: `DockBarHero/Lore/LoreSpeechService.swift`
- Merge: `DockBarHero/Lore/LoreReaderController.swift`
- Merge: `DockBarHeroTests/LoreReaderControllerTests.swift`
- Merge: `DockBarHeroTests/LoreSpeechServiceTests.swift`
- Merge: `DockBarHero/Resources/Lore/Audio/**`
- Merge: `DockBarHero/Resources/Lore/lore_audio_manifest.json`
- Merge: `scripts/validate_lore_audio.py`
- Merge: `project.yml`
- Regenerate: `DockBarHero.xcodeproj/project.pbxproj`

- [ ] Merge `codex/recorded-lore-voiceover` and stop at the expected speech-service, reader-test, project-file, and QA-packet conflicts.
- [ ] Add or retain focused tests proving recorded cues play in authored order, speech remains opt-in and Book-scoped, closing/interruption stops playback, and stale completions cannot advance a newer sequence.
- [ ] Resolve `LoreSpeechService` by keeping the latest generation-safe completion contract while selecting bundled recorded audio when a validated manifest asset exists and using the existing synthesis path as fallback.
- [ ] Resolve controller tests by retaining both latest manga dialogue-order coverage and recorded-audio coverage.
- [ ] Keep separate QA evidence rather than replacing the manga review packet with an older branch copy.
- [ ] Regenerate the Xcode project from `project.yml` instead of manually reconciling generated UUID blocks.
- [ ] Validate the audio bundle and run focused lore speech/controller tests.

Run:

```bash
git merge --no-ff codex/recorded-lore-voiceover -m "merge: integrate recorded lore voiceover"
python3 scripts/validate_lore_audio.py
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreSpeechServiceTests -only-testing:DockBarHeroTests/LoreReaderControllerTests
```

Expected: audio validation passes; focused tests pass with recorded playback and ordered-cue interruption coverage both present.

### Task 4: Merge Area One campaign while preserving current sprite rendering

**Files:**
- Merge: `DockBarHero/Rendering/PrototypeScene.swift`
- Merge: `DockBarHero/Rendering/SpriteCatalog.swift`
- Merge: `DockBarHeroTests/PrototypeSceneHostTests.swift`
- Merge: `DockBarHeroTests/SpriteCatalogTests.swift`
- Merge: `DockBarHero/Campaign/**`
- Merge: `DockBarHero/App/**`
- Merge: `project.yml`
- Regenerate: `DockBarHero.xcodeproj/project.pbxproj`

- [ ] Merge `feature/campaign-area-one` and stop at the expected rendering/catalog/test/project conflicts.
- [ ] Retain campaign encounter/overlay state and deterministic Area One progression.
- [ ] Retain the current outlined rail labels, outlined-actor fill behavior, hero silhouette visibility, deterministic production clips, and checksum validation.
- [ ] Combine tests so the campaign presentation and sprite contrast contracts are both asserted.
- [ ] Regenerate the Xcode project after resolving source and test files.
- [ ] Run focused campaign, sprite catalog, and scene host tests.

Run:

```bash
git merge --no-ff feature/campaign-area-one -m "merge: integrate campaign area one"
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/CampaignContentTests -only-testing:DockBarHeroTests/SpriteCatalogTests -only-testing:DockBarHeroTests/PrototypeSceneHostTests
```

### Task 5: Establish the combined automated verification milestone

**Files:**
- Modify: `PROJECT.md`
- Modify: `docs/qa/review-packets/lore-manga-vertical-slice.md`
- Modify: campaign/voiceover QA packets only where new combined evidence belongs

- [ ] Run the full arm64 XCTest suite.
- [ ] Run all sprite-pipeline Python tests.
- [ ] Run a clean unsigned arm64 build.
- [ ] Run the repository context guard.
- [ ] Inspect `git diff --check` and confirm no unmerged entries.
- [ ] Update `PROJECT.md` only with freshly verified combined truth, keeping it at or below 150 lines.
- [ ] Add exact combined test/build evidence to the relevant QA packets without claiming manual checks not performed.
- [ ] Commit documentation/evidence updates.

Run:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64'
python3 -m unittest discover -s scripts/tests -p 'test_*.py'
xcodebuild clean build -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO
python3 /Users/n3kr0/.codex/skills/maintaining-project-context/scripts/context_guard.py check --root .
git diff --check
test -z "$(git ls-files -u)"
```

### Task 6: Launch and inspect the exact combined bundle

**Files:**
- Modify: relevant `docs/qa/review-packets/*.md` with only observed results

- [ ] Stop stale DockBarHero processes and run `./script/build_and_run.sh --verify` from this exact worktree.
- [ ] Confirm one DockBarHero process and identify its bundle path.
- [ ] Open the Book and inspect wide and compact manga layouts, right-to-left navigation, fixed text, the single animated panel, censorship, audio opt-in, the reversed potentiometer, and Book reactions.
- [ ] Verify recorded dialogue plays only while the Book is open and stops when closed; exercise interruption/page-change behavior.
- [ ] Inspect the Area One campaign overlay and the rail in light and dark appearance for readable labels and visible hero silhouettes.
- [ ] Record only directly observed pass/fail evidence; fix and re-run any failed check before integration to `main`.

Run:

```bash
./script/build_and_run.sh --verify
pgrep -fl DockBarHero
```

### Task 7: Merge the verified result into local main safely

**Files:**
- Preserve: `/Users/n3kr0/Projects/TBH/docs/superpowers/plans/2026-07-15-dockbarhero-recorded-lore-voiceover.md`

- [ ] Confirm the root worktree has no change other than the pre-existing untracked voiceover plan and that it is byte-identical to the integration branch's tracked copy.
- [ ] Preserve that user-owned file by committing the identical plan on `main` before merging, rather than deleting or overwriting it.
- [ ] Merge `codex/integrate-current-worktrees` into local `main` with a merge commit.
- [ ] Re-run the full test suite, clean unsigned build, context guard, and exact-worktree launch from `main`.
- [ ] Do not push and do not remove any source worktree unless the user separately requests it.

Run:

```bash
cd /Users/n3kr0/Projects/TBH
cmp docs/superpowers/plans/2026-07-15-dockbarhero-recorded-lore-voiceover.md .worktrees/integrate-current-worktrees/docs/superpowers/plans/2026-07-15-dockbarhero-recorded-lore-voiceover.md
git add docs/superpowers/plans/2026-07-15-dockbarhero-recorded-lore-voiceover.md
git commit -m "docs: plan recorded lore voiceover"
git merge --no-ff codex/integrate-current-worktrees -m "merge: integrate current DockBarHero worktrees"
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64'
xcodebuild clean build -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO
python3 /Users/n3kr0/.codex/skills/maintaining-project-context/scripts/context_guard.py check --root .
./script/build_and_run.sh --verify
```

