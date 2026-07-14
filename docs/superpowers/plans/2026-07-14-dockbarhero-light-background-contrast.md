# DockBarHero Light-Background Contrast Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add crisp black outlines to rail text and animated actors while preserving every existing sprite color and opaque interior pixel.

**Architecture:** Keep the change inside `PrototypeScene`: eight offset black child labels sit behind each untouched foreground label, and one shared SpriteKit fragment shader adds an exterior contour to the existing animated textures. Do not regenerate or modify sprite assets.

**Tech Stack:** Swift 6, SpriteKit `SKLabelNode` layering and `SKShader`, XCTest, Xcode arm64 test/build tooling.

## Global Constraints

- Preserve the existing transparent rail, scene geometry, labels, health bars, actor dimensions, animation timing, actor opacity, and texture filtering.
- Preserve every source texture color and alpha value; no PNG, source board, sprite manifest, or asset pipeline edits.
- Draw a black text stroke approximately one display point wide and a one-source-texel black contour outside actor silhouettes.
- Do not add a shadow, glow, plate, or background behind actors.

---

### Task 1: Outlined Dynamic Rail Labels

**Files:**
- Modify: `DockBarHero/Rendering/PrototypeScene.swift:69-111,334-342,436-440`
- Test: `DockBarHeroTests/PrototypeSceneHostTests.swift`

**Interfaces:**
- Consumes: existing `SKLabelNode` foreground colors and dynamic label strings.
- Produces: `setOutlinedText(_:on:)` for synchronizing every foreground label with its eight black child outline layers.

- [ ] **Step 1: Write the failing label regression test**

Add `testRailLabelsKeepVisibleForegroundAboveEightBlackOutlineLayers()`. Render the standard active presentation, unwrap `heroLevel`, `heroAction`, `enemyLevel`, `rollingDPS`, and `farmingStatus`, then assert the foreground labels have no attributed text and keep their white or orange `fontColor`. Assert each owns eight black child labels at every one-point neighboring offset, with matching text and `zPosition == -1`.

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/LightContrastRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/PrototypeSceneHostTests/testRailLabelsKeepVisibleForegroundAboveEightBlackOutlineLayers
```

Expected: FAIL because the attributed-stroke implementation has no separate outline layers and does not leave the foreground plain.

- [ ] **Step 3: Implement outlined label formatting**

Create eight black child labels in `label(name:fontSize:fontName:)` at offsets `(-1,-1)` through `(1,1)`, excluding `(0,0)`. Give them `zPosition = -1`. Route all label assignments in `render(_:)` plus the hit marker through this helper:

```swift
private func setOutlinedText(_ text: String?, on label: SKLabelNode) {
    label.attributedText = nil
    label.text = text
    for outline in label.children.compactMap({ $0 as? SKLabelNode }) {
        outline.text = text
        outline.fontName = label.fontName
        outline.fontSize = label.fontSize
        outline.horizontalAlignmentMode = label.horizontalAlignmentMode
        outline.verticalAlignmentMode = label.verticalAlignmentMode
    }
}
```

- [ ] **Step 4: Run the focused scene suite and verify GREEN**

Run the Task 1 command without the method suffix. Expected: all `PrototypeSceneHostTests` pass and existing plain-text assertions remain valid.

- [ ] **Step 5: Commit**

```bash
git add DockBarHero/Rendering/PrototypeScene.swift DockBarHeroTests/PrototypeSceneHostTests.swift
git commit -m "fix: outline rail labels"
```

### Task 2: Exterior Actor Contour

**Files:**
- Modify: `DockBarHero/Rendering/PrototypeScene.swift:4-13,229-237`
- Test: `DockBarHeroTests/PrototypeSceneHostTests.swift`

**Interfaces:**
- Consumes: the existing 96x64 frame textures from `SpriteCatalog`.
- Produces: one shared `SKShader` with `u_outlineStep = (1/96, 1/64)`, assigned to every actor when it is created.

- [ ] **Step 1: Write the failing actor regression test**

Add `testActorsUseOneTexelExteriorOutlineWithoutChangingPresentation()`. Unwrap hero and enemy, assert each shader is non-nil, assert `u_outlineStep.floatVector2Value` equals `(1/96, 1/64)`, and retain the existing assertions for texture size, actor size, hero/enemy scale, alpha 1, and `.nearest` filtering.

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/LightContrastRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/PrototypeSceneHostTests/testActorsUseOneTexelExteriorOutlineWithoutChangingPresentation
```

Expected: FAIL because existing actors have no shader.

- [ ] **Step 3: Implement the shared outline shader**

Add a static shader that samples the current texel unchanged when alpha is nonzero. When current alpha is zero, sample all eight neighbors at `u_outlineStep`; return opaque black when any neighbor alpha is nonzero and transparent black otherwise. Construct it with:

```swift
SKShader(
    source: fragmentSource,
    uniforms: [SKUniform(
        name: "u_outlineStep",
        vectorFloat2: vector_float2(1.0 / 96.0, 1.0 / 64.0)
    )]
)
```

Assign `node.shader = Self.actorOutlineShader` in `actor(name:token:x:)`. Do not set `color`, `colorBlendFactor`, or actor alpha.

- [ ] **Step 4: Run the focused scene suite and verify GREEN**

Run the Task 2 command without the method suffix. Expected: every `PrototypeSceneHostTests` test passes.

- [ ] **Step 5: Commit**

```bash
git add DockBarHero/Rendering/PrototypeScene.swift DockBarHeroTests/PrototypeSceneHostTests.swift
git commit -m "fix: outline rail actors"
```

### Task 3: Full Verification and Context Record

**Files:**
- Modify only if verified current truth changes: `PROJECT.md`

**Interfaces:**
- Consumes: Tasks 1 and 2.
- Produces: fresh automated and live evidence for the isolated branch.

- [ ] **Step 1: Validate generated assets remain unchanged**

```bash
python3 scripts/build_sprite_assets.py --manifest art/sprite-manifest.json --output DockBarHero/Resources/Sprites --check
python3 -m unittest discover -s scripts/tests -p 'test_*.py'
```

Expected: asset check succeeds and all sprite pipeline tests pass.

- [ ] **Step 2: Run the full arm64 suite**

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/LightContrastFull CODE_SIGNING_ALLOWED=NO
```

Expected: `** TEST SUCCEEDED **` with zero failures.

- [ ] **Step 3: Run clean build and context guard**

```bash
xcodebuild clean build -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/LightContrastClean CODE_SIGNING_ALLOWED=NO
python3 /Users/n3kr0/.codex/skills/maintaining-project-context/scripts/context_guard.py check --root .
```

Expected: `** BUILD SUCCEEDED **` and `project context is valid`.

- [ ] **Step 4: Launch the exact worktree build and inspect both backgrounds**

```bash
./script/build_and_run.sh --verify
```

Use the exact app bundle printed by the script. Confirm a pale desktop shows readable outlined text and actors with unchanged opaque interior colors; confirm a dark desktop keeps the accepted appearance without a shadow or backplate. Record any unavailable manual evidence honestly.

- [ ] **Step 5: Review the diff and update project context only if warranted**

Run `git diff feature/class-actions-and-loot...HEAD --check`, `git status --short`, and the context guard. Update `PROJECT.md` only if this verified fix changes its current milestone truth, then commit that isolated documentation change.
