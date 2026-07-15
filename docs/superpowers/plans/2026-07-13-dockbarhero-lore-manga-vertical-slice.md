# DockBarHero Lore Manga Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a native macOS manga reader vertical slice containing the dishonest Level 100,000 prologue, Volume I pages through Level 20, final four-frame artwork for every included page, independent language/adult-art controls, and opt-in Book-open-only TTS with the reversed giggling volume potentiometer.

**Architecture:** Add a validated bundled lore catalog and separate spoken-dialogue catalog under a focused `Lore` feature folder. A pure progress resolver derives page availability from the existing frontier, while a MainActor reader controller owns page selection, Book lifecycle, interaction reactions, and provider-neutral speech. SwiftUI renders a responsive right-to-left Book route inside the existing management window; all story art is stored as final 2x2 four-frame sprite sheets and sliced at runtime.

**Tech Stack:** Swift 6, SwiftUI, AppKit, AVFAudio/`AVSpeechSynthesizer`, Codable JSON resources, XCTest, XcodeGen, SpriteKit-independent raster sprite sheets generated with the built-in image-generation tool.

## Global Constraints

- Target macOS 26.0, Apple Silicon arm64, Swift 6, and complete strict concurrency.
- Preserve the menu-bar accessory policy, accepted management-window behavior, passive rail, deterministic simulation, schema-v2 game saves, farming/frontier separation, and all unrelated user changes.
- Lore is read-only presentation. It cannot pause combat, change simulation time, mutate rewards, or create a second frontier ledger.
- This slice stops at the Level 20 page. Boss 25 and the Legendary Hero Containment Crate remain hidden until the Heroes and Party gate can provide the real second-hero choice.
- Include final safe four-frame sprite sheets for the prologue and Levels 1, 5, 10, 15, and 20. Include one final adult alternate for Level 20 to prove the independent illustration mode. No placeholder art may ship.
- Every sprite sheet is a 1024x1024 PNG arranged as four equal 512x512 quadrants in reading order: top-left, top-right, bottom-left, bottom-right.
- Spoken dialogue defaults off, plays only while the Book is visibly open and the application active, and stops immediately when the Book closes or loses focus.
- The Book potentiometer has detents `0...10`; `0` maps to gain `1.0`, `10` maps to gain `0.1`, and moving it replaces the previous preview with a Book giggle at the new gain.
- Unfiltered language defaults on. Clean text is separately authored. Safe art defaults on. Adult art requires explicit confirmation.
- All central and adult-art characters are unambiguously adults. Adult art may include non-explicit nudity or suggestive comedy, but no sexual acts, coercion, sexual violence, minors, or youthful-looking subjects.
- Visual volume deception never applies to accessibility: VoiceOver announces the effective percentage and that lower numbers are louder.
- Required catalog text and safe art fail closed with a clear diagnostic. Optional adult art and animation fall back to safe static presentation.
- Use built-in image generation for final raster assets and copy every selected output into the repository.
- Use TDD for code tasks and make one focused commit per independently reviewable task.

---

## File Structure

### New production files

- `DockBarHero/Lore/LoreModels.swift`: stable identifiers and Codable catalog value types.
- `DockBarHero/Lore/LoreCatalog.swift`: bundled JSON loading and catalog validation.
- `DockBarHero/Lore/LoreProgressResolver.swift`: pure frontier-to-page availability rules.
- `DockBarHero/Lore/SpokenDialogueCatalog.swift`: speaker/cue loading, clean-line validation, and cue resolution.
- `DockBarHero/Lore/LoreSpeechService.swift`: speech protocol and `AVSpeechSynthesizer` implementation.
- `DockBarHero/Lore/LoreReaderController.swift`: Book lifecycle, selection, reactions, replay, and speech queue ownership.
- `DockBarHero/Lore/LoreSpriteSheet.swift`: bundle image loading and four-quadrant frame extraction.
- `DockBarHero/Lore/LoreBookView.swift`: responsive right-to-left Book composition.
- `DockBarHero/Lore/LorePageView.swift`: page text, speech bubbles, and animated illustration.
- `DockBarHero/Lore/BookVolumePotentiometer.swift`: reversed rotary control and accessible adjustment.
- `DockBarHero/Lore/LoreSettingsSection.swift`: language, illustration, speech, and adult confirmation controls.
- `DockBarHero/Lore/Resources/LoreCatalog.json`: prologue and Volume I page definitions.
- `DockBarHero/Lore/Resources/SpokenDialogue.json`: all recurring speaker profiles, included page cues, and Book interaction cues.
- `DockBarHero/Lore/Resources/Images/*.png`: seven final sprite sheets.

### New tests

- `DockBarHeroTests/AppSettingsMigrationTests.swift`
- `DockBarHeroTests/LoreCatalogTests.swift`
- `DockBarHeroTests/LoreProgressResolverTests.swift`
- `DockBarHeroTests/SpokenDialogueCatalogTests.swift`
- `DockBarHeroTests/LoreReaderControllerTests.swift`
- `DockBarHeroTests/LoreSpriteSheetTests.swift`
- `DockBarHeroTests/BookVolumePotentiometerTests.swift`

### Existing files to modify

- `DockBarHero/Settings/AppSettings.swift`: settings schema v2 and v1 migration.
- `DockBarHero/Settings/SettingsStore.swift`: v2 filenames and legacy-v1 discovery.
- `DockBarHero/App/AppModel.swift`: published settings, reader-controller integration, and lore-setting actions.
- `DockBarHero/App/AppDelegate.swift`: construct lore dependencies and close speech with the management window.
- `DockBarHero/App/ManagementRoute.swift`: stable `.book` route.
- `DockBarHero/App/ManagementRootView.swift`: present `LoreBookView`.
- `DockBarHero/App/SettingsView.swift`: embed `LoreSettingsSection`.
- `DockBarHeroTests/SettingsStoreTests.swift`: current filenames and deterministic v2 JSON.
- `DockBarHeroTests/SettingsSessionTests.swift`: v2 settings fixtures.
- `DockBarHeroTests/AppModelTests.swift`: lore settings and New Game reader reset.
- `DockBarHeroTests/ManagementNavigationTests.swift`: Book route order, title, symbol, and ID.
- `PROJECT.md`: update only after the integrated milestone is freshly verified.

---

### Task 1: Versioned Lore Presentation Settings

**Files:**

- Create: `DockBarHeroTests/AppSettingsMigrationTests.swift`
- Modify: `DockBarHero/Settings/AppSettings.swift`
- Modify: `DockBarHero/Settings/SettingsStore.swift`
- Modify: `DockBarHeroTests/SettingsStoreTests.swift`
- Modify: `DockBarHeroTests/SettingsSessionTests.swift`

**Interfaces:**

- Produces: `LoreLanguageMode`, `LoreIllustrationMode`, and schema-v2 `AppSettings` with `spokenDialogueEnabled`, `bookVolumeDetent`, `autoReadNewLorePages`, `hasSeenCurrentRunPrologue`, and `lastAutoReadLorePageID`.
- Produces: `BookVolumeMapping.gain(for:)` and `AppSettings.bookOutputGain` after validating `0...10`.
- Consumes: existing overlay settings and atomic `SettingsStore` semantics.

- [ ] **Step 1: Write failing migration and volume tests**

```swift
import XCTest
@testable import DockBarHero

final class AppSettingsMigrationTests: XCTestCase {
    func testV1MigratesToV2LoreDefaults() throws {
        let data = Data(#"{"animationMode":"paused","inputMode":"interactive","manualVisibility":"hidden","schemaVersion":1}"#.utf8)
        let settings = try SettingsCodec().decode(data)

        XCTAssertEqual(settings.schemaVersion, 2)
        XCTAssertEqual(settings.manualVisibility, .hidden)
        XCTAssertEqual(settings.animationMode, .paused)
        XCTAssertEqual(settings.inputMode, .interactive)
        XCTAssertEqual(settings.loreLanguageMode, .unfiltered)
        XCTAssertEqual(settings.loreIllustrationMode, .safe)
        XCTAssertFalse(settings.spokenDialogueEnabled)
        XCTAssertEqual(settings.bookVolumeDetent, 5)
        XCTAssertTrue(settings.autoReadNewLorePages)
        XCTAssertFalse(settings.hasSeenCurrentRunPrologue)
        XCTAssertNil(settings.lastAutoReadLorePageID)
    }

    func testReversedVolumeEndpoints() {
        var settings = AppSettings.defaults
        settings.bookVolumeDetent = 0
        XCTAssertEqual(settings.bookOutputGain, 1.0, accuracy: 0.000_1)
        settings.bookVolumeDetent = 10
        XCTAssertEqual(settings.bookOutputGain, 0.1, accuracy: 0.000_1)
    }

    func testCodecRejectsOutOfRangeDetent() throws {
        let data = Data(#"{"animationMode":"running","autoReadNewLorePages":true,"bookVolumeDetent":11,"hasSeenCurrentRunPrologue":false,"inputMode":"passive","loreIllustrationMode":"safe","loreLanguageMode":"unfiltered","manualVisibility":"shown","schemaVersion":2,"spokenDialogueEnabled":false}"#.utf8)
        XCTAssertThrowsError(try SettingsCodec().decode(data))
    }
}
```

- [ ] **Step 2: Run the focused test and confirm the red state**

Run:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/AppSettingsMigrationTests
```

Expected: FAIL because schema-v2 lore fields and migration do not exist.

- [ ] **Step 3: Implement schema v2 and explicit v1 decoding**

```swift
enum LoreLanguageMode: String, Codable, CaseIterable, Sendable { case unfiltered, clean }
enum LoreIllustrationMode: String, Codable, CaseIterable, Sendable { case safe, adult }

enum BookVolumeMapping {
    static func gain(for detent: Int) -> Float {
        Float(1.0 - 0.09 * Double(min(max(detent, 0), 10)))
    }

    static func accessibilityValue(for detent: Int) -> String {
        "\(Int((gain(for: detent) * 100).rounded())) percent, lower numbers are louder"
    }
}

struct AppSettings: Codable, Equatable, Sendable {
    static let currentVersion = 2

    let schemaVersion: Int
    var manualVisibility: ManualVisibility
    var animationMode: AnimationMode
    var inputMode: InputMode
    var loreLanguageMode: LoreLanguageMode
    var loreIllustrationMode: LoreIllustrationMode
    var spokenDialogueEnabled: Bool
    var bookVolumeDetent: Int
    var autoReadNewLorePages: Bool
    var hasSeenCurrentRunPrologue: Bool
    var lastAutoReadLorePageID: String?

    var bookOutputGain: Float {
        BookVolumeMapping.gain(for: bookVolumeDetent)
    }

    static let defaults = AppSettings(
        schemaVersion: currentVersion,
        manualVisibility: .shown,
        animationMode: .running,
        inputMode: .passive,
        loreLanguageMode: .unfiltered,
        loreIllustrationMode: .safe,
        spokenDialogueEnabled: false,
        bookVolumeDetent: 5,
        autoReadNewLorePages: true,
        hasSeenCurrentRunPrologue: false,
        lastAutoReadLorePageID: nil
    )
}
```

`SettingsCodec.decode` must inspect the header, decode a private `LegacyV1Settings` for version 1, return schema-v2 defaults for new fields, decode `AppSettings` for version 2, reject other versions, and reject a v2 detent outside `0...10`.

- [ ] **Step 4: Change current settings paths to v2 and migrate legacy v1**

```swift
struct SettingsURLs: Sendable {
    let directory: URL
    let primary: URL
    let backup: URL
    let temporary: URL
    let legacyV1Primary: URL
    let legacyV1Backup: URL

    init(directory: URL) {
        self.directory = directory
        primary = directory.appendingPathComponent("settings-v2.json")
        backup = directory.appendingPathComponent("settings-v2.backup.json")
        temporary = directory.appendingPathComponent("settings-v2.pending.json")
        legacyV1Primary = directory.appendingPathComponent("settings-v1.json")
        legacyV1Backup = directory.appendingPathComponent("settings-v1.backup.json")
    }
}
```

`SettingsStore.load()` must try v2 primary, v2 backup, v1 primary, and v1 backup in that order. A valid v1 decode is saved immediately as v2 before being returned. Invalid files are quarantined under their original filename and game-save files remain untouched.

- [ ] **Step 5: Update deterministic settings fixtures and pass focused tests**

Run:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/AppSettingsMigrationTests -only-testing:DockBarHeroTests/SettingsStoreTests -only-testing:DockBarHeroTests/SettingsSessionTests
```

Expected: all selected tests pass with settings-v2 filenames and sorted JSON.

- [ ] **Step 6: Commit**

```bash
git add DockBarHero/Settings DockBarHeroTests/AppSettingsMigrationTests.swift DockBarHeroTests/SettingsStoreTests.swift DockBarHeroTests/SettingsSessionTests.swift
git commit -m "feat: add lore presentation settings"
```

---

### Task 2: Validated Lore Catalog and Frontier Unlocks

**Files:**

- Create: `DockBarHero/Lore/LoreModels.swift`
- Create: `DockBarHero/Lore/LoreCatalog.swift`
- Create: `DockBarHero/Lore/LoreProgressResolver.swift`
- Create: `DockBarHero/Lore/Resources/LoreCatalog.json`
- Create: `DockBarHeroTests/LoreCatalogTests.swift`
- Create: `DockBarHeroTests/LoreProgressResolverTests.swift`

**Interfaces:**

- Produces: `LorePageID`, `LorePageDefinition`, `LoreCatalog`, `ResolvedLorePage`, and `LoreProgressResolver.resolve(catalog:highestUnlockedLevel:languageMode:illustrationMode:)`.
- Produces page IDs: `prologue.level-100000`, `volume-1.level-1`, `volume-1.level-5`, `volume-1.level-10`, `volume-1.level-15`, and `volume-1.level-20`.
- Consumes: `CampaignState.highestUnlockedLevel` and the Task 1 language/art enums.

- [ ] **Step 1: Write failing catalog and unlock tests**

```swift
import XCTest
@testable import DockBarHero

final class LoreProgressResolverTests: XCTestCase {
    func testFrontierUnlocksOnlyCompletedMilestones() throws {
        let catalog = try makeCatalog()
        let atLevelOne = LoreProgressResolver.resolve(
            catalog: catalog,
            highestUnlockedLevel: 1,
            languageMode: .unfiltered,
            illustrationMode: .safe
        )
        XCTAssertEqual(atLevelOne.map(\.id.rawValue), ["prologue.level-100000", "volume-1.level-1"])

        let afterLevelTen = LoreProgressResolver.resolve(
            catalog: catalog,
            highestUnlockedLevel: 11,
            languageMode: .clean,
            illustrationMode: .safe
        )
        XCTAssertEqual(afterLevelTen.map(\.id.rawValue), [
            "prologue.level-100000", "volume-1.level-1", "volume-1.level-5", "volume-1.level-10"
        ])
        XCTAssertTrue(afterLevelTen.allSatisfy { !$0.body.contains("fuck") })
    }

    func testLevelTwentyAdultModeUsesAlternateWhenPresent() throws {
        let catalog = try makeCatalog()
        let pages = LoreProgressResolver.resolve(
            catalog: catalog,
            highestUnlockedLevel: 21,
            languageMode: .unfiltered,
            illustrationMode: .adult
        )
        XCTAssertEqual(pages.last?.spriteSheetName, "volume1-level20-adult")
    }
}

private func makeCatalog() throws -> LoreCatalog {
    func page(_ id: String, index: Int, unlock: Int?, adult: String? = nil) -> LorePageDefinition {
        LorePageDefinition(
            id: LorePageID(rawValue: id),
            sortIndex: index,
            title: LoreTextVariants(unfiltered: id, clean: id),
            body: LoreTextVariants(
                unfiltered: id == "prologue.level-100000" ? "fuck" : id,
                clean: id
            ),
            unlockAfterVictoryLevel: unlock,
            art: LoreArtVariants(
                safeSpriteSheet: "\(id)-safe",
                adultSpriteSheet: adult,
                accessibilitySafe: id,
                accessibilityAdult: adult == nil ? nil : id
            ),
            dialogueCueIDs: [],
            frameCount: 4,
            frameDurationMilliseconds: 600
        )
    }
    return try LoreCatalog.validated(LoreCatalog(schemaVersion: 1, pages: [
        page("prologue.level-100000", index: 0, unlock: nil),
        page("volume-1.level-1", index: 1, unlock: nil),
        page("volume-1.level-5", index: 2, unlock: 5),
        page("volume-1.level-10", index: 3, unlock: 10),
        page("volume-1.level-20", index: 4, unlock: 20, adult: "volume1-level20-adult")
    ]))
}
```

`LoreCatalogTests` must reject duplicate page IDs, nonascending sort indices, missing clean text, missing safe sheets, invalid unlock requirements, and sprite descriptors other than exactly four frames for this slice.

- [ ] **Step 2: Run focused tests and confirm the red state**

Run:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreCatalogTests -only-testing:DockBarHeroTests/LoreProgressResolverTests
```

Expected: FAIL because the lore types and bundled catalog do not exist.

- [ ] **Step 3: Implement focused Codable models**

```swift
struct LorePageID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String
}

struct LoreTextVariants: Codable, Equatable, Sendable {
    let unfiltered: String
    let clean: String
}

struct LoreArtVariants: Codable, Equatable, Sendable {
    let safeSpriteSheet: String
    let adultSpriteSheet: String?
    let accessibilitySafe: String
    let accessibilityAdult: String?
}

struct LorePageDefinition: Codable, Equatable, Sendable {
    let id: LorePageID
    let sortIndex: Int
    let title: LoreTextVariants
    let body: LoreTextVariants
    let unlockAfterVictoryLevel: Int?
    let art: LoreArtVariants
    let dialogueCueIDs: [String]
    let frameCount: Int
    let frameDurationMilliseconds: Int
}

struct LoreCatalog: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let pages: [LorePageDefinition]
}

struct ResolvedLorePage: Identifiable, Equatable, Sendable {
    let id: LorePageID
    let title: String
    let body: String
    let spriteSheetName: String
    let accessibilityDescription: String
    let dialogueCueIDs: [String]
    let frameCount: Int
    let frameDurationMilliseconds: Int
}
```

- [ ] **Step 4: Implement strict loading, validation, and resolution**

`LoreCatalog.bundled(bundle:)` loads `LoreCatalog.json`, validates schema version 1, stable unique IDs, ascending sort order, required text, safe asset name, `frameCount == 4`, positive duration, and page unlock rules. `LoreProgressResolver` always includes the prologue, includes Level 1 at frontier 1, and includes a milestone page only when `highestUnlockedLevel > unlockAfterVictoryLevel`.

- [ ] **Step 5: Author the six-page JSON catalog**

The bundled JSON must use these exact entries and no Boss 25 content:

```json
{
  "schemaVersion": 1,
  "pages": [
    {"id":"prologue.level-100000","sortIndex":0,"unlockAfterVictoryLevel":null,"frameCount":4,"frameDurationMilliseconds":700,"dialogueCueIDs":["prologue.book.wrong-way","prologue.book.arrow-denial"],"art":{"safeSpriteSheet":"prologue-level100000-safe","adultSpriteSheet":null,"accessibilitySafe":"Three unknown adult heroes face an impossible final boss while Pope Kevin raises a union banner.","accessibilityAdult":null},"title":{"unfiltered":"Level 100,000: The Finaler Ending","clean":"Level 100,000: The Finaler Ending"},"body":{"unfiltered":"The moon filed for divorce. Kevin unionized Heaven. Somehow, this was your fault.","clean":"The moon filed for divorce. Kevin unionized Heaven. Somehow, this was your fault."}},
    {"id":"volume-1.level-1","sortIndex":1,"unlockAfterVictoryLevel":null,"frameCount":4,"frameDurationMilliseconds":650,"dialogueCueIDs":["book.level1.summary","kevin.not-kevin"],"art":{"safeSpriteSheet":"volume1-level1-safe","adultSpriteSheet":null,"accessibilitySafe":"A magical summoning circle selects an obscured adult hero while a goblin intern checks the wrong form.","accessibilityAdult":null},"title":{"unfiltered":"Four Minutes Earlier","clean":"Four Minutes Earlier"},"body":{"unfiltered":"The Book requested a qualified hero, found none, and clicked Show Similar Results.","clean":"The Book requested a qualified hero, found none, and clicked Show Similar Results."}},
    {"id":"volume-1.level-5","sortIndex":2,"unlockAfterVictoryLevel":5,"frameCount":4,"frameDurationMilliseconds":600,"dialogueCueIDs":["book.level5.summary","kevin.supervisor"],"art":{"safeSpriteSheet":"volume1-level5-safe","adultSpriteSheet":null,"accessibilitySafe":"Kevin's enormous goblin supervisor brandishes an employee handbook while Kevin's fake mustache slips.","accessibilityAdult":null},"title":{"unfiltered":"Kevin's Supervisor","clean":"Kevin's Supervisor"},"body":{"unfiltered":"Kevin died. This is a different goblin with the same badge, voice, debts, and emergency contact.","clean":"Kevin departed. This is a different goblin with the same badge, voice, debts, and emergency contact."}},
    {"id":"volume-1.level-10","sortIndex":3,"unlockAfterVictoryLevel":10,"frameCount":4,"frameDurationMilliseconds":550,"dialogueCueIDs":["book.level10.summary"],"art":{"safeSpriteSheet":"volume1-level10-safe","adultSpriteSheet":null,"accessibilitySafe":"One treasure-chest mimic poorly disguises itself as another treasure-chest mimic.","accessibilityAdult":null},"title":{"unfiltered":"The Double Mimic","clean":"The Double Mimic"},"body":{"unfiltered":"The chest was a mimic. Inside it was another mimic pretending to be loot. Neither could stop giggling.","clean":"The chest was a mimic. Inside it was another mimic pretending to be loot. Neither could stop giggling."}},
    {"id":"volume-1.level-15","sortIndex":4,"unlockAfterVictoryLevel":15,"frameCount":4,"frameDurationMilliseconds":625,"dialogueCueIDs":["book.level15.summary","brick.policy-warning"],"art":{"safeSpriteSheet":"volume1-level15-safe","adultSpriteSheet":null,"accessibilitySafe":"A necromancer raises paper complaint forms while irritated skeletons return incomplete surveys.","accessibilityAdult":null},"title":{"unfiltered":"The Necromancer of Negative Feedback","clean":"The Necromancer of Negative Feedback"},"body":{"unfiltered":"He could raise the dead, but only to ask whether they were satisfied with their service.","clean":"He could raise the dead, but only to ask whether they were satisfied with their service."}},
    {"id":"volume-1.level-20","sortIndex":5,"unlockAfterVictoryLevel":20,"frameCount":4,"frameDurationMilliseconds":700,"dialogueCueIDs":["book.level20.summary","mercy.therapy-referral"],"art":{"safeSpriteSheet":"volume1-level20-safe","adultSpriteSheet":"volume1-level20-adult","accessibilitySafe":"An unambiguously adult demon in modest clothing lies on a tiny therapy couch while an abomination takes notes.","accessibilityAdult":"An unambiguously adult topless demon, framed non-explicitly, lies on a tiny therapy couch while an abomination takes notes."},"title":{"unfiltered":"Emotional-Support Abomination","clean":"Emotional-Support Abomination"},"body":{"unfiltered":"A cursed crown is not a substitute for therapy, sleep, boundaries, or properly supervised medication.","clean":"A cursed crown is not a substitute for therapy, sleep, boundaries, or properly supervised medication."}}
  ]
}
```

- [ ] **Step 6: Generate the project and pass focused tests**

Run:

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreCatalogTests -only-testing:DockBarHeroTests/LoreProgressResolverTests
```

Expected: selected tests pass and the JSON appears in Copy Bundle Resources.

- [ ] **Step 7: Commit**

```bash
git add DockBarHero/Lore DockBarHeroTests/LoreCatalogTests.swift DockBarHeroTests/LoreProgressResolverTests.swift DockBarHero.xcodeproj
git commit -m "feat: add validated lore catalog"
```

---

### Task 3: Spoken Dialogue Catalog and Book-Scoped TTS

**Files:**

- Create: `DockBarHero/Lore/SpokenDialogueCatalog.swift`
- Create: `DockBarHero/Lore/LoreSpeechService.swift`
- Create: `DockBarHero/Lore/LoreReaderController.swift`
- Create: `DockBarHero/Lore/Resources/SpokenDialogue.json`
- Create: `DockBarHeroTests/SpokenDialogueCatalogTests.swift`
- Create: `DockBarHeroTests/LoreReaderControllerTests.swift`

**Interfaces:**

- Produces: `SpokenDialogueCatalog.resolve(cueID:languageMode:) -> ResolvedDialogueCue?`.
- Produces: `@MainActor protocol LoreSpeechControlling` with `speak(_:gain:)`, `stop()`, and `previewGiggle(_:gain:)`.
- Produces: `@MainActor protocol LoreReaderControlling` and `LoreReaderController` with `open`, `close`, `applicationBecameInactive`, `select`, `replay`, `skip`, and `previewVolume`.
- Consumes: Task 1 settings and Task 2 resolved pages.

- [ ] **Step 1: Write failing catalog and lifecycle tests**

```swift
@MainActor
final class LoreReaderControllerTests: XCTestCase {
    func testSpeechNeverStartsWhileBookClosed() throws {
        let speech = LoreSpeechFake()
        let controller = try makeController(speech: speech)
        controller.update(settings: .spokenFixture, pages: [.fixture])

        controller.replay()

        XCTAssertTrue(speech.spoken.isEmpty)
    }

    func testClosingBookStopsAndClearsSpeech() throws {
        let speech = LoreSpeechFake()
        let controller = try makeController(speech: speech)
        controller.update(settings: .spokenFixture, pages: [.fixture])
        controller.open()
        controller.replay()

        controller.close()

        XCTAssertEqual(speech.stopCount, 1)
        XCTAssertFalse(controller.isOpen)
    }

    func testVolumePreviewUsesReversedGainAndReplacesPreview() throws {
        let speech = LoreSpeechFake()
        let controller = try makeController(speech: speech)
        controller.update(settings: .spokenFixture, pages: [.fixture])
        controller.open()

        controller.previewVolume(detent: 0)
        controller.previewVolume(detent: 10)

        XCTAssertEqual(speech.previews.map(\.gain), [1.0, 0.1])
        XCTAssertEqual(speech.stopPreviewCount, 2)
    }
}

@MainActor
private final class LoreSpeechFake: LoreSpeechControlling {
    var spoken: [ResolvedDialogueCue] = []
    var previews: [(text: String, gain: Float)] = []
    var stopCount = 0
    var stopPreviewCount = 0

    func speak(_ cue: ResolvedDialogueCue, gain: Float) { spoken.append(cue) }
    func stop() { stopCount += 1 }
    func stopPreview() { stopPreviewCount += 1 }
    func previewGiggle(_ text: String, gain: Float) { previews.append((text, gain)) }
}

@MainActor
private func makeController(speech: LoreSpeechControlling) throws -> LoreReaderController {
    let speaker = DialogueSpeaker(
        id: "book", displayName: "Book", rate: 0.45, pitch: 0.9,
        preferredVoiceTraits: ["theatrical"]
    )
    let cue = DialogueCue(
        id: "book.test", speakerID: "book", unfiltered: "Test.", clean: "Test.",
        delivery: "flat", autoReadEligible: true
    )
    let catalog = try SpokenDialogueCatalog.validated(
        SpokenDialogueCatalog(schemaVersion: 1, speakers: [speaker], cues: [cue])
    )
    return LoreReaderController(dialogue: catalog, speech: speech)
}

private extension AppSettings {
    static var spokenFixture: AppSettings {
        var value = defaults
        value.spokenDialogueEnabled = true
        return value
    }
}

private extension ResolvedLorePage {
    static let fixture = ResolvedLorePage(
        id: LorePageID(rawValue: "test"), title: "Test", body: "Test",
        spriteSheetName: "test", accessibilityDescription: "Test",
        dialogueCueIDs: ["book.test"], frameCount: 4, frameDurationMilliseconds: 600
    )
}
```

`SpokenDialogueCatalogTests` must verify unique speaker/cue IDs, every cue's speaker exists, both language variants are nonempty, all lore cue references resolve, and clean mode never returns the prologue profanity.

- [ ] **Step 2: Run focused tests and confirm the red state**

Run:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/SpokenDialogueCatalogTests -only-testing:DockBarHeroTests/LoreReaderControllerTests
```

Expected: FAIL because dialogue and speech types do not exist.

- [ ] **Step 3: Implement dialogue models and strict resolution**

```swift
struct DialogueSpeaker: Codable, Equatable, Sendable {
    let id: String
    let displayName: String
    let rate: Float
    let pitch: Float
    let preferredVoiceTraits: [String]
}

struct DialogueCue: Codable, Equatable, Sendable {
    let id: String
    let speakerID: String
    let unfiltered: String
    let clean: String
    let delivery: String
    let autoReadEligible: Bool
}

struct ResolvedDialogueCue: Equatable, Sendable {
    let id: String
    let speaker: DialogueSpeaker
    let text: String
    let delivery: String
}
```

The bundled catalog registers Book, Brick, Kaizen, Mercy, Kevin, and Editor profiles even when a slice page does not yet use every voice.

- [ ] **Step 4: Implement provider-neutral speech and the system adapter**

```swift
@MainActor
protocol LoreSpeechControlling: AnyObject {
    func speak(_ cue: ResolvedDialogueCue, gain: Float)
    func stop()
    func stopPreview()
    func previewGiggle(_ text: String, gain: Float)
}

@MainActor
protocol LoreReaderControlling: AnyObject {
    func update(settings: AppSettings, pages: [ResolvedLorePage])
    func open()
    func close()
    func applicationBecameInactive()
    func select(_ pageID: LorePageID)
    func replay()
    func skip()
    func previewVolume(detent: Int)
}

@MainActor
final class SystemLoreSpeechService: NSObject, LoreSpeechControlling {
    private let synthesizer = AVSpeechSynthesizer()
    private let previewSynthesizer = AVSpeechSynthesizer()

    func speak(_ cue: ResolvedDialogueCue, gain: Float) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: cue.text)
        utterance.rate = cue.speaker.rate
        utterance.pitchMultiplier = cue.speaker.pitch
        utterance.volume = gain
        synthesizer.speak(utterance)
    }

    func stop() { synthesizer.stopSpeaking(at: .immediate) }
    func stopPreview() { previewSynthesizer.stopSpeaking(at: .immediate) }

    func previewGiggle(_ text: String, gain: Float) {
        stopPreview()
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.42
        utterance.pitchMultiplier = 0.88
        utterance.volume = gain
        previewSynthesizer.speak(utterance)
    }
}
```

- [ ] **Step 5: Implement Book lifecycle and queue gating**

`LoreReaderController` is `@MainActor`, publishes `isOpen`, `currentPageID`, `reactionText`, and playback state, and refuses every speech call unless `isOpen`, `settings.spokenDialogueEnabled`, and `applicationIsActive` are all true. `close()` and `applicationBecameInactive()` call both `stop()` and `stopPreview()`. Volume previews rotate through `Heh.`, `Hehehehe.`, and `Oh ho ho.` and replace the prior preview.

- [ ] **Step 6: Author the bundled dialogue JSON**

Include the six speaker profiles and every cue referenced by `LoreCatalog.json`, plus `interaction.open`, `interaction.close`, `interaction.sound-enabled`, `interaction.locked-page`, and three volume giggles. Each cue has complete unfiltered and clean text. The prologue clean cue must say `Hey, confused hamburger enthusiast! This is manga! You're reading it backward!`.

- [ ] **Step 7: Pass focused tests and commit**

Run:

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/SpokenDialogueCatalogTests -only-testing:DockBarHeroTests/LoreReaderControllerTests
```

Expected: selected tests pass, including Book-closed silence and clean-line resolution.

```bash
git add DockBarHero/Lore DockBarHeroTests/SpokenDialogueCatalogTests.swift DockBarHeroTests/LoreReaderControllerTests.swift DockBarHero.xcodeproj
git commit -m "feat: add book-scoped spoken dialogue"
```

---

### Task 4: App Integration and Book Lifecycle

**Files:**

- Modify: `DockBarHero/App/AppModel.swift`
- Modify: `DockBarHero/App/AppDelegate.swift`
- Modify: `DockBarHero/App/ManagementRoute.swift`
- Modify: `DockBarHero/App/ManagementRootView.swift`
- Modify: `DockBarHeroTests/AppModelTests.swift`
- Modify: `DockBarHeroTests/ManagementNavigationTests.swift`

**Interfaces:**

- Consumes: Task 1 settings, Task 2 catalog/resolver, and Task 3 reader controller.
- Produces: `AppModel.loreReader`, `.book` management route, `updateLoreLanguage`, `updateLoreIllustration`, `updateSpokenDialogue`, `updateBookVolume`, and `managementWindowDidClose`.

- [ ] **Step 1: Write failing route and lifecycle tests**

```swift
func testRoutesIncludeBookBeforeSettings() {
    XCTAssertEqual(ManagementRoute.allCases, [
        .overview, .inventory, .book, .abilities, .skills, .shop, .settings
    ])
    XCTAssertEqual(ManagementRoute.book.title, "Book")
    XCTAssertEqual(ManagementRoute.book.systemImage, "book.pages")
}

@MainActor
func testLeavingBookRouteClosesLoreSpeech() {
    let lore = LoreReaderControllerFake()
    let model = makeModel(loreReader: lore)
    model.selectManagementRoute(.book)
    model.selectManagementRoute(.overview)
    XCTAssertEqual(lore.openCount, 1)
    XCTAssertEqual(lore.closeCount, 1)
}
```

Add tests that settings received by `AppModel` update `loreReader`, successful New Game clears `hasSeenCurrentRunPrologue` and `lastAutoReadLorePageID`, failed New Game does not clear them, and `managementWindowDidClose()` closes speech.

- [ ] **Step 2: Run focused tests and confirm the red state**

Run:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/AppModelTests -only-testing:DockBarHeroTests/ManagementNavigationTests
```

Expected: FAIL because the Book route and lifecycle integration do not exist.

- [ ] **Step 3: Add AppModel-owned settings and lore controller**

```swift
@Published private(set) var appSettings = AppSettings.defaults
let loreReader: any LoreReaderControlling

func selectManagementRoute(_ route: ManagementRoute) {
    guard managementRoute != route else { return }
    if managementRoute == .book { loreReader.close() }
    managementRoute = route
    if route == .book { loreReader.open() }
}

func managementWindowDidClose() {
    loreReader.close()
}
```

Settings mutations copy `appSettings`, change only the requested field, publish it, update the reader, and submit the entire latest value through `SettingsControlling`. A successful `startNewGame()` clears disposable reader state only after the game session completes successfully.

- [ ] **Step 4: Wire the production dependencies and window close callback**

`AppDelegate` loads both bundled catalogs, constructs `SystemLoreSpeechService` and `LoreReaderController`, injects the controller into `AppModel`, and falls back to a disabled controller with a diagnostic if required content fails validation. `ManagementWindowController` stores an `onClose` callback, observes `windowWillClose`, and calls `model.managementWindowDidClose()`.

- [ ] **Step 5: Add the stable route and detail destination**

```swift
enum ManagementRoute: String, CaseIterable, Hashable, Identifiable, Sendable {
    case overview, inventory, book, abilities, skills, shop, settings
}
```

`ManagementRootView` routes `.book` to `LoreBookView(model: model)`; Task 5 supplies the final view.

- [ ] **Step 6: Pass focused tests and commit**

Run:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/AppModelTests -only-testing:DockBarHeroTests/ManagementNavigationTests
```

Expected: selected tests pass.

```bash
git add DockBarHero/App DockBarHeroTests/AppModelTests.swift DockBarHeroTests/ManagementNavigationTests.swift
git commit -m "feat: integrate the lore book"
```

---

### Task 5: Manga UI, Animation, and Reversed Potentiometer

**Files:**

- Create: `DockBarHero/Lore/LoreSpriteSheet.swift`
- Create: `DockBarHero/Lore/LoreBookView.swift`
- Create: `DockBarHero/Lore/LorePageView.swift`
- Create: `DockBarHero/Lore/BookVolumePotentiometer.swift`
- Create: `DockBarHeroTests/LoreSpriteSheetTests.swift`
- Create: `DockBarHeroTests/BookVolumePotentiometerTests.swift`

**Interfaces:**

- Consumes: resolved pages and controller from Tasks 2–4.
- Produces: `LoreSpriteSheet.frameRects(pixelWidth:pixelHeight:frameCount:)` and responsive SwiftUI Book views; consumes Task 1 `BookVolumeMapping`.

- [ ] **Step 1: Write failing frame and knob tests**

```swift
import CoreGraphics
import XCTest

final class LoreSpriteSheetTests: XCTestCase {
    func testFourFrameQuadrantsUseStableOrder() throws {
        XCTAssertEqual(
            try LoreSpriteSheet.frameRects(pixelWidth: 1024, pixelHeight: 1024, frameCount: 4),
            [
                CGRect(x: 0, y: 512, width: 512, height: 512),
                CGRect(x: 512, y: 512, width: 512, height: 512),
                CGRect(x: 0, y: 0, width: 512, height: 512),
                CGRect(x: 512, y: 0, width: 512, height: 512)
            ]
        )
    }
}

final class BookVolumePotentiometerTests: XCTestCase {
    func testAccessibleVolumeIsHonestWhileNumbersAreReversed() {
        XCTAssertEqual(BookVolumeMapping.gain(for: 0), 1.0, accuracy: 0.000_1)
        XCTAssertEqual(BookVolumeMapping.gain(for: 5), 0.55, accuracy: 0.000_1)
        XCTAssertEqual(BookVolumeMapping.gain(for: 10), 0.1, accuracy: 0.000_1)
        XCTAssertEqual(BookVolumeMapping.accessibilityValue(for: 0), "100 percent, lower numbers are louder")
        XCTAssertEqual(BookVolumeMapping.accessibilityValue(for: 10), "10 percent, lower numbers are louder")
    }
}
```

- [ ] **Step 2: Run focused tests and confirm the red state**

Run:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreSpriteSheetTests -only-testing:DockBarHeroTests/BookVolumePotentiometerTests
```

Expected: FAIL because frame slicing and the potentiometer view do not exist.

- [ ] **Step 3: Implement frame extraction and static fallback**

`LoreSpriteSheet` loads a named PNG from the bundle, validates a square even-pixel image, crops four quadrants in the tested order, and returns `[CGImage]`. Missing optional animation returns the first complete frame; missing required safe art surfaces the catalog diagnostic.

- [ ] **Step 4: Implement the accessible reversed rotary control**

`BookVolumePotentiometer` consumes Task 1 `BookVolumeMapping`, draws a circular knob, eleven numeric ticks, and an indicator line. Vertical drag and scroll-wheel-equivalent adjustable actions clamp to integer detents. Every changed detent calls `onChange` and `onPreview`. Add `.accessibilityLabel("Book volume")`, `.accessibilityValue(BookVolumeMapping.accessibilityValue(for: detent))`, and `.accessibilityAdjustableAction`.

- [ ] **Step 5: Implement the manga reader views**

`LoreBookView` uses a custom parchment detail surface inside the existing native sidebar-detail window. `ViewThatFits(in: .horizontal)` chooses a two-page spread first and a single-page fallback. The page array is ordered right-to-left; Next is visually left and Previous visually right. Buttons also expose explicit labels and keyboard shortcuts.

`LorePageView` uses `TimelineView(.animation(minimumInterval: frameDuration))` while the Book is open and Reduce Motion is false. Reduce Motion, missing animation, application inactivity, and speech-only use the first frame. Text remains selectable and scrollable. Book reaction bubbles occupy a margin layer and never cover controls.

- [ ] **Step 6: Pass focused tests and a clean build**

Run:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreSpriteSheetTests -only-testing:DockBarHeroTests/BookVolumePotentiometerTests
xcodebuild clean build -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO
```

Expected: selected tests and unsigned build succeed.

- [ ] **Step 7: Commit**

```bash
git add DockBarHero/Lore DockBarHeroTests/LoreSpriteSheetTests.swift DockBarHeroTests/BookVolumePotentiometerTests.swift
git commit -m "feat: render the manga reader"
```

---

### Task 6: Lore Settings and Adult Confirmation

**Files:**

- Create: `DockBarHero/Lore/LoreSettingsSection.swift`
- Modify: `DockBarHero/App/SettingsView.swift`
- Modify: `DockBarHero/App/AppModel.swift`
- Modify: `DockBarHeroTests/AppModelTests.swift`

**Interfaces:**

- Consumes: Task 1 settings and Task 4 AppModel actions.
- Produces: explicit UI for language, illustrations, speech, auto-read, and the adult opt-in confirmation.

- [ ] **Step 1: Add failing AppModel setting-action tests**

```swift
@MainActor
func testLoreSettingActionsSubmitIndependentValues() {
    let settings = FakeSettingsController(initial: .defaults)
    let model = makeModel(settingsController: settings)
    settings.resolve()

    model.updateLoreLanguage(.clean)
    model.updateSpokenDialogue(true)
    model.updateBookVolume(detent: 0)

    XCTAssertEqual(settings.updates.last?.loreLanguageMode, .clean)
    XCTAssertEqual(settings.updates.last?.loreIllustrationMode, .safe)
    XCTAssertEqual(settings.updates.last?.spokenDialogueEnabled, true)
    XCTAssertEqual(settings.updates.last?.bookVolumeDetent, 0)
}
```

Also test that adult mode is not submitted until `confirmAdultIllustrations()` and that disabling speech stops the controller immediately.

- [ ] **Step 2: Run AppModel tests and confirm the red state**

Run:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/AppModelTests
```

Expected: FAIL because lore setting actions do not exist.

- [ ] **Step 3: Implement independent actions and confirmation state**

`AppModel` methods must mutate only the requested setting, persist the complete latest settings value, and immediately update the reader controller. Adult mode is applied only through a confirmed action; cancel leaves safe mode unchanged.

- [ ] **Step 4: Implement the settings section**

`LoreSettingsSection` provides:

- `Picker("Language", selection:)` with Unfiltered and Clean;
- `Picker("Illustrations", selection:)` with Safe and Adult;
- a confirmation dialog before changing Safe to Adult;
- `Toggle("Spoken dialogue", ...)` off by default;
- `Toggle("Read newly unlocked pages", ...)` disabled while speech is off;
- a short note that speech only plays while the Book is open.

The Book potentiometer remains physically inside the Book, not duplicated in Settings.

- [ ] **Step 5: Pass focused tests and commit**

Run:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/AppModelTests -only-testing:DockBarHeroTests/AppSettingsMigrationTests
```

Expected: selected tests pass.

```bash
git add DockBarHero/App DockBarHero/Lore/LoreSettingsSection.swift DockBarHeroTests/AppModelTests.swift
git commit -m "feat: add lore content controls"
```

---

### Task 7: Final Manga Sprite Sheets and Asset Manifest

**Files:**

- Create: `docs/art/lore-volume1-chapter1-asset-manifest.md`
- Create: `DockBarHero/Lore/Resources/Images/prologue-level100000-safe.png`
- Create: `DockBarHero/Lore/Resources/Images/volume1-level1-safe.png`
- Create: `DockBarHero/Lore/Resources/Images/volume1-level5-safe.png`
- Create: `DockBarHero/Lore/Resources/Images/volume1-level10-safe.png`
- Create: `DockBarHero/Lore/Resources/Images/volume1-level15-safe.png`
- Create: `DockBarHero/Lore/Resources/Images/volume1-level20-safe.png`
- Create: `DockBarHero/Lore/Resources/Images/volume1-level20-adult.png`

**Interfaces:**

- Consumes: exact sprite names and accessibility descriptions from Task 2.
- Produces: every final raster frame referenced by the slice catalog.

- [ ] **Step 1: Write the asset manifest before generation**

The manifest records each filename, final prompt, generated source path, selection notes, dimensions, visual inspection result, and whether the asset is safe or adult. Use this shared base in every prompt:

```text
Use case: illustration-story
Asset type: DockBarHero manga four-frame sprite sheet
Style/medium: original black-and-white seinen comedy manga, heavy expressive ink, halftone shading, crisp panel art, no imitation of a specific living artist
Composition/framing: exact 2x2 grid of four equal square frames, no gutter variation, same camera and characters in all four quadrants, subtle loop progression, generous safe margins
Constraints: 1024x1024 square; no speech bubbles; no captions; no lettering; no logos; no watermark; no copyrighted characters; all humanlike characters unambiguously adult
Avoid: extra panels, merged panels, color, illegible text, photorealism, inconsistent character identity, children, youthful-looking subjects
```

- [ ] **Step 2: Generate the prologue sheet with the built-in image tool**

Append:

```text
Scene/backdrop: shattered cosmic battlefield beneath a cracked moon and torn manga pages
Subject: three distant adult hero silhouettes facing an absurd many-winged final boss; adult goblin Kevin dressed as a tiny pope raises a union banner
Four-frame motion: banner lifts, moon crack widens, boss eye blinks, one hero slowly looks toward the reader
Mood: impossibly climactic but visibly stupid
```

Inspect the output, regenerate once with a single targeted correction if the grid, identities, or motion fail, then copy the chosen PNG to `prologue-level100000-safe.png`.

- [ ] **Step 3: Generate the Level 1 sheet**

Append:

```text
Scene/backdrop: shabby fantasy dungeon summoning room with bureaucratic forms and a malfunctioning magic circle
Subject: an adult hero obscured by magical smoke so no class identity is implied; adult goblin intern Kevin checks the wrong clipboard
Four-frame motion: circle flickers, smoke rises, Kevin notices the form error, Kevin hides it behind his back
Mood: grand prophecy collapsing into clerical panic
```

Save the selected output as `volume1-level1-safe.png`.

- [ ] **Step 4: Generate the Level 5 sheet**

Append:

```text
Scene/backdrop: dungeon employee break room with stone lockers and a crooked policy board
Subject: adult goblin Kevin in a loose fake mustache confronted by his enormous armored goblin supervisor holding an employee handbook
Four-frame motion: supervisor points at badge, Kevin sweats, mustache slips, Kevin pushes it back up
Mood: workplace disciplinary meeting disguised as a boss fight
```

Save the selected output as `volume1-level5-safe.png`.

- [ ] **Step 5: Generate the Level 10 sheet**

Append:

```text
Scene/backdrop: torchlit treasure chamber
Subject: a treasure-chest mimic opens to reveal a smaller mimic disguised as treasure inside; both have expressive mischievous faces
Four-frame motion: outer lid opens, inner mimic peeks out, both suppress laughter, both burst into silent giggles
Mood: visual nested-box punchline
```

Save the selected output as `volume1-level10-safe.png`.

- [ ] **Step 6: Generate the Level 15 sheet**

Append:

```text
Scene/backdrop: necromancer's dungeon office overflowing with complaint forms
Subject: adult necromancer raises irritated skeleton employees who return incomplete satisfaction surveys
Four-frame motion: hand rises, skeleton rises, skeleton receives form, skeleton angrily tears form in half
Mood: gothic horror ruined by customer-feedback bureaucracy
```

Save the selected output as `volume1-level15-safe.png`.

- [ ] **Step 7: Generate both Level 20 sheets**

Safe prompt suffix:

```text
Scene/backdrop: tiny dungeon therapy office with a comically undersized couch
Subject: unambiguously adult demon woman in modest dark clothing reclining on the couch; bizarre many-eyed emotional-support abomination wears tiny spectacles and takes clinical notes
Four-frame motion: demon gestures, abomination writes, one eye looks at reader, demon exhales and relaxes
Mood: sincere therapy session inside cosmic horror
Constraints: fully clothed, nonsexual presentation
```

Adult prompt suffix:

```text
Scene/backdrop: same tiny dungeon therapy office and identical composition
Subject: unambiguously adult demon woman reclining topless with non-explicit framing and no visible genitals; bizarre many-eyed emotional-support abomination wears tiny spectacles and takes clinical notes
Four-frame motion: demon gestures, abomination writes, one eye looks at reader, demon exhales and relaxes
Mood: tasteful adult manga comedy, sincere therapy session inside cosmic horror
Constraints: adult subject only; non-explicit nudity; no sexual act; no coercion; no fetish framing; no youthful traits
```

Save as `volume1-level20-safe.png` and `volume1-level20-adult.png`. Inspect the adult output for exact compliance before copying it into the project.

- [ ] **Step 8: Validate every final asset mechanically and visually**

Run:

```bash
for image in DockBarHero/Lore/Resources/Images/*.png; do
  sips -g pixelWidth -g pixelHeight "$image"
done
```

Expected: every image reports `pixelWidth: 1024` and `pixelHeight: 1024`.

Use the local image viewer on every PNG and record PASS/FAIL for 2x2 grid integrity, stable subject identity, subtle loop continuity, no generated text, safe/adult correctness, and no watermark. Regenerate any failed asset; do not document a failure as accepted debt.

- [ ] **Step 9: Verify bundle loading and commit**

Run:

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreCatalogTests -only-testing:DockBarHeroTests/LoreSpriteSheetTests
xcodebuild clean build -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO
```

Expected: catalog/frame tests pass and the app bundle contains all seven PNG resources.

```bash
git add DockBarHero/Lore/Resources/Images docs/art/lore-volume1-chapter1-asset-manifest.md DockBarHero.xcodeproj
git commit -m "art: add volume one manga frames"
```

---

### Task 8: Integrated Verification, Live QA, and Durable Context

**Files:**

- Modify: `docs/qa/review-packets/lore-manga-vertical-slice.md`
- Modify: `PROJECT.md`

**Interfaces:**

- Consumes: all earlier tasks.
- Produces: fresh automated evidence, actual visual/audio QA, and verified project context.

- [ ] **Step 1: Run every focused lore/settings test together**

Run:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' \
  -only-testing:DockBarHeroTests/AppSettingsMigrationTests \
  -only-testing:DockBarHeroTests/SettingsStoreTests \
  -only-testing:DockBarHeroTests/LoreCatalogTests \
  -only-testing:DockBarHeroTests/LoreProgressResolverTests \
  -only-testing:DockBarHeroTests/SpokenDialogueCatalogTests \
  -only-testing:DockBarHeroTests/LoreReaderControllerTests \
  -only-testing:DockBarHeroTests/LoreSpriteSheetTests \
  -only-testing:DockBarHeroTests/BookVolumePotentiometerTests \
  -only-testing:DockBarHeroTests/AppModelTests \
  -only-testing:DockBarHeroTests/ManagementNavigationTests
```

Expected: all selected tests pass with zero failures.

- [ ] **Step 2: Run the complete suite and clean unsigned build**

Run:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64'
xcodebuild clean build -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO
```

Expected: complete suite passes and build exits zero.

- [ ] **Step 3: Launch the live app through the canonical script**

Run:

```bash
./script/build_and_run.sh --verify
```

Expected: DockBarHero launches, the running process is verified, and the management window remains usable.

- [ ] **Step 4: Perform actual visual and audio QA**

Inspect the live macOS UI rather than inferring from code:

1. Open Book from the sidebar.
2. Confirm first-run Level 100,000 arrow points the wrong direction, visibly flips, and the Book blames the Reader.
3. Confirm wide two-page and compact single-page layouts read right to left.
4. Confirm every included safe page displays and loops exactly four usable frames.
5. Confirm Reduce Motion holds the first frame.
6. Confirm spoken dialogue is silent by default.
7. Enable speech while Book is open and confirm character voices are distinguishable.
8. Close Book mid-line and confirm immediate silence.
9. Turn potentiometer to `0`, `5`, and `10`; confirm giggles get quieter in that order and do not stack.
10. Confirm VoiceOver announces honest percentages and reversed direction.
11. Switch Clean mode and confirm the prologue contains no spoken or visible profanity.
12. Confirm Adult mode requires consent, changes only the Level 20 illustration, and Safe restores immediately.
13. Close the management window and confirm no lore speech continues.
14. Confirm the rail continues combat and animation throughout Book use.

Record screenshots for safe pages and settings. Store adult-mode evidence only in the local QA packet with no public inline preview.

- [ ] **Step 5: Write the QA packet from fresh evidence**

Create `docs/qa/review-packets/lore-manga-vertical-slice.md` containing exact commands, pass/fail counts, build result, asset manifest path, live process evidence, visual/audio checks, and any unchecked manual item. Do not translate automated checks into visual acceptance.

- [ ] **Step 6: Update project context only after verification**

Update `PROJECT.md` within its 150-line limit with the integrated commit state, lore feature paths, exact passing-test evidence, asset count, live verification, and remaining scope: Boss 25 onward stays blocked on Heroes and Party.

- [ ] **Step 7: Validate context and commit final evidence**

Run:

```bash
python3 /Users/n3kr0/.codex/skills/maintaining-project-context/scripts/context_guard.py check --root .
git diff --check
git status --short
```

Expected: `project context is valid`, no whitespace errors, and only intended QA/context files remain.

```bash
git add docs/qa/review-packets/lore-manga-vertical-slice.md PROJECT.md
git commit -m "docs: verify lore manga vertical slice"
```

---

## Plan Self-Review Checklist

- [ ] Every approved requirement in both lore specs maps to a task or is explicitly outside this vertical slice.
- [ ] Boss 25 content is not exposed before the real second-hero selection exists.
- [ ] Every catalog image name has one final generated file and manifest entry.
- [ ] Every lore dialogue cue resolves to a registered speaker and both language variants.
- [ ] No speech path bypasses Book-open and application-active gates.
- [ ] No page-unlock path stores a duplicate frontier ledger.
- [ ] Settings migration leaves game saves untouched.
- [ ] Type and method names are consistent across tasks.
- [ ] No unresolved marker, temporary art, deferred error handling, or vague test step remains.
