# Lore Book Fixed Two-Page Spread Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the difficult-to-read, independently scrolling lore pages with a stable, high-contrast two-page manga spread whose text, reactions, and controls never shift one another.

**Architecture:** Add a small pure layout policy that selects the default two-page spread and the existing compact single-page fallback from available detail width. Refactor each page into a fixed artwork region plus a fixed caption card, then move Book reactions out of normal layout flow into an anchored overlay and open the management window large enough to show the spread by default.

**Tech Stack:** Swift 6, SwiftUI, AppKit, XCTest, XcodeGen, macOS 26

## Global Constraints

- Preserve the approved right-to-left reading order: the current page is on the right and the following page is on the left.
- Wide windows show two pages; compact windows may show one page, as required by the approved manga design.
- No `ScrollView` may wrap a lore page or its artwork/caption composition.
- Page title and body must use explicit high-contrast foreground colors on an opaque caption background.
- Book reaction text must be an overlay with no effect on header, page, or control-rail geometry.
- Book reactions may overlap a page margin but must never cover the bottom navigation permanently.
- Existing lore animation, reduced-motion behavior, text selection, censorship, adult-art selection, TTS opt-in, Replay, Skip, and reversed volume behavior must remain unchanged.
- Visual page arrows remain right-to-left jokes; accessibility labels must say `Next Page` and `Previous Page` plainly.
- Default management-window sizing must reveal the two-page spread without removing the approved compact fallback.
- Do not add a snapshot-testing dependency for this focused repair.

---

## File Structure

- Create `DockBarHero/Lore/LoreBookLayout.swift`: pure width, caption-height, and page-pairing policy shared by the reader view and unit tests.
- Create `DockBarHero/Lore/BookReactionBubble.swift`: noninteractive, bounded reaction overlay styling.
- Modify `DockBarHero/Lore/LorePageView.swift`: fixed artwork/caption composition with no scrolling and explicit contrast.
- Modify `DockBarHero/Lore/LoreBookView.swift`: deterministic spread selection, fixed header/control shelf, reaction overlay, and explicit accessibility labels.
- Modify `DockBarHero/App/AppDelegate.swift`: larger initial management-window content size while preserving the existing minimum size.
- Create `DockBarHeroTests/LoreBookLayoutTests.swift`: focused unit coverage for spread thresholds, right-to-left page pairing, bounds, and caption sizing.
- Modify `docs/qa/review-packets/lore-manga-vertical-slice.md`: record fresh automated results and the new live visual QA evidence only after it is actually observed.
- Modify `PROJECT.md`: parent orchestrator only, after all verification is complete, to replace the stale locked-session QA status with current truth.

### Task 1: Lock the responsive spread policy with tests

**Files:**
- Create: `DockBarHeroTests/LoreBookLayoutTests.swift`
- Create: `DockBarHero/Lore/LoreBookLayout.swift`

**Interfaces:**
- Produces: `LoreBookLayout.minimumSpreadWidth: CGFloat`
- Produces: `LoreBookLayout.mode(forContentWidth:) -> LoreBookLayout.Mode`
- Produces: `LoreBookLayout.spread(pageCount:currentIndex:) -> LoreBookLayout.Spread?`
- Produces: `LoreBookLayout.captionHeight(forPageHeight:) -> CGFloat`
- Consumes: no application state or SwiftUI environment.

- [ ] **Step 1: Write the failing layout-policy tests**

Create `DockBarHeroTests/LoreBookLayoutTests.swift`:

```swift
import XCTest
@testable import DockBarHero

final class LoreBookLayoutTests: XCTestCase {
    func testWideContentUsesTwoPageSpreadAndCompactContentUsesSinglePage() {
        XCTAssertEqual(
            LoreBookLayout.mode(forContentWidth: LoreBookLayout.minimumSpreadWidth),
            .spread
        )
        XCTAssertEqual(
            LoreBookLayout.mode(forContentWidth: LoreBookLayout.minimumSpreadWidth - 1),
            .singlePage
        )
    }

    func testSpreadPlacesCurrentPageOnRightAndFollowingPageOnLeft() {
        XCTAssertEqual(
            LoreBookLayout.spread(pageCount: 6, currentIndex: 2),
            .init(leftIndex: 3, rightIndex: 2)
        )
    }

    func testFinalSpreadUsesBlankLeftPage() {
        XCTAssertEqual(
            LoreBookLayout.spread(pageCount: 6, currentIndex: 5),
            .init(leftIndex: nil, rightIndex: 5)
        )
    }

    func testSpreadRejectsEmptyOrOutOfBoundsSelection() {
        XCTAssertNil(LoreBookLayout.spread(pageCount: 0, currentIndex: 0))
        XCTAssertNil(LoreBookLayout.spread(pageCount: 2, currentIndex: -1))
        XCTAssertNil(LoreBookLayout.spread(pageCount: 2, currentIndex: 2))
    }

    func testCaptionHeightIsBoundedAcrossSupportedWindowHeights() {
        XCTAssertEqual(LoreBookLayout.captionHeight(forPageHeight: 300), 150)
        XCTAssertEqual(LoreBookLayout.captionHeight(forPageHeight: 500), 180)
        XCTAssertEqual(LoreBookLayout.captionHeight(forPageHeight: 900), 190)
    }
}
```

- [ ] **Step 2: Generate the project and run the new tests to verify they fail**

Run:

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreBookLayoutTests
```

Expected: build failure because `LoreBookLayout` does not exist.

- [ ] **Step 3: Implement the pure layout policy**

Create `DockBarHero/Lore/LoreBookLayout.swift`:

```swift
import CoreGraphics

enum LoreBookLayout {
    enum Mode: Equatable {
        case spread
        case singlePage
    }

    struct Spread: Equatable {
        let leftIndex: Int?
        let rightIndex: Int
    }

    static let minimumSpreadWidth: CGFloat = 720

    static func mode(forContentWidth width: CGFloat) -> Mode {
        width >= minimumSpreadWidth ? .spread : .singlePage
    }

    static func spread(pageCount: Int, currentIndex: Int) -> Spread? {
        guard pageCount > 0, (0..<pageCount).contains(currentIndex) else { return nil }
        let nextIndex = currentIndex + 1
        return Spread(
            leftIndex: nextIndex < pageCount ? nextIndex : nil,
            rightIndex: currentIndex
        )
    }

    static func captionHeight(forPageHeight height: CGFloat) -> CGFloat {
        min(190, max(150, height * 0.36))
    }
}
```

- [ ] **Step 4: Regenerate and rerun the focused tests**

Run:

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreBookLayoutTests
```

Expected: 5 tests pass with zero failures.

- [ ] **Step 5: Commit the tested layout policy**

```bash
git add DockBarHero/Lore/LoreBookLayout.swift DockBarHeroTests/LoreBookLayoutTests.swift DockBarHero.xcodeproj/project.pbxproj
git commit -m "test: define stable lore spread layout"
```

### Task 2: Replace scrolling pages with fixed artwork and caption regions

**Files:**
- Modify: `DockBarHero/Lore/LorePageView.swift`

**Interfaces:**
- Consumes: `LoreBookLayout.captionHeight(forPageHeight:)` from Task 1.
- Preserves: `LorePageView(page:isBookOpen:)` initializer used by `LoreBookView`.
- Preserves: `LoreSpriteSheet.frames(named:frameCount:)` and the current `TimelineView` animation path.

- [ ] **Step 1: Add a failing behavioral test for fixed page regions**

Append this test to `DockBarHeroTests/LoreBookLayoutTests.swift`:

```swift
func testPageRegionsConsumeTheAvailableHeightWithoutOverlap() {
    let regions = LoreBookLayout.pageRegions(forPageHeight: 500, dividerHeight: 1)

    XCTAssertEqual(regions.artworkHeight, 319)
    XCTAssertEqual(regions.dividerHeight, 1)
    XCTAssertEqual(regions.captionHeight, 180)
    XCTAssertEqual(
        regions.artworkHeight + regions.dividerHeight + regions.captionHeight,
        500
    )
}
```

This tests the production geometry contract used by `LorePageView`: artwork, divider, and caption receive fixed, non-overlapping regions that exactly consume the page height.

- [ ] **Step 2: Run the region test to verify it fails before implementation**

Run:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreBookLayoutTests/testPageRegionsConsumeTheAvailableHeightWithoutOverlap
```

Expected: build failure because `LoreBookLayout.pageRegions(forPageHeight:dividerHeight:)` does not exist.

- [ ] **Step 3: Implement the tested fixed-region calculation**

Add to `LoreBookLayout.swift`:

```swift
struct PageRegions: Equatable {
    let artworkHeight: CGFloat
    let dividerHeight: CGFloat
    let captionHeight: CGFloat
}

static func pageRegions(forPageHeight height: CGFloat, dividerHeight: CGFloat) -> PageRegions {
    let safeHeight = max(0, height)
    let safeDividerHeight = min(max(0, dividerHeight), safeHeight)
    let captionHeight = min(
        Self.captionHeight(forPageHeight: safeHeight),
        safeHeight - safeDividerHeight
    )
    return PageRegions(
        artworkHeight: safeHeight - safeDividerHeight - captionHeight,
        dividerHeight: safeDividerHeight,
        captionHeight: captionHeight
    )
}
```

- [ ] **Step 4: Refactor `LorePageView` into a fixed composition**

Replace the `body` and add the caption helpers below while leaving the existing sprite loading and `artwork` animation implementation intact:

```swift
var body: some View {
    GeometryReader { geometry in
        let regions = LoreBookLayout.pageRegions(
            forPageHeight: geometry.size.height,
            dividerHeight: 1
        )

        VStack(spacing: 0) {
            artwork
                .frame(maxWidth: .infinity)
                .frame(height: regions.artworkHeight)
                .background(Color.black.opacity(0.9))
                .clipped()
                .accessibilityLabel(page.accessibilityDescription)

            Divider()
                .frame(height: regions.dividerHeight)
                .overlay(Color.black.opacity(0.35))

            caption
                .frame(height: regions.captionHeight, alignment: .topLeading)
        }
        .background(Color(red: 0.96, green: 0.89, blue: 0.72))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.black.opacity(0.5), lineWidth: 2)
        )
    }
    .task(id: page.spriteSheetName) {
        frames = (try? LoreSpriteSheet.frames(
            named: page.spriteSheetName,
            frameCount: page.frameCount
        )) ?? []
    }
}

private var caption: some View {
    ViewThatFits(in: .vertical) {
        captionContent(titleSize: 22, bodySize: 15, spacing: 8, padding: 16)
        captionContent(titleSize: 19, bodySize: 13, spacing: 6, padding: 12)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Color(red: 0.98, green: 0.93, blue: 0.82))
    .foregroundStyle(Color(red: 0.12, green: 0.08, blue: 0.06))
    .textSelection(.enabled)
}

private func captionContent(
    titleSize: CGFloat,
    bodySize: CGFloat,
    spacing: CGFloat,
    padding: CGFloat
) -> some View {
    VStack(alignment: .leading, spacing: spacing) {
        Text(page.title)
            .font(.system(size: titleSize, weight: .black, design: .serif))
            .fixedSize(horizontal: false, vertical: true)
        Text(page.body)
            .font(.system(size: bodySize, weight: .medium, design: .serif))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }
    .padding(padding)
}
```

Update `frameImage(_:)` so the panel animation fills its allotted artwork region without altering caption geometry:

```swift
private func frameImage(_ image: CGImage) -> some View {
    Image(decorative: image, scale: 1)
        .resizable()
        .scaledToFit()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}
```

- [ ] **Step 5: Run the layout tests and existing sprite-sheet tests**

Run:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' \
  -only-testing:DockBarHeroTests/LoreBookLayoutTests \
  -only-testing:DockBarHeroTests/LoreSpriteSheetTests
```

Expected: all selected tests pass; the region test confirms that fixed page sections consume the available height exactly.

- [ ] **Step 6: Commit the fixed page composition**

```bash
git add DockBarHero/Lore/LorePageView.swift DockBarHeroTests/LoreBookLayoutTests.swift
git commit -m "fix: stabilize lore page captions"
```

### Task 3: Anchor Book reactions and make the spread the default presentation

**Files:**
- Create: `DockBarHero/Lore/BookReactionBubble.swift`
- Modify: `DockBarHero/Lore/LoreBookView.swift`
- Modify: `DockBarHero/App/AppDelegate.swift:8-17`

**Interfaces:**
- Consumes: `LoreBookLayout.mode(forContentWidth:)` and `LoreBookLayout.spread(pageCount:currentIndex:)` from Task 1.
- Consumes: `LoreReaderController.reactionText` without changing controller behavior.
- Produces: `BookReactionBubble(text:)`, a pointer-transparent overlay with bounded width.
- Preserves: all existing `LoreReaderController` calls and the `BookVolumePotentiometer` callback.

- [ ] **Step 1: Add a failing test against production window-sizing constants**

Append to `LoreBookLayoutTests.swift`:

```swift
func testDefaultManagementWindowCanShowSpreadBesideSidebar() {
    let maximumSidebarWidth: CGFloat = 230

    XCTAssertEqual(ManagementWindowSizing.initialContentSize.width, 1_100)
    XCTAssertEqual(ManagementWindowSizing.initialContentSize.height, 720)
    XCTAssertEqual(ManagementWindowSizing.minimumSize.width, 720)
    XCTAssertEqual(ManagementWindowSizing.minimumSize.height, 520)
    XCTAssertGreaterThanOrEqual(
        ManagementWindowSizing.initialContentSize.width - maximumSidebarWidth,
        LoreBookLayout.minimumSpreadWidth
    )
}
```

This protects the product requirement using the same production constants consumed by `ManagementWindowController`.

- [ ] **Step 2: Run the default-presentation test to verify it fails before implementation**

Run:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreBookLayoutTests
```

Expected: build failure because `ManagementWindowSizing` does not exist.

- [ ] **Step 3: Create the anchored reaction bubble**

Create `DockBarHero/Lore/BookReactionBubble.swift`:

```swift
import SwiftUI

struct BookReactionBubble: View {
    let text: String

    var body: some View {
        if !text.isEmpty {
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded).italic())
                .foregroundStyle(Color.black)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: 320, alignment: .leading)
                .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                .allowsHitTesting(false)
                .accessibilityLabel("The Book says: \(text)")
        }
    }
}
```

- [ ] **Step 4: Rebuild the reader shell around fixed geometry**

In `LoreBookView.swift`:

1. Wrap the existing `VStack` in `ZStack(alignment: .topTrailing)`.
2. Remove the `reactionText` view from `header` entirely.
3. Give `header` a fixed height of `62` points.
4. Replace `ViewThatFits` with a `GeometryReader` that uses `LoreBookLayout.mode(forContentWidth:)`.
5. Give the content region `layoutPriority(1)` so it receives remaining height.
6. Overlay `BookReactionBubble(text:)` below the header with trailing padding and no hit testing.
7. Keep the bottom control shelf outside the content geometry.

The resulting body and content selector should be:

```swift
var body: some View {
    ZStack(alignment: .topTrailing) {
        VStack(spacing: 0) {
            header
                .frame(height: 62)
            Divider()

            if model.lorePages.isEmpty {
                ContentUnavailableView("No Pages Yet", systemImage: "book.closed")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geometry in
                    readerContent(for: LoreBookLayout.mode(forContentWidth: geometry.size.width))
                }
                .layoutPriority(1)
            }

            Divider()
            controls
        }

        BookReactionBubble(text: controller.reactionText)
            .padding(.top, 74)
            .padding(.trailing, 18)
    }
    .background(Color(red: 0.20, green: 0.08, blue: 0.06))
    .task {
        arrowPointsWrongWay = true
        try? await Task.sleep(for: .milliseconds(900))
        arrowPointsWrongWay = false
        controller.arrowCorrected()
    }
}

@ViewBuilder
private func readerContent(for mode: LoreBookLayout.Mode) -> some View {
    switch mode {
    case .spread:
        twoPageSpread
    case .singlePage:
        singlePage
    }
}
```

Replace `twoPageSpread` with the tested pairing policy:

```swift
private var twoPageSpread: some View {
    Group {
        if let spread = LoreBookLayout.spread(
            pageCount: model.lorePages.count,
            currentIndex: currentIndex
        ) {
            HStack(spacing: 3) {
                if let leftIndex = spread.leftIndex {
                    page(model.lorePages[leftIndex])
                } else {
                    Color(red: 0.93, green: 0.85, blue: 0.68)
                }
                page(model.lorePages[spread.rightIndex])
            }
        }
    }
    .padding(10)
}
```

Keep `singlePage` only as the approved compact fallback and constrain it so it does not stretch edge-to-edge:

```swift
private var singlePage: some View {
    page(model.lorePages[currentIndex])
        .frame(maxWidth: 560)
        .padding(10)
        .frame(maxWidth: .infinity)
}
```

Remove the old `.frame(minWidth:minHeight:)` calls from both page modes. Add explicit accessibility labels to the existing navigation buttons:

```swift
Button("Next ◀") { select(index: currentIndex + 1) }
    .accessibilityLabel("Next Page")

Button("Previous ▶") { select(index: currentIndex - 1) }
    .accessibilityLabel("Previous Page")
```

Give `controls` a stable minimum height of `92` points after its background modifier:

```swift
.frame(minHeight: 92)
```

- [ ] **Step 5: Make the management window reveal the spread by default using tested production constants**

Add this production sizing policy above `ManagementWindowController` in `DockBarHero/App/AppDelegate.swift`:

```swift
enum ManagementWindowSizing {
    static let initialContentSize = NSSize(width: 1_100, height: 720)
    static let minimumSize = NSSize(width: 720, height: 520)
}
```

Then update `ManagementWindowController.init(model:)` to consume those values:

```swift
window.setContentSize(ManagementWindowSizing.initialContentSize)
window.minSize = ManagementWindowSizing.minimumSize
```

The unchanged minimum retains the approved single-page fallback for deliberately compact windows; the new initial size makes the two-page spread the normal first impression.

- [ ] **Step 6: Run the focused lore UI-policy and controller tests**

Run:

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' \
  -only-testing:DockBarHeroTests/LoreBookLayoutTests \
  -only-testing:DockBarHeroTests/LoreReaderControllerTests \
  -only-testing:DockBarHeroTests/BookVolumePotentiometerTests
```

Expected: all selected tests pass with zero failures.

- [ ] **Step 7: Commit the stable reader shell**

```bash
git add DockBarHero/Lore/BookReactionBubble.swift DockBarHero/Lore/LoreBookView.swift DockBarHero/App/AppDelegate.swift DockBarHeroTests/LoreBookLayoutTests.swift DockBarHero.xcodeproj/project.pbxproj
git commit -m "fix: anchor the two-page lore reader"
```

### Task 4: Verify readability, stability, and preserved behavior

**Files:**
- Modify: `docs/qa/review-packets/lore-manga-vertical-slice.md`
- Modify: `PROJECT.md` (parent orchestrator only)

**Interfaces:**
- Consumes: the complete reader from Tasks 1-3.
- Produces: current automated and manual evidence without converting one into the other.

- [ ] **Step 1: Run the complete automated test suite**

Run:

```bash
xcodegen generate
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64'
```

Expected: the full suite passes with zero failures. Record the fresh test count from the command output rather than copying the previous 291-test claim.

- [ ] **Step 2: Run a clean unsigned build**

Run:

```bash
xcodebuild clean build -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Launch the verified build**

Run:

```bash
./script/build_and_run.sh --verify
```

Expected: the script reports a live DockBarHero PID.

- [ ] **Step 4: Perform live wide-window visual QA**

Open the management window and choose Book. Verify and capture evidence for every item:

1. The initial window displays two pages, with the current page on the right.
2. Both caption cards remain fixed while pointer, trackpad, and wheel input move over them; no page scroll indicator appears.
3. The longest current entry, `Level 100,000: The Finaler Ending`, displays its complete title and body without clipping.
4. Page title and body remain clearly readable against opaque caption cards in both light and dark system appearances.
5. Moving the volume potentiometer changes the Book reaction without moving the header, either page, or the bottom controls.
6. Waiting for the lying arrow to correct itself changes only the arrow and anchored reaction bubble.
7. Next and Previous preserve right-to-left page placement.
8. The reaction bubble cannot intercept page, navigation, Replay, Skip, or potentiometer input.

- [ ] **Step 5: Perform live compact and behavior-regression QA**

Resize the management window to its minimum and back to the default width. Verify:

1. Compact width shows one centered page with the complete caption.
2. Returning to wide width restores the two-page spread without changing the selected page.
3. Reduced Motion freezes the illustration on its static frame.
4. With spoken dialogue disabled, the potentiometer produces only the visual Book giggle.
5. With spoken dialogue enabled, Replay, Skip, volume preview, page-turn interruption, Book-close interruption, and app-deactivation silence behave as before.
6. VoiceOver announces `Next Page`, `Previous Page`, and the honest effective Book volume.

- [ ] **Step 6: Update the QA packet with observed evidence only**

In `docs/qa/review-packets/lore-manga-vertical-slice.md`, add:

- the branch and final commit tested;
- the fresh focused and full-suite counts;
- clean-build and launch results;
- each manual item above marked pass or still pending;
- screenshot paths for wide and compact layouts if captured;
- any audio/VoiceOver item not actually heard or inspected left explicitly pending.

- [ ] **Step 7: Update project context after the milestone is verified**

The parent orchestrator updates `PROJECT.md` to state that the fixed spread is implemented and to replace the old locked-session QA language with the exact live evidence from Steps 4-6. Run:

```bash
python3 /Users/n3kr0/.codex/skills/maintaining-project-context/scripts/context_guard.py check --root .
```

Expected: `AGENTS.md` and `PROJECT.md` remain within their line limits and the context check passes.

- [ ] **Step 8: Commit the verified QA record**

```bash
git add docs/qa/review-packets/lore-manga-vertical-slice.md PROJECT.md
git commit -m "docs: verify fixed lore spread"
```

## Self-Review

- Spec coverage: two-page default, compact fallback, right-to-left pairing, fixed captions, explicit contrast, anchored reactions, fixed controls, accessibility labels, animation preservation, and live audio/readability checks each map to a task above.
- Placeholder scan: the plan contains no deferred implementation placeholders; every code-changing step includes exact code or exact replacement rules.
- Test-quality scan: layout behavior is tested through production geometry policy, and default window behavior is tested through the same production sizing constants used by AppKit; no source-text or duplicated-local-value assertions remain.
- Type consistency: `LoreBookLayout.Mode`, `LoreBookLayout.Spread`, `mode(forContentWidth:)`, `spread(pageCount:currentIndex:)`, and `captionHeight(forPageHeight:)` use the same signatures in tests and consuming views.
