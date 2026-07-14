# DockBarHero Production Sprites Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the five approved sprite reference boards into a reproducible production asset library and replace DockBarHero's procedural rail motion with deterministic class-, enemy-, and boss-specific animation clips.

**Architecture:** A checksum-locked manifest and ImageMagick-backed repository tool produce equal-cell transparent strips and a runtime manifest. A bundled catalog slices strips into nearest-filtered `SpriteClip` values, an `EnemySpriteResolver` chooses presentation-only identities from level/tier, and `PrototypeScene` runs event-selected clips on stable actor nodes without positional movement.

**Tech Stack:** Swift 6, SpriteKit, AppKit, XCTest, JSON, Python 3 standard library, ImageMagick, XcodeGen, arm64 macOS.

## Global Constraints

- Work inline in `/Users/n3kr0/Projects/TBH/.worktrees/heroes-and-party` on `feature/class-actions-and-loot`; do not dispatch subagents.
- Preserve combat timing, event ordering, rewards, persistence, overlay placement, focus behavior, fullscreen suppression, input behavior, farming status, enemy labels, DPS scale, and all application settings.
- Archive the five owner-supplied boards byte-identically and never modify them in place.
- Every generated cell is 96×64 RGBA, bottom-center anchored, and nearest-neighbor scaled.
- Preserve every supplied animation action in the asset manifest; wire only behavior already represented by current game events.
- Enemy identity is presentation-only, deterministic from encounter level/tier, and is never saved.
- Boss art adds no mechanic, reward, encounter timing, or party-size scaling.
- Use TDD for pipeline behavior, runtime parsing/resolution, and scene behavior; generated binary artifacts are verified by deterministic validators.
- Run focused tests after every slice, then the complete arm64 suite, clean unsigned build, context guard, exact-bundle launch, and live QA.
- Do not merge to `main`, release, or start authored boss rewards.

## File Structure

- Create `art/sprite-boards/`: immutable source-board archive.
- Create `art/sprite-manifest.json`: source hashes, crop rectangles, frame order, action metadata, and output names.
- Create `scripts/build_sprite_assets.py`: validation, ImageMagick extraction, normalization, strip assembly, and runtime-manifest emission.
- Create `scripts/tests/test_build_sprite_assets.py`: deterministic pipeline contract tests using temporary synthetic boards.
- Create `DockBarHero/Resources/Sprites/`: generated strips and `manifest.json` bundled by XcodeGen.
- Create `DockBarHero/Rendering/SpriteClip.swift`: clip metadata and animation policy.
- Modify `DockBarHero/Rendering/SpriteCatalog.swift`: production manifest loader with built-in fallback.
- Create `DockBarHero/Rendering/EnemySpriteResolver.swift`: deterministic presentation identity.
- Modify `DockBarHero/Rendering/PrototypeScene.swift`: stable anchored clip playback with no procedural movement.
- Modify `DockBarHeroTests/SpriteCatalogTests.swift`, `DockBarHeroTests/PrototypeSceneHostTests.swift`; create `DockBarHeroTests/EnemySpriteResolverTests.swift`.
- Create `docs/qa/review-packets/production-sprites.md`; update `PROJECT.md` only after verified completion.

---

### Task 1: Archive Sources and Build the Deterministic Asset Tool

**Files:**
- Create: `art/sprite-boards/dps-reference.png`
- Create: `art/sprite-boards/tank-reference.png`
- Create: `art/sprite-boards/healer-reference.png`
- Create: `art/sprite-boards/standard-enemies-reference.png`
- Create: `art/sprite-boards/elite-enemies-reference.png`
- Create: `art/sprite-manifest.json`
- Create: `scripts/build_sprite_assets.py`
- Create: `scripts/tests/test_build_sprite_assets.py`

**Interfaces:**
- Consumes: manifest JSON with `sources`, `actors`, `actions`, `frames`, and crop rectangles `[x, y, width, height]`.
- Produces: `build_assets(manifest_path: Path, output_root: Path) -> dict` and a generated runtime `manifest.json`.

- [x] **Step 1: Write failing pipeline tests**

Tests create a synthetic RGB board with two colored actors on a dark background and assert that `build_assets` rejects the wrong source hash, emits two transparent 96×64 frames in one strip, retains nonempty alpha, and writes exact frame count/duration/loop metadata.

- [x] **Step 2: Verify RED**

Run:

```bash
python3 -m unittest scripts.tests.test_build_sprite_assets -v
```

Expected: import failure because `scripts.build_sprite_assets` does not exist.

- [x] **Step 3: Implement the minimal pipeline**

Use only Python's standard library for orchestration and `subprocess.run(..., check=True)` for ImageMagick. Verify SHA-256 before processing. For each crop, remove the edge-connected board color, trim, scale the actor union once per clip, composite each frame bottom-center into 96×64 transparent cells, and append cells horizontally. Validate output with `magick identify` and emit sorted deterministic JSON.

- [x] **Step 4: Verify GREEN and source hashes**

Run:

```bash
python3 -m unittest scripts.tests.test_build_sprite_assets -v
shasum -a 256 art/sprite-boards/*.png
```

Expected: all pipeline tests pass and every archived source matches the design SHA.

- [x] **Step 5: Commit the pipeline slice**

```bash
git add art/sprite-boards art/sprite-manifest.json scripts/build_sprite_assets.py scripts/tests/test_build_sprite_assets.py
git commit -m "feat: add deterministic sprite asset pipeline"
```

### Task 2: Produce and Validate the Complete Asset Library

**Files:**
- Modify: `art/sprite-manifest.json`
- Generate: `DockBarHero/Resources/Sprites/**/*.png`
- Generate: `DockBarHero/Resources/Sprites/manifest.json`

**Interfaces:**
- Consumes: Task 1's `build_assets` contract and five archived sources.
- Produces: production strips named `<actor>/<action>.png` plus runtime entries `{token, action, resource, frameCount, secondsPerFrame, repeats}`.

- [x] **Step 1: Add every supplied actor/action crop to the manifest**

Record DPS, Tank, Healer, fourteen normal identities, eight elite identities, and every available action frame. Mark reference-only direction/equipment/palette examples as excluded with an explicit reason rather than emitting misleading clips.

- [x] **Step 2: Generate the supplied library**

Run:

```bash
python3 scripts/build_sprite_assets.py --manifest art/sprite-manifest.json --output DockBarHero/Resources/Sprites
```

Expected: deterministic strips and a manifest with no missing requested action.

- [x] **Step 3: Create four original boss sheets**

Using the approved boards as style references, create Ironroot Warchief, Ossuary Sovereign, Embermaw Colossus, and Astral Wyrm with idle, attack, signature, hit, and defeat sequences. Normalize them through the same 96×64 pipeline and record source/provenance metadata without modifying gameplay.

- [x] **Step 4: Validate every generated artifact**

Run the builder with `--check`, verify every PNG is RGBA, every width is a positive multiple of 96, every height is 64, every cell has nonzero alpha, and generate contact sheets under `.build/SpritePreviews/` for visual inspection.

- [ ] **Step 5: Commit production assets**

```bash
git add art/sprite-manifest.json DockBarHero/Resources/Sprites
git commit -m "assets: add production hero enemy and boss sprites"
```

### Task 3: Load Bundled Animation Clips

**Files:**
- Create: `DockBarHero/Rendering/SpriteClip.swift`
- Modify: `DockBarHero/Rendering/SpriteCatalog.swift`
- Modify: `DockBarHero/Rendering/BuiltinPixelSprites.swift`
- Modify: `DockBarHeroTests/SpriteCatalogTests.swift`

**Interfaces:**
- Produces: `SpriteClip { textures: [SKTexture], secondsPerFrame: TimeInterval, repeats: Bool }`.
- Produces: `SpriteCatalog.clip(for: SpriteToken, action: SpriteAction) -> SpriteClip`.
- Produces: expanded `SpriteToken` and `SpriteAction` raw-value enums matching the runtime manifest.

- [ ] **Step 1: Write failing catalog tests**

Specify deterministic manifest decoding, equal-width strip slicing, `.nearest` filtering, declared timing/loop behavior, all required token/action entries, and fallback to the built-in idle definition when a resource or clip is absent.

- [ ] **Step 2: Verify RED**

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/SpriteCatalogRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/SpriteCatalogTests
```

Expected: compile failure because `SpriteClip` and `clip(for:action:)` do not exist.

- [ ] **Step 3: Implement the catalog**

Decode the bundled manifest once, load strip images by resource path, split them into declared equal frames, set `.nearest`, and return the declared timing. Keep `BuiltinSpriteCatalog` as an injectable fallback and log invalid resources once.

- [ ] **Step 4: Verify GREEN**

Run the focused SpriteCatalog suite and expect zero failures and `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit the catalog slice**

```bash
git add DockBarHero/Rendering/SpriteClip.swift DockBarHero/Rendering/SpriteCatalog.swift DockBarHero/Rendering/BuiltinPixelSprites.swift DockBarHeroTests/SpriteCatalogTests.swift project.yml DockBarHero.xcodeproj
git commit -m "feat: load bundled sprite animation clips"
```

### Task 4: Resolve Deterministic Enemy Identities

**Files:**
- Create: `DockBarHero/Rendering/EnemySpriteResolver.swift`
- Create: `DockBarHeroTests/EnemySpriteResolverTests.swift`

**Interfaces:**
- Produces: `EnemySpriteResolver.token(level: Int, tier: EnemyTierID) -> SpriteToken`.

- [ ] **Step 1: Write failing resolver tests**

Assert the exact normal sequence, exact elite sequence, boss 25/50/75/100 identities, stable cycling after level 100, and generic fallback for invalid levels.

- [ ] **Step 2: Verify RED**

Run only `DockBarHeroTests/EnemySpriteResolverTests`; expect compile failure because the resolver is absent.

- [ ] **Step 3: Implement the minimal pure resolver**

Use immutable ordered token arrays. Normal index is `(level - 1) % 14`, elite index is `((level / 5) - 1) % 8`, and boss index is `((level / 25) - 1) % 4`. Invalid levels return `.enemy`.

- [ ] **Step 4: Verify GREEN and commit**

```bash
git add DockBarHero/Rendering/EnemySpriteResolver.swift DockBarHeroTests/EnemySpriteResolverTests.swift
git commit -m "feat: resolve deterministic enemy sprite identities"
```

### Task 5: Replace Procedural Hero Motion with Clips

**Files:**
- Modify: `DockBarHero/Rendering/PrototypeScene.swift`
- Modify: `DockBarHeroTests/PrototypeSceneHostTests.swift`

**Interfaces:**
- Consumes: `SpriteCatalog.clip(for:action:)` and stable hero slot prefixes.
- Produces: keyed `spriteLoop` and `spriteAction` actions with no keyed `idle` or `eventAttack` movement.

- [ ] **Step 1: Write failing hero animation tests**

Assert every rendered party slot starts a repeating idle clip, repeated snapshots retain the same idle action identity, `.heroAttack(slot:)` animates only that slot without changing position, class-action events choose `.classAction`, `.heroDown` ends on defeat and remains down, and victory/revival restores every slot to idle.

- [ ] **Step 2: Verify RED**

Run `PrototypeSceneHostTests`; expect failures because secondary nodes lack idle actions and current attacks use positional movement.

- [ ] **Step 3: Implement stable clip playback**

Remove the procedural bob and `animateHeroAttack`. Start idle when a node is created or its identity changes. Play nonlooping event clips, return living actors to idle on completion, retain the final defeat frame, and route `.classActionCast(heroSlot:actionID:)` to the exact hero.

- [ ] **Step 4: Verify GREEN and commit**

```bash
git add DockBarHero/Rendering/PrototypeScene.swift DockBarHeroTests/PrototypeSceneHostTests.swift
git commit -m "feat: animate every hero from production clips"
```

### Task 6: Animate Standard, Elite, and Boss Enemies

**Files:**
- Modify: `DockBarHero/Rendering/PrototypeScene.swift`
- Modify: `DockBarHeroTests/PrototypeSceneHostTests.swift`

**Interfaces:**
- Consumes: `EnemySpriteResolver` and `GamePresentation.state.encounter`.
- Produces: stable enemy node identity and clip selection with no saved field.

- [ ] **Step 1: Write failing enemy scene tests**

Assert normal/elite/boss renders select expected tokens, identity changes replace idle once, unchanged snapshots do not restart it, enemy attacks/hits/defeats use the resolved token, and encounter resolution starts the next identity's idle clip.

- [ ] **Step 2: Verify RED**

Run the focused scene suite; expect token/call mismatches because the scene always uses `.enemy`.

- [ ] **Step 3: Implement resolved enemy playback**

Track `renderedEnemyToken`, resolve it from level/tier during render, and route enemy event clips through that token. Remove enemy positional lunges and the defeat fade while retaining hit markers and all labels.

- [ ] **Step 4: Verify GREEN and commit**

```bash
git add DockBarHero/Rendering/PrototypeScene.swift DockBarHeroTests/PrototypeSceneHostTests.swift
git commit -m "feat: animate deterministic enemy identities"
```

### Task 7: Full Verification and Live QA

**Files:**
- Create: `docs/qa/review-packets/production-sprites.md`
- Modify: `PROJECT.md`
- Modify: `docs/superpowers/plans/2026-07-13-dockbarhero-production-sprites.md`

- [ ] **Step 1: Run asset and focused gates**

Run the pipeline tests, builder `--check`, SpriteCatalog, EnemySpriteResolver, and PrototypeSceneHost suites. Record actual counts only.

- [ ] **Step 2: Run complete arm64 gates**

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/ProductionSpritesFull CODE_SIGNING_ALLOWED=NO
xcodebuild clean build -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/ProductionSpritesBuild CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 3: Launch one exact worktree bundle**

Terminate every existing DockBarHero process, run `./script/build_and_run.sh --verify`, and prove exactly one process uses the absolute worktree path.

- [ ] **Step 4: Perform live visual QA**

Verify all three heroes idle independently, simultaneous attacks animate by slot without drift, class actions use their clips, damage/defeat/victory restore correctly, normal/elite/boss identities change at correct levels, farming/push status remains correct, sprites do not obscure health/action/level/DPS labels, animation pause works, and passive rail remains click-through. Preserve settings and saves.

- [ ] **Step 5: Record verified facts and guard context**

Write the QA packet, update `PROJECT.md`, run context guard, `git diff --check`, line limits, and inspect the complete diff.

- [ ] **Step 6: Commit, push, and prove isolation**

```bash
git add PROJECT.md docs/qa/review-packets/production-sprites.md docs/superpowers/plans/2026-07-13-dockbarhero-production-sprites.md
git commit -m "docs: verify production sprite milestone"
git push
test -z "$(git status --porcelain)"
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/feature/class-actions-and-loot)"
test "$(git -C /Users/n3kr0/Projects/TBH rev-parse main)" = "$(git -C /Users/n3kr0/Projects/TBH rev-parse origin/main)"
```

Expected: clean synchronized feature branch, unchanged `main`, no merge, no release.
