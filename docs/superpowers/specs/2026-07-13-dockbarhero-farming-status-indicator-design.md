# DockBarHero Farming Status Indicator Design

**Status:** Written review requested

**Date:** 2026-07-13

**Project:** DockBarHero

**Builds on:**

- `docs/superpowers/specs/2026-07-12-dockbarhero-progression-safety-design.md`
- `feature/class-actions-and-loot` at `7264f8b`

## 1. Problem and Scope

The rail identifies the current enemy level but does not distinguish frontier pushing from intentional farming. A high-level party repeatedly defeating an identical low-level enemy can therefore look like combat is stalled or the enemy is immortal.

This change adds a read-only farming status line to the rail. It does not change campaign selection, encounter transitions, persistence, combat, rewards, DPS, management navigation, or overlay input behavior.

## 2. Approved Presentation

The rail keeps the existing enemy tier and level label unchanged. While `CampaignMode` is `farming`, a second line above it displays:

`FARMING • FRONTIER <highest unlocked level>`

The status uses the rail's existing monospaced typography and `NSColor.systemOrange` foreground so it reads as contextual status rather than health, damage, or an action. It occupies the currently unused enemy-side action row, aligned vertically with the party's Class Action labels.

While `CampaignMode` is `push`, the farming status node is hidden and contributes no visible placeholder. The indicator is status-only in passive and interactive modes: it has no click handler, hit target, hover behavior, or destination-changing side effect.

## 3. State and Update Rules

`GamePresentation.state.campaign` is the sole source of truth. The label reads `highestUnlockedLevel` for the frontier and keys visibility from `mode`; it does not infer mode by comparing levels.

A queued destination does not change the indicator early. The existing encounter-boundary transaction first activates the queued destination and campaign mode, then the next presentation updates the status. Returning to the frontier hides the indicator only after that transition commits. Entering manual or remedial farming shows it only after the farming destination commits.

No new saved field, event, timer, or derived domain model is introduced. Relaunch correctness follows from the already-persisted campaign mode and frontier.

## 4. Rendering Boundary

`PrototypeScene` owns a stable `farmingStatus` label node created with the other rail labels. Rendering updates its text, color, visibility, and position from the immutable presentation snapshot. The node remains presentation-only and does not participate in SpriteKit input routing.

The existing enemy label, health bar, sprite, DPS scale, party labels, rail dimensions, placement, focus behavior, fullscreen suppression, and passive click-through behavior remain unchanged.

## 5. Testing and Live QA

Implementation uses TDD. Focused scene tests prove:

- farming renders the exact frontier status and `NSColor.systemOrange` color;
- push mode hides the status node;
- the existing enemy tier/level label remains unchanged;
- rendering a farming-to-push or push-to-farming snapshot updates visibility without recreating or duplicating the node;
- the status node does not become a Class Action hit target.

Regression verification runs the complete arm64 suite, clean unsigned arm64 build, context guard, and exact-worktree launch. Live QA confirms the current level-1 farming run visibly reports its level-192 frontier and that returning to the frontier removes the status at the encounter boundary.

## 6. Completion Criteria

The feature is complete when the rail unambiguously identifies every farming encounter and its current frontier, remains visually unchanged during frontier pushing except for hiding the status, preserves all simulation and overlay behavior, and passes focused, full-suite, build, context, launch, and live-transition checks.
