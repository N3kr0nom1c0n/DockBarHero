# DockBarHero Rail Appearance Scaling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Settings controls that persistently scale combat actors and rail text without changing gameplay state.

**Architecture:** Store the two appearance values in `AppSettings`, expose update methods through `AppModel`, and pass a small scene-only appearance value through `SceneControlling`. `PrototypeScene` applies actor scale during layout and text scale through named base font sizes while preserving existing collision clamps.

**Tech Stack:** Swift 6, SwiftUI Settings form, SpriteKit rail scene, XCTest, existing settings codec/session/store.

## Global Constraints

- Do not change combat, balance, save-game, inventory, or lore unlock semantics.
- Do not scale health bars in this slice; only actor sprites and rail text change.
- Actor scale range is `75...140`, default `100`.
- Rail text scale range is `85...130`, default `100`.
- Older settings migrate to both defaults.
- Settings changes must apply immediately to the current rail, even if no new game presentation arrives.
- Keep existing collision and minimum font-size behavior for narrow rails.
- Use TDD: every production behavior change gets a failing focused test first.
- Do not push.

---

## File Structure

- Modify `DockBarHero/Settings/AppSettings.swift`
  - Add persisted settings fields, schema migration, validation errors, and range clamps.
- Modify `DockBarHero/Settings/SettingsStore.swift`
  - Move settings file URLs from `settings-v2*` to `settings-v3*` while retaining v2 and v1 lookup for migration.
- Modify `DockBarHero/App/AppModel.swift`
  - Add update methods and apply scene appearance after settings load/change.
- Modify `DockBarHero/App/SettingsView.swift`
  - Add a `Rail Appearance` section with two sliders.
- Modify `DockBarHero/Rendering/PrototypeSceneHost.swift`
  - Add a scene appearance value and `setAppearance(_:)` to `SceneControlling`.
- Modify `DockBarHero/Rendering/PrototypeScene.swift`
  - Store appearance, scale actor sizes and label sizes, and relayout on appearance changes.
- Modify tests:
  - `DockBarHeroTests/AppSettingsMigrationTests.swift`
  - `DockBarHeroTests/SettingsStoreTests.swift`
  - `DockBarHeroTests/AppModelTests.swift`
  - `DockBarHeroTests/PrototypeSceneHostTests.swift`

---

### Task 1: Persist Rail Appearance Settings

**Files:**
- Modify: `DockBarHero/Settings/AppSettings.swift`
- Modify: `DockBarHero/Settings/SettingsStore.swift`
- Test: `DockBarHeroTests/AppSettingsMigrationTests.swift`
- Test: `DockBarHeroTests/SettingsStoreTests.swift`

**Interfaces:**
- Produces: `AppSettings.actorScalePercent: Int`
- Produces: `AppSettings.railTextScalePercent: Int`
- Produces: `SettingsDecodingError.invalidActorScalePercent(Int)`
- Produces: `SettingsDecodingError.invalidRailTextScalePercent(Int)`

- [ ] **Step 1: Write failing migration/default tests**

Add to `DockBarHeroTests/AppSettingsMigrationTests.swift`:

```swift
func testV2MigratesToV3RailAppearanceDefaults() throws {
    let data = Data(
        #"{"animationMode":"paused","autoReadNewLorePages":true,"bookVolumeDetent":5,"hasSeenCurrentRunPrologue":false,"inputMode":"interactive","loreIllustrationMode":"safe","loreLanguageMode":"unfiltered","manualVisibility":"hidden","schemaVersion":2,"spokenDialogueEnabled":false}"#.utf8
    )

    let settings = try SettingsCodec().decode(data)

    XCTAssertEqual(settings.schemaVersion, 3)
    XCTAssertEqual(settings.manualVisibility, .hidden)
    XCTAssertEqual(settings.animationMode, .paused)
    XCTAssertEqual(settings.inputMode, .interactive)
    XCTAssertEqual(settings.actorScalePercent, 100)
    XCTAssertEqual(settings.railTextScalePercent, 100)
}

func testCodecRejectsOutOfRangeRailAppearanceValues() throws {
    let actorData = Data(
        #"{"actorScalePercent":141,"animationMode":"running","autoReadNewLorePages":true,"bookVolumeDetent":5,"hasSeenCurrentRunPrologue":false,"inputMode":"passive","loreIllustrationMode":"safe","loreLanguageMode":"unfiltered","manualVisibility":"shown","railTextScalePercent":100,"schemaVersion":3,"spokenDialogueEnabled":false}"#.utf8
    )
    let textData = Data(
        #"{"actorScalePercent":100,"animationMode":"running","autoReadNewLorePages":true,"bookVolumeDetent":5,"hasSeenCurrentRunPrologue":false,"inputMode":"passive","loreIllustrationMode":"safe","loreLanguageMode":"unfiltered","manualVisibility":"shown","railTextScalePercent":84,"schemaVersion":3,"spokenDialogueEnabled":false}"#.utf8
    )

    XCTAssertThrowsError(try SettingsCodec().decode(actorData)) { error in
        XCTAssertEqual(error as? SettingsDecodingError, .invalidActorScalePercent(141))
    }
    XCTAssertThrowsError(try SettingsCodec().decode(textData)) { error in
        XCTAssertEqual(error as? SettingsDecodingError, .invalidRailTextScalePercent(84))
    }
}
```

Update the existing v1 migration assertion name/body to expect schema `3` and the two new defaults.

- [ ] **Step 2: Run migration tests to verify red**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/AppSettingsMigrationTests test
```

Expected: FAIL because schema `3`, new fields, and new validation errors do not exist.

- [ ] **Step 3: Implement settings schema v3**

In `DockBarHero/Settings/AppSettings.swift`, change:

```swift
static let currentVersion = 3
```

Add fields:

```swift
var actorScalePercent: Int
var railTextScalePercent: Int
```

Add initializer parameters after `inputMode`:

```swift
actorScalePercent: Int = 100,
railTextScalePercent: Int = 100,
```

Assign them in `init`.

Add errors:

```swift
case invalidActorScalePercent(Int)
case invalidRailTextScalePercent(Int)
```

Add validation:

```swift
guard (75...140).contains(settings.actorScalePercent) else {
    throw SettingsDecodingError.invalidActorScalePercent(settings.actorScalePercent)
}
guard (85...130).contains(settings.railTextScalePercent) else {
    throw SettingsDecodingError.invalidRailTextScalePercent(settings.railTextScalePercent)
}
```

Add `LegacyV2Settings` with the current v2 fields, then decode case `2` to v3:

```swift
case 2:
    let legacy = try JSONDecoder().decode(LegacyV2Settings.self, from: data)
    return AppSettings(
        schemaVersion: AppSettings.currentVersion,
        manualVisibility: legacy.manualVisibility,
        animationMode: legacy.animationMode,
        inputMode: legacy.inputMode,
        loreLanguageMode: legacy.loreLanguageMode,
        loreIllustrationMode: legacy.loreIllustrationMode,
        spokenDialogueEnabled: legacy.spokenDialogueEnabled,
        bookVolumeDetent: legacy.bookVolumeDetent,
        autoReadNewLorePages: legacy.autoReadNewLorePages,
        hasSeenCurrentRunPrologue: legacy.hasSeenCurrentRunPrologue,
        lastAutoReadLorePageID: legacy.lastAutoReadLorePageID
    )
```

Make the existing v1 case also return schema `3` through the current initializer defaults.

In `DockBarHero/Settings/SettingsStore.swift`, extend `SettingsURLs`:

```swift
let legacyV2Primary: URL
let legacyV2Backup: URL
```

Change current paths to `settings-v3*`, and assign:

```swift
self.legacyV2Primary = directory.appendingPathComponent("settings-v2.json", isDirectory: false)
self.legacyV2Backup = directory.appendingPathComponent("settings-v2.backup.json", isDirectory: false)
```

Load order should become:

```swift
for url in [urls.primary, urls.backup, urls.legacyV2Primary, urls.legacyV2Backup, urls.legacyV1Primary, urls.legacyV1Backup] {
```

Persist migrated settings when the loaded URL is any legacy URL.

- [ ] **Step 4: Update settings store tests**

In `DockBarHeroTests/SettingsStoreTests.swift`, update URL expectations:

```swift
XCTAssertEqual(urls.primary.lastPathComponent, "settings-v3.json")
XCTAssertEqual(urls.backup.lastPathComponent, "settings-v3.backup.json")
XCTAssertEqual(urls.temporary.lastPathComponent, "settings-v3.pending.json")
XCTAssertEqual(urls.legacyV2Primary.lastPathComponent, "settings-v2.json")
XCTAssertEqual(urls.legacyV2Backup.lastPathComponent, "settings-v2.backup.json")
```

Update deterministic JSON expected string to include:

```json
"actorScalePercent":100
"railTextScalePercent":100
"schemaVersion":3
```

Update corrupt quarantine name checks from `settings-v2.json.invalid-` to `settings-v3.json.invalid-`.

Add v2 file migration coverage:

```swift
func testLegacyV2MigratesToV3Primary() async throws {
    let urls = SettingsURLs(directory: directory)
    let legacy = Data(
        #"{"animationMode":"paused","autoReadNewLorePages":true,"bookVolumeDetent":5,"hasSeenCurrentRunPrologue":false,"inputMode":"interactive","loreIllustrationMode":"safe","loreLanguageMode":"unfiltered","manualVisibility":"hidden","schemaVersion":2,"spokenDialogueEnabled":false}"#.utf8
    )
    try legacy.write(to: urls.legacyV2Primary)

    let loaded = await makeStore().load()

    XCTAssertEqual(loaded.schemaVersion, 3)
    XCTAssertEqual(loaded.actorScalePercent, 100)
    XCTAssertEqual(loaded.railTextScalePercent, 100)
    XCTAssertTrue(FileManager.default.fileExists(atPath: urls.primary.path))
    XCTAssertEqual(try decode(urls.primary), loaded)
    XCTAssertEqual(try Data(contentsOf: urls.legacyV2Primary), legacy)
}
```

- [ ] **Step 5: Run settings tests to verify green**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/AppSettingsMigrationTests -only-testing:DockBarHeroTests/SettingsStoreTests test
```

Expected: PASS.

---

### Task 2: Apply Appearance Through AppModel and SceneControlling

**Files:**
- Modify: `DockBarHero/Rendering/PrototypeSceneHost.swift`
- Modify: `DockBarHero/App/AppModel.swift`
- Test: `DockBarHeroTests/AppModelTests.swift`

**Interfaces:**
- Produces: `RailAppearance: Equatable, Sendable`
- Produces: `SceneControlling.setAppearance(_ appearance: RailAppearance)`
- Produces: `AppModel.updateActorScalePercent(_:)`
- Produces: `AppModel.updateRailTextScalePercent(_:)`

- [ ] **Step 1: Write failing AppModel tests**

Add to `DockBarHeroTests/AppModelTests.swift`:

```swift
func testSettingsScaleUpdatesPersistAndApplyToScene() {
    let settings = FakeSettingsController(initial: .defaults)
    let scene = FakeScene()
    let model = makeModel(scene: scene, settingsController: settings)
    settings.resolve()

    model.updateActorScalePercent(125)
    model.updateRailTextScalePercent(120)

    XCTAssertEqual(model.appSettings.actorScalePercent, 125)
    XCTAssertEqual(model.appSettings.railTextScalePercent, 120)
    XCTAssertEqual(settings.updates.last?.actorScalePercent, 125)
    XCTAssertEqual(settings.updates.last?.railTextScalePercent, 120)
    XCTAssertEqual(scene.appearances.last, RailAppearance(actorScalePercent: 125, railTextScalePercent: 120))
}

func testReceivedSettingsApplyAppearanceToConnectedScene() {
    var initial = AppSettings.defaults
    initial.actorScalePercent = 90
    initial.railTextScalePercent = 115
    let settings = FakeSettingsController(initial: initial)
    let scene = FakeScene()
    let model = makeModel(scene: scene, settingsController: settings)

    settings.resolve()

    XCTAssertEqual(scene.appearances.last, RailAppearance(actorScalePercent: 90, railTextScalePercent: 115))
    XCTAssertEqual(model.appSettings.actorScalePercent, 90)
    XCTAssertEqual(model.appSettings.railTextScalePercent, 115)
}
```

Add storage to `FakeScene`:

```swift
var appearances: [RailAppearance] = []
func setAppearance(_ appearance: RailAppearance) { appearances.append(appearance) }
```

- [ ] **Step 2: Run AppModel tests to verify red**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/AppModelTests/testSettingsScaleUpdatesPersistAndApplyToScene -only-testing:DockBarHeroTests/AppModelTests/testReceivedSettingsApplyAppearanceToConnectedScene test
```

Expected: FAIL because `RailAppearance`, scene method, and update methods do not exist.

- [ ] **Step 3: Implement scene appearance contract**

In `DockBarHero/Rendering/PrototypeSceneHost.swift`, add near `SceneControlling`:

```swift
struct RailAppearance: Equatable, Sendable {
    var actorScalePercent: Int
    var railTextScalePercent: Int

    static let defaults = RailAppearance(actorScalePercent: 100, railTextScalePercent: 100)
}
```

Add to `SceneControlling`:

```swift
func setAppearance(_ appearance: RailAppearance)
```

Add default extension:

```swift
func setAppearance(_ appearance: RailAppearance) { }
```

In `PrototypeSceneHost`, implement:

```swift
func setAppearance(_ appearance: RailAppearance) {
    scene.setAppearance(appearance)
}
```

- [ ] **Step 4: Implement AppModel updates**

In `DockBarHero/App/AppModel.swift`, add:

```swift
func updateActorScalePercent(_ percent: Int) {
    appSettings.actorScalePercent = min(max(percent, 75), 140)
    publishAppearanceSettings()
}

func updateRailTextScalePercent(_ percent: Int) {
    appSettings.railTextScalePercent = min(max(percent, 85), 130)
    publishAppearanceSettings()
}
```

Add helper:

```swift
private func publishAppearanceSettings() {
    applyAppearance()
    settingsController?.update(appSettings)
}

private func applyAppearance() {
    scene?.setAppearance(RailAppearance(
        actorScalePercent: appSettings.actorScalePercent,
        railTextScalePercent: appSettings.railTextScalePercent
    ))
}
```

Call `applyAppearance()` in `connect(...)` after setting handlers and in `receive(_ settings:)` after assigning `state`.

- [ ] **Step 5: Run AppModel tests to verify green**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/AppModelTests/testSettingsScaleUpdatesPersistAndApplyToScene -only-testing:DockBarHeroTests/AppModelTests/testReceivedSettingsApplyAppearanceToConnectedScene test
```

Expected: PASS.

---

### Task 3: Scale Actors in PrototypeScene

**Files:**
- Modify: `DockBarHero/Rendering/PrototypeScene.swift`
- Test: `DockBarHeroTests/PrototypeSceneHostTests.swift`

**Interfaces:**
- Consumes: `RailAppearance`
- Produces: `PrototypeScene.setAppearance(_ appearance: RailAppearance)`

- [ ] **Step 1: Write failing actor scale geometry test**

Add to `DockBarHeroTests/PrototypeSceneHostTests.swift`:

```swift
func testActorScaleResizesHeroesAndEnemyWithoutMovingFormationCenters() throws {
    let host = try PrototypeSceneHost(size: CGSize(width: 1_140, height: 96))
    var state = GameState.newGame(classID: .tank, balance: .standard, progression: .standard)
    let dps = GameState.newGame(classID: .dps, balance: .standard, progression: .standard).party.heroes[0]
    state.party = PartyState(heroes: [state.party.heroes[0], dps], unlocks: .secondUnlocked)
    host.render(.active(GameSimulation(state: state).presentation))

    let hero = try requiredNode("hero", in: host.scene, file: #filePath, line: #line)
    let second = try requiredNode("hero-1", in: host.scene, file: #filePath, line: #line)
    let enemy = try requiredNode("enemy", in: host.scene, file: #filePath, line: #line)
    let originalPositions = [hero.position, second.position, enemy.position]

    host.scene.setAppearance(RailAppearance(actorScalePercent: 125, railTextScalePercent: 100))

    XCTAssertEqual([hero.position, second.position, enemy.position], originalPositions)
    XCTAssertEqual(hero.frame.width, 67.5, accuracy: 0.001)
    XCTAssertEqual(second.frame.width, 67.5, accuracy: 0.001)
    XCTAssertEqual(enemy.frame.width, 67.5, accuracy: 0.001)
    XCTAssertFalse(hero.frame.intersects(second.frame))
}
```

- [ ] **Step 2: Run actor scale test to verify red**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/PrototypeSceneHostTests/testActorScaleResizesHeroesAndEnemyWithoutMovingFormationCenters test
```

Expected: FAIL because `setAppearance` is not implemented on `PrototypeScene` and actor sizes remain unscaled.

- [ ] **Step 3: Implement actor scaling**

In `DockBarHero/Rendering/PrototypeScene.swift`, add state:

```swift
private var appearance = RailAppearance.defaults
```

Add method:

```swift
func setAppearance(_ appearance: RailAppearance) {
    self.appearance = appearance
    updateLayout()
}
```

Add helper:

```swift
private var actorScale: CGFloat {
    CGFloat(appearance.actorScalePercent) / 100
}
```

In `updateLayout`, replace actor sizing:

```swift
let baseActorWidth = min(actorSize.width * actorScale, max(1, heroCellWidth - 12))
let renderedActorSize = CGSize(width: baseActorWidth, height: baseActorWidth / 1.5)
```

For the enemy, set its size too:

```swift
if let enemy = childNode(withName: "enemy") as? SKSpriteNode {
    let enemyWidth = actorSize.width * actorScale
    enemy.size = CGSize(width: enemyWidth, height: enemyWidth / 1.5)
    enemy.position = CGPoint(x: enemyX, y: 32)
}
```

Keep the existing `xScale = -1` for enemy orientation.

- [ ] **Step 4: Run actor scale test to verify green**

Run the same focused test.

Expected: PASS.

---

### Task 4: Scale Rail Text Without Breaking Collision Clamps

**Files:**
- Modify: `DockBarHero/Rendering/PrototypeScene.swift`
- Test: `DockBarHeroTests/PrototypeSceneHostTests.swift`

**Interfaces:**
- Consumes: `RailAppearance.railTextScalePercent`

- [ ] **Step 1: Write failing text scale tests**

Add to `DockBarHeroTests/PrototypeSceneHostTests.swift`:

```swift
func testRailTextScaleIncreasesDefaultLabelsAndOutlines() throws {
    let host = try PrototypeSceneHost(size: CGSize(width: 1_140, height: 96))

    host.scene.setAppearance(RailAppearance(actorScalePercent: 100, railTextScalePercent: 125))
    host.render(.active(GameSimulation().presentation))

    let heroLevel = try XCTUnwrap(host.scene.childNode(withName: "//heroLevel") as? SKLabelNode)
    let heroOutline = try XCTUnwrap(heroLevel.children.first as? SKLabelNode)
    let rollingDPS = try XCTUnwrap(host.scene.childNode(withName: "//rollingDPS") as? SKLabelNode)

    XCTAssertEqual(heroLevel.fontSize, 15, accuracy: 0.001)
    XCTAssertEqual(heroOutline.fontSize, heroLevel.fontSize, accuracy: 0.001)
    XCTAssertEqual(rollingDPS.fontSize, 15, accuracy: 0.001)
}

func testRailTextScaleStillClampsNarrowEnemyLabelsToLane() throws {
    let host = try PrototypeSceneHost(size: CGSize(width: 400, height: 96))
    var state = GameState.newGame(balance: .standard)
    state.campaign.highestUnlockedLevel = 100
    state.campaign.selectedLevel = 74
    state.campaign.mode = .farming
    state.encounter.enemyLevel = 74
    state.encounter.tier = .normal
    var presentation = GameSimulation(state: state).presentation
    presentation.campaign = nil

    host.scene.setAppearance(RailAppearance(actorScalePercent: 100, railTextScalePercent: 130))
    host.render(.active(presentation))

    let level = try XCTUnwrap(host.scene.childNode(withName: "//enemyLevel") as? SKLabelNode)
    let status = try XCTUnwrap(host.scene.childNode(withName: "//farmingStatus") as? SKLabelNode)

    XCTAssertGreaterThanOrEqual(level.fontSize, 8)
    XCTAssertGreaterThanOrEqual(status.fontSize, 8)
    XCTAssertLessThanOrEqual(level.frame.maxX, 392.5)
    XCTAssertLessThanOrEqual(status.frame.maxX, 392.5)
    XCTAssertFalse(level.frame.intersects(status.frame))
}
```

- [ ] **Step 2: Run text scale tests to verify red**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/PrototypeSceneHostTests/testRailTextScaleIncreasesDefaultLabelsAndOutlines -only-testing:DockBarHeroTests/PrototypeSceneHostTests/testRailTextScaleStillClampsNarrowEnemyLabelsToLane test
```

Expected: FAIL because text scale is not applied.

- [ ] **Step 3: Implement text scaling helpers**

In `PrototypeScene`, add:

```swift
private var textScale: CGFloat {
    CGFloat(appearance.railTextScalePercent) / 100
}

private func scaledFontSize(_ base: CGFloat) -> CGFloat {
    base * textScale
}
```

In `updateLayout`, replace hard-coded layout font assignments:

```swift
level.fontSize = usesCompactHeroLabels ? scaledFontSize(8) : scaledFontSize(12)
action.fontSize = usesCompactHeroLabels ? scaledFontSize(8) : scaledFontSize(10)
```

For enemy labels in `layoutEnemyLabels`, replace base maxima:

```swift
let maximumFontSize: CGFloat = if showsAuthoredFarming {
    scaledFontSize(10)
} else if showsFarming {
    scaledFontSize(12)
} else {
    scaledFontSize(12)
}
```

Preserve `max(8, ...)` clamps in `fitLabelToWidth`.

Set `rollingDPS` in `updateLayout`:

```swift
(childNode(withName: "rollingDPS") as? SKLabelNode)?.fontSize = scaledFontSize(12)
```

Set area title in `updateLayout`:

```swift
(childNode(withName: "//areaTitle") as? SKLabelNode)?.fontSize = scaledFontSize(10)
```

Call `setOutlinedText(label.text, on: label)` after changing any label font size so outline children stay synchronized.

- [ ] **Step 4: Run text scale tests to verify green**

Run the focused text tests again.

Expected: PASS.

- [ ] **Step 5: Run scene geometry suite**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/PrototypeSceneHostTests test
```

Expected: PASS. Existing tests that assert exact font size should be updated only if they fail because the new default path still produces the same size at `100%`.

---

### Task 5: Add Settings UI Controls

**Files:**
- Modify: `DockBarHero/App/SettingsView.swift`
- Test: `DockBarHeroTests/AppModelTests.swift`

**Interfaces:**
- Consumes: `AppModel.updateActorScalePercent(_:)`
- Consumes: `AppModel.updateRailTextScalePercent(_:)`

- [ ] **Step 1: Add model clamping tests if not already covered**

If Task 2 did not assert clamping, add:

```swift
func testSettingsScaleUpdatesClampToSupportedRanges() {
    let settings = FakeSettingsController(initial: .defaults)
    let model = makeModel(settingsController: settings)
    settings.resolve()

    model.updateActorScalePercent(200)
    model.updateRailTextScalePercent(10)

    XCTAssertEqual(model.appSettings.actorScalePercent, 140)
    XCTAssertEqual(model.appSettings.railTextScalePercent, 85)
}
```

Run it and verify red before implementation if clamping is missing.

- [ ] **Step 2: Add `Rail Appearance` Settings section**

In `DockBarHero/App/SettingsView.swift`, insert before `LoreSettingsSection(model: model)`:

```swift
Section("Rail Appearance") {
    VStack(alignment: .leading, spacing: 6) {
        HStack {
            Text("Actor scale")
            Spacer()
            Text("\(model.appSettings.actorScalePercent)%")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        Slider(
            value: Binding(
                get: { Double(model.appSettings.actorScalePercent) },
                set: { model.updateActorScalePercent(Int($0.rounded())) }
            ),
            in: 75...140,
            step: 5
        )
    }

    VStack(alignment: .leading, spacing: 6) {
        HStack {
            Text("Rail text scale")
            Spacer()
            Text("\(model.appSettings.railTextScalePercent)%")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        Slider(
            value: Binding(
                get: { Double(model.appSettings.railTextScalePercent) },
                set: { model.updateRailTextScalePercent(Int($0.rounded())) }
            ),
            in: 85...130,
            step: 5
        )
    }
}
```

No explanatory copy is needed in-app; labels and percent values are enough.

- [ ] **Step 3: Run settings/app tests**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/AppModelTests -only-testing:DockBarHeroTests/SettingsSessionTests -only-testing:DockBarHeroTests/SettingsStoreTests -only-testing:DockBarHeroTests/AppSettingsMigrationTests test
```

Expected: PASS.

---

### Task 6: Final Verification and Backlog Update

**Files:**
- Modify: `BACKLOG.md`

**Interfaces:**
- Consumes: all prior tasks.
- Produces: verified implementation record only; do not mark owner acceptance complete without manual approval.

- [ ] **Step 1: Run focused full verification**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/PrototypeSceneHostTests -only-testing:DockBarHeroTests/AppModelTests -only-testing:DockBarHeroTests/SettingsSessionTests -only-testing:DockBarHeroTests/SettingsStoreTests -only-testing:DockBarHeroTests/AppSettingsMigrationTests test
```

Expected: PASS.

- [ ] **Step 2: Run canonical build/launch**

Run:

```bash
./script/build_and_run.sh --verify --fast
```

Expected: `** BUILD SUCCEEDED **` and `DockBarHero launched`.

- [ ] **Step 3: Run hygiene checks**

Run:

```bash
git diff --check
wc -l AGENTS.md PROJECT.md BACKLOG.md
git status --short
```

Expected:
- `git diff --check` has no output.
- `AGENTS.md` remains at or below 100 lines.
- `PROJECT.md` remains at or below 150 lines.
- `BACKLOG.md` can exceed those caps; it is the product backlog.

- [ ] **Step 4: Update backlog**

Add an implementation record to `BACKLOG.md` under `B1. Tighten the party formation` or a new `B4. Rail appearance scaling` if the backlog has been split by then:

```markdown
**Implementation record:** Added persisted Settings controls for Actor Scale and Rail Text Scale. Actor scale changes hero and enemy sprite sizes from 75% to 140% without changing combat state or health-bar sizing. Rail text scale changes rail labels from 85% to 130% while preserving existing narrow-lane collision clamps. Red/green coverage includes settings migration/validation, AppModel persistence and live scene application, actor-size geometry, and text-size clamping. Focused settings and scene tests passed, and the canonical verify build launched. Owner visual acceptance is still pending.
```

Do not mark acceptance checkboxes complete until the owner manually approves the live look.

- [ ] **Step 5: Final status**

Report:
- Files changed.
- Exact tests run and pass counts where available.
- Manual visual acceptance still pending.
- No push performed.

