# DockBarHero Product Backlog

**Captured:** 2026-07-15

**Source:** Owner review of the integrated local `main` build

**Status:** Pending; this file records product intent, not approved implementation designs

## Working Rules

- Ground each item in current code and live behavior before changing it.
- Use a focused design/spec discussion for every item marked **Design gate**.
- Do not generate or replace manga pages until the cohesive-story design is discussed and approved.
- Preserve unrelated user work and keep the app runnable after each accepted slice.
- The dropped-loot decision below supersedes the older roadmap rule that every overflow item remains directly accessible to the player.

## Recommended Order

1. Diagnose the balance failure and restore readable, trustworthy rail/management information.
2. Repair existing Book behavior and clarify its audio/progression controls.
3. Tighten party layout and add the temporary Dock presence.
4. Design the shared audio system and hero conversation feature.
5. Design the cohesive campaign story and Map together; do not generate art yet.
6. Design dropped loot/shop recovery and skill trees as separate gameplay slices.

## A. Immediate Bugs and Readability

### A1. Fix overlapping enemy/status typography

**Observed:** `FARMING • FRONTIER 100`, enemy identity, and `Normal · Enemy Lv. 74` overlap and become unreadable on the rail.

**Required outcome:**

- Enemy/status copy uses the same readable visual scale as the other rail labels.
- Farming, enemy identity, enemy level/tier, health bar, and sprites do not intersect at supported rail widths.
- Long authored names remain clipped or marquee within their own lane.
- Add geometry tests for wide and narrow layouts and live-check both light and dark desktop backgrounds.

**Likely surfaces:** `DockBarHero/Rendering/PrototypeScene.swift`, `DockBarHeroTests/PrototypeSceneHostTests.swift`

### A2. Replace the twitchy DPS readout

**Design gate:** Decide the primary metric before implementation.

**Owner direction:** Real-time DPS is not useful enough. Prefer a stable recent average, such as the last 60 seconds; total damage may also be useful.

**Candidate presentation:** Primary `60s DPS`, with total run or encounter damage available in management rather than crowding the rail.

**Required outcome:**

- Define exact sample window, startup behavior before 60 seconds, encounter-boundary behavior, and whether farming transitions reset it.
- Keep metric state bounded and deterministic.
- Avoid rapid zero/high-number flicker.

**Likely surfaces:** `DockBarHero/Game/DamageMetrics.swift`, `DockBarHero/Game/GameModels.swift`, `DockBarHero/Rendering/PrototypeScene.swift`, `DockBarHero/App/OverviewView.swift`

### A3. Correct the misleading Deaths statistic

**Observed/code finding:** Overview labels `HeroState.consecutiveDeaths` as `Deaths`. That field resets after recovery/progression, so zero is a streak value rather than lifetime history.

**Design gate:** Choose one of these meanings:

- Rename the existing value to `Current Death Streak`; or
- Add a durable lifetime/area death counter and display that as `Deaths`.

**Required outcome:** The label and stored statistic must have the same scope and reset rules.

**Likely surfaces:** `DockBarHero/App/OverviewView.swift`, `DockBarHero/Game/GameModels.swift`, reward/defeat resolvers, save validation and fixtures

### A4. Audit Level 100 boss balance

**Observed:** Two Level 240 heroes are being wiped by the Level 100 boss.

**Diagnosis before tuning:**

- Capture hero class, stats, equipment, abilities/cooldowns, party unlock state, boss stats, damage order, and defeat sequence.
- Determine whether the cause is scaling math, missing third-party-slot progression, poor equipment, inactive class actions, boss tuning, or a combination.
- Compare Boss 100 time-to-kill and incoming damage against nearby Normal/Elite encounters and intended progression pacing.

**Required outcome:** Boss 100 is a meaningful gate without invalidating roughly 140 levels of hero advantage. Balance changes require deterministic regression fixtures.

**Likely surfaces:** balance configuration, encounter schedule, enemy factory, combat/ability resolvers, party unlock rules

## B. Rail and Window UX

### B1. Tighten the party formation

**Observed:** Current heroes and health bars are spread too far apart, and the formation does not feel like a party.

**Required outcome:**

- Reduce health-bar width and horizontal gaps while preserving readable labels.
- Keep Tank, DPS, and Healer visually grouped when all three slots are active.
- Preserve collision-free layouts at wide and narrow rail widths.
- Verify the Boss 100 third-slot unlock/selection path while doing this work.

**Likely surfaces:** `DockBarHero/Rendering/PrototypeScene.swift`, party unlock presentation/tests

### B2. Show a Dock icon only while management is open

**Required outcome:**

- Opening the management window temporarily gives DockBarHero a Dock icon and normal app-switching presence.
- Clicking the icon returns to the existing management window rather than creating another instance.
- Closing the management window removes the Dock icon and returns the app to menu-bar/overlay behavior.
- The transition must not steal focus during passive gameplay or create duplicate app processes/windows.

**Likely surfaces:** `DockBarHero/App/AppDelegate.swift`, management window controller/delegate, activation-policy tests and live Mac QA

### B3. Add hero conversations on the rail

**Design gate:** Define cadence, interruption rules, cast voices, content catalog, and relationship to combat events.

**Required outcome:**

- Heroes occasionally show small thought/speech bubbles and conduct short exchanges.
- Conversations remain readable without obscuring combat labels or actors.
- Every authored exchange can have matching voiced cues.
- Repetition is bounded and deterministic enough to test; conversations never change combat state.
- Muting hero audio does not hide text bubbles unless a separate future setting explicitly does so.

## C. Book Repairs and Audio UX

### C1. Restore the audible volume-knob giggle

**Observed:** Moving the Book volume knob produces only a text reaction; no giggle is audible.

**Required outcome:**

- Knob movement triggers the authored giggle audio when Book audio is enabled and the Book is open.
- Rapid knob movement is debounced/throttled so samples do not stack into noise.
- Muting Book audio or all audio suppresses the sound while retaining accessible textual feedback.
- The reaction respects Book volume and stops when the Book closes.

**Likely surfaces:** `DockBarHero/Lore/BookVolumePotentiometer.swift`, `LoreBookView.swift`, lore audio service/manifest, App settings/model

### C2. Restore manga motion-panel animation

**Observed:** The one designated animated panel on manga pages no longer animates.

**Diagnosis before repair:** Verify decoded frame count, selected motion panel, Book-open state, scene phase, Reduced Motion, global animation preference, and timeline scheduling.

**Required outcome:**

- Exactly one authored motion region loops at four or five frames maximum.
- Still panels remain still.
- Reduced Motion intentionally freezes the motion region and clearly explains why in Settings/accessibility copy.
- Closing the Book or deactivating the app pauses work; reopening resumes correctly.

**Likely surfaces:** `DockBarHero/Lore/LorePageView.swift`, lore catalog/resources, animation settings and tests

### C3. Reduce speech-bubble artwork coverage

**Required outcome:**

- Speech balloons occupy less of each manga panel while remaining legible.
- Prefer authored anchor/focal-point-aware placement over one global overlay position.
- Long lines wrap compactly and cannot cover the motion panel's focal subject.
- Validate every current page at wide and compact Book sizes.

**Likely surfaces:** `DockBarHero/Lore/LoreMangaTextOverlay.swift`, composition sidecars, `LorePageView.swift`

### C4. Add bottom padding below the volume knob

**Required outcome:** Move the knob a few pixels farther from the Book's bottom border without shrinking its hit target or breaking compact layout.

**Likely surface:** `DockBarHero/Lore/LoreBookView.swift`

### C5. Explain when the Book speaks and how pages unlock

**Design gate:** Finalize the reader contract before changing controls/copy.

**Questions the UI must answer:**

- When does a page speak automatically, if ever?
- What is muted by Book mute versus global mute?
- How does the player replay the current line/page?
- Does changing pages interrupt or queue speech?
- Which pages are unlocked by campaign/frontier progress?
- Can unlocked pages always be revisited freely?

**Required outcome:** Controls and short in-Book/Settings copy make these rules discoverable without requiring documentation. Speech remains opt-in and never plays while the Book is closed.

### C6. Build a real audio mixer in Settings

**Design gate:** Specify persistence and precedence rules.

**Required controls:**

- Mute all audio.
- Mute Book audio only.
- Mute hero conversation audio only.
- Separate Book and hero volume controls.

**Required behavior:** Global mute overrides channel settings without destroying their saved values. Unmuting restores prior per-channel levels. All audio remains opt-in by default, and no Book audio plays outside the open Book.

**Likely surfaces:** `DockBarHero/Settings/AppSettings.swift`, `DockBarHero/App/SettingsView.swift`, App model/actions, lore speech service, new hero speech service

## D. Story and Campaign Cohesion

### D1. Rewrite the lore around one coherent ridiculous story

**Discussion required — do not generate pages yet.**

**Owner direction:** Kevin is a successful recurring thread, but the current pages feel like disconnected jokes. The story must remain absurd, profane, genre-mashed, fourth-wall-breaking, and funny while still having causal continuity.

**Story design must establish:**

- The sequence of events that brings Tank, DPS, Healer, Kevin, and the Book together.
- What each character wanted before joining and why they reluctantly stay.
- A continuing problem/goal that carries across areas and 100-level story volumes.
- How dungeon events cause later locations, warp gates, villains, and genre shifts.
- Character relationships, recurring setups/payoffs, and consequences beneath the jokes.
- The Book as an unreliable interface character whose mistakes can cause plot events.

**Hard gate:** Discuss and approve the narrative spine, cast arcs, area sequence, and Volume One page outline before writing dialogue or generating/replacing images.

### D2. Add a Map management section

**Design gate:** Design alongside the campaign/story spine.

**Required outcome:**

- Show areas, routes/warp gates, current farming location, frontier, unlocked destinations, bosses, and story gates.
- Clearly distinguish discovered, unlocked, current, completed, and future/unknown locations.
- Selecting a destination follows existing queued-travel/farming rules rather than bypassing progression.
- Map state comes from deterministic campaign data and becomes the connective surface for story progression.

**Likely surfaces:** management routes/root view, campaign catalog/state/resolver, new Map view and tests

## E. Loot and Economy

### E1. Replace overflow inventory with dropped ground loot

**Design gate:** This changes durable save/economy semantics and supersedes the older overflow model.

**Confirmed product rule:** When the currently unlocked inventory slots are full, newly earned loot is dropped on the ground rather than stored in inventory overflow.

**Required behavior:**

- Track enough durable aggregate value/quantity to survive save, relaunch, offline progress, and crashes without retaining a second browsable inventory.
- Dropped items cannot be equipped, moved, salvaged, or individually inspected.
- Visiting the Shop automatically sells every dropped item for exactly 25% of its normal value and clears the pile atomically.
- The player receives a concise sale summary.
- Define deterministic rounding, Unique-item treatment, stack valuation, integer-overflow protection, and save migration/removal of existing overflow stacks.
- Offline loot uses the same rule and cannot be claimed twice.

**Likely surfaces:** inventory/reward/loot resolvers, game/save models, validation/migration fixtures, Inventory and Shop views

### E2. Render the escalating loot pile behind the heroes

**Required outcome:**

- Display approximate pile tiers based on dropped-loot quantity/value; no item-for-item visual accuracy is required.
- Use deliberately escalating, roughly Fibonacci-like thresholds so each tier grows noticeably.
- Keep the pile behind actors and labels.
- At extreme tiers, animate occasional junk falling off the rail as a presentation-only gag.
- Reduced Motion freezes falling pieces without changing the pile tier or economy.
- Visiting the Shop clears the visual pile when the atomic auto-sale succeeds.

**Asset direction:** Create a small sequence of transparent pile sprites from tiny heap through screen-edge catastrophe; do not generate these assets until the pile thresholds/layout are approved.

## F. Long-Term Progression

### F1. Add class skill trees and skill points

**Design gate:** Define the progression economy before implementation.

**Required design decisions:**

- How skill points are earned and whether gains are per hero or party-wide.
- Tank, DPS, and Healer tree identities and prerequisites.
- Passive versus active upgrades, ranks, caps, and unlock pacing.
- Respec availability/cost and invalid-build handling after balance changes.
- Save persistence, validation, and migration behavior.
- Interaction with current class actions, equipment, auto-cast, and balance targets.

**Required outcome:** Each class gets meaningful build choices rather than a linear stat ladder. Implement as separate testable slices after the system design is approved.

**Likely surfaces:** existing Skills route, new skill catalog/resolver/state, Settings/management presentation, save fixtures

## Definition of Backlog Completion

This review backlog is complete only when each checkbox below has a linked approved spec or verified implementation record:

- [ ] Rail typography is readable and collision-free.
- [ ] DPS presentation uses the approved stable metric.
- [ ] Death statistics are correctly scoped and labeled.
- [ ] Boss 100 balance is diagnosed and accepted.
- [ ] Three-hero formation and unlock presentation are accepted.
- [ ] Management has temporary Dock presence while open.
- [ ] Hero text/voice conversations and audio controls are accepted.
- [ ] Book giggle, motion panel, bubbles, padding, and speech UX are accepted.
- [ ] Cohesive story and Map designs are approved before new manga art.
- [ ] Overflow is replaced by durable dropped loot and 25% Shop auto-sale.
- [ ] Loot-pile presentation is approved and implemented.
- [ ] Class skill trees and skill-point progression are approved and implemented.
