# DockBarHero Book Speech Unlock UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the existing Book speech and page-unlock rules discoverable in Settings and the Book footer without changing gameplay, save, unlock, or speech-controller semantics.

**Architecture:** Add a small `LoreBookSpeechStatus` formatting helper so Settings and Book footer copy share one tested contract. Keep `LoreReaderController` behavior unchanged and wire only view-facing text into `LoreSettingsSection` and `LoreBookView`.

**Tech Stack:** Swift 6, SwiftUI, XCTest, existing `AppSettings`, `AppModel`, `LoreReaderController`, and Book view components.

## Global Constraints

- Spoken dialogue remains opt-in.
- Auto-reading newly unlocked pages remains a separate opt-in sub-setting under Spoken dialogue.
- The Book only speaks while the Book is visibly open and the app is active.
- Closing the Book or deactivating the app stops speech immediately.
- Replay remains the explicit command to read the current page.
- Page navigation interrupts current speech. It does not read an already-read page unless the page qualifies for the auto-read rule.
- No gameplay or save semantics change in this slice.
- Settings must explain the durable rule, not current page state.
- The Book footer line must stay concise, secondary, and non-modal.
- Owner confirmation of the Book footer copy in the running app remains a manual acceptance gate.

---

## File Structure

- Create `DockBarHero/Lore/LoreBookSpeechStatus.swift`
  - Owns exact user-facing Book speech status copy.
  - Produces `settingsExplanation` and `footerText(settings:)`.
- Modify `DockBarHero/Lore/LoreSettingsSection.swift`
  - Reuses `LoreBookSpeechStatus.settingsExplanation`.
  - Keeps current controls and toggle dependencies.
- Modify `DockBarHero/Lore/LoreBookView.swift`
  - Adds one compact secondary footer line near Replay/Skip/page navigation.
  - Reuses `LoreBookSpeechStatus.footerText(settings:)`.
- Create `DockBarHeroTests/LoreBookSpeechStatusTests.swift`
  - Tests the three footer states and Settings explanation copy.
- Modify `DockBarHeroTests/AppModelTests.swift`
  - Adds a focused model test proving disabled Spoken dialogue sends disabled settings to the lore reader while preserving the saved auto-read preference.
- Do not modify `LoreReaderController.swift` unless an existing regression test fails and proves behavior drift.

---

### Task 1: Add Tested Book Speech Status Copy

**Files:**
- Create: `DockBarHero/Lore/LoreBookSpeechStatus.swift`
- Create: `DockBarHeroTests/LoreBookSpeechStatusTests.swift`

**Interfaces:**
- Produces: `enum LoreBookSpeechStatus`
- Produces: `static let settingsExplanation: String`
- Produces: `static func footerText(settings: AppSettings) -> String`

- [ ] **Step 1: Write the failing formatter tests**

Create `DockBarHeroTests/LoreBookSpeechStatusTests.swift`:

```swift
import XCTest
@testable import DockBarHero

final class LoreBookSpeechStatusTests: XCTestCase {
    func testFooterTextWhenSpeechIsOff() {
        var settings = AppSettings.defaults
        settings.spokenDialogueEnabled = false
        settings.autoReadNewLorePages = true

        XCTAssertEqual(
            LoreBookSpeechStatus.footerText(settings: settings),
            "Spoken dialogue is off."
        )
    }

    func testFooterTextWhenSpeechIsOnAndAutoReadIsOff() {
        var settings = AppSettings.defaults
        settings.spokenDialogueEnabled = true
        settings.autoReadNewLorePages = false

        XCTAssertEqual(
            LoreBookSpeechStatus.footerText(settings: settings),
            "Replay reads this page. New pages will not auto-read."
        )
    }

    func testFooterTextWhenSpeechAndAutoReadAreOn() {
        var settings = AppSettings.defaults
        settings.spokenDialogueEnabled = true
        settings.autoReadNewLorePages = true

        XCTAssertEqual(
            LoreBookSpeechStatus.footerText(settings: settings),
            "Replay reads this page. Newly unlocked pages can auto-read while the Book is open."
        )
    }

    func testSettingsExplanationNamesOpenBookAndNewPages() {
        XCTAssertEqual(
            LoreBookSpeechStatus.settingsExplanation,
            "Speech only plays while the Book is open. Newly unlocked pages can auto-read when that option is on. Closing the Book stops speech."
        )
    }
}
```

- [ ] **Step 2: Run formatter tests to verify red**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreBookSpeechStatusTests test
```

Expected: FAIL to compile with `cannot find 'LoreBookSpeechStatus' in scope`.

- [ ] **Step 3: Implement the formatter**

Create `DockBarHero/Lore/LoreBookSpeechStatus.swift`:

```swift
enum LoreBookSpeechStatus {
    static let settingsExplanation =
        "Speech only plays while the Book is open. Newly unlocked pages can auto-read when that option is on. Closing the Book stops speech."

    static func footerText(settings: AppSettings) -> String {
        guard settings.spokenDialogueEnabled else {
            return "Spoken dialogue is off."
        }
        if settings.autoReadNewLorePages {
            return "Replay reads this page. Newly unlocked pages can auto-read while the Book is open."
        }
        return "Replay reads this page. New pages will not auto-read."
    }
}
```

- [ ] **Step 4: Run formatter tests to verify green**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreBookSpeechStatusTests test
```

Expected: PASS, 4 tests with 0 failures.

- [ ] **Step 5: Commit Task 1**

```bash
git add DockBarHero/Lore/LoreBookSpeechStatus.swift DockBarHeroTests/LoreBookSpeechStatusTests.swift
git commit -m "Add Book speech status copy"
```

---

### Task 2: Update Settings Copy Through the Shared Contract

**Files:**
- Modify: `DockBarHero/Lore/LoreSettingsSection.swift`
- Test: `DockBarHeroTests/LoreBookSpeechStatusTests.swift`

**Interfaces:**
- Consumes: `LoreBookSpeechStatus.settingsExplanation: String`
- Produces: Settings section copy sourced from the tested helper.

- [ ] **Step 1: Write the failing Settings contract test**

Append this test to `DockBarHeroTests/LoreBookSpeechStatusTests.swift`:

```swift
func testSettingsExplanationIsShortEnoughForSettingsSection() {
    XCTAssertLessThanOrEqual(LoreBookSpeechStatus.settingsExplanation.count, 160)
    XCTAssertTrue(LoreBookSpeechStatus.settingsExplanation.contains("Book is open"))
    XCTAssertTrue(LoreBookSpeechStatus.settingsExplanation.contains("Newly unlocked pages"))
    XCTAssertTrue(LoreBookSpeechStatus.settingsExplanation.contains("Closing the Book stops speech"))
}
```

- [ ] **Step 2: Run the Settings copy test to verify red or current mismatch**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreBookSpeechStatusTests/testSettingsExplanationIsShortEnoughForSettingsSection test
```

Expected before production wiring: PASS is acceptable because this test verifies the copy contract introduced in Task 1. The production view still uses older hard-coded text and is fixed in the next step.

- [ ] **Step 3: Replace hard-coded Settings help text**

In `DockBarHero/Lore/LoreSettingsSection.swift`, replace:

```swift
Text("Speech is opt-in and only plays while the Book is visibly open. Closing it shuts the Book up immediately.")
    .font(.caption)
    .foregroundStyle(.secondary)
```

with:

```swift
Text(LoreBookSpeechStatus.settingsExplanation)
    .font(.caption)
    .foregroundStyle(.secondary)
```

- [ ] **Step 4: Run focused Settings/copy verification**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreBookSpeechStatusTests test
```

Expected: PASS, 5 tests with 0 failures.

- [ ] **Step 5: Commit Task 2**

```bash
git add DockBarHero/Lore/LoreSettingsSection.swift DockBarHeroTests/LoreBookSpeechStatusTests.swift
git commit -m "Clarify Book speech settings copy"
```

---

### Task 3: Add the Compact Book Footer Status

**Files:**
- Modify: `DockBarHero/Lore/LoreBookView.swift`
- Test: `DockBarHeroTests/LoreBookSpeechStatusTests.swift`

**Interfaces:**
- Consumes: `LoreBookSpeechStatus.footerText(settings: AppSettings) -> String`
- Produces: A visible secondary footer line near Book controls.

- [ ] **Step 1: Write the footer line contract test**

Append this test to `DockBarHeroTests/LoreBookSpeechStatusTests.swift`:

```swift
func testFooterCopyStaysCompact() {
    for spoken in [false, true] {
        for autoRead in [false, true] {
            var settings = AppSettings.defaults
            settings.spokenDialogueEnabled = spoken
            settings.autoReadNewLorePages = autoRead

            let text = LoreBookSpeechStatus.footerText(settings: settings)

            XCTAssertLessThanOrEqual(text.count, 88)
            XCTAssertFalse(text.contains("\n"))
        }
    }
}
```

- [ ] **Step 2: Run the footer contract test**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreBookSpeechStatusTests/testFooterCopyStaysCompact test
```

Expected: PASS. This verifies the copy is safe to place in a compact footer before wiring the view.

- [ ] **Step 3: Add footer status to the Book controls**

In `DockBarHero/Lore/LoreBookView.swift`, replace the current `controls` body:

```swift
private var controls: some View {
    HStack(spacing: 14) {
        Button("Next ◀") { select(index: currentIndex + 1) }
            .keyboardShortcut(.leftArrow, modifiers: [])
            .disabled(currentIndex + 1 >= model.lorePages.count)
            .accessibilityLabel("Next Page")
        Button("Previous ▶") { select(index: currentIndex - 1) }
            .keyboardShortcut(.rightArrow, modifiers: [])
            .disabled(currentIndex == 0)
            .accessibilityLabel("Previous Page")

        Divider().frame(height: 32)
        Button("Replay", systemImage: "speaker.wave.2") { controller.replay() }
            .disabled(!model.appSettings.spokenDialogueEnabled)
        Button("Skip", systemImage: "forward.end") { controller.skip() }
            .disabled(!model.appSettings.spokenDialogueEnabled)

        Spacer()
        BookVolumePotentiometer(detent: model.appSettings.bookVolumeDetent) { model.updateBookVolume($0) }
            .frame(width: 100)
    }
    .buttonStyle(.bordered)
    .padding(.horizontal, LoreBookLayout.controlsPadding.horizontal)
    .padding(.top, LoreBookLayout.controlsPadding.top)
    .padding(.bottom, LoreBookLayout.controlsPadding.bottom)
    .background(Color(red: 0.78, green: 0.61, blue: 0.36))
    .frame(minHeight: 92)
}
```

with:

```swift
private var controls: some View {
    VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 14) {
            Button("Next ◀") { select(index: currentIndex + 1) }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(currentIndex + 1 >= model.lorePages.count)
                .accessibilityLabel("Next Page")
            Button("Previous ▶") { select(index: currentIndex - 1) }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(currentIndex == 0)
                .accessibilityLabel("Previous Page")

            Divider().frame(height: 32)
            Button("Replay", systemImage: "speaker.wave.2") { controller.replay() }
                .disabled(!model.appSettings.spokenDialogueEnabled)
                .accessibilityLabel("Replay current Book page")
            Button("Skip", systemImage: "forward.end") { controller.skip() }
                .disabled(!model.appSettings.spokenDialogueEnabled)
                .accessibilityLabel("Skip current Book line")

            Spacer()
            BookVolumePotentiometer(detent: model.appSettings.bookVolumeDetent) { model.updateBookVolume($0) }
                .frame(width: 100)
        }
        Text(LoreBookSpeechStatus.footerText(settings: model.appSettings))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityLabel(LoreBookSpeechStatus.footerText(settings: model.appSettings))
    }
    .buttonStyle(.bordered)
    .padding(.horizontal, LoreBookLayout.controlsPadding.horizontal)
    .padding(.top, LoreBookLayout.controlsPadding.top)
    .padding(.bottom, LoreBookLayout.controlsPadding.bottom)
    .background(Color(red: 0.78, green: 0.61, blue: 0.36))
    .frame(minHeight: 92)
}
```

- [ ] **Step 4: Run focused footer/copy tests**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreBookSpeechStatusTests test
```

Expected: PASS, 6 tests with 0 failures.

- [ ] **Step 5: Commit Task 3**

```bash
git add DockBarHero/Lore/LoreBookView.swift DockBarHeroTests/LoreBookSpeechStatusTests.swift
git commit -m "Show Book speech footer status"
```

---

### Task 4: Preserve Disabled Speech Behavior Through AppModel

**Files:**
- Modify: `DockBarHeroTests/AppModelTests.swift`

**Interfaces:**
- Consumes: `AppModel.updateSpokenDialogue(_:)`
- Consumes: `AppModel.updateAutoReadNewLorePages(_:)`
- Consumes: `LoreReaderControllerFake.updates`
- Produces: Regression coverage proving disabling speech is the effective auto-read gate.

- [ ] **Step 1: Write the focused AppModel test**

Add this test near `testLoreSettingActionsSubmitIndependentValues` in `DockBarHeroTests/AppModelTests.swift`:

```swift
func testDisablingSpokenDialogueLeavesAutoReadSavedButInertForLoreReader() {
    var initial = AppSettings.defaults
    initial.spokenDialogueEnabled = true
    initial.autoReadNewLorePages = true
    let settings = FakeSettingsController(initial: initial)
    let lore = LoreReaderControllerFake()
    let model = AppModel(settingsController: settings, loreReader: lore)
    model.start()
    settings.resolve()

    model.updateSpokenDialogue(false)

    XCTAssertFalse(model.appSettings.spokenDialogueEnabled)
    XCTAssertTrue(model.appSettings.autoReadNewLorePages)
    XCTAssertFalse(lore.updates.last?.settings.spokenDialogueEnabled ?? true)
    XCTAssertTrue(lore.updates.last?.settings.autoReadNewLorePages ?? false)
    XCTAssertEqual(settings.updates.last, model.appSettings)
}
```

- [ ] **Step 2: Run the AppModel test**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/AppModelTests/testDisablingSpokenDialogueLeavesAutoReadSavedButInertForLoreReader test
```

Expected: PASS. This confirms the existing model state passed to the lore reader disables speech even when the saved auto-read preference remains true.

- [ ] **Step 3: Commit Task 4**

```bash
git add DockBarHeroTests/AppModelTests.swift
git commit -m "Cover disabled Book speech auto-read gate"
```

---

### Task 5: Final Verification and Backlog Update

**Files:**
- Modify: `BACKLOG.md` only if the implementation and focused verification pass.

**Interfaces:**
- Consumes: all tasks above.
- Produces: verified implementation record for `BACKLOG.md` C5.

- [ ] **Step 1: Run focused C5 verification**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreBookSpeechStatusTests -only-testing:DockBarHeroTests/LoreReaderControllerTests -only-testing:DockBarHeroTests/AppModelTests/testDisablingSpokenDialogueLeavesAutoReadSavedButInertForLoreReader test
```

Expected: PASS with all selected tests reporting 0 failures.

- [ ] **Step 2: Build the app**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Update `BACKLOG.md` C5 implementation record**

In `BACKLOG.md`, under `### C5. Explain when the Book speaks and how pages unlock`, add this implementation record after the required outcome paragraph:

```markdown
**Implementation record:** Added shared Book speech status copy and surfaced it in Manga Book Settings plus the Book footer. The UI now states that speech only plays while the Book is open, closing the Book stops speech, Replay reads the selected page, and newly unlocked pages only auto-read when the opt-in auto-read setting is enabled. Focused tests cover all three footer states, Settings copy, compact footer length, existing `LoreReaderController` speech gating/replay/skip behavior, and the AppModel disabled-speech auto-read gate. Manual owner confirmation of the footer copy in the running app is still pending.
```

Do not mark the definition-of-completion checkbox for `Book giggle, motion panel, bubbles, padding, and speech UX` as complete; this slice only covers the speech/unlock UX copy and leaves the other manual acceptance gaps open.

- [ ] **Step 4: Run final focused verification after backlog update**

Run:

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreBookSpeechStatusTests -only-testing:DockBarHeroTests/LoreReaderControllerTests -only-testing:DockBarHeroTests/AppModelTests/testDisablingSpokenDialogueLeavesAutoReadSavedButInertForLoreReader test
```

Expected: PASS with all selected tests reporting 0 failures.

- [ ] **Step 5: Commit final implementation record**

```bash
git add BACKLOG.md
git commit -m "Record Book speech unlock UX implementation"
```

- [ ] **Step 6: Report remaining manual acceptance gaps**

Final handoff must state:

```text
Manual acceptance still pending: Book footer copy in the running app, subjective Book audio/giggle preview, motion-panel visual confirmation, manga overlay sizing review, volume knob padding acceptance, and party formation owner acceptance.
```
