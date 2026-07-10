# DockBarHero Phase 0 Technical Prototype Design

**Status:** Approved

**Date:** 2026-07-10

**Project:** DockBarHero

**Related outline:** [mac-taskbar-hero-project-outline.md](../../../mac-taskbar-hero-project-outline.md)

## 1. Purpose

Phase 0 proves that DockBarHero's defining macOS experience is technically viable before game systems or production content are built.

The prototype is a lightweight animated rail positioned near the bottom of the desktop. It must coexist with normal Mac use without stealing focus, blocking clicks, behaving unpredictably across Spaces, or consuming excessive resources.

This phase is a technical go/no-go gate. It is not a playable game milestone.

## 2. Target Environment

Phase 0 targets only the current development machine:

- Apple M5 Max MacBook Pro
- Apple Silicon (`arm64`)
- macOS 26.5.1
- Xcode 26.5
- Swift 6.3.2
- macOS 26.0 deployment target

Intel support, older macOS versions, and generalized hardware compatibility are deferred until the prototype succeeds on this machine.

## 3. Goals

The prototype must demonstrate:

- A transparent, borderless animated rail near the bottom edge of the display.
- Reliable click-through behavior enabled by default.
- A menu bar interface for controlling the rail.
- Stable placement during Dock auto-hide transitions.
- Visibility across normal desktop Spaces.
- Automatic hiding while another application is fullscreen.
- No focus theft during passive desktop use.
- Low active resource use and negligible hidden or paused resource use.
- Clean separation between testable state and macOS window integration.

## 4. Non-Goals

Phase 0 will not include:

- Real combat rules, statistics, progression, or rewards.
- Inventory, equipment, classes, skills, or character builds.
- Save files or offline progress.
- Steamworks, achievements, cloud saves, or tradable items.
- Accounts, servers, networking, telemetry services, or crash reporting services.
- Production artwork, audio, onboarding, or accessibility polish.
- Multiplayer, social features, leaderboards, or live operations.
- Mac App Store packaging, notarization, or release automation.
- Intel or cross-platform support.

Placeholder actors may move, attack, react, and emit effects, but these actions exist only to exercise rendering and window behavior.

## 5. User Experience

### 5.1 Launch

DockBarHero launches as a menu-bar accessory application without a normal Dock icon or conventional main window. The rail appears automatically after its target screen and placement have been resolved.

The rail does not activate the application or move keyboard focus away from the current application.

### 5.2 Rail Geometry

The initial rail geometry is:

- Width: 66 percent of the target display's visible width.
- Minimum width: 720 points.
- Maximum width: 1,400 points.
- Height: 96 points.
- Horizontal alignment: centered on the target display.
- Bottom offset with a normally visible Dock: 8 points above `NSScreen.visibleFrame.minY`.
- Bottom offset with an auto-hidden Dock: 8 points above the display's lower edge.

The prototype uses the screen containing the active menu bar as its target. Multi-display selection UI is not included in Phase 0.

Dock reveal and conceal events must not make the rail jump. Temporary overlap while an auto-hidden Dock is visible is accepted for this prototype.

### 5.3 Visibility

The rail:

- Appears on every normal desktop Space.
- Hides automatically when another application occupies a fullscreen Space.
- Returns when the user moves back to a normal desktop Space.
- Can be hidden or shown manually from the menu bar.
- Remains hidden when manually hidden, even after a Space transition, until the user shows it again.

Manual visibility is therefore an explicit user preference and takes priority over automatic visibility.

### 5.4 Input

The rail starts in passive mode with `ignoresMouseEvents` enabled. Mouse clicks and scrolling pass through to the application underneath it.

The menu bar can toggle interactive mode. In interactive mode, clicking a placeholder actor triggers a visible reaction so event delivery can be verified. Interactive mode must not turn the rail into a key window or steal keyboard focus.

Returning to passive mode immediately restores click-through behavior.

### 5.5 Menu Bar Commands

The menu bar item provides:

- Show Rail / Hide Rail
- Resume Animation / Pause Animation
- Enable Interaction / Disable Interaction
- Quit DockBarHero

Labels reflect current state. Commands must remain available if the SpriteKit scene fails to load.

## 6. Visual Prototype

The SpriteKit scene contains:

- A transparent background.
- A subtle ground reference that does not resemble window chrome.
- At least one placeholder hero and one placeholder enemy.
- Continuous idle and movement animation.
- A repeated mock encounter sequence with an attack and hit reaction.
- A small transient hit effect.
- An interactive reaction when an actor is clicked in interactive mode.

The scene contains no buttons, inventory, HUD panels, or explanatory text. Its purpose is to make stability, transparency, placement, and energy usage observable.

Rendering is capped at 30 frames per second. Rendering is suspended while the rail is hidden or animation is paused.

## 7. Architecture

### 7.1 Application Shell

SwiftUI owns application lifecycle and the menu bar command surface. AppKit is used only where macOS window behavior requires it.

The application runs with accessory activation behavior so it does not create a normal Dock icon.

### 7.2 Overlay Window

An AppKit controller owns one borderless, transparent, non-activating `NSPanel` containing an `SKView`.

The panel is configured to:

- Remain visually transparent outside rendered SpriteKit content.
- Avoid shadows and standard window chrome.
- Avoid becoming the key or main window.
- Join all normal desktop Spaces.
- Ignore mouse events in passive mode.
- Use a window level sufficient to remain visible during ordinary desktop work without appearing over fullscreen applications.

All AppKit-specific behavior remains inside this controller and supporting adapters.

### 7.3 State Model

A platform-independent `OverlayState` represents:

- Manual visibility: shown or hidden.
- Automatic environment visibility: normal Space or fullscreen Space.
- Animation state: running or paused.
- Input state: passive or interactive.
- Current target screen identifier.
- Last calculated panel frame.

Effective visibility is derived from manual and environment visibility. The window controller observes state and applies it to the panel; menu commands mutate state rather than manipulating the window directly.

### 7.4 Placement Service

A placement service accepts screen geometry and placement policy as plain values and returns a panel rectangle. It contains no global `NSScreen` access, allowing geometry to be unit tested.

An AppKit adapter:

- Resolves the target screen.
- Converts `NSScreen` values into placement inputs.
- Observes display and workspace changes.
- Requests recalculation when stable screen geometry changes.
- Suppresses movement caused only by transient auto-hidden Dock reveal or conceal events.

### 7.5 Space and Fullscreen Monitoring

A workspace monitor observes active Space and frontmost application changes, then updates automatic environment visibility.

The implementation must use documented macOS APIs and must not require Accessibility, Screen Recording, or other privacy permissions for the prototype. If reliable fullscreen detection cannot be achieved under that constraint, Phase 0 is not considered complete; the limitation must be documented and reviewed before changing the requirement.

Fullscreen detection uses documented window geometry. An opaque frontmost layer-zero window matching the target display within two points is intentionally treated as fullscreen so fullscreen games and applications are covered. This may falsely hide the rail for a rare borderless exact-screen window on a normal Space. The owner accepts this Phase 0 limitation because exact Space membership cannot be distinguished under the documented APIs without privacy permissions.

### 7.6 Scene Host

A SpriteKit scene host owns scene creation, animation state, and interaction forwarding. It exposes only the controls needed by `OverlayState`:

- Start animation.
- Pause animation.
- Resume animation.
- Handle or ignore pointer interaction.

No gameplay simulation layer is introduced in Phase 0.

## 8. Data Flow

At launch:

1. The application creates `OverlayState`.
2. The screen adapter resolves the target screen.
3. The placement service calculates the rail frame.
4. The window controller creates and positions the panel.
5. The scene host creates the SpriteKit scene.
6. The panel appears only after valid placement and scene setup complete.

During operation:

1. Menu commands update `OverlayState`.
2. Workspace and screen monitors update environmental state.
3. Derived state determines effective visibility, animation, and input behavior.
4. The window controller and scene host apply only relevant state changes.

There is no persistence. Every launch begins with the approved defaults: shown, running, and passive.

## 9. Failure Handling

- If no target screen is available, the panel remains hidden and screen resolution is retried after the next display notification.
- If placement inputs are invalid, the last valid frame is retained; without a last valid frame, the panel remains hidden.
- If SpriteKit scene creation fails, the panel remains hidden while menu bar commands and Quit continue to work.
- If fullscreen state cannot be resolved temporarily, the previous known environment visibility is retained to prevent rapid flashing.
- Display and workspace events are debounced so a burst of notifications cannot repeatedly move or show the panel.
- Errors are logged with Apple `Logger`; no remote telemetry is sent.

The app must not crash because a display disappears, screen geometry changes, or an event arrives during shutdown.

## 10. Runtime Logging

Use structured `Logger` categories for:

- Application lifecycle
- Overlay state changes
- Panel creation and placement
- Screen selection and geometry changes
- Space and fullscreen transitions
- Scene lifecycle

Logs must record state and geometry needed for diagnosis without recording window titles, application content, user input, or other private data.

## 11. Automated Testing

Unit tests cover:

- Width calculation at, below, and above clamp boundaries.
- Centering and bottom-offset calculations.
- Placement with normally visible and auto-hidden Dock policies.
- Manual visibility taking priority over automatic visibility.
- Fullscreen hide and normal-Space restore behavior.
- Pause/resume and passive/interactive state transitions.
- Invalid geometry retaining the last valid frame.
- Notification debouncing behavior using a controllable clock.

AppKit integration remains thin enough that most behavior can be tested without creating a real panel.

The build and unit-test suite must pass from the command line with `xcodebuild` before any task passes review.

## 12. Manual QA Gate

On the target Mac, verify:

- Launch creates one menu bar item and no normal Dock icon.
- The rail appears centered at the approved dimensions.
- Underlying desktop and application controls receive clicks in passive mode.
- Interactive mode receives actor clicks without taking keyboard focus.
- Switching among normal Spaces does not duplicate, lose, or visibly jump the rail.
- Entering another application's fullscreen Space hides the rail.
- Returning to a normal Space restores the rail unless manually hidden.
- Revealing and hiding an auto-hidden Dock does not move the rail.
- Manual hide, pause, and interaction commands remain internally consistent.
- Sleep and wake restore a valid rail exactly once.
- Relaunch returns to shown, running, passive defaults.
- Quit terminates without a lingering process or panel.

Resource measurements on the target machine:

- Active animated rail: average process CPU below 5 percent over five minutes.
- Hidden or paused rail: average process CPU below 0.5 percent over five minutes.
- No monotonic memory growth over a 30-minute active run.

Measurements are recorded in the Phase 0 completion report.

## 13. Delivery and Review Process

The primary model owns requirements, architecture, implementation planning, task decomposition, integration decisions, and final acceptance.

Subagent model routing:

- `gpt-5.6-luna`: default implementer for tightly scoped code and test tasks.
- `gpt-5.6-terra`: multi-file integration, debugging, and task-level review.
- `gpt-5.6-sol`: architecture-sensitive work and final whole-branch review only.

If a task exceeds its assigned model's capability, it is clarified, split, or escalated to the next model tier. The same blocked prompt is not repeatedly sent unchanged. The primary conversation model cannot switch itself automatically; if account allocation is exhausted, durable progress records allow work to resume without repeating completed tasks.

Each implementation task requires:

1. A bounded task brief with explicit file ownership and tests.
2. Test-first implementation by a fresh coding subagent.
3. Passing focused tests and implementer self-review.
4. Independent specification and code-quality review.
5. Fixes and re-review for Critical or Important findings.
6. A recorded completion entry in the subagent-development progress ledger.

After all tasks:

1. Run the full build and test suite.
2. Complete the manual QA gate on the target Mac.
3. Run an independent whole-branch review with `gpt-5.6-sol`.
4. Fix and re-review all release-blocking findings.
5. Record final verification evidence before declaring Phase 0 complete.

## 14. Go/No-Go Decision

Phase 0 passes only when all automated tests, manual QA checks, resource gates, and code reviews pass.

Current owner decision: **conditional/deferred GO**. Desktop viability is accepted and development may proceed based on the current evidence, while the Dock reveal observation and the unrun hidden, paused, and 30-minute memory measurements remain open accepted deferrals. These deferrals do not change the requirements above.

Passing Phase 0 authorizes design and planning for the playable MVP. It does not automatically authorize Steam integration, online services, production content volume, or any feature listed as deferred in the project outline.

If the overlay cannot meet focus, Space, fullscreen, stability, or resource requirements using documented APIs and no privacy permissions, the project pauses for an explicit product decision rather than hiding the limitation behind additional game development.
