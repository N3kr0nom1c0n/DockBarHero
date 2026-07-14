# DockBarHero Multi-Panel Manga Pages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace each lore page's single illustration and bottom prose block with a stable right-to-left manga composition containing five to seven irregular panels, exactly one animated panel, live narration boxes, and live speech balloons.

**Architecture:** Keep the existing four-frame animation sheets and add one 3x2 six-cell context atlas per page. A schema-v2 lore catalog maps authored panels and text overlays into one of four normalized layout templates; a focused SwiftUI renderer crops the animation and context cells, clips them into irregular shapes, and renders resolved text over the page without scrolling. Data validation, image decoding, geometry, language/art resolution, and accessibility order remain independently testable.

**Tech Stack:** Swift 6, SwiftUI, CoreGraphics, XCTest, JSON sidecars, XcodeGen, ImageMagick, built-in image generation.

## Global Constraints

- macOS deployment target remains `26.0`, arm64, with Swift strict concurrency enabled.
- Every page contains five to seven panels and exactly one animated anchor panel.
- Panel and text reading order is right to left and top to bottom.
- Only the existing motion sheet animates; context-atlas cells remain static.
- Generated artwork contains no baked text, captions, speech bubbles, logos, watermarks, or copied characters.
- Clean language is a separately authored rewrite; adult art remains an independent explicit opt-in.
- Spoken dialogue remains off by default and cannot play outside the visibly open active Book.
- Reduced Motion, a closed Book, or an inactive app freezes the motion panel on its first complete frame.
- The fixed bottom caption region and scrolling page prose do not return.
- Preserve unrelated user changes and update `PROJECT.md` only after fresh full verification.

---

## File Structure

- Create `DockBarHero/Lore/LoreMangaLayout.swift`: normalized geometry and four templates.
- Create `DockBarHero/Lore/LoreMangaPanelShape.swift`: normalized polygons converted into SwiftUI paths.
- Create `DockBarHero/Lore/LoreMangaTextOverlay.swift`: narration, speech, title, and sound-effect treatments.
- Create `DockBarHero/Lore/LoreContextSheet.swift`: strict six-cell 3x2 atlas decoder.
- Modify `DockBarHero/Lore/LoreModels.swift`, `LoreCatalog.swift`, and `LoreProgressResolver.swift`: authored and resolved composition contracts.
- Modify `DockBarHero/Lore/LorePageView.swift` and `LoreBookLayout.swift`: full-page, non-scrolling manga canvas.
- Modify `DockBarHero/Lore/Resources/LoreCatalog.json`: six authored compositions.
- Add six `DockBarHero/Lore/Resources/Images/*-context-safe.png` atlases.
- Create `DockBarHeroTests/LoreMangaLayoutTests.swift` and `LoreContextSheetTests.swift`; modify existing lore tests.
- Modify the lore asset manifest, QA packet, and—only after verification—`PROJECT.md`.

---

### Task 1: Add the Composition Data Contract and Migrate the Catalog

**Files:**
- Modify: `DockBarHero/Lore/LoreModels.swift`
- Modify: `DockBarHero/Lore/LoreCatalog.swift`
- Modify: `DockBarHero/Lore/LoreProgressResolver.swift`
- Modify: `DockBarHero/Lore/Resources/LoreCatalog.json`
- Modify: `DockBarHeroTests/LoreCatalogTests.swift`
- Modify: `DockBarHeroTests/LoreProgressResolverTests.swift`

**Interfaces:**
- Produces: `LoreMangaLayoutID`, `LorePanelDefinition`, `LoreTextOverlayDefinition`, `LoreCompositionDefinition`, and `ResolvedLoreComposition`.
- Produces: `ResolvedLorePage.composition` for layout and rendering tasks.
- Consumes: existing language mode, illustration mode, motion sheets, page unlocks, and accessibility copy.

- [ ] **Step 1: Write failing composition and resolver tests**

Add tests for schema 2; exactly one motion panel; five-to-seven panel count; unique panel IDs, slot IDs, overlay IDs, and reading orders; still source cells inside `0...5`; an invalid optional gag source being omittable; nonempty safe context art; nonempty optional adult context names; overlays attached to real panels; clean overlay resolution; adult motion selection with safe context fallback.

```swift
func testRejectsCompositionWithoutExactlyOneMotionPanel() {
    var page = LoreFixtures.page("bad-motion", index: 0, unlock: nil)
    page = page.replacingComposition(
        page.composition.replacingPanels(page.composition.panels.map {
            .init(
                id: $0.id, slotID: $0.slotID, role: .still,
                sourceCell: 0, readingOrder: $0.readingOrder,
                focalPoint: $0.focalPoint
            )
        })
    )
    XCTAssertThrowsError(try LoreCatalog.validated(.init(schemaVersion: 2, pages: [page]))) {
        XCTAssertEqual($0 as? LoreCatalogError, .invalidComposition("bad-motion"))
    }
}

func testResolverUsesCleanOverlayAndSafeContextFallback() throws {
    let page = LoreFixtures.page("resolved", index: 0, unlock: nil, adult: "resolved-adult")
    let resolved = try XCTUnwrap(LoreProgressResolver.resolve(
        catalog: try LoreCatalog.validated(.init(schemaVersion: 2, pages: [page])),
        highestUnlockedLevel: 1, languageMode: .clean, illustrationMode: .adult
    ).first)
    XCTAssertEqual(resolved.spriteSheetName, "resolved-adult")
    XCTAssertEqual(resolved.composition.contextSheetName, "resolved-context-safe")
    XCTAssertEqual(resolved.composition.textOverlays.first?.text, "resolved clean narration")
}

private extension LorePageDefinition {
    func replacingComposition(_ replacement: LoreCompositionDefinition) -> Self {
        .init(
            id: id, sortIndex: sortIndex, title: title, body: body,
            unlockAfterVictoryLevel: unlockAfterVictoryLevel, art: art,
            composition: replacement, dialogueCueIDs: dialogueCueIDs,
            frameCount: frameCount, frameDurationMilliseconds: frameDurationMilliseconds
        )
    }
}

private extension LoreCompositionDefinition {
    func replacingPanels(_ replacement: [LorePanelDefinition]) -> Self {
        .init(
            layoutID: layoutID, safeContextSheet: safeContextSheet,
            adultContextSheet: adultContextSheet, panels: replacement,
            textOverlays: textOverlays
        )
    }
}
```

- [ ] **Step 2: Run tests and verify the contract is absent**

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreCatalogTests -only-testing:DockBarHeroTests/LoreProgressResolverTests
```

Expected: compilation fails because the composition types and schema-v2 fields do not exist.

- [ ] **Step 3: Add the exact model types**

```swift
enum LoreMangaLayoutID: String, Codable, CaseIterable, Hashable, Sendable {
    case cascadeFive, brokenSix, staggeredSix, shatteredSeven
}
enum LorePanelRole: String, Codable, Equatable, Sendable { case motion, still, gag }
enum LoreTextOverlayStyle: String, Codable, Equatable, Sendable { case title, narration, speech, soundEffect }
enum LoreTextPlacement: String, Codable, Equatable, Sendable {
    case topLeading, topTrailing, bottomLeading, bottomTrailing, center
}
struct LoreFocalPoint: Codable, Equatable, Sendable { let x: Double; let y: Double }
struct LorePanelDefinition: Codable, Equatable, Sendable {
    let id: String
    let slotID: String
    let role: LorePanelRole
    let sourceCell: Int?
    let readingOrder: Int
    let focalPoint: LoreFocalPoint
}
struct LoreTextOverlayDefinition: Codable, Equatable, Sendable {
    let id: String
    let panelID: String
    let style: LoreTextOverlayStyle
    let placement: LoreTextPlacement
    let speakerID: String?
    let dialogueCueID: String?
    let copy: LoreTextVariants
}
struct LoreCompositionDefinition: Codable, Equatable, Sendable {
    let layoutID: LoreMangaLayoutID
    let safeContextSheet: String
    let adultContextSheet: String?
    let panels: [LorePanelDefinition]
    let textOverlays: [LoreTextOverlayDefinition]
}
struct ResolvedLoreTextOverlay: Equatable, Sendable {
    let id: String
    let panelID: String
    let style: LoreTextOverlayStyle
    let placement: LoreTextPlacement
    let speakerID: String?
    let dialogueCueID: String?
    let text: String
}
struct ResolvedLoreComposition: Equatable, Sendable {
    let layoutID: LoreMangaLayoutID
    let contextSheetName: String
    let panels: [LorePanelDefinition]
    let textOverlays: [ResolvedLoreTextOverlay]
}
```

Add `composition` to both page types. Keep existing motion-sheet fields. Resolve context art independently:

```swift
let contextSheetName = illustrationMode == .adult
    ? page.composition.adultContextSheet ?? page.composition.safeContextSheet
    : page.composition.safeContextSheet
let overlays = page.composition.textOverlays.map {
    ResolvedLoreTextOverlay(
        id: $0.id, panelID: $0.panelID, style: $0.style,
        placement: $0.placement, speakerID: $0.speakerID,
        dialogueCueID: $0.dialogueCueID,
        text: languageMode == .clean ? $0.copy.clean : $0.copy.unfiltered
    )
}
```

Update `LoreFixtures.page` with this complete default composition so every existing test fixture remains valid under schema 2:

```swift
composition: LoreCompositionDefinition(
    layoutID: .cascadeFive,
    safeContextSheet: "\(id)-context-safe",
    adultContextSheet: nil,
    panels: [
        .init(id: "p1", slotID: "slot1", role: .still, sourceCell: 0, readingOrder: 0, focalPoint: .init(x: 0.5, y: 0.5)),
        .init(id: "p2", slotID: "slot2", role: .motion, sourceCell: nil, readingOrder: 1, focalPoint: .init(x: 0.5, y: 0.5)),
        .init(id: "p3", slotID: "slot3", role: .still, sourceCell: 1, readingOrder: 2, focalPoint: .init(x: 0.5, y: 0.5)),
        .init(id: "p4", slotID: "slot4", role: .still, sourceCell: 2, readingOrder: 3, focalPoint: .init(x: 0.5, y: 0.5)),
        .init(id: "p5", slotID: "slot5", role: .gag, sourceCell: 3, readingOrder: 4, focalPoint: .init(x: 0.5, y: 0.5))
    ],
    textOverlays: [
        .init(
            id: "o1", panelID: "p1", style: .narration,
            placement: .topTrailing, speakerID: nil, dialogueCueID: nil,
            copy: .init(unfiltered: "resolved narration", clean: "resolved clean narration")
        )
    ]
)
```

- [ ] **Step 4: Enforce schema-v2 composition validation**

Add `LoreCatalogError.invalidComposition(String)`. Require five-to-seven authored slots, exactly one motion role, unique IDs/slots/orders, focal coordinates inside `0...1`, `nil` source for motion, source `0...5` for required still panels, optional source `0...5` for gag panels, complete text variants, and existing panel attachments. A gag with a missing or invalid source is omitted by the renderer rather than invalidating required story art.

```swift
let panels = page.composition.panels
let panelIDs = panels.map(\.id)
let overlays = page.composition.textOverlays
guard (5...7).contains(panels.count),
      panels.filter({ $0.role == .motion }).count == 1,
      Set(panelIDs).count == panelIDs.count,
      Set(panels.map(\.slotID)).count == panels.count,
      Set(panels.map(\.readingOrder)).count == panels.count,
      panels.allSatisfy({
          (0...1).contains($0.focalPoint.x) &&
          (0...1).contains($0.focalPoint.y) &&
          ($0.role == .motion ? $0.sourceCell == nil : true) &&
          ($0.role == .still ? $0.sourceCell.map { (0...5).contains($0) } == true : true)
      }),
      page.composition.adultContextSheet.map {
          !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      } ?? true,
      Set(overlays.map(\.id)).count == overlays.count,
      overlays.allSatisfy({
          panelIDs.contains($0.panelID) &&
          !$0.copy.unfiltered.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
          !$0.copy.clean.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      }),
      Set(page.composition.textOverlays.compactMap(\.dialogueCueID)) == Set(page.dialogueCueIDs) else {
    throw LoreCatalogError.invalidComposition(page.id.rawValue)
}
```

- [ ] **Step 5: Migrate all six pages**

Use these layouts and ordered roles:

| Page | Layout | Panels |
|---|---|---|
| Prologue | `brokenSix` | still 0, motion, still 1, still 2, still 3, gag 4 |
| Level 1 | `cascadeFive` | still 0, motion, still 1, still 2, gag 3 |
| Level 5 | `staggeredSix` | still 0, motion, still 1, still 2, still 3, gag 4 |
| Level 10 | `shatteredSeven` | still 0, motion, still 1, still 2, still 3, still 4, gag 5 |
| Level 15 | `brokenSix` | still 0, motion, still 1, still 2, still 3, gag 4 |
| Level 20 | `cascadeFive` | still 0, motion, still 1, still 2, gag 3 |

Use `slot1...slot7`, sequential reading orders from zero, and context names ending in `-context-safe`. Author these live lines as JSON overlays:

| Page | Visible overlays |
|---|---|
| Prologue | `LEVEL 100,000: THE FINALER ENDING`; `The moon filed for divorce. Kevin unionized Heaven.`; `Somehow, this was your fault.`; unfiltered `Hey, American jackass! This is a manga! You're reading it backwards, ya fuckwad!` / clean `Hey, confused hamburger enthusiast! This is manga! You're reading it backward!`; `Slander. The arrow has always pointed left.` |
| Level 1 | `FOUR MINUTES EARLIER`; `Four minutes earlier, I requested a qualified hero. The universe clicked Show Similar Results.`; unfiltered `I'm not Kevin. Kevin died. This mustache is hereditary.` / clean replacing `died` with `departed` |
| Level 5 | `KEVIN'S SUPERVISOR`; `Behold Kevin's supervisor: Kevin, but larger and legally a separate workplace incident.`; `Initial here to acknowledge your replacement Kevin.`; `My name is Kévin. The accent mark makes this airtight.` |
| Level 10 | `THE DOUBLE MIMIC`; `The chest was a mimic. Inside it was another mimic pretending to be loot. Both have tenure.`; `Don't laugh.`; `You first.`; `hnk—` |
| Level 15 | `THE NECROMANCER OF NEGATIVE FEEDBACK`; `The necromancer raises the dead exclusively for customer-satisfaction surveys.`; `On a scale from one to ten—`; `Vomiting blood on the adventurers is against dungeon policy.` |
| Level 20 | `EMOTIONAL-SUPPORT ABOMINATION`; `The demon requested an emotional-support abomination. Insurance approved six tentacles and no weekends.`; unfiltered `A cursed crown is not a substitute for therapy, sleep, boundaries, or properly supervised mood stabilizers.` / clean ending with `properly supervised medication.`; `And how did becoming “Dread Queen” make you feel?` |

For rows without two variants, copy the exact line into both `unfiltered` and `clean`. Use IDs `o1...o5` in listed order and attach them as follows:

| Page | Panel, placement, cue mapping |
|---|---|
| Prologue | `o1 p1 topTrailing no cue`; `o2 p1 bottomLeading no cue`; `o3 p2 topLeading no cue`; `o4 p4 topTrailing prologue.book.wrong-way speaker book`; `o5 p5 bottomLeading prologue.book.arrow-denial speaker book` |
| Level 1 | `o1 p1 topTrailing no cue`; `o2 p1 bottomLeading book.level1.summary speaker book`; `o3 p4 topTrailing kevin.not-kevin speaker kevin` |
| Level 5 | `o1 p1 topTrailing no cue`; `o2 p1 bottomLeading book.level5.summary speaker book`; `o3 p3 topTrailing no cue speaker supervisor`; `o4 p4 bottomLeading kevin.supervisor speaker kevin` |
| Level 10 | `o1 p1 topTrailing no cue`; `o2 p1 bottomLeading book.level10.summary speaker book`; `o3 p3 topTrailing no cue speaker outer-mimic`; `o4 p4 bottomLeading no cue speaker inner-mimic`; `o5 p5 center no cue` |
| Level 15 | `o1 p1 topTrailing no cue`; `o2 p1 bottomLeading book.level15.summary speaker book`; `o3 p3 topTrailing no cue speaker necromancer`; `o4 p5 bottomLeading brick.policy-warning speaker brick` |
| Level 20 | `o1 p1 topTrailing no cue`; `o2 p1 bottomLeading book.level20.summary speaker book`; `o3 p3 topTrailing mercy.therapy-referral speaker mercy`; `o4 p4 bottomLeading no cue speaker abomination` |

This mapping makes every page-level TTS cue visibly represented once and preserves exact clean/unfiltered cue copy.

- [ ] **Step 6: Regenerate, test, and commit**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreCatalogTests -only-testing:DockBarHeroTests/LoreProgressResolverTests
git add DockBarHero/Lore/LoreModels.swift DockBarHero/Lore/LoreCatalog.swift DockBarHero/Lore/LoreProgressResolver.swift DockBarHero/Lore/Resources/LoreCatalog.json DockBarHeroTests/LoreCatalogTests.swift DockBarHeroTests/LoreProgressResolverTests.swift DockBarHero.xcodeproj
git commit -m "feat: author multi-panel lore compositions"
```

Expected: focused tests pass and the catalog decodes as schema 2.

---

### Task 2: Build Four Deterministic Irregular Layouts

**Files:**
- Create: `DockBarHero/Lore/LoreMangaLayout.swift`
- Create: `DockBarHeroTests/LoreMangaLayoutTests.swift`
- Modify: `DockBarHero/Lore/LoreCatalog.swift`
- Modify: `DockBarHeroTests/LoreCatalogTests.swift`

**Interfaces:**
- Produces: `LoreMangaLayout.template(for:) -> LoreMangaTemplate`.
- Consumes: layout IDs and `slot1...slot7` from Task 1.

- [ ] **Step 1: Write failing template tests**

```swift
func testTemplatesHaveExpectedPanelCountsAndUniqueSlots() {
    let expected: [LoreMangaLayoutID: Int] = [
        .cascadeFive: 5, .brokenSix: 6, .staggeredSix: 6, .shatteredSeven: 7
    ]
    for (id, count) in expected {
        let template = LoreMangaLayout.template(for: id)
        XCTAssertEqual(template.slots.count, count)
        XCTAssertEqual(Set(template.slots.map(\.id)).count, count)
    }
}

func testSlotsStayInBoundsAndFramesDoNotOverlap() {
    for id in LoreMangaLayoutID.allCases {
        let slots = LoreMangaLayout.template(for: id).slots
        for slot in slots {
            XCTAssertTrue(slot.frame.isInsideUnitSquare)
            XCTAssertTrue(slot.clipPolygon.allSatisfy {
                (0...1).contains($0.x) && (0...1).contains($0.y)
            })
        }
        for left in slots.indices {
            for right in slots.indices where right > left {
                XCTAssertFalse(slots[left].frame.hasInteriorOverlap(with: slots[right].frame))
            }
        }
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreMangaLayoutTests
```

Expected: compilation fails because the layout types do not exist.

- [ ] **Step 3: Implement normalized template types**

```swift
struct LoreNormalizedPoint: Equatable, Sendable { let x: CGFloat; let y: CGFloat }
struct LoreNormalizedRect: Equatable, Sendable {
    let x: CGFloat; let y: CGFloat; let width: CGFloat; let height: CGFloat
    var isInsideUnitSquare: Bool { x >= 0 && y >= 0 && x + width <= 1 && y + height <= 1 }
    func hasInteriorOverlap(with other: Self) -> Bool {
        min(x + width, other.x + other.width) - max(x, other.x) > 0.0001 &&
        min(y + height, other.y + other.height) - max(y, other.y) > 0.0001
    }
}
struct LoreMangaPanelSlot: Equatable, Sendable {
    let id: String
    let frame: LoreNormalizedRect
    let clipPolygon: [LoreNormalizedPoint]
}
struct LoreMangaTemplate: Equatable, Sendable {
    let id: LoreMangaLayoutID
    let slots: [LoreMangaPanelSlot]
    func slot(id: String) -> LoreMangaPanelSlot? { slots.first { $0.id == id } }
}
```

Author the templates with these exact normalized frames `(x, y, width, height)`:

| Layout | Slots in order |
|---|---|
| `cascadeFive` | `slot1 (0.600,0.015,0.385,0.290)`; `slot2 (0.420,0.317,0.565,0.668)`; `slot3 (0.015,0.015,0.573,0.290)`; `slot4 (0.015,0.317,0.393,0.320)`; `slot5 (0.015,0.649,0.393,0.336)` |
| `brokenSix` | `slot1 (0.640,0.015,0.345,0.250)`; `slot2 (0.480,0.277,0.505,0.708)`; `slot3 (0.015,0.015,0.613,0.250)`; `slot4 (0.015,0.277,0.453,0.220)`; `slot5 (0.015,0.509,0.453,0.220)`; `slot6 (0.015,0.741,0.453,0.244)` |
| `staggeredSix` | `slot1 (0.650,0.015,0.335,0.220)`; `slot2 (0.440,0.247,0.545,0.660)`; `slot3 (0.015,0.015,0.623,0.220)`; `slot4 (0.015,0.247,0.413,0.200)`; `slot5 (0.015,0.459,0.413,0.200)`; `slot6 (0.015,0.671,0.413,0.314)` |
| `shatteredSeven` | `slot1 (0.015,0.015,0.393,0.200)`; `slot2 (0.420,0.015,0.565,0.650)`; `slot3 (0.015,0.227,0.393,0.200)`; `slot4 (0.015,0.439,0.393,0.226)`; `slot5 (0.015,0.677,0.300,0.308)`; `slot6 (0.327,0.677,0.318,0.308)`; `slot7 (0.657,0.677,0.328,0.308)` |

Apply local clip polygon `[(0,0), (1,0), (0.94,1), (0.06,1)]` to odd-numbered slots and `[(0.06,0), (0.94,0), (1,1), (0,1)]` to even-numbered slots. `slot2` is the dominant 35–45% panel in every template.

- [ ] **Step 4: Validate slot coverage and test rejection**

```swift
let template = LoreMangaLayout.template(for: page.composition.layoutID)
guard page.composition.panels.count == template.slots.count,
      Set(page.composition.panels.map(\.slotID)) == Set(template.slots.map(\.id)) else {
    throw LoreCatalogError.invalidComposition(page.id.rawValue)
}
```

Add a catalog test replacing one valid slot with `slot99`.

- [ ] **Step 5: Test and commit**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreMangaLayoutTests -only-testing:DockBarHeroTests/LoreCatalogTests
git add DockBarHero/Lore/LoreMangaLayout.swift DockBarHero/Lore/LoreCatalog.swift DockBarHeroTests/LoreMangaLayoutTests.swift DockBarHeroTests/LoreCatalogTests.swift DockBarHero.xcodeproj
git commit -m "feat: add irregular manga page layouts"
```

Expected: both test classes pass.

---

### Task 3: Add the Six-Cell Context-Atlas Loader

**Files:**
- Create: `DockBarHero/Lore/LoreContextSheet.swift`
- Create: `DockBarHeroTests/LoreContextSheetTests.swift`

**Interfaces:**
- Produces: `cellRects(pixelWidth:pixelHeight:)` and `cells(named:bundle:)`.
- Consumes: resolved context-sheet resource names.

- [ ] **Step 1: Write failing crop-order tests**

```swift
func testCellsUseRightToLeftTopThenRightToLeftBottomOrder() throws {
    XCTAssertEqual(try LoreContextSheet.cellRects(pixelWidth: 1536, pixelHeight: 1024), [
        .init(x: 1024, y: 512, width: 512, height: 512),
        .init(x: 512, y: 512, width: 512, height: 512),
        .init(x: 0, y: 512, width: 512, height: 512),
        .init(x: 1024, y: 0, width: 512, height: 512),
        .init(x: 512, y: 0, width: 512, height: 512),
        .init(x: 0, y: 0, width: 512, height: 512)
    ])
}
func testRejectsWrongAspectOddDimensionsAndMissingResource() {
    XCTAssertThrowsError(try LoreContextSheet.cellRects(pixelWidth: 1024, pixelHeight: 1024))
    XCTAssertThrowsError(try LoreContextSheet.cellRects(pixelWidth: 1535, pixelHeight: 1024))
    XCTAssertThrowsError(try LoreContextSheet.cells(named: "missing-lore-context"))
}
```

- [ ] **Step 2: Run the focused test and verify failure**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreContextSheetTests
```

- [ ] **Step 3: Implement strict 3x2 decoding**

Mirror `LoreSpriteSheet` lookup/decoding. Enforce width divisible by 3, height divisible by 2, and square cells. Crop in the tested RTL order.

```swift
enum LoreContextSheetError: Error, Equatable {
    case invalidDimensions
    case resourceMissing(String)
    case imageDecodeFailed
    case cropFailed
}
```

- [ ] **Step 4: Test and commit**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreContextSheetTests
git add DockBarHero/Lore/LoreContextSheet.swift DockBarHeroTests/LoreContextSheetTests.swift DockBarHero.xcodeproj
git commit -m "feat: decode lore context atlases"
```

Expected: all context-sheet tests pass.

---

### Task 4: Generate and Deliver Six Context Atlases

**Files:**
- Create: `DockBarHero/Lore/Resources/Images/prologue-level100000-context-safe.png`
- Create: `DockBarHero/Lore/Resources/Images/volume1-level1-context-safe.png`
- Create: `DockBarHero/Lore/Resources/Images/volume1-level5-context-safe.png`
- Create: `DockBarHero/Lore/Resources/Images/volume1-level10-context-safe.png`
- Create: `DockBarHero/Lore/Resources/Images/volume1-level15-context-safe.png`
- Create: `DockBarHero/Lore/Resources/Images/volume1-level20-context-safe.png`
- Modify: `DockBarHeroTests/LoreContextSheetTests.swift`
- Modify: `docs/art/lore-volume1-chapter1-asset-manifest.md`

**Interfaces:**
- Consumes: each matching existing motion sheet as an image-generation reference.
- Produces: six text-free 1536x1024 PNGs with six 512x512 cells.

- [ ] **Step 1: Generate one image per page**

Use the built-in image generator once per atlas. Every prompt starts with:

```text
Create one landscape 3:2 contact sheet for an original black-and-white seinen comedy manga. Exact 3 columns by 2 rows, six equal square cells, thick clean white gutters, no text, no lettering, no logos, no watermark. Match the characters, costumes, setting, ink weight, halftone shading, and expressions from the supplied reference. Six DISTINCT still story beats ordered right-to-left across the top row, then right-to-left across the bottom row. Stable identities, readable silhouettes, original characters, safe composition, and every humanlike subject unambiguously adult.
```

Append the exact page beats:

- Prologue: impossible final victory tableau; suspicious manga navigation arrow; Book's bookmark secretly rotating it; guilty bookmark and shocked hero close-up; red ink erasing evidence; heroes staring toward the Reader while the Book blames them.
- Level 1: rejected celestial hiring form; confused adult hero emerging; Kevin comparing an absurd checklist; Book hiding qualification papers; Kevin's fake mustache and wrong badge; queue of unqualified adult silhouettes.
- Level 5: Kevin applying fake mustache; supervisor presenting huge handbook; identical badge close-up; adult hero noticing replacement-goblin uniforms; unsigned form accusation; tiny goblin rehearsing another Kevin accent.
- Level 10: adult hero with absurdly long pole; outer mimic sweating; inner mimic peeking out; both suppressing laughter; both posing innocently; Kevin selling blank insurance scroll.
- Level 15: necromancer distributing blank surveys; skeleton returning incomplete form; one-star pictographic rating without letters; complaint desk rising; adult Brick enforcing dungeon policy; bottomless suggestion box.
- Level 20: fully clothed adult demon on tiny couch; adult Mercy offering blank referral card; many-eyed clinician taking notes; cursed crown filling blank intake form; safely closed supervised-medication container without label text; Book waiting outside therapy.

- [ ] **Step 2: Inspect and normalize each accepted source**

Reject any sheet without exactly six distinct cells, stable principal identities, clean gutters, or text-free safe artwork. For each image-generation result, assign its returned local `output_hint` path to `generated_path`, then assign the matching destination from the six exact filenames in this task to `destination_path`. Normalize immediately before generating the next atlas:

```bash
magick "$generated_path" -resize 1536x1024! -colorspace sRGB -strip "$destination_path"
magick identify DockBarHero/Lore/Resources/Images/*-context-safe.png
```

Expected: every destination reports `PNG 1536x1024`.

- [ ] **Step 3: Add bundled-load coverage**

```swift
func testEveryBundledContextSheetLoadsAsSixCells() throws {
    for page in try LoreCatalog.bundled().pages {
        XCTAssertEqual(try LoreContextSheet.cells(named: page.composition.safeContextSheet).count, 6)
        if let adult = page.composition.adultContextSheet {
            XCTAssertEqual(try LoreContextSheet.cells(named: adult).count, 6)
        }
    }
}
```

- [ ] **Step 4: Test, document, and commit**

Record filenames, generation result IDs, beats, dimensions, grid inspection, identity inspection, and text/watermark inspection in the manifest.

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreContextSheetTests
git add DockBarHero/Lore/Resources/Images/*-context-safe.png DockBarHeroTests/LoreContextSheetTests.swift docs/art/lore-volume1-chapter1-asset-manifest.md DockBarHero.xcodeproj
git commit -m "art: add multi-panel lore context atlases"
```

Expected: all six atlases load as six cells.

---

### Task 5: Render Panels and Live Manga Text

**Files:**
- Create: `DockBarHero/Lore/LoreMangaPanelShape.swift`
- Create: `DockBarHero/Lore/LoreMangaTextOverlay.swift`
- Modify: `DockBarHero/Lore/LorePageView.swift`
- Modify: `DockBarHero/Lore/LoreBookLayout.swift`
- Modify: `DockBarHeroTests/LoreBookLayoutTests.swift`

**Interfaces:**
- Consumes: resolved composition, layout template, animation frames, and context cells.
- Produces: one stable full-page panel canvas and exactly one `TimelineView`.

- [ ] **Step 1: Replace caption-region tests with canvas tests**

```swift
func testPageCanvasInsetsRemainLegible() {
    XCTAssertEqual(LoreBookLayout.pageCanvasInsets(forPageWidth: 320), 8)
    XCTAssertEqual(LoreBookLayout.pageCanvasInsets(forPageWidth: 520), 12)
}
func testPanelGutterIsBounded() {
    XCTAssertEqual(LoreBookLayout.panelGutter(forPageWidth: 320), 5)
    XCTAssertEqual(LoreBookLayout.panelGutter(forPageWidth: 520), 8)
    XCTAssertEqual(LoreBookLayout.panelGutter(forPageWidth: 900), 8)
}
func testLongCopyInANarrowPanelUsesPageCallout() {
    XCTAssertTrue(LoreBookLayout.usesPageCallout(characterCount: 80, panelWidth: 160))
    XCTAssertFalse(LoreBookLayout.usesPageCallout(characterCount: 40, panelWidth: 220))
}
```

Run the focused test and expect compilation failure:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreBookLayoutTests
```

- [ ] **Step 2: Implement polygon clipping**

```swift
struct LoreMangaPanelShape: Shape {
    let points: [LoreNormalizedPoint]
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: .init(x: rect.minX + first.x * rect.width, y: rect.minY + first.y * rect.height))
        for point in points.dropFirst() {
            path.addLine(to: .init(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height))
        }
        path.closeSubpath()
        return path
    }
}
```

- [ ] **Step 3: Implement live text treatments**

`LoreMangaTextOverlay` accepts a resolved overlay and compact flag. Use the complete initial treatment below; placement within the attached panel is handled by `LorePageView` from `overlay.placement`.

```swift
struct LoreMangaTextOverlay: View {
    let overlay: ResolvedLoreTextOverlay
    let compact: Bool

    @ViewBuilder
    var body: some View {
        switch overlay.style {
        case .title, .narration:
            Text(overlay.text)
                .font(.system(size: overlay.style == .title ? (compact ? 14 : 16) : (compact ? 13 : 14), weight: .black, design: .serif))
                .foregroundStyle(Color.black)
                .padding(compact ? 6 : 8)
                .background(Color(red: 0.98, green: 0.93, blue: 0.82).opacity(0.97))
                .overlay(Rectangle().stroke(Color.black, lineWidth: 1.5))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(overlay.text)
        case .speech:
            Text(overlay.text)
                .font(.system(size: compact ? 13 : 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.black)
                .padding(.horizontal, compact ? 8 : 10)
                .padding(.vertical, compact ? 7 : 9)
                .padding(.bottom, 5)
                .background(LoreSpeechBalloonShape().fill(Color.white.opacity(0.97)))
                .overlay(LoreSpeechBalloonShape().stroke(Color.black, lineWidth: 1.5))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(overlay.text)
        case .soundEffect:
            Text(overlay.text)
                .font(.system(size: compact ? 18 : 24, weight: .black, design: .rounded))
                .foregroundStyle(Color.white)
                .shadow(color: .black, radius: 0, x: 2, y: 0)
                .shadow(color: .black, radius: 0, x: -2, y: 0)
                .shadow(color: .black, radius: 0, x: 0, y: 2)
                .shadow(color: .black, radius: 0, x: 0, y: -2)
                .rotationEffect(.degrees(-8))
                .accessibilityHidden(true)
        }
    }
}

private struct LoreSpeechBalloonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let body = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: max(0, rect.height - 8))
        var path = Path(roundedRect: body, cornerRadius: min(18, body.height / 2))
        path.move(to: CGPoint(x: body.minX + body.width * 0.72, y: body.maxY - 1))
        path.addLine(to: CGPoint(x: body.minX + body.width * 0.86, y: rect.maxY))
        path.addLine(to: CGPoint(x: body.minX + body.width * 0.62, y: body.maxY - 1))
        path.closeSubpath()
        return path
    }
}
```

- [ ] **Step 4: Replace the vertical stack with the panel canvas**

Use separate `motionFrames` and `contextCells` state. Load both sheets in one task. For each panel: find its template slot; map its normalized frame into the inset canvas; choose motion or context cell; aspect-fill around `LoreFocalPoint`; clip and border it; then place attached live text.

The motion branch is the only timeline:

```swift
if panel.role == .motion, let first = motionFrames.first {
    if reduceMotion || !isBookOpen || motionFrames.count == 1 {
        panelImage(first, focalPoint: panel.focalPoint)
    } else {
        TimelineView(.animation(minimumInterval: Double(page.frameDurationMilliseconds) / 1_000)) { context in
            let duration = Double(page.frameDurationMilliseconds) / 1_000
            let index = Int(context.date.timeIntervalSinceReferenceDate / duration) % motionFrames.count
            panelImage(motionFrames[index], focalPoint: panel.focalPoint)
        }
    }
}
```

If motion is missing, use context cell zero as the static anchor. If required context decoding does not return exactly six cells, replace only that affected page's canvas with the illustrator-eaten diagnostic instead of rendering blank still panels. A gag whose source is absent or outside `0...5` is skipped. Sort accessibility text by panel `readingOrder` and catalog overlay order; hide decorative images.

Add `@Environment(\.scenePhase) private var scenePhase` and require `scenePhase == .active` in the animated branch. An inactive app must render the same first static frame as Reduced Motion and a closed Book.

- [ ] **Step 5: Remove obsolete caption policy**

Delete `PageRegions`, `captionHeight`, and `pageRegions`. Add:

```swift
static func pageCanvasInsets(forPageWidth width: CGFloat) -> CGFloat { width < 420 ? 8 : 12 }
static func panelGutter(forPageWidth width: CGFloat) -> CGFloat { min(8, max(5, width * 0.015)) }
static func usesPageCallout(characterCount: Int, panelWidth: CGFloat) -> Bool {
    panelWidth < 180 && characterCount > 55
}
```

Retain parchment background and page border, with the canvas consuming the full interior. When `usesPageCallout` is true, render that overlay as an opaque 13-point minimum callout at the nearest page edge with width capped at 280 points; it may cover decorative art but must remain inside the canvas and outside navigation. Do not clip, truncate, shrink below 13 points, or introduce a `ScrollView`.

- [ ] **Step 6: Test and commit**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreBookLayoutTests -only-testing:DockBarHeroTests/LoreMangaLayoutTests -only-testing:DockBarHeroTests/LoreCatalogTests -only-testing:DockBarHeroTests/LoreContextSheetTests
git add DockBarHero/Lore/LoreMangaPanelShape.swift DockBarHero/Lore/LoreMangaTextOverlay.swift DockBarHero/Lore/LorePageView.swift DockBarHero/Lore/LoreBookLayout.swift DockBarHeroTests/LoreBookLayoutTests.swift DockBarHero.xcodeproj
git commit -m "feat: render multi-panel manga lore pages"
```

Expected: selected tests pass.

---

### Task 6: Verify Dialogue, Accessibility Order, and Fallbacks

**Files:**
- Modify: `DockBarHeroTests/SpokenDialogueCatalogTests.swift`
- Modify: `DockBarHeroTests/LoreProgressResolverTests.swift`
- Modify: `DockBarHeroTests/LoreCatalogTests.swift`
- Modify: `DockBarHero/Lore/Resources/SpokenDialogue.json` only for a proven missing existing-line cue.

**Interfaces:**
- Consumes: overlay cue IDs and resolved copy.
- Produces: cross-catalog proof that visible text, TTS, clean mode, and adult fallback agree.

- [ ] **Step 1: Add cross-catalog tests**

```swift
func testEveryOverlayDialogueCueExistsInSpokenSidecar() throws {
    let lore = try LoreCatalog.bundled()
    let spoken = try SpokenDialogueCatalog.bundled(loreCatalog: lore)
    let cueIDs = Set(spoken.cues.map(\.id))
    for overlay in lore.pages.flatMap({ $0.composition.textOverlays }) {
        if let cueID = overlay.dialogueCueID {
            XCTAssertTrue(cueIDs.contains(cueID), cueID)
        }
    }
}
```

Also assert overlay reading order is stable, clean overlays contain no `fuck`, Level 20 adult mode chooses adult motion plus safe context, and required text remains nonempty.

- [ ] **Step 2: Run tests, correct only proven mappings, and commit**

Use only existing matching cues: `prologue.book.wrong-way`, `prologue.book.arrow-denial`, `book.level1.summary`, `kevin.not-kevin`, `book.level5.summary`, `kevin.supervisor`, `book.level10.summary`, `book.level15.summary`, `brick.policy-warning`, `book.level20.summary`, and `mercy.therapy-referral`. Do not voice sound effects or incidental background lines.

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/SpokenDialogueCatalogTests -only-testing:DockBarHeroTests/LoreProgressResolverTests -only-testing:DockBarHeroTests/LoreCatalogTests
git add DockBarHero/Lore/Resources/SpokenDialogue.json DockBarHeroTests/SpokenDialogueCatalogTests.swift DockBarHeroTests/LoreProgressResolverTests.swift DockBarHeroTests/LoreCatalogTests.swift
git commit -m "test: verify manga dialogue and fallback contracts"
```

Expected: all selected tests pass. Omit unchanged paths from the commit.

---

### Task 7: Run Full Automated Verification

**Files:**
- Modify: only files directly implicated by fresh failures.

- [ ] **Step 1: Run worktree and Markdown checks**

```bash
git diff --check
git status --short
```

- [ ] **Step 2: Run the full Swift suite**

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64'
```

Expected: zero failures.

- [ ] **Step 3: Run sprite-pipeline tests and clean build**

```bash
python3 -m unittest discover -s scripts/tests -p 'test_*.py'
xcodebuild clean build -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO
```

Expected: all Python tests pass and `BUILD SUCCEEDED`.

- [ ] **Step 4: Run the context guard**

```bash
python3 /Users/n3kr0/.codex/skills/maintaining-project-context/scripts/context_guard.py check --root .
```

Expected: no structural or line-limit violations.

- [ ] **Step 5: Repair only branch-caused regressions**

Repeat the exact failing command, then repeat Steps 2–4. Do not modify unrelated gameplay, persistence, production sprites, or user changes.

---

### Task 8: Launch One Exact App and Record Visual QA

**Files:**
- Modify: `docs/qa/review-packets/lore-manga-vertical-slice.md`
- Modify: `PROJECT.md`

- [ ] **Step 1: Launch exactly one worktree instance**

```bash
pkill -x DockBarHero || true
./script/build_and_run.sh --verify -- --open-book
pgrep -fl '/lore-manga-vertical-slice/.*/DockBarHero.*--open-book'
```

Expected: exactly one matching process from this worktree.

- [ ] **Step 2: Inspect all pages wide and compact**

Confirm: five-to-seven panels; current page on right in the spread; exactly one moving panel; static surrounding panels; obvious RTL sequence; no bottom paragraph; no floating text; opaque readable balloons; coherent identities; stable resizing; and unclipped controls.

- [ ] **Step 3: Exercise behavioral states**

Verify compact layout, Reduced Motion, clean language, safe/adult selection, close/reopen, page turning, and Level 20 adult motion with safe context fallback. Verify the prologue's arrow tampering, attempted redaction, insult, and denial read as a panel sequence. With TTS off, confirm silence; after explicit opt-in, confirm Book-open-only speech and immediate stop on close.

- [ ] **Step 4: Update evidence and current truth**

Record exact test counts, Python counts, clean-build result, executable path/PID, direct visual observations, and unexercised checks in the QA packet. Update `PROJECT.md` with new plan/spec/art paths and verified state, keeping it at or below 150 lines.

- [ ] **Step 5: Final checks and verification commit**

```bash
git diff --check
python3 /Users/n3kr0/.codex/skills/maintaining-project-context/scripts/context_guard.py check --root .
git add docs/qa/review-packets/lore-manga-vertical-slice.md PROJECT.md DockBarHero.xcodeproj
git commit -m "docs: record multi-panel manga verification"
git status --short
```

Expected: checks pass and the worktree is clean.

---

## Final Review Checklist

- [ ] Every page visibly contains five to seven panels.
- [ ] Every page has exactly one animated panel and four to six distinct still beats.
- [ ] All four irregular templates are deterministic, in bounds, and non-overlapping.
- [ ] Text reads RTL, stays opaque and legible, and never floats while scrolling.
- [ ] Narration boxes and character speech balloons are visually distinct.
- [ ] Clean copy, adult fallback, TTS cues, accessibility order, and Reduced Motion are verified.
- [ ] All six context atlases are bundled, text-free, 1536x1024, and recorded in the manifest.
- [ ] Full Swift tests, Python sprite tests, clean build, exact launch, and context guard pass freshly.
- [ ] Manual QA claims do not exceed direct observation.
