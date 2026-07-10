# DockBarHero Phase 0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and verify a native macOS technical prototype that renders a low-overhead, transparent, click-through animated rail near the Dock.

**Architecture:** SwiftUI owns the app lifecycle and menu bar, a narrow AppKit bridge owns a non-activating `NSPanel`, and SpriteKit renders the placeholder scene. Pure Swift state and placement units drive the platform adapters so behavior can be tested without relying on a live desktop.

**Tech Stack:** Swift 6.3.2, SwiftUI, AppKit, SpriteKit, CoreGraphics, OSLog, XCTest, Xcode 26.5, XcodeGen as a development-only project generator.

## Global Constraints

- Target only the current Apple M5 Max MacBook Pro running macOS 26.5.1 on `arm64`.
- Set the macOS deployment target to 26.0.
- Use only documented macOS APIs and request no Accessibility, Screen Recording, or other privacy permission.
- Use no third-party runtime dependencies.
- The rail width is 66 percent of visible screen width, clamped to 720...1,400 points and never wider than the screen; height is exactly 96 points.
- Center the rail horizontally with an 8-point bottom offset.
- Keep the rail fixed during auto-hidden Dock reveal and conceal transitions; temporary Dock overlap is accepted.
- Show the rail on normal Spaces and hide it while another app is fullscreen.
- Default every launch to shown, animating, and click-through passive mode; do not persist state.
- Cap rendering at 30 FPS and suspend it while hidden or paused.
- Do not add gameplay, saves, Steamworks, networking, production assets, or packaging work.
- Use `Logger` without recording window titles, user input, application content, or other private data.
- Use test-first development and run the focused test target before every task commit.
- Use `gpt-5.6-luna` for bounded implementation, `gpt-5.6-terra` for integration and task review, and `gpt-5.6-sol` only for architecture-sensitive escalation and final whole-branch review.
- Every task requires an independent spec/code-quality review; Critical and Important findings must be fixed and re-reviewed before proceeding.

## File Structure

```text
DockBarHero/
  App/
    AppDelegate.swift                 # Creates live dependencies after app launch
    AppModel.swift                    # Reduces user/environment events into applied state
    DockBarHeroApp.swift              # SwiftUI app and MenuBarExtra lifecycle
    MenuBarContent.swift              # State-derived menu commands
  Core/
    OverlayPlacement.swift            # Pure geometry and last-valid-frame behavior
    OverlayState.swift                # Pure state, actions, and derived behavior
  Environment/
    EnvironmentMonitor.swift          # Debounced workspace/screen notifications
    FullscreenWindowClassifier.swift  # Pure fullscreen classification and CGWindow adapter
  Overlay/
    AppKitScreenProvider.swift         # Stable target-screen and Dock policy snapshot
    OverlayPanel.swift                # Non-activating NSPanel behavior
    OverlayWindowController.swift     # Applies frame, visibility, and input state
  Rendering/
    PrototypeScene.swift              # Placeholder SpriteKit animation and hit reaction
    PrototypeSceneHost.swift          # SKView lifecycle and render controls
  Support/
    AppLog.swift                      # Privacy-conscious Logger categories
DockBarHeroTests/
  AppModelTests.swift
  EnvironmentMonitorTests.swift
  FullscreenWindowClassifierTests.swift
  OverlayPlacementTests.swift
  OverlayStateTests.swift
  OverlayWindowControllerTests.swift
  PrototypeSceneHostTests.swift
docs/qa/phase-0-checklist.md
scripts/measure-process.sh
.gitignore
project.yml
DockBarHero.xcodeproj/                # Generated and committed from project.yml
```

---

### Task 1: Project Foundation and Overlay State

**Owner/model:** Fresh `gpt-5.6-luna` implementer; `gpt-5.6-terra` reviewer.

**Files:**

- Create: `.gitignore`
- Create: `project.yml`
- Generate: `DockBarHero.xcodeproj/`
- Create: `DockBarHero/App/DockBarHeroApp.swift`
- Create: `DockBarHero/Core/OverlayState.swift`
- Create: `DockBarHero/Support/AppLog.swift`
- Create: `DockBarHeroTests/OverlayStateTests.swift`

**Interfaces:**

- Produces: `OverlayState`, `OverlayAction`, `ManualVisibility`, `EnvironmentVisibility`, `AnimationMode`, and `InputMode`.
- Produces: `AppLog` categories used by every platform task.
- Consumes: no prior task interfaces.

- [ ] **Step 1: Create the project definition and failing state tests**

Create `.gitignore`:

```gitignore
.DS_Store
.build/
DerivedData/
*.xcuserstate
xcuserdata/
.superpowers/
.worktrees/
```

Create `project.yml`:

```yaml
name: DockBarHero
options:
  bundleIdPrefix: com.n3kr0nom1c0n
  createIntermediateGroups: true
  deploymentTarget:
    macOS: "26.0"
settings:
  base:
    SWIFT_VERSION: "6.0"
    SWIFT_STRICT_CONCURRENCY: complete
    MACOSX_DEPLOYMENT_TARGET: "26.0"
targets:
  DockBarHero:
    type: application
    platform: macOS
    sources:
      - DockBarHero
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.n3kr0nom1c0n.DockBarHero
        PRODUCT_NAME: DockBarHero
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_CFBundleDisplayName: DockBarHero
        INFOPLIST_KEY_LSUIElement: YES
        MARKETING_VERSION: 0.1.0
        CURRENT_PROJECT_VERSION: 1
  DockBarHeroTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - DockBarHeroTests
    dependencies:
      - target: DockBarHero
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
schemes:
  DockBarHero:
    build:
      targets:
        DockBarHero: all
        DockBarHeroTests:
          - test
    test:
      gatherCoverageData: true
      targets:
        - DockBarHeroTests
```

Create the temporary buildable shell in `DockBarHero/App/DockBarHeroApp.swift`:

```swift
import AppKit
import SwiftUI

@main
struct DockBarHeroApp: App {
    var body: some Scene {
        MenuBarExtra("DockBarHero", systemImage: "sparkles") {
            Text("Phase 0")
            Divider()
            Button("Quit DockBarHero") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
```

Create `DockBarHeroTests/OverlayStateTests.swift` before the production state file:

```swift
import XCTest
@testable import DockBarHero

final class OverlayStateTests: XCTestCase {
    func testDefaultsAreShownAnimatingAndPassive() {
        let state = OverlayState()

        XCTAssertEqual(state.manualVisibility, .shown)
        XCTAssertEqual(state.environmentVisibility, .normalSpace)
        XCTAssertEqual(state.animationMode, .running)
        XCTAssertEqual(state.inputMode, .passive)
        XCTAssertTrue(state.isEffectivelyVisible)
        XCTAssertTrue(state.shouldAnimate)
        XCTAssertFalse(state.acceptsInput)
    }

    func testManualHideWinsAcrossEnvironmentChanges() {
        var state = OverlayState()

        state.apply(.setManualVisibility(.hidden))
        state.apply(.setEnvironmentVisibility(.fullscreen))
        state.apply(.setEnvironmentVisibility(.normalSpace))

        XCTAssertFalse(state.isEffectivelyVisible)
        XCTAssertEqual(state.manualVisibility, .hidden)
    }

    func testFullscreenSuppressesVisibilityAndAnimation() {
        var state = OverlayState(inputMode: .interactive)

        state.apply(.setEnvironmentVisibility(.fullscreen))

        XCTAssertFalse(state.isEffectivelyVisible)
        XCTAssertFalse(state.shouldAnimate)
        XCTAssertFalse(state.acceptsInput)
    }

    func testPauseAndInteractiveActionsAreIndependent() {
        var state = OverlayState()

        state.apply(.setAnimationMode(.paused))
        state.apply(.setInputMode(.interactive))

        XCTAssertFalse(state.shouldAnimate)
        XCTAssertTrue(state.acceptsInput)
    }
}
```

- [ ] **Step 2: Generate the project and verify the tests fail**

Install XcodeGen only when `command -v xcodegen` fails:

```bash
brew install xcodegen
```

Generate and test:

```bash
xcodegen generate
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS' -derivedDataPath .build/DerivedData test CODE_SIGNING_ALLOWED=NO
```

Expected: build fails because `OverlayState` and related types do not exist.

- [ ] **Step 3: Implement the minimal state model and logging categories**

Create `DockBarHero/Core/OverlayState.swift`:

```swift
import Foundation

enum ManualVisibility: Equatable {
    case shown
    case hidden
}

enum EnvironmentVisibility: Equatable {
    case normalSpace
    case fullscreen
}

enum AnimationMode: Equatable {
    case running
    case paused
}

enum InputMode: Equatable {
    case passive
    case interactive
}

enum OverlayAction: Equatable {
    case setManualVisibility(ManualVisibility)
    case setEnvironmentVisibility(EnvironmentVisibility)
    case setAnimationMode(AnimationMode)
    case setInputMode(InputMode)
}

struct OverlayState: Equatable {
    var manualVisibility: ManualVisibility = .shown
    var environmentVisibility: EnvironmentVisibility = .normalSpace
    var animationMode: AnimationMode = .running
    var inputMode: InputMode = .passive

    var isEffectivelyVisible: Bool {
        manualVisibility == .shown && environmentVisibility == .normalSpace
    }

    var shouldAnimate: Bool {
        isEffectivelyVisible && animationMode == .running
    }

    var acceptsInput: Bool {
        isEffectivelyVisible && inputMode == .interactive
    }

    mutating func apply(_ action: OverlayAction) {
        switch action {
        case .setManualVisibility(let value):
            manualVisibility = value
        case .setEnvironmentVisibility(let value):
            environmentVisibility = value
        case .setAnimationMode(let value):
            animationMode = value
        case .setInputMode(let value):
            inputMode = value
        }
    }
}
```

Create `DockBarHero/Support/AppLog.swift`:

```swift
import OSLog

enum AppLog {
    private static let subsystem = "com.n3kr0nom1c0n.DockBarHero"

    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    static let overlay = Logger(subsystem: subsystem, category: "overlay")
    static let placement = Logger(subsystem: subsystem, category: "placement")
    static let environment = Logger(subsystem: subsystem, category: "environment")
    static let scene = Logger(subsystem: subsystem, category: "scene")
}
```

- [ ] **Step 4: Run the focused tests and build**

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS' -derivedDataPath .build/DerivedData test CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/OverlayStateTests
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/DerivedData build CODE_SIGNING_ALLOWED=NO
```

Expected: both commands finish with `** TEST SUCCEEDED **` and `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add .gitignore project.yml DockBarHero.xcodeproj DockBarHero DockBarHeroTests/OverlayStateTests.swift
git commit -m "build: scaffold DockBarHero state model"
```

---

### Task 2: Pure Rail Placement

**Owner/model:** Fresh `gpt-5.6-luna` implementer; `gpt-5.6-terra` reviewer.

**Files:**

- Create: `DockBarHero/Core/OverlayPlacement.swift`
- Create: `DockBarHeroTests/OverlayPlacementTests.swift`

**Interfaces:**

- Produces: `DockMode`, `ScreenGeometry`, `OverlayPlacementPolicy`, `OverlayPlacementCalculator`, and `PlacementResolver`.
- Consumes: `CGRect` from CoreGraphics only.

- [ ] **Step 1: Write the failing placement tests**

Create `DockBarHeroTests/OverlayPlacementTests.swift`:

```swift
import CoreGraphics
import XCTest
@testable import DockBarHero

final class OverlayPlacementTests: XCTestCase {
    private let calculator = OverlayPlacementCalculator()

    func testCalculatesBalancedRailAboveVisibleDock() throws {
        let screen = ScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 1_728, height: 1_117),
            visibleFrame: CGRect(x: 0, y: 74, width: 1_728, height: 1_018),
            dockMode: .visibleBottom
        )

        let frame = try XCTUnwrap(calculator.frame(for: screen))

        XCTAssertEqual(frame.width, 1_140.48, accuracy: 0.001)
        XCTAssertEqual(frame.height, 96)
        XCTAssertEqual(frame.midX, 864, accuracy: 0.001)
        XCTAssertEqual(frame.minY, 82)
    }

    func testUsesDisplayBottomForAutoHiddenDock() throws {
        let screen = ScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 1_728, height: 1_117),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_728, height: 1_117),
            dockMode: .autoHidden
        )

        let frame = try XCTUnwrap(calculator.frame(for: screen))

        XCTAssertEqual(frame.minY, 8)
    }

    func testNeverExceedsNarrowScreen() throws {
        let screen = ScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 600, height: 500),
            visibleFrame: CGRect(x: 0, y: 0, width: 600, height: 500),
            dockMode: .autoHidden
        )

        XCTAssertEqual(try XCTUnwrap(calculator.frame(for: screen)).width, 600)
    }

    func testClampsWideScreenToMaximum() throws {
        let screen = ScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 3_000, height: 1_500),
            visibleFrame: CGRect(x: 0, y: 0, width: 3_000, height: 1_500),
            dockMode: .autoHidden
        )

        let frame = try XCTUnwrap(calculator.frame(for: screen))

        XCTAssertEqual(frame.width, 1_400)
        XCTAssertEqual(frame.minX, 800)
    }

    func testResolverRetainsLastValidFrame() throws {
        var resolver = PlacementResolver()
        let valid = ScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
            dockMode: .autoHidden
        )

        let first = try XCTUnwrap(resolver.resolve(valid))
        let invalid = ScreenGeometry(frame: .zero, visibleFrame: .zero, dockMode: .autoHidden)

        XCTAssertEqual(resolver.resolve(invalid), first)
    }
}
```

- [ ] **Step 2: Run the tests and verify failure**

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS' -derivedDataPath .build/DerivedData test CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/OverlayPlacementTests
```

Expected: build fails because placement types do not exist.

- [ ] **Step 3: Implement placement and last-valid-frame behavior**

Create `DockBarHero/Core/OverlayPlacement.swift`:

```swift
import CoreGraphics
import Foundation

enum DockMode: Equatable {
    case visibleBottom
    case autoHidden
}

struct ScreenGeometry: Equatable {
    let frame: CGRect
    let visibleFrame: CGRect
    let dockMode: DockMode
}

struct OverlayPlacementPolicy: Equatable {
    let widthFraction: CGFloat
    let minimumWidth: CGFloat
    let maximumWidth: CGFloat
    let height: CGFloat
    let bottomOffset: CGFloat

    static let phaseZero = OverlayPlacementPolicy(
        widthFraction: 0.66,
        minimumWidth: 720,
        maximumWidth: 1_400,
        height: 96,
        bottomOffset: 8
    )
}

struct OverlayPlacementCalculator {
    let policy: OverlayPlacementPolicy

    init(policy: OverlayPlacementPolicy = .phaseZero) {
        self.policy = policy
    }

    func frame(for screen: ScreenGeometry) -> CGRect? {
        guard screen.frame.isFiniteAndPositive,
              screen.visibleFrame.isFiniteAndPositive,
              policy.height + policy.bottomOffset <= screen.frame.height else {
            return nil
        }

        let proposedWidth = screen.visibleFrame.width * policy.widthFraction
        let clampedWidth = min(max(proposedWidth, policy.minimumWidth), policy.maximumWidth)
        let width = min(clampedWidth, screen.visibleFrame.width)
        let x = screen.visibleFrame.midX - width / 2
        let baseY = screen.dockMode == .visibleBottom
            ? screen.visibleFrame.minY
            : screen.frame.minY

        return CGRect(
            x: x,
            y: baseY + policy.bottomOffset,
            width: width,
            height: policy.height
        )
    }
}

struct PlacementResolver {
    private var calculator = OverlayPlacementCalculator()
    private(set) var lastValidFrame: CGRect?

    mutating func resolve(_ screen: ScreenGeometry) -> CGRect? {
        guard let frame = calculator.frame(for: screen) else {
            return lastValidFrame
        }
        lastValidFrame = frame
        return frame
    }
}

private extension CGRect {
    var isFiniteAndPositive: Bool {
        origin.x.isFinite && origin.y.isFinite
            && width.isFinite && height.isFinite
            && width > 0 && height > 0
    }
}
```

- [ ] **Step 4: Run focused and regression tests**

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS' -derivedDataPath .build/DerivedData test CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/OverlayPlacementTests -only-testing:DockBarHeroTests/OverlayStateTests
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add DockBarHero/Core/OverlayPlacement.swift DockBarHeroTests/OverlayPlacementTests.swift
git commit -m "feat: calculate stable rail placement"
```

---

### Task 3: Fullscreen Classification and Debounced Environment Monitoring

**Owner/model:** Fresh `gpt-5.6-terra` implementer because this crosses AppKit, CoreGraphics, notifications, and Swift concurrency; independent `gpt-5.6-terra` reviewer.

**Files:**

- Create: `DockBarHero/Environment/FullscreenWindowClassifier.swift`
- Create: `DockBarHero/Environment/EnvironmentMonitor.swift`
- Create: `DockBarHeroTests/FullscreenWindowClassifierTests.swift`
- Create: `DockBarHeroTests/EnvironmentMonitorTests.swift`

**Interfaces:**

- Consumes: `EnvironmentVisibility` from Task 1.
- Produces: `WindowSnapshot`, `FullscreenWindowClassifier`, `EnvironmentEvaluating`, `WorkspaceEnvironmentEvaluator`, `EnvironmentScheduling`, `EnvironmentMonitoring`, and `EnvironmentMonitor`.
- `EnvironmentMonitoring.onVisibilityChange` and `.onGeometryChange` are assigned by Task 6.

- [ ] **Step 1: Write failing classifier and monitor tests**

Create `DockBarHeroTests/FullscreenWindowClassifierTests.swift`:

```swift
import CoreGraphics
import XCTest
@testable import DockBarHero

final class FullscreenWindowClassifierTests: XCTestCase {
    func testClassifiesFrontmostLayerZeroScreenSizedWindow() {
        let windows = [
            WindowSnapshot(ownerPID: 42, layer: 0, bounds: CGRect(x: 0, y: 0, width: 1_728, height: 1_117), isOnScreen: true)
        ]

        XCTAssertTrue(FullscreenWindowClassifier().isFullscreen(
            frontmostPID: 42,
            ownPID: 99,
            screenFrame: CGRect(x: 0, y: 0, width: 1_728, height: 1_117),
            windows: windows
        ))
    }

    func testRejectsOwnAppWrongLayerAndPartialWindows() {
        let screen = CGRect(x: 0, y: 0, width: 1_728, height: 1_117)
        let classifier = FullscreenWindowClassifier()

        XCTAssertFalse(classifier.isFullscreen(frontmostPID: 99, ownPID: 99, screenFrame: screen, windows: []))
        XCTAssertFalse(classifier.isFullscreen(
            frontmostPID: 42,
            ownPID: 99,
            screenFrame: screen,
            windows: [WindowSnapshot(ownerPID: 42, layer: 1, bounds: screen, isOnScreen: true)]
        ))
        XCTAssertFalse(classifier.isFullscreen(
            frontmostPID: 42,
            ownPID: 99,
            screenFrame: screen,
            windows: [WindowSnapshot(ownerPID: 42, layer: 0, bounds: screen.insetBy(dx: 20, dy: 20), isOnScreen: true)]
        ))
    }
}
```

Create `DockBarHeroTests/EnvironmentMonitorTests.swift`:

```swift
import XCTest
@testable import DockBarHero

@MainActor
final class EnvironmentMonitorTests: XCTestCase {
    func testBurstOfChangesProducesOneEvaluation() {
        let evaluator = FakeEnvironmentEvaluator(result: .fullscreen)
        let scheduler = ManualEnvironmentScheduler()
        let monitor = EnvironmentMonitor(evaluator: evaluator, scheduler: scheduler)
        var received: [EnvironmentVisibility] = []
        monitor.onVisibilityChange = { received.append($0) }

        monitor.environmentDidChange()
        monitor.environmentDidChange()
        monitor.environmentDidChange()
        scheduler.fire()

        XCTAssertEqual(evaluator.callCount, 1)
        XCTAssertEqual(received, [.fullscreen])
    }

    func testBurstOfGeometryChangesProducesOneCallback() {
        let evaluator = FakeEnvironmentEvaluator(result: .normalSpace)
        let scheduler = ManualEnvironmentScheduler()
        let monitor = EnvironmentMonitor(evaluator: evaluator, scheduler: scheduler)
        var geometryChangeCount = 0
        monitor.onGeometryChange = { geometryChangeCount += 1 }

        monitor.geometryDidChange()
        monitor.geometryDidChange()
        monitor.geometryDidChange()
        scheduler.fire()

        XCTAssertEqual(geometryChangeCount, 1)
        XCTAssertEqual(evaluator.callCount, 1)
    }
}

@MainActor
private final class FakeEnvironmentEvaluator: EnvironmentEvaluating {
    let result: EnvironmentVisibility?
    private(set) var callCount = 0

    init(result: EnvironmentVisibility?) {
        self.result = result
    }

    func currentVisibility() -> EnvironmentVisibility? {
        callCount += 1
        return result
    }
}

@MainActor
private final class ManualEnvironmentScheduler: EnvironmentScheduling {
    private var operation: (@MainActor @Sendable () -> Void)?

    func schedule(_ operation: @escaping @MainActor @Sendable () -> Void) {
        self.operation = operation
    }

    func cancel() {
        operation = nil
    }

    func fire() {
        let pending = operation
        operation = nil
        pending?()
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS' -derivedDataPath .build/DerivedData test CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/FullscreenWindowClassifierTests -only-testing:DockBarHeroTests/EnvironmentMonitorTests
```

Expected: build fails because environment types do not exist.

- [ ] **Step 3: Implement the pure classifier and documented CGWindow adapter**

Create `DockBarHero/Environment/FullscreenWindowClassifier.swift`:

```swift
import AppKit
import CoreGraphics

struct WindowSnapshot: Equatable {
    let ownerPID: pid_t
    let layer: Int
    let bounds: CGRect
    let isOnScreen: Bool
}

struct FullscreenWindowClassifier {
    func isFullscreen(
        frontmostPID: pid_t,
        ownPID: pid_t,
        screenFrame: CGRect,
        windows: [WindowSnapshot]
    ) -> Bool {
        guard frontmostPID != ownPID else { return false }

        return windows.contains { window in
            window.ownerPID == frontmostPID
                && window.layer == 0
                && window.isOnScreen
                && abs(window.bounds.width - screenFrame.width) <= 2
                && abs(window.bounds.height - screenFrame.height) <= 2
        }
    }
}

@MainActor
protocol EnvironmentEvaluating: AnyObject {
    func currentVisibility() -> EnvironmentVisibility?
}

@MainActor
final class WorkspaceEnvironmentEvaluator: EnvironmentEvaluating {
    private let classifier = FullscreenWindowClassifier()

    func currentVisibility() -> EnvironmentVisibility? {
        guard let screen = NSScreen.screens.first,
              let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        guard let rawWindows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        let windows = rawWindows.compactMap(Self.snapshot)
        let fullscreen = classifier.isFullscreen(
            frontmostPID: app.processIdentifier,
            ownPID: ProcessInfo.processInfo.processIdentifier,
            screenFrame: screen.frame,
            windows: windows
        )
        return fullscreen ? .fullscreen : .normalSpace
    }

    private static func snapshot(_ info: [String: Any]) -> WindowSnapshot? {
        guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
              let layer = info[kCGWindowLayer as String] as? Int,
              let boundsDictionary = info[kCGWindowBounds as String] as? CFDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsDictionary) else {
            return nil
        }
        let isOnScreen = info[kCGWindowIsOnscreen as String] as? Bool ?? false
        return WindowSnapshot(ownerPID: ownerPID, layer: layer, bounds: bounds, isOnScreen: isOnScreen)
    }
}
```

- [ ] **Step 4: Implement coalesced environment notifications**

Create `DockBarHero/Environment/EnvironmentMonitor.swift`:

```swift
import AppKit

@MainActor
protocol EnvironmentScheduling: AnyObject {
    func schedule(_ operation: @escaping @MainActor @Sendable () -> Void)
    func cancel()
}

@MainActor
final class MainQueueEnvironmentScheduler: EnvironmentScheduling {
    private var task: Task<Void, Never>?

    func schedule(_ operation: @escaping @MainActor @Sendable () -> Void) {
        task?.cancel()
        task = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            operation()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

@MainActor
protocol EnvironmentMonitoring: AnyObject {
    var onVisibilityChange: (@MainActor (EnvironmentVisibility) -> Void)? { get set }
    var onGeometryChange: (@MainActor () -> Void)? { get set }
    func start()
    func stop()
}

@MainActor
final class EnvironmentMonitor: NSObject, EnvironmentMonitoring {
    var onVisibilityChange: (@MainActor (EnvironmentVisibility) -> Void)?
    var onGeometryChange: (@MainActor () -> Void)?

    private let evaluator: EnvironmentEvaluating
    private let scheduler: EnvironmentScheduling
    private var started = false
    private var geometryDirty = false

    init(
        evaluator: EnvironmentEvaluating,
        scheduler: EnvironmentScheduling = MainQueueEnvironmentScheduler()
    ) {
        self.evaluator = evaluator
        self.scheduler = scheduler
    }

    func start() {
        guard !started else { return }
        started = true
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(self, selector: #selector(handleEnvironmentNotification), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        workspaceCenter.addObserver(self, selector: #selector(handleEnvironmentNotification), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        workspaceCenter.addObserver(self, selector: #selector(handleWakeNotification), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleGeometryNotification), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        environmentDidChange()
    }

    func stop() {
        guard started else { return }
        started = false
        scheduler.cancel()
        geometryDirty = false
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    func environmentDidChange() {
        scheduler.schedule { [weak self] in
            guard let self else { return }
            if self.geometryDirty {
                self.geometryDirty = false
                self.onGeometryChange?()
            }
            if let visibility = self.evaluator.currentVisibility() {
                AppLog.environment.debug("Environment visibility changed")
                self.onVisibilityChange?(visibility)
            }
        }
    }

    func geometryDidChange() {
        geometryDirty = true
        environmentDidChange()
    }

    @objc private func handleEnvironmentNotification(_ notification: Notification) {
        environmentDidChange()
    }

    @objc private func handleWakeNotification(_ notification: Notification) {
        geometryDidChange()
    }

    @objc private func handleGeometryNotification(_ notification: Notification) {
        geometryDidChange()
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }
}
```

- [ ] **Step 5: Run focused tests and commit**

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS' -derivedDataPath .build/DerivedData test CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/FullscreenWindowClassifierTests -only-testing:DockBarHeroTests/EnvironmentMonitorTests
git add DockBarHero/Environment DockBarHeroTests/FullscreenWindowClassifierTests.swift DockBarHeroTests/EnvironmentMonitorTests.swift
git commit -m "feat: monitor fullscreen environment changes"
```

Expected before commit: `** TEST SUCCEEDED **`.

---

### Task 4: SpriteKit Prototype Scene

**Owner/model:** Fresh `gpt-5.6-luna` implementer; `gpt-5.6-terra` reviewer.

**Files:**

- Create: `DockBarHero/Rendering/PrototypeScene.swift`
- Create: `DockBarHero/Rendering/PrototypeSceneHost.swift`
- Create: `DockBarHeroTests/PrototypeSceneHostTests.swift`

**Interfaces:**

- Produces: `SceneControlling`, `PrototypeSceneHost`, and `PrototypeScene`.
- `SceneControlling.view` is consumed by Task 5.
- `setAnimating(_:)` and `setInteractive(_:)` are consumed by Task 6.

- [ ] **Step 1: Write the failing scene-host tests**

Create `DockBarHeroTests/PrototypeSceneHostTests.swift`:

```swift
import SpriteKit
import XCTest
@testable import DockBarHero

@MainActor
final class PrototypeSceneHostTests: XCTestCase {
    func testHostConfiguresTransparentThirtyFPSScene() throws {
        let host = try PrototypeSceneHost()

        XCTAssertEqual(host.view.preferredFramesPerSecond, 30)
        XCTAssertTrue(host.view.allowsTransparency)
        XCTAssertEqual(host.scene.backgroundColor, .clear)
        XCTAssertNotNil(host.scene.childNode(withName: "hero"))
        XCTAssertNotNil(host.scene.childNode(withName: "enemy"))
        XCTAssertNotNil(host.scene.childNode(withName: "ground"))
    }

    func testAnimationAndInteractionControls() throws {
        let host = try PrototypeSceneHost()

        host.setAnimating(false)
        host.setInteractive(true)

        XCTAssertTrue(host.scene.isPaused)
        XCTAssertTrue(host.scene.isUserInteractionEnabled)
    }
}
```

- [ ] **Step 2: Run the focused test and verify failure**

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS' -derivedDataPath .build/DerivedData test CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/PrototypeSceneHostTests
```

Expected: build fails because scene-host types do not exist.

- [ ] **Step 3: Implement the placeholder scene**

Create `DockBarHero/Rendering/PrototypeScene.swift`:

```swift
import AppKit
import SpriteKit

@MainActor
final class PrototypeScene: SKScene {
    override func didMove(to view: SKView) {
        guard childNode(withName: "ground") == nil else { return }
        backgroundColor = .clear
        scaleMode = .resizeFill
        isUserInteractionEnabled = false

        let ground = SKShapeNode(rectOf: CGSize(width: size.width, height: 2))
        ground.name = "ground"
        ground.fillColor = NSColor.white.withAlphaComponent(0.45)
        ground.strokeColor = .clear
        ground.position = CGPoint(x: size.width / 2, y: 12)
        addChild(ground)

        let hero = actor(name: "hero", color: .systemYellow, x: size.width * 0.22)
        let enemy = actor(name: "enemy", color: .systemRed, x: size.width * 0.78)
        addChild(hero)
        addChild(enemy)

        let idle = SKAction.repeatForever(.sequence([
            .moveBy(x: 0, y: 2, duration: 0.3),
            .moveBy(x: 0, y: -2, duration: 0.3)
        ]))
        hero.run(idle, withKey: "idle")
        enemy.run(idle.reversed(), withKey: "idle")

        let attack = SKAction.repeatForever(.sequence([
            .wait(forDuration: 1.4),
            .moveBy(x: 26, y: 0, duration: 0.12),
            .run { [weak self, weak enemy] in self?.showHit(at: enemy?.position) },
            .moveBy(x: -26, y: 0, duration: 0.12),
            .wait(forDuration: 0.8)
        ]))
        hero.run(attack, withKey: "attack")
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        childNode(withName: "ground")?.position = CGPoint(x: size.width / 2, y: 12)
        if let ground = childNode(withName: "ground") as? SKShapeNode {
            ground.path = CGPath(rect: CGRect(x: -size.width / 2, y: -1, width: size.width, height: 2), transform: nil)
        }
        childNode(withName: "hero")?.position.x = size.width * 0.22
        childNode(withName: "enemy")?.position.x = size.width * 0.78
    }

    override func mouseDown(with event: NSEvent) {
        guard isUserInteractionEnabled else { return }
        let point = event.location(in: self)
        guard let actor = nodes(at: point).first(where: { $0.name == "hero" || $0.name == "enemy" }) else { return }
        actor.run(.sequence([
            .scale(to: 1.25, duration: 0.08),
            .scale(to: 1.0, duration: 0.08)
        ]))
    }

    private func actor(name: String, color: NSColor, x: CGFloat) -> SKShapeNode {
        let node = SKShapeNode(rectOf: CGSize(width: 24, height: 36), cornerRadius: 2)
        node.name = name
        node.fillColor = color
        node.strokeColor = NSColor.black.withAlphaComponent(0.35)
        node.position = CGPoint(x: x, y: 32)
        return node
    }

    private func showHit(at point: CGPoint?) {
        guard let point else { return }
        let hit = SKLabelNode(text: "*")
        hit.fontName = "Menlo-Bold"
        hit.fontSize = 20
        hit.fontColor = .white
        hit.position = CGPoint(x: point.x, y: point.y + 24)
        addChild(hit)
        hit.run(.sequence([
            .group([.moveBy(x: 0, y: 14, duration: 0.25), .fadeOut(withDuration: 0.25)]),
            .removeFromParent()
        ]))
    }
}
```

- [ ] **Step 4: Implement the scene host and controls**

Create `DockBarHero/Rendering/PrototypeSceneHost.swift`:

```swift
import SpriteKit

enum PrototypeSceneHostError: Error {
    case scenePresentationFailed
}

@MainActor
protocol SceneControlling: AnyObject {
    var view: SKView { get }
    func setAnimating(_ isAnimating: Bool)
    func setInteractive(_ isInteractive: Bool)
}

@MainActor
final class PrototypeSceneHost: SceneControlling {
    let view: SKView
    let scene: PrototypeScene

    init(size: CGSize = CGSize(width: 1_140, height: 96)) throws {
        view = SKView(frame: CGRect(origin: .zero, size: size))
        view.allowsTransparency = true
        view.preferredFramesPerSecond = 30
        scene = PrototypeScene(size: size)
        view.presentScene(scene)
        guard view.scene === scene else {
            throw PrototypeSceneHostError.scenePresentationFailed
        }
        AppLog.scene.info("Prototype scene created")
    }

    func setAnimating(_ isAnimating: Bool) {
        scene.isPaused = !isAnimating
        view.isPaused = !isAnimating
    }

    func setInteractive(_ isInteractive: Bool) {
        scene.isUserInteractionEnabled = isInteractive
    }
}
```

- [ ] **Step 5: Run focused tests and commit**

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS' -derivedDataPath .build/DerivedData test CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/PrototypeSceneHostTests
git add DockBarHero/Rendering DockBarHeroTests/PrototypeSceneHostTests.swift
git commit -m "feat: render animated prototype scene"
```

Expected before commit: `** TEST SUCCEEDED **`.

---

### Task 5: Non-Activating Overlay Panel and Screen Provider

**Owner/model:** Fresh `gpt-5.6-terra` implementer; independent `gpt-5.6-terra` reviewer.

**Files:**

- Create: `DockBarHero/Overlay/OverlayPanel.swift`
- Create: `DockBarHero/Overlay/OverlayWindowController.swift`
- Create: `DockBarHero/Overlay/AppKitScreenProvider.swift`
- Create: `DockBarHeroTests/OverlayWindowControllerTests.swift`

**Interfaces:**

- Consumes: `ScreenGeometry` and `DockMode` from Task 2.
- Consumes: `SceneControlling.view` from Task 4.
- Produces: `OverlayWindowControlling`, `OverlayWindowController`, `ScreenProviding`, and `AppKitScreenProvider` for Task 6.

- [ ] **Step 1: Write failing panel-configuration tests**

Create `DockBarHeroTests/OverlayWindowControllerTests.swift`:

```swift
import AppKit
import XCTest
@testable import DockBarHero

@MainActor
final class OverlayWindowControllerTests: XCTestCase {
    func testPanelIsTransparentNonActivatingAndPassive() {
        let content = NSView(frame: CGRect(x: 0, y: 0, width: 800, height: 96))
        let controller = OverlayWindowController(contentView: content)
        let panel = controller.panel

        XCTAssertFalse(panel.isOpaque)
        XCTAssertEqual(panel.backgroundColor, .clear)
        XCTAssertFalse(panel.hasShadow)
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
    }

    func testControllerAppliesFrameInputAndVisibility() {
        let controller = OverlayWindowController(contentView: NSView())
        let frame = CGRect(x: 10, y: 20, width: 900, height: 96)

        controller.setFrame(frame)
        controller.setInputEnabled(true)
        controller.setVisible(false)

        XCTAssertEqual(controller.panel.frame, frame)
        XCTAssertFalse(controller.panel.ignoresMouseEvents)
        XCTAssertFalse(controller.panel.isVisible)
    }
}
```

- [ ] **Step 2: Run the focused test and verify failure**

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS' -derivedDataPath .build/DerivedData test CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/OverlayWindowControllerTests
```

Expected: build fails because window-controller types do not exist.

- [ ] **Step 3: Implement the panel and controller**

Create `DockBarHero/Overlay/OverlayPanel.swift`:

```swift
import AppKit

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
```

Create `DockBarHero/Overlay/OverlayWindowController.swift`:

```swift
import AppKit

@MainActor
protocol OverlayWindowControlling: AnyObject {
    func setFrame(_ frame: CGRect)
    func setVisible(_ isVisible: Bool)
    func setInputEnabled(_ isEnabled: Bool)
}

@MainActor
final class OverlayWindowController: OverlayWindowControlling {
    let panel: OverlayPanel

    init(contentView: NSView) {
        contentView.autoresizingMask = [.width, .height]
        panel = OverlayPanel(
            contentRect: contentView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = contentView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        AppLog.overlay.info("Overlay panel created")
    }

    func setFrame(_ frame: CGRect) {
        panel.setFrame(frame, display: true)
        AppLog.placement.debug("Applied overlay frame x=\(frame.minX) y=\(frame.minY) w=\(frame.width) h=\(frame.height)")
    }

    func setVisible(_ isVisible: Bool) {
        if isVisible {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    func setInputEnabled(_ isEnabled: Bool) {
        panel.ignoresMouseEvents = !isEnabled
    }
}
```

- [ ] **Step 4: Implement stable target-screen geometry**

Create `DockBarHero/Overlay/AppKitScreenProvider.swift`:

```swift
import AppKit

@MainActor
protocol ScreenProviding: AnyObject {
    func currentGeometry() -> ScreenGeometry?
}

@MainActor
final class AppKitScreenProvider: ScreenProviding {
    private var stableDockModes: [NSNumber: DockMode] = [:]

    func currentGeometry() -> ScreenGeometry? {
        guard let screen = NSScreen.screens.first,
              let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            AppLog.placement.error("No target screen available")
            return nil
        }

        let inferredMode: DockMode = screen.visibleFrame.minY > screen.frame.minY + 1
            ? .visibleBottom
            : .autoHidden
        let stableMode = stableDockModes[screenNumber] ?? inferredMode
        stableDockModes[screenNumber] = stableMode

        return ScreenGeometry(
            frame: screen.frame,
            visibleFrame: screen.visibleFrame,
            dockMode: stableMode
        )
    }
}
```

- [ ] **Step 5: Run focused tests and commit**

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS' -derivedDataPath .build/DerivedData test CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/OverlayWindowControllerTests -only-testing:DockBarHeroTests/OverlayPlacementTests
git add DockBarHero/Overlay DockBarHeroTests/OverlayWindowControllerTests.swift
git commit -m "feat: host scene in passive overlay panel"
```

Expected before commit: `** TEST SUCCEEDED **`.

---

### Task 6: Application Coordination and Menu Bar Integration

**Owner/model:** Fresh `gpt-5.6-terra` implementer; independent `gpt-5.6-terra` reviewer.

**Files:**

- Create: `DockBarHero/App/AppModel.swift`
- Create: `DockBarHero/App/AppDelegate.swift`
- Replace: `DockBarHero/App/DockBarHeroApp.swift`
- Create: `DockBarHero/App/MenuBarContent.swift`
- Create: `DockBarHeroTests/AppModelTests.swift`

**Interfaces:**

- Consumes: `OverlayState` and `OverlayAction` from Task 1.
- Consumes: `PlacementResolver` from Task 2.
- Consumes: `EnvironmentMonitoring` from Task 3.
- Consumes: `SceneControlling` from Task 4.
- Consumes: `OverlayWindowControlling` and `ScreenProviding` from Task 5.
- Produces: the fully integrated Phase 0 app.

- [ ] **Step 1: Write failing coordination tests with fakes**

Create `DockBarHeroTests/AppModelTests.swift`:

```swift
import AppKit
import SpriteKit
import XCTest
@testable import DockBarHero

@MainActor
final class AppModelTests: XCTestCase {
    func testStartPlacesVisiblePassiveAnimatingRailOnce() {
        let dependencies = TestDependencies()
        let model = dependencies.makeModel()

        model.start()
        model.start()

        XCTAssertEqual(dependencies.window.frames.count, 1)
        XCTAssertEqual(dependencies.window.visibility, [true])
        XCTAssertEqual(dependencies.window.inputEnabled, [false])
        XCTAssertEqual(dependencies.scene.animationEnabled, [true])
        XCTAssertEqual(dependencies.monitor.startCount, 1)
    }

    func testFullscreenHidesAndPausesThenRestores() {
        let dependencies = TestDependencies()
        let model = dependencies.makeModel()
        model.start()

        dependencies.monitor.onVisibilityChange?(.fullscreen)
        dependencies.monitor.onVisibilityChange?(.normalSpace)

        XCTAssertEqual(dependencies.window.visibility, [true, false, true])
        XCTAssertEqual(dependencies.scene.animationEnabled, [true, false, true])
    }

    func testManualHideSurvivesFullscreenRoundTrip() {
        let dependencies = TestDependencies()
        let model = dependencies.makeModel()
        model.start()

        model.send(.setManualVisibility(.hidden))
        dependencies.monitor.onVisibilityChange?(.fullscreen)
        dependencies.monitor.onVisibilityChange?(.normalSpace)

        XCTAssertFalse(model.state.isEffectivelyVisible)
        XCTAssertEqual(model.state.manualVisibility, .hidden)
    }

    func testInteractiveModeEnablesWindowAndSceneInput() {
        let dependencies = TestDependencies()
        let model = dependencies.makeModel()
        model.start()

        model.send(.setInputMode(.interactive))

        XCTAssertEqual(dependencies.window.inputEnabled.last, true)
        XCTAssertEqual(dependencies.scene.interactionEnabled.last, true)
    }
}

@MainActor
private final class TestDependencies {
    let window = FakeWindow()
    let scene = FakeScene()
    let screen = FakeScreen()
    let monitor = FakeMonitor()

    func makeModel() -> AppModel {
        AppModel(window: window, scene: scene, screen: screen, monitor: monitor)
    }
}

@MainActor
private final class FakeWindow: OverlayWindowControlling {
    var frames: [CGRect] = []
    var visibility: [Bool] = []
    var inputEnabled: [Bool] = []
    func setFrame(_ frame: CGRect) { frames.append(frame) }
    func setVisible(_ isVisible: Bool) { visibility.append(isVisible) }
    func setInputEnabled(_ isEnabled: Bool) { inputEnabled.append(isEnabled) }
}

@MainActor
private final class FakeScene: SceneControlling {
    let view = SKView()
    var animationEnabled: [Bool] = []
    var interactionEnabled: [Bool] = []
    func setAnimating(_ isAnimating: Bool) { animationEnabled.append(isAnimating) }
    func setInteractive(_ isInteractive: Bool) { interactionEnabled.append(isInteractive) }
}

@MainActor
private final class FakeScreen: ScreenProviding {
    func currentGeometry() -> ScreenGeometry? {
        ScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 1_728, height: 1_117),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_728, height: 1_117),
            dockMode: .autoHidden
        )
    }
}

@MainActor
private final class FakeMonitor: EnvironmentMonitoring {
    var onVisibilityChange: (@MainActor (EnvironmentVisibility) -> Void)?
    var onGeometryChange: (@MainActor () -> Void)?
    var startCount = 0
    func start() { startCount += 1 }
    func stop() {}
}
```

- [ ] **Step 2: Run the focused test and verify failure**

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS' -derivedDataPath .build/DerivedData test CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/AppModelTests
```

Expected: build fails because `AppModel` does not exist.

- [ ] **Step 3: Implement the app model**

Create `DockBarHero/App/AppModel.swift`:

```swift
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var state = OverlayState()

    private var window: OverlayWindowControlling?
    private var scene: SceneControlling?
    private var screen: ScreenProviding?
    private var monitor: EnvironmentMonitoring?
    private var placement = PlacementResolver()
    private var started = false

    init(
        window: OverlayWindowControlling? = nil,
        scene: SceneControlling? = nil,
        screen: ScreenProviding? = nil,
        monitor: EnvironmentMonitoring? = nil
    ) {
        self.window = window
        self.scene = scene
        self.screen = screen
        self.monitor = monitor
    }

    func connect(
        window: OverlayWindowControlling,
        scene: SceneControlling,
        screen: ScreenProviding,
        monitor: EnvironmentMonitoring
    ) {
        precondition(!started, "Dependencies must be connected before start")
        self.window = window
        self.scene = scene
        self.screen = screen
        self.monitor = monitor
    }

    func start() {
        guard !started else { return }
        started = true
        monitor?.onVisibilityChange = { [weak self] visibility in
            self?.send(.setEnvironmentVisibility(visibility))
        }
        monitor?.onGeometryChange = { [weak self] in
            self?.refreshPlacement()
        }
        refreshPlacement()
        applyState()
        monitor?.start()
        AppLog.lifecycle.info("Application coordination started")
    }

    func stop() {
        monitor?.stop()
        window?.setVisible(false)
        scene?.setAnimating(false)
    }

    func send(_ action: OverlayAction) {
        state.apply(action)
        applyState()
        AppLog.overlay.debug("Overlay state updated")
    }

    private func refreshPlacement() {
        guard let geometry = screen?.currentGeometry(),
              let frame = placement.resolve(geometry) else {
            window?.setVisible(false)
            return
        }
        window?.setFrame(frame)
    }

    private func applyState() {
        let hasPlacement = placement.lastValidFrame != nil
        window?.setVisible(state.isEffectivelyVisible && hasPlacement)
        window?.setInputEnabled(state.acceptsInput)
        scene?.setAnimating(state.shouldAnimate && hasPlacement)
        scene?.setInteractive(state.acceptsInput)
    }
}
```

- [ ] **Step 4: Implement live bootstrap and state-derived menu commands**

Create `DockBarHero/App/AppDelegate.swift`:

```swift
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        do {
            let scene = try PrototypeSceneHost()
            let window = OverlayWindowController(contentView: scene.view)
            let screen = AppKitScreenProvider()
            let monitor = EnvironmentMonitor(evaluator: WorkspaceEnvironmentEvaluator())
            model.connect(window: window, scene: scene, screen: screen, monitor: monitor)
            model.start()
            AppLog.lifecycle.info("DockBarHero launched")
        } catch {
            AppLog.scene.error("Scene bootstrap failed: \(error.localizedDescription)")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    func send(_ action: OverlayAction) {
        model.send(action)
    }
}
```

Create `DockBarHero/App/MenuBarContent.swift`:

```swift
import AppKit
import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var model: AppModel
    let send: (OverlayAction) -> Void

    var body: some View {
        Button(model.state.manualVisibility == .shown ? "Hide Rail" : "Show Rail") {
            send(.setManualVisibility(model.state.manualVisibility == .shown ? .hidden : .shown))
        }
        Button(model.state.animationMode == .running ? "Pause Animation" : "Resume Animation") {
            send(.setAnimationMode(model.state.animationMode == .running ? .paused : .running))
        }
        Button(model.state.inputMode == .passive ? "Enable Interaction" : "Disable Interaction") {
            send(.setInputMode(model.state.inputMode == .passive ? .interactive : .passive))
        }
        Divider()
        Button("Quit DockBarHero") {
            NSApplication.shared.terminate(nil)
        }
    }
}
```

Replace `DockBarHero/App/DockBarHeroApp.swift`:

```swift
import SwiftUI

@main
struct DockBarHeroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("DockBarHero", systemImage: "sparkles") {
            MenuBarContent(model: appDelegate.model, send: appDelegate.send)
        }
        .menuBarExtraStyle(.menu)
    }
}
```

The shared `AppModel` is the only state source, so menu labels update after both environment callbacks and menu actions.

- [ ] **Step 5: Run coordination, regression, and build gates**

```bash
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS' -derivedDataPath .build/DerivedData test CODE_SIGNING_ALLOWED=NO -only-testing:DockBarHeroTests/AppModelTests -only-testing:DockBarHeroTests/OverlayStateTests -only-testing:DockBarHeroTests/OverlayPlacementTests
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/DerivedData build CODE_SIGNING_ALLOWED=NO
```

Expected: `** TEST SUCCEEDED **` and `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add DockBarHero/App DockBarHeroTests/AppModelTests.swift
git commit -m "feat: integrate overlay menu bar application"
```

---

### Task 7: QA Harness, Full Verification, and Completion Evidence

**Owner/model:** Fresh `gpt-5.6-luna` implementer for scripts/docs; `gpt-5.6-terra` reviewer. The primary model performs GUI QA; `gpt-5.6-sol` performs the final whole-branch review.

**Files:**

- Create: `scripts/measure-process.sh`
- Create: `docs/qa/phase-0-checklist.md`
- Modify only if verification finds a defect: files owned by Tasks 1-6, followed by focused regression tests.

**Interfaces:**

- Consumes: the complete application from Tasks 1-6.
- Produces: repeatable resource measurements and the Phase 0 completion record.

- [ ] **Step 1: Create the resource measurement script**

Create executable `scripts/measure-process.sh`:

```bash
#!/bin/zsh
set -euo pipefail

if (( $# < 1 || $# > 3 )); then
  echo "usage: $0 PID [DURATION_SECONDS] [INTERVAL_SECONDS]" >&2
  exit 64
fi

pid="$1"
duration="${2:-300}"
interval="${3:-5}"
samples=$(( duration / interval ))
output="$(mktemp)"
trap 'rm -f "$output"' EXIT

for (( index = 0; index < samples; index++ )); do
  if ! ps -p "$pid" -o %cpu=,rss= >> "$output"; then
    echo "process $pid exited before measurement completed" >&2
    exit 1
  fi
  sleep "$interval"
done

awk '
  { cpu += $1; rss += $2; count += 1 }
  END {
    if (count == 0) exit 1
    printf "samples=%d average_cpu_percent=%.3f average_rss_mb=%.2f\n", count, cpu / count, (rss / count) / 1024
  }
' "$output"
```

Run:

```bash
chmod +x scripts/measure-process.sh
scripts/measure-process.sh
```

Expected: exits 64 and prints the usage line because a PID is required.

- [ ] **Step 2: Create the manual QA completion record**

Create `docs/qa/phase-0-checklist.md`:

```markdown
# DockBarHero Phase 0 QA Checklist

**Build commit:**
**Tester:**
**Date:**
**Machine:** Apple M5 Max MacBook Pro, macOS 26.5.1

## Automated Gates

- [ ] Clean command-line build succeeds.
- [ ] Complete test suite succeeds.
- [ ] `git diff --check` succeeds.

## Desktop Behavior

- [ ] Launch creates one menu bar item and no normal Dock icon.
- [ ] Rail is centered, 96 points tall, and uses the approved balanced width.
- [ ] Passive mode passes clicks and scrolling to underlying applications.
- [ ] Interactive actor clicks react without taking keyboard focus.
- [ ] Normal Space changes do not duplicate, lose, or jump the rail.
- [ ] Another application's fullscreen Space hides the rail.
- [ ] Returning to a normal Space restores the rail unless manually hidden.
- [ ] Auto-hidden Dock reveal and conceal do not move the rail.
- [ ] Hide/show, pause/resume, and input menu labels match actual state.
- [ ] Sleep/wake restores exactly one correctly placed rail.
- [ ] Relaunch returns to shown, running, passive defaults.
- [ ] Quit leaves no DockBarHero process or panel.

## Resource Gates

- [ ] Active five-minute average CPU is below 3 percent.
- [ ] Hidden five-minute average CPU is below 0.5 percent.
- [ ] Paused five-minute average CPU is below 0.5 percent.
- [ ] A 30-minute active run shows no monotonic memory growth.

## Recorded Evidence

Full test command and result:

Active resource output:

Hidden resource output:

Paused resource output:

30-minute memory observations:

Failures, fixes, and retest evidence:

## Decision

- [ ] PASS: Phase 0 meets every gate.
- [ ] NO-GO: One or more gate remains unresolved.
```

- [ ] **Step 3: Run the clean automated gate**

```bash
xcodegen generate
xcodebuild -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS' -derivedDataPath .build/Phase0Verification clean test CODE_SIGNING_ALLOWED=NO
git diff --check
```

Expected: `** CLEAN SUCCEEDED **`, `** TEST SUCCEEDED **`, and no output from `git diff --check`.

- [ ] **Step 4: Launch and complete GUI QA on the target Mac**

```bash
open .build/Phase0Verification/Build/Products/Debug/DockBarHero.app
pgrep -x DockBarHero
```

Use the returned PID with `scripts/measure-process.sh`. Record every result in `docs/qa/phase-0-checklist.md`. Exercise normal Spaces, another app's fullscreen mode, Dock auto-hide, passive and interactive modes, manual visibility, pause, sleep/wake, relaunch, and quit.

Expected: every desktop-behavior and resource checkbox passes. Any failure blocks Phase 0 and must be fixed with a focused test where automation is possible, followed by a task-level re-review.

- [ ] **Step 5: Commit the QA harness and evidence**

```bash
git add scripts/measure-process.sh docs/qa/phase-0-checklist.md
git commit -m "test: record Phase 0 QA evidence"
```

- [ ] **Step 6: Run the final whole-branch review**

Generate a review package from the implementation branch merge base through `HEAD`. Dispatch `gpt-5.6-sol` with the approved design, this plan, the review package, test evidence, and QA record. Fix all Critical and Important findings in one consolidated fix pass, rerun covering tests, and re-dispatch the review.

Expected: final review reports no release-blocking findings and the QA record marks `PASS`.

## Execution Handoff

Execute this plan with `superpowers:subagent-driven-development`, as already selected by the user. Use a fresh implementer and independent reviewer for every task, record progress in `.superpowers/sdd/progress.md`, and continue through all seven tasks without pausing unless blocked by a genuine product decision.
