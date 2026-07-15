# Review Backlog Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the integrated-build review backlog from `BACKLOG.md` while keeping accepted visual/audio work verifiable, keeping design-gated work out of implementation until approved, and preserving unrelated changes.

**Architecture:** This is a master execution plan, not a single feature plan. It separates acceptance verification, already-scoped repairs, design packets, and larger implementation tracks so each slice can be reviewed independently. Every implementation slice uses red/green tests first, then focused verification, then `BACKLOG.md` status updates only after the result is proven and accepted.

**Tech Stack:** macOS Swift/SwiftUI/AppKit app, XCTest, XcodeGen, `xcodebuild`, `./script/build_and_run.sh --verify`, SpriteKit rail rendering, local resource manifests, JSON catalogs.

## Global Constraints

- Work in `/Users/n3kr0/Projects/TBH`.
- Read `AGENTS.md`, `PROJECT.md`, and `BACKLOG.md` before broad source exploration.
- Read only files needed for the assigned task.
- Preserve unrelated user changes.
- Do not push anything.
- Do not delete any existing worktrees.
- Do not generate or replace manga pages until cohesive story, character origins, campaign spine, and Map design are approved.
- Use TDD for behavior changes: write the failing test, verify red, implement minimal code, verify green.
- Run checks proportional to each change.
- Do not describe work as complete without fresh verification.
- Update `BACKLOG.md` as items are completed or accepted.
- Keep `PROJECT.md` parent-owned; update only when a verified milestone is clear and parent approval exists.
- Use canonical commands from `PROJECT.md`; current known integrated verifier is `./script/build_and_run.sh --verify`.
- Commit only if the owner explicitly asks for commits in the active run.

---

## Scope Partition

This backlog covers independent subsystems. Execute as separate reviewable tracks:

1. Acceptance and backlog closeout for already-implemented fixes.
2. Boss 100 balance decision packet and optional visibility/tuning slice.
3. Book speech rules and audio mixer.
4. Hero rail conversations and hero audio.
5. Cohesive story plus Map design packet.
6. Map implementation after design approval.
7. Dropped loot economy.
8. Loot pile presentation after economy and visual threshold approval.
9. Class skill trees after progression economy approval.

Do not merge these tracks into one broad refactor. Each task below ends with a runnable app and an updated status note.

---

### Task 1: Acceptance Verification For Current Review Fixes

**Files:**
- Modify: `BACKLOG.md`
- Read: `DockBarHero/Rendering/PrototypeScene.swift`
- Read: `DockBarHero/Lore/LoreBookLayout.swift`
- Read: `DockBarHero/Lore/LoreBookView.swift`
- Read: `DockBarHero/Lore/LorePageView.swift`
- Read: `DockBarHero/Lore/LoreReaderController.swift`

**Interfaces:**
- Consumes: Current uncommitted implementation records in `BACKLOG.md`.
- Produces: Accepted or rejected status notes for A2, B1, C1, C2, C3, and C4.

- [ ] **Step 1: Confirm current diff and no untracked profiling output**

Run:

```bash
git status --short
ls -1 default.profraw 2>/dev/null || true
```

Expected: tracked changes only; no `default.profraw`. If `default.profraw` exists, remove only that generated profiling file:

```bash
rm -f default.profraw
```

- [ ] **Step 2: Run focused automated verification for accepted fixes**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' \
  -only-testing:DockBarHeroTests/DamageMetricsTests \
  -only-testing:DockBarHeroTests/GameSimulationTests \
  -only-testing:DockBarHeroTests/PrototypeSceneHostTests \
  -only-testing:DockBarHeroTests/ManagementViewTests \
  -only-testing:DockBarHeroTests/LoreBookLayoutTests \
  -only-testing:DockBarHeroTests/LoreReaderControllerTests \
  -only-testing:DockBarHeroTests/LoreSpriteSheetTests \
  -only-testing:DockBarHeroTests/LoreMangaLayoutTests \
  -only-testing:DockBarHeroTests/LoreMangaAccessibilityTests \
  test
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 3: Run canonical build and launch verification**

Run:

```bash
./script/build_and_run.sh --verify
```

Expected: `** BUILD SUCCEEDED **` and `DockBarHero launched (pid ...)`.

- [ ] **Step 4: Perform manual acceptance pass on the exact built app**

Open the exact app produced by `.build/RunDerivedData`, not a stale app-name lookup.

Check:

- Rail: `DPS AVG` remains stable and does not dip to zero after idle/damage gaps.
- Rail: three-hero party appears grouped, with compact non-overlapping bars/labels.
- Book: volume knob produces an audible giggle when spoken dialogue is enabled.
- Book: rapid knob movement does not stack noisy overlapping samples.
- Book: motion panel animates while Book is open and app is active.
- Book: motion panel freezes when Reduced Motion is enabled.
- Book: current page bubbles cover less art and stay legible.
- Book: bottom space below volume knob looks intentional.
- Window: plain launch is accessory/menu-bar style; management window gets Dock presence; close returns to accessory behavior.

Expected: owner accepts or gives concrete correction notes.

- [ ] **Step 5: Update `BACKLOG.md` only for accepted outcomes**

If accepted, mark the relevant checkboxes:

- A2: `DPS presentation uses the approved stable metric.`
- B1: `Three-hero formation and unlock presentation are accepted.`
- Book aggregate only if C1, C2, C3, C4, and later C5/C6 are accepted together.

Do not mark Book aggregate complete while C5/C6 remain unresolved.

- [ ] **Step 6: Final hygiene**

Run:

```bash
git diff --check
git status --short
```

Expected: no whitespace errors; status contains only intended tracked changes.

---

### Task 2: Boss 100 Decision Packet

**Files:**
- Modify: `BACKLOG.md`
- Read/Test: `DockBarHeroTests/HeroesAndPartyTests.swift`
- Read as needed: combat resolver, balance configuration, enemy factory, encounter schedule.

**Interfaces:**
- Consumes: Existing fixtures proving no-equipment Level 240 Tank+DPS lose and Level 100 equipment wins.
- Produces: Owner-reviewable decision packet: accept gear gate, improve visibility, or tune balance.

- [ ] **Step 1: Re-run existing diagnosis fixtures**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' \
  -only-testing:DockBarHeroTests/HeroesAndPartyTests \
  test
```

Expected: `HeroesAndPartyTests` passes.

- [ ] **Step 2: Prepare the decision text in `BACKLOG.md`**

Add a short decision section under A4 with three explicit owner choices:

```markdown
**Pending decision:**

1. Accept Level 100 equipment as the intended Boss 100 gate and improve gear-state visibility.
2. Keep equipment important but tune Boss 100 so very overleveled heroes survive longer without gear.
3. Rework the gate around third-slot/healer progression instead of equipment alone.
```

- [ ] **Step 3: If owner accepts choice 1 later, plan a visibility-only slice**

Planned visible signals:

- Overview: show average equipped item level beside party combat readiness.
- Rail or management boss hint: show `Gear check` or `Boss 100 expects Level 100 gear`.
- Tests: management formatting and deterministic Boss 100 fixtures.

- [ ] **Step 4: If owner requests tuning later, require new red fixture before changing numbers**

Write a failing fixture that states the desired survival/win boundary, then change only the smallest balance surface needed.

Verification command:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' \
  -only-testing:DockBarHeroTests/HeroesAndPartyTests \
  -only-testing:DockBarHeroTests/CombatResolverTests \
  -only-testing:DockBarHeroTests/EnemyFactoryTests \
  test
```

Expected: all selected tests pass.

---

### Task 3: Book Speech UX Contract

**Files:**
- Modify: `BACKLOG.md`
- Modify after approval: `DockBarHero/Lore/LoreBookView.swift`
- Modify after approval: `DockBarHero/Lore/LoreSettingsSection.swift`
- Modify after approval: `DockBarHero/Lore/LoreReaderController.swift`
- Test after approval: `DockBarHeroTests/LoreReaderControllerTests.swift`
- Test after approval: `DockBarHeroTests/ManagementViewTests.swift`

**Interfaces:**
- Consumes: `LoreReaderController` methods `open()`, `close()`, `applicationBecameActive()`, `applicationBecameInactive()`, `select(_:)`, `replay()`, `skip()`, and `previewVolume(detent:)`.
- Produces: Approved reader contract and visible in-app explanation for speech and unlock rules.

- [ ] **Step 1: Document proposed contract for owner review**

Add this proposed contract to the C5 planning notes:

```markdown
**Proposed Book speech contract:**

- Auto-read happens only when `autoReadNewLorePages` is enabled.
- Auto-read only starts for a newly unlocked page that has not already been auto-read.
- Speech never starts while the Book is closed or the app is inactive.
- Opening the Book does not replay old pages automatically.
- Selecting a page interrupts current speech and does not queue old audio.
- Replay restarts the current page's dialogue sequence from the first cue.
- Skip advances to the next cue on the current page; skipping past the last cue stops speech.
- Book mute suppresses Book dialogue and giggle previews while keeping text reactions.
- Global mute suppresses every audio channel while preserving saved per-channel values.
- Unlocked pages can be revisited freely.
```

- [ ] **Step 2: Write failing tests after approval**

Add tests to `DockBarHeroTests/LoreReaderControllerTests.swift`:

- `testSelectingPageInterruptsSpeechWithoutQueueingPreviousCue`
- `testReplayRestartsCurrentPageFromFirstCue`
- `testBookClosedNeverStartsAutoRead`
- `testUnlockedPagesRemainSelectableAfterProgressionRefresh`

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' \
  -only-testing:DockBarHeroTests/LoreReaderControllerTests \
  test
```

Expected before implementation: at least one new test fails for missing explicit contract behavior or missing UI copy contract.

- [ ] **Step 3: Implement the smallest reader/controller or UI copy changes**

Keep the reader behavior in `LoreReaderController`. Keep explanatory copy in the Book or Settings UI. Do not add a documentation-only answer; the rules must be discoverable in-app.

- [ ] **Step 4: Verify**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' \
  -only-testing:DockBarHeroTests/LoreReaderControllerTests \
  -only-testing:DockBarHeroTests/ManagementViewTests \
  test
./script/build_and_run.sh --verify
git diff --check
```

Expected: selected tests pass, build launches, whitespace check clean.

- [ ] **Step 5: Update `BACKLOG.md`**

Record C5 implementation evidence and leave broader Book aggregate unchecked until C6 and manual acceptance are complete.

---

### Task 4: Real Audio Mixer

**Files:**
- Modify: `DockBarHero/Settings/AppSettings.swift`
- Modify: `DockBarHero/App/AppModel.swift`
- Modify: `DockBarHero/App/SettingsView.swift`
- Modify: `DockBarHero/Lore/LoreSettingsSection.swift`
- Modify: `DockBarHero/Lore/LoreReaderController.swift`
- Modify: `DockBarHero/Lore/LoreSpeechService.swift`
- Test: `DockBarHeroTests/AppSettingsMigrationTests.swift`
- Test: `DockBarHeroTests/AppModelTests.swift`
- Test: `DockBarHeroTests/LoreReaderControllerTests.swift`
- Test: `DockBarHeroTests/ManagementViewTests.swift`

**Interfaces:**
- Produces in `AppSettings`: `isAudioMuted`, `isBookAudioMuted`, `isHeroAudioMuted`, `bookVolumeDetent`, `heroVoiceVolumeDetent`.
- Produces resolved gains: Book speech/giggle gain is `0` when global or Book mute is active; hero gain is `0` when global or hero mute is active.

- [ ] **Step 1: Approve persistence and precedence rules**

Default rules for review:

- Global mute overrides all channels without changing saved channel mute or volume values.
- Book mute only affects Book dialogue and Book giggle preview.
- Hero mute only affects future hero conversation audio.
- Text bubbles and Book reactions remain visible when muted.
- New installs remain opt-in: spoken dialogue defaults to disabled.

- [ ] **Step 2: Write failing settings migration tests**

Add tests proving older settings decode with:

```swift
isAudioMuted == false
isBookAudioMuted == false
isHeroAudioMuted == false
heroVoiceVolumeDetent == 5
```

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' \
  -only-testing:DockBarHeroTests/AppSettingsMigrationTests \
  test
```

Expected before implementation: decoding or property assertions fail.

- [ ] **Step 3: Implement settings model and migration**

Add codable fields to `AppSettings` with stable defaults. Keep existing `bookVolumeDetent` behavior compatible.

- [ ] **Step 4: Write failing AppModel and reader tests**

Test that:

- Global mute suppresses Book preview audio.
- Book mute suppresses Book preview audio.
- Muted preview still updates `reactionText`.
- Unmuting restores previous detent-derived gain.

- [ ] **Step 5: Implement mixer routing**

Route Book speech and preview through one AppSettings-derived gain decision. Do not add hero conversation playback until Task 5.

- [ ] **Step 6: Implement Settings UI**

Add controls to Settings or Lore settings:

- Mute all audio.
- Mute Book audio.
- Mute hero conversation audio.
- Book volume.
- Hero voice volume.

- [ ] **Step 7: Verify**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' \
  -only-testing:DockBarHeroTests/AppSettingsMigrationTests \
  -only-testing:DockBarHeroTests/AppModelTests \
  -only-testing:DockBarHeroTests/LoreReaderControllerTests \
  -only-testing:DockBarHeroTests/ManagementViewTests \
  test
./script/build_and_run.sh --verify
git diff --check
```

Expected: selected tests pass, app builds and launches.

- [ ] **Step 8: Update `BACKLOG.md`**

Record C6 evidence. Mark Book aggregate complete only after owner accepts C1-C6 behavior visually/audibly.

---

### Task 5: Hero Rail Conversations

**Files:**
- Create after approval: `DockBarHero/HeroConversations/HeroConversationModels.swift`
- Create after approval: `DockBarHero/HeroConversations/HeroConversationCatalog.swift`
- Create after approval: `DockBarHero/HeroConversations/HeroConversationScheduler.swift`
- Modify: `DockBarHero/Game/GamePresentation` related file after locating exact model definitions.
- Modify: `DockBarHero/Rendering/PrototypeScene.swift`
- Modify: `DockBarHero/Settings/AppSettings.swift`
- Test: `DockBarHeroTests/HeroConversationSchedulerTests.swift`
- Test: `DockBarHeroTests/PrototypeSceneHostTests.swift`
- Test: `DockBarHeroTests/AppSettingsMigrationTests.swift`

**Interfaces:**
- Produces: deterministic conversation events attached to presentation state only.
- Consumes: hero class, party composition, encounter type, combat state, mute settings.
- Constraint: conversations never mutate combat state.

- [ ] **Step 1: Approve conversation design**

Default rules for review:

- Conversations are short two-line exchanges.
- Cadence is low: no more than one conversation every 30-60 seconds during active combat.
- Combat-critical labels have priority over bubbles.
- Conversations are text-first; voice cues are optional per line.
- Muting hero audio does not hide text bubbles.
- Repetition is bounded by deterministic cooldown and recent-history exclusion.

- [ ] **Step 2: Write failing scheduler tests**

Test names:

- `testConversationSchedulerDoesNotMutateCombatState`
- `testConversationSchedulerRespectsCooldown`
- `testConversationSchedulerAvoidsRecentRepeats`
- `testHeroAudioMuteDoesNotSuppressText`

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' \
  -only-testing:DockBarHeroTests/HeroConversationSchedulerTests \
  test
```

Expected before implementation: missing types or failing assertions.

- [ ] **Step 3: Implement catalog and scheduler**

Keep catalog small for first slice: Tank/DPS/Healer/Kevin/Book-ready text events only. Do not wire final voice assets until casting is accepted.

- [ ] **Step 4: Render bubbles on rail**

Add bubble nodes to `PrototypeScene.swift` with collision tests against:

- actor sprites
- health bars
- enemy labels
- DPS label
- farming/frontier status

- [ ] **Step 5: Verify**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' \
  -only-testing:DockBarHeroTests/HeroConversationSchedulerTests \
  -only-testing:DockBarHeroTests/PrototypeSceneHostTests \
  -only-testing:DockBarHeroTests/AppSettingsMigrationTests \
  test
./script/build_and_run.sh --verify
git diff --check
```

Expected: all selected tests pass and app launches.

- [ ] **Step 6: Voice casting gate**

Do not accept generated hero audio that sounds like obvious TTS. Use the known acceptance bar: natural or acted speech is required before final voice cues are marked complete.

---

### Task 6: Story And Map Design Packet

**Files:**
- Create: `docs/superpowers/specs/2026-07-15-dockbarhero-story-map-spine.md`
- Modify after approval: `BACKLOG.md`

**Interfaces:**
- Produces: approved narrative spine, character origins, area sequence, Volume One page outline, and Map behavior spec.
- Blocks: manga page generation/replacement and Map implementation.

- [ ] **Step 1: Draft story spine without generating art**

The spec must define:

- how Tank, DPS, Healer, Kevin, and the Book meet
- what each wanted before joining
- why each reluctantly stays
- the continuing problem across areas and 100-level volumes
- how dungeon events cause later locations, warp gates, villains, and genre shifts
- recurring setups/payoffs
- Book mistakes that cause plot events

- [ ] **Step 2: Draft character origins**

Use the existing product tone:

- absurd
- profane with clean-mode support
- genre-mashed
- fourth-wall-breaking
- funny with causal continuity
- Kevin remains a recurring thread
- Book is an unreliable interface character

- [ ] **Step 3: Draft campaign and Map behavior**

Map spec must define:

- discovered
- unlocked
- current
- completed
- future/unknown
- routes and warp gates
- bosses
- story gates
- selected destination uses queued travel/farming rules

- [ ] **Step 4: Review with owner**

Do not proceed to manga dialogue, page replacement, or Map implementation until approved.

- [ ] **Step 5: Update `BACKLOG.md` after approval**

Record the approved spec link under D1 and D2. Keep implementation checkboxes open until code is shipped.

---

### Task 7: Map Implementation

**Files:**
- Create after approval: `DockBarHero/Campaign/CampaignMapModels.swift`
- Create after approval: `DockBarHero/Campaign/CampaignMapResolver.swift`
- Create after approval: `DockBarHero/App/MapView.swift`
- Modify: `DockBarHero/App/ManagementRoute.swift`
- Modify: `DockBarHero/App/ManagementRootView.swift`
- Modify as needed: campaign catalog/state files after locating exact paths.
- Test: `DockBarHeroTests/CampaignMapResolverTests.swift`
- Test: `DockBarHeroTests/ManagementNavigationTests.swift`
- Test: `DockBarHeroTests/ManagementViewTests.swift`

**Interfaces:**
- Consumes: approved story/Map spec from Task 6.
- Produces: deterministic management Map section.

- [ ] **Step 1: Write failing route/navigation tests**

Test that `ManagementRoute.allCases` includes `.map`, title is `Map`, and system image is stable.

- [ ] **Step 2: Write failing map resolver tests**

Test discovered/unlocked/current/completed/future states using deterministic campaign fixtures.

- [ ] **Step 3: Implement map models and resolver**

Keep resolver pure: input campaign state, output view model.

- [ ] **Step 4: Implement `MapView`**

Display the map as a management tool, not a landing page. It must be scannable and utilitarian.

- [ ] **Step 5: Implement destination selection through existing travel/farming rules**

Do not bypass progression. Invalid/future locations are not selectable.

- [ ] **Step 6: Verify**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' \
  -only-testing:DockBarHeroTests/CampaignMapResolverTests \
  -only-testing:DockBarHeroTests/ManagementNavigationTests \
  -only-testing:DockBarHeroTests/ManagementViewTests \
  test
./script/build_and_run.sh --verify
git diff --check
```

Expected: selected tests pass and app launches.

---

### Task 8: Dropped Loot Economy

**Files:**
- Modify after approval: inventory/reward/loot resolver files after locating exact current paths.
- Modify after approval: game/save models.
- Modify after approval: Inventory and Shop views.
- Test: `DockBarHeroTests/InventoryResolverTests.swift`
- Test: `DockBarHeroTests/RewardResolverTests.swift`
- Test: `DockBarHeroTests/SaveDocumentTests.swift`
- Test: `DockBarHeroTests/SaveMigrationRegistryTests.swift`
- Test: `DockBarHeroTests/LootSystemTests.swift`

**Interfaces:**
- Produces: durable dropped-loot aggregate, 25% Shop auto-sale, migration away from overflow as player-accessible inventory.

- [ ] **Step 1: Approve economy details**

Default proposal:

- dropped loot stores aggregate count and aggregate normal sale value
- no individual dropped item inspection
- no equip, move, salvage, or manual claim from dropped pile
- Shop visit auto-sells entire pile at exactly 25%
- sale value uses deterministic integer floor unless owner requests another rounding rule
- unique items contribute their normal value to aggregate before sale discount
- offline loot uses the same drop path and cannot be claimed twice

- [ ] **Step 2: Write failing save/model tests**

Tests must prove dropped aggregate survives save/relaunch and old overflow migrates safely.

- [ ] **Step 3: Write failing reward tests**

Tests must prove full inventory routes new loot to dropped aggregate, not overflow.

- [ ] **Step 4: Write failing Shop tests**

Tests must prove visiting Shop sells all dropped loot at 25% and clears the pile atomically.

- [ ] **Step 5: Implement economy model and resolvers**

Implement durable aggregate first, then UI.

- [ ] **Step 6: Verify**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' \
  -only-testing:DockBarHeroTests/InventoryResolverTests \
  -only-testing:DockBarHeroTests/RewardResolverTests \
  -only-testing:DockBarHeroTests/SaveDocumentTests \
  -only-testing:DockBarHeroTests/SaveMigrationRegistryTests \
  -only-testing:DockBarHeroTests/LootSystemTests \
  test
./script/build_and_run.sh --verify
git diff --check
```

Expected: selected tests pass and app launches.

---

### Task 9: Loot Pile Presentation

**Files:**
- Create after threshold approval: `DockBarHero/Loot/LootPilePresentation.swift`
- Modify: `DockBarHero/Rendering/PrototypeScene.swift`
- Modify: sprite resources only after asset approval.
- Test: `DockBarHeroTests/PrototypeSceneHostTests.swift`
- Test: new loot pile presentation tests after file creation.

**Interfaces:**
- Consumes: dropped-loot aggregate from Task 8.
- Produces: presentation-only loot pile behind heroes.

- [ ] **Step 1: Approve thresholds and layout**

Default threshold proposal for count or value tiers:

```text
0, 1, 2, 3, 5, 8, 13, 21, 34, 55+
```

Use the larger tier from dropped count and dropped value band if both exist.

- [ ] **Step 2: Write failing resolver tests**

Test tier selection for threshold boundaries.

- [ ] **Step 3: Implement pure presentation resolver**

No economy mutation in presentation code.

- [ ] **Step 4: Render behind actors and labels**

Ensure pile is behind heroes and does not collide with labels.

- [ ] **Step 5: Add falling-junk gag only after static pile is accepted**

Reduced Motion freezes falling pieces.

- [ ] **Step 6: Verify**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' \
  -only-testing:DockBarHeroTests/PrototypeSceneHostTests \
  test
python3 scripts/build_sprite_assets.py --manifest art/sprite-manifest.json --output DockBarHero/Resources/Sprites --check
./script/build_and_run.sh --verify
git diff --check
```

Expected: tests pass, sprite check passes if assets changed, app launches.

---

### Task 10: Class Skill Trees

**Files:**
- Create after approval: `DockBarHero/Skills/SkillTreeModels.swift`
- Create after approval: `DockBarHero/Skills/SkillTreeCatalog.swift`
- Create after approval: `DockBarHero/Skills/SkillTreeResolver.swift`
- Modify: existing Skills route/view.
- Modify: save models and combat/class-action integration after locating exact paths.
- Test: `DockBarHeroTests/SkillTreeCatalogTests.swift`
- Test: `DockBarHeroTests/SkillTreeResolverTests.swift`
- Test: `DockBarHeroTests/SaveDocumentTests.swift`
- Test: `DockBarHeroTests/CombatResolverTests.swift`
- Test: `DockBarHeroTests/ClassActionConfigurationTests.swift`

**Interfaces:**
- Produces: meaningful class build choices for Tank, DPS, and Healer.
- Consumes: approved skill-point economy.

- [ ] **Step 1: Approve skill economy**

Decisions required:

- point source
- per-hero or party-wide points
- passive versus active upgrades
- rank caps
- prerequisites
- respec availability and cost
- invalid-build behavior after balance changes

- [ ] **Step 2: Write catalog validation tests**

Tests must reject duplicate IDs, missing prerequisites, cycles, invalid class IDs, and rank caps below 1.

- [ ] **Step 3: Write resolver tests**

Tests must prove point spending, prerequisites, rank upgrades, and invalid spend rejection.

- [ ] **Step 4: Implement save migration**

Older saves decode with empty trees and zero unspent skill points unless approved economy says otherwise.

- [ ] **Step 5: Wire selected upgrades into combat/class actions**

Do this one upgrade at a time with red/green combat tests.

- [ ] **Step 6: Implement Skills UI**

Use management-tool density, not a marketing layout. Show class, points, available upgrades, locked prerequisites, and current ranks.

- [ ] **Step 7: Verify**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' \
  -only-testing:DockBarHeroTests/SkillTreeCatalogTests \
  -only-testing:DockBarHeroTests/SkillTreeResolverTests \
  -only-testing:DockBarHeroTests/SaveDocumentTests \
  -only-testing:DockBarHeroTests/CombatResolverTests \
  -only-testing:DockBarHeroTests/ClassActionConfigurationTests \
  test
./script/build_and_run.sh --verify
git diff --check
```

Expected: selected tests pass and app launches.

---

## Completion Checklist

- [ ] A2 accepted and checked in `BACKLOG.md`.
- [ ] A4 owner decision recorded.
- [ ] B1 accepted and checked in `BACKLOG.md`.
- [ ] C1-C6 accepted and Book aggregate checked in `BACKLOG.md`.
- [ ] B3 hero conversations and audio controls accepted.
- [ ] D1/D2 story and Map designs approved before manga art.
- [ ] Map implementation shipped after design approval.
- [ ] E1 dropped loot economy shipped.
- [ ] E2 loot pile presentation approved and shipped.
- [ ] F1 skill tree design approved and shipped.
- [ ] Final verification packet includes focused tests, `./script/build_and_run.sh --verify`, `git diff --check`, and manual QA notes for UI/audio.

## Self-Review

Spec coverage: Every open `BACKLOG.md` checkbox maps to a task above. Design-gated items remain gated and do not include implementation before owner approval. Manga page generation/replacement remains blocked until story and Map approval.

Placeholder scan: This plan avoids implementation placeholders by separating approval decisions from concrete post-approval steps and commands. Larger design areas identify exact decisions required before code.

Type consistency: New proposed symbols are scoped to their task and not consumed by earlier tasks. Shared settings names in Task 4 are reused by Task 5 for hero audio.
