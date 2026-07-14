# DockBarHero Farming Status Indicator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the desktop rail clearly identify a farming encounter and its current frontier without changing campaign or input behavior.

**Architecture:** `PrototypeScene` reads the already-persisted campaign snapshot from `GamePresentation` and owns one stable presentation-only `SKLabelNode`. Rendering shows `FARMING • FRONTIER <level>` in system orange for `.farming` and hides it for `.push`; no domain, persistence, event, or input API changes.

**Tech Stack:** Swift 6, AppKit, SpriteKit, XCTest, Xcode/xcodebuild on arm64 macOS.

## Global Constraints

- Work inline in `/Users/n3kr0/Projects/TBH/.worktrees/heroes-and-party` on `feature/class-actions-and-loot`; do not dispatch subagents.
- Preserve the existing enemy tier/level label, DPS scale, rail dimensions, overlay placement, focus behavior, fullscreen suppression, and passive click-through behavior.
- The indicator is status-only in passive and interactive modes and never changes a destination.
- Visibility keys directly from `CampaignMode`; queued destinations update the indicator only after the encounter-boundary transaction commits.
- Add no saved field, domain event, timer, inferred mode, dependency, authored quest reward, Class Action modifier, merge, or release work.
- Use TDD, deterministic existing snapshots, focused tests, the full arm64 suite, clean unsigned build, context guard, exact-bundle launch, and live transition QA.

## File Structure

- Modify `DockBarHero/Rendering/PrototypeScene.swift`: create, render, position, and hide the stable presentation-only label.
- Modify `DockBarHeroTests/PrototypeSceneHostTests.swift`: specify farming copy, color, placement, identity, mode transitions, existing enemy copy, and noninteractive node behavior.
- Create `docs/qa/review-packets/farming-status-indicator.md`: record only fresh focused, integrated, build, launch, process, and live visual evidence.
- Modify `PROJECT.md`: add the verified follow-up and QA packet only after every gate passes.

---

### Task 1: Render Farming Frontier Status

**Files:**
- Modify: `DockBarHero/Rendering/PrototypeScene.swift:43-51,68-97,159-183,291-300`
- Test: `DockBarHeroTests/PrototypeSceneHostTests.swift:8-45`

**Interfaces:**
- Consumes: `GamePresentation.state.campaign.mode: CampaignMode` and `GamePresentation.state.campaign.highestUnlockedLevel: Int`.
- Produces: a stable `SKLabelNode` named `farmingStatus`; no new public or domain interface.

- [x] **Step 1: Write the failing farming-to-push rendering test**

Add this test after `testRailUsesExplicitHeroEnemyAndTierLabels`:

```swift
func testFarmingStatusShowsFrontierAndTracksModeTransitions() throws {
    let host = try PrototypeSceneHost(size: CGSize(width: 1_140, height: 96))
    var state = GameState.newGame(balance: .standard)
    state.campaign.highestUnlockedLevel = 192
    state.campaign.selectedLevel = 1
    state.campaign.mode = .farming

    host.render(.active(GameSimulation(state: state).presentation))

    let status = try XCTUnwrap(
        host.scene.childNode(withName: "//farmingStatus") as? SKLabelNode
    )
    XCTAssertEqual(status.text, "FARMING • FRONTIER 192")
    let statusColor = try XCTUnwrap(status.fontColor?.usingColorSpace(.deviceRGB))
    let expectedColor = try XCTUnwrap(NSColor.systemOrange.usingColorSpace(.deviceRGB))
    XCTAssertEqual(statusColor.redComponent, expectedColor.redComponent, accuracy: 0.001)
    XCTAssertEqual(statusColor.greenComponent, expectedColor.greenComponent, accuracy: 0.001)
    XCTAssertEqual(statusColor.blueComponent, expectedColor.blueComponent, accuracy: 0.001)
    XCTAssertEqual(statusColor.alphaComponent, expectedColor.alphaComponent, accuracy: 0.001)
    XCTAssertFalse(status.isHidden)
    XCTAssertFalse(status.isUserInteractionEnabled)
    XCTAssertEqual(status.position.x, host.scene.size.width * 0.78, accuracy: 0.001)
    XCTAssertEqual(status.position.y, 82, accuracy: 0.001)
    XCTAssertEqual(
        (host.scene.childNode(withName: "//enemyLevel") as? SKLabelNode)?.text,
        "Normal · Enemy Lv. 1"
    )

    let originalStatus = status
    state.campaign.selectedLevel = 192
    state.campaign.mode = .push
    state.encounter.enemyLevel = 192
    host.render(.active(GameSimulation(state: state).presentation))

    let pushedStatus = try XCTUnwrap(
        host.scene.childNode(withName: "//farmingStatus") as? SKLabelNode
    )
    XCTAssertTrue(pushedStatus === originalStatus)
    XCTAssertTrue(pushedStatus.isHidden)
    XCTAssertNil(pushedStatus.text)
}
```

Extend `testClassSelectionHidesCombatPresentation` with:

```swift
XCTAssertTrue(host.scene.childNode(withName: "//farmingStatus")?.isHidden == true)
```

- [x] **Step 2: Run the focused test and verify RED**

Run:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/FarmingStatusFocusedRed CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/PrototypeSceneHostTests
```

Expected: `testFarmingStatusShowsFrontierAndTracksModeTransitions` fails because `//farmingStatus` does not exist.

- [x] **Step 3: Add the minimal stable label implementation**

In `didMove(to:)`, create the node beside the existing enemy and DPS labels:

```swift
let enemyLevel = label(name: "enemyLevel", fontSize: 12)
let farmingStatus = label(name: "farmingStatus", fontSize: 10)
farmingStatus.fontColor = .systemOrange
farmingStatus.isUserInteractionEnabled = false
let rollingDPS = label(name: "rollingDPS", fontSize: 12)
addChild(heroLevel)
addChild(heroAction)
addChild(enemyLevel)
addChild(farmingStatus)
addChild(rollingDPS)
```

In `render(_:)`, update from the campaign snapshot after the enemy label:

```swift
if let farmingStatus = childNode(withName: "farmingStatus") as? SKLabelNode {
    switch presentation.state.campaign.mode {
    case .farming:
        farmingStatus.text = "FARMING • FRONTIER \(presentation.state.campaign.highestUnlockedLevel)"
        farmingStatus.isHidden = false
    case .push:
        farmingStatus.text = nil
        farmingStatus.isHidden = true
    }
}
```

Position it in `updateLayout()` on the enemy-side action row:

```swift
(childNode(withName: "enemyLevel") as? SKLabelNode)?.position = CGPoint(x: enemyX, y: 70)
(childNode(withName: "farmingStatus") as? SKLabelNode)?.position = CGPoint(x: enemyX, y: 82)
(childNode(withName: "rollingDPS") as? SKLabelNode)?.position = CGPoint(x: size.width / 2, y: 70)
```

Include it in `setCombatHidden(_:)`:

```swift
var names = [
    "enemy", "enemyHealthBackground", "enemyHealthFill", "enemyLevel",
    "farmingStatus", "rollingDPS"
]
```

- [x] **Step 4: Run the focused scene suite and verify GREEN**

Run:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/FarmingStatusFocusedGreen CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/PrototypeSceneHostTests
```

Expected: 16 `PrototypeSceneHostTests` pass with zero failures and `** TEST SUCCEEDED **`.

- [x] **Step 5: Review and commit the rendering slice**

Run:

```bash
git diff --check
git diff -- DockBarHero/Rendering/PrototypeScene.swift DockBarHeroTests/PrototypeSceneHostTests.swift
git add DockBarHero/Rendering/PrototypeScene.swift DockBarHeroTests/PrototypeSceneHostTests.swift
git commit -m "feat: show farming frontier on rail"
```

Expected: only the stable label and its focused tests are committed.

### Task 2: Verify the Live Transition and Record the Handoff

**Files:**
- Create: `docs/qa/review-packets/farming-status-indicator.md`
- Modify: `PROJECT.md:6-15,34-46,61-82`

**Interfaces:**
- Consumes: the Task 1 `farmingStatus` node and the existing management `returnToFrontier` intent path.
- Produces: verified QA evidence and current project context; no runtime interface.

- [ ] **Step 1: Run the complete automated and build gates**

Run the full suite:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/FarmingStatusFull CODE_SIGNING_ALLOWED=NO
```

Expected: 345 tests pass with zero failures and `** TEST SUCCEEDED **`.

Run the clean build:

```bash
xcodebuild clean build -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/FarmingStatusBuild CODE_SIGNING_ALLOWED=NO
```

Expected: clean/build exits zero and reports `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Launch only the exact worktree bundle**

Run:

```bash
pkill -x DockBarHero 2>/dev/null || true
./script/build_and_run.sh --verify
ps -axo pid=,command= | awk '/DockBarHero\.app\/Contents\/MacOS\/DockBarHero$/ {print}'
```

Expected: one process from `/Users/n3kr0/Projects/TBH/.worktrees/heroes-and-party/.build/RunDerivedData/Build/Products/Debug/DockBarHero.app/Contents/MacOS/DockBarHero`.

- [ ] **Step 3: Perform exact-window live QA at the encounter boundary**

With the existing clean run at farming level 1/frontier 192:

1. Capture the rail window and verify the orange `FARMING • FRONTIER 192` line appears above `Normal • Enemy Lv. 1` without obscuring the DPS scale.
2. Use the existing management `Return to Frontier` control; do not alter settings or save files directly.
3. Before the level-1 encounter resolves, verify the farming line remains visible because the destination is only queued.
4. After the encounter boundary activates level 192 in push mode, capture the rail and verify the farming line is hidden while the enemy tier/level and DPS labels remain visible.
5. Verify process count remains one and both settings files retain SHA-256 `1bd458308cf46a91b10dfe45093bf41993bdd24477626ca80278cf6e981a61a9`.

Expected: both visible and hidden states match the approved design without changing passive rail behavior.

- [ ] **Step 4: Write verified QA and current context**

After every preceding command and live check matches its expected result, create `docs/qa/review-packets/farming-status-indicator.md` with this exact content. If any observed value differs, stop and record the actual evidence instead of using this block:

```markdown
# Farming Status Indicator Review Packet

- Branch: `feature/class-actions-and-loot`
- Scope: read-only farming/frontier rail status
- Exclusions: campaign behavior changes, click actions, merge, and release

## Automated Evidence

- Focused rendering: 16 tests passed with zero failures.
- Full arm64 suite: 345 tests passed with zero failures.
- Clean unsigned arm64 build: `** BUILD SUCCEEDED **`.

## Live Evidence

- Farming capture: `FARMING • FRONTIER 192` appeared above `Normal • Enemy Lv. 1`; DPS remained unobstructed.
- Queued return preserved farming status until encounter resolution.
- Frontier capture hid the status after push mode committed.
- Exact bundle/process: one process at `/Users/n3kr0/Projects/TBH/.worktrees/heroes-and-party/.build/RunDerivedData/Build/Products/Debug/DockBarHero.app/Contents/MacOS/DockBarHero`.
- Both settings files retained SHA-256 `1bd458308cf46a91b10dfe45093bf41993bdd24477626ca80278cf6e981a61a9`.

## Final State

- Context guard: `project context is valid`.
- Branch remains unmerged and unreleased.
```

Update `PROJECT.md` to link the new packet and state only the verified test count, build, launch, visible farming copy, boundary transition, and branch status.

- [ ] **Step 5: Run documentation and repository guards**

Run:

```bash
python3 /Users/n3kr0/.codex/skills/maintaining-project-context/scripts/context_guard.py check --root .
git diff --check
wc -l AGENTS.md PROJECT.md
git status --short
```

Expected: context valid, no whitespace errors, `AGENTS.md` at most 100 lines, `PROJECT.md` at most 150 lines, and only the QA/context files modified.

- [ ] **Step 6: Commit, push, and prove isolation**

Run:

```bash
git add PROJECT.md docs/qa/review-packets/farming-status-indicator.md
git commit -m "docs: verify farming rail status"
git push
test -z "$(git status --porcelain)"
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/feature/class-actions-and-loot)"
test "$(git -C /Users/n3kr0/Projects/TBH rev-parse main)" = "$(git -C /Users/n3kr0/Projects/TBH rev-parse origin/main)"
```

Expected: the feature branch is pushed and clean, local/remote feature SHAs match, and `main` remains unchanged and unmerged.
