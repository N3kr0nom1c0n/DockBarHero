# Mac Desktop Idle RPG Project Outline

## Executive Summary

This project would be a macOS-native desktop companion inspired by *TBH: Task Bar Hero*: a tiny idle RPG that lives along the bottom edge of the desktop, continues fighting and gathering loot with minimal input, and opens into larger management views when the player wants to adjust equipment, skills, or party composition.

A literal copy of the Windows taskbar presentation is not practical on macOS. Apple does not provide a supported way for third-party apps to embed animated gameplay inside the Dock. The closest reliable Mac-native experience is:

- A narrow, transparent, borderless game window positioned immediately above the Dock.
- A menu bar item for pause, visibility, settings, and quit controls.
- A conventional management window for inventory, builds, progression, and settings.
- Behavior that adapts to Dock position, auto-hide, multiple displays, Spaces, fullscreen apps, and Stage Manager.

The recommended first release is a focused, local-first desktop idle RPG. Steam achievements and cloud saves can follow once the core experience is stable. Tradable Steam Market items and a server-backed economy should be explicitly deferred because they add substantial security, operational, and economy-design complexity.

## Product Experience

The player sees a small pixel-art party continuously traveling and fighting along the lower edge of the desktop. The strip should feel present without competing with normal Mac use.

The core loop is:

1. Heroes automatically encounter and fight enemies.
2. Enemies award experience, currency, and equipment.
3. The player periodically opens the management window to compare loot, equip items, choose upgrades, and adjust the party.
4. Stronger builds advance into harder areas, elite encounters, and bosses.
5. Progress continues at a controlled rate while the app is closed, using calculated offline progress rather than replaying every missed combat frame.

The game strip should support a few deliberate interaction modes:

- **Passive:** Clicks pass through to the app underneath it.
- **Interactive:** The player can click heroes, loot, or compact controls.
- **Hidden:** The simulation continues while the strip is not visible.
- **Paused:** Both rendering and progression stop.

## macOS Platform Constraints

### No Supported Dock Embedding

The app should not attempt to inject views into, modify, or replace the macOS Dock. That would depend on private APIs or brittle system manipulation and would create compatibility, signing, security, and distribution problems.

The supported approximation is an independent transparent window aligned to the Dock edge. It can visually appear attached to the Dock while remaining a normal application-owned window.

### Desktop Placement

The overlay must account for:

- Dock on the bottom, left, or right side of a display.
- Dock auto-hide and changing available screen space.
- Multiple monitors with different resolutions and scaling factors.
- The user changing the primary display while the app is running.
- Mission Control and separate Spaces.
- Fullscreen applications, where the overlay should normally stay out of the way.
- Stage Manager and other window-management behavior.
- Menu bar and safe-area changes across Mac models.

`NSScreen.visibleFrame` provides a useful starting point, but placement logic will need to observe screen and workspace changes and re-evaluate the overlay position. The user should also be able to choose a display and manually adjust the strip offset when automatic placement is imperfect.

### App Store Versus Direct Distribution

A sandboxed Mac App Store build may impose constraints that complicate Steam integration and some desktop-level behavior. The initial distribution target should be a signed and notarized direct-download or Steam build. App Store feasibility can be evaluated after the overlay behavior and required entitlements are proven.

## Recommended Technical Architecture

### Native Application Shell

Use Swift and SwiftUI for the application lifecycle, management windows, settings, menus, and standard Mac controls. Use a narrow AppKit bridge where SwiftUI does not expose enough control over the overlay window.

The overlay would be hosted in a borderless `NSPanel` or `NSWindow` configured for:

- Transparent background.
- No title bar or conventional window chrome.
- Stable placement above the Dock.
- Optional click-through behavior.
- Controlled behavior across Spaces and fullscreen contexts.
- No accidental activation or focus stealing during passive play.

The AppKit integration should remain isolated in a window controller rather than spreading AppKit state throughout the game and UI code.

### Rendering

SpriteKit is the recommended renderer for the first version. It is well suited to a small 2D pixel-art scene, animation, particles, hit effects, and sprite batching without adding the footprint of a general-purpose engine.

Metal is available if profiling later shows that SpriteKit cannot meet a specific rendering need, but it would add implementation cost without a clear early benefit. Unity or Godot could also build the game, but integrating their rendering and lifecycle cleanly into a lightweight, Mac-native desktop overlay would produce a larger and less native application.

### Simulation and Rendering Separation

Combat and progression must be independent of animation frames. The simulation should operate on deterministic game state and elapsed time, while SpriteKit only presents that state.

Suggested component boundaries:

- `GameSimulation`: Advances combat, encounters, timers, rewards, and progression.
- `CombatResolver`: Applies attacks, abilities, status effects, deaths, and victory rules.
- `EncounterDirector`: Selects waves, elites, bosses, and area progression.
- `LootGenerator`: Produces items from versioned drop tables.
- `Inventory`: Owns item storage, equipment, comparison, and salvage rules.
- `BuildSystem`: Owns classes, stats, skills, and upgrade choices.
- `SaveStore`: Persists versioned local game state and migrations.
- `OfflineProgressCalculator`: Computes bounded progress from time away.
- `OverlayWindowController`: Owns Mac-specific window placement and interaction mode.
- `GameScene`: Renders the current simulation state with SpriteKit.
- `SteamService`: An optional boundary for achievements, cloud saves, and stats.

This separation allows the game logic to be tested without running a window or renderer and prevents frame-rate changes from changing combat outcomes.

### Persistence

Use a versioned, atomic local save format. The app should keep a recent backup and recover gracefully from an interrupted write or incompatible save.

Offline progression should:

- Store a trusted last-save timestamp and the minimum state needed to resume.
- Apply a configurable maximum offline duration.
- Simulate results in aggregate rather than executing millions of individual ticks.
- Present a concise return summary showing time away, encounters completed, currency earned, and notable loot.

Steam Cloud should synchronize the same save format later. Conflict handling must let the player choose between clearly timestamped local and cloud versions rather than silently replacing progress.

## Initial Game Scope

### Core Systems

The first complete version should include:

- One controllable party with a small number of hero slots.
- Three distinct classes with complementary combat roles.
- Automatic attacks and a limited set of class abilities.
- Several normal enemy families, elite variants, and bosses.
- Area or act progression with increasing difficulty.
- Experience, levels, base stats, and meaningful upgrade choices.
- Equipment slots and procedurally rolled loot.
- A small number of understandable item rarity tiers.
- Inventory management, comparison, equip, lock, and salvage actions.
- Local saves and bounded offline progress.
- Audio, animation, and overlay visibility controls.
- A reset or prestige system only if normal progression becomes exhausted during playtesting.

### Management Window

The larger window should provide:

- Party and character details.
- Equipment and inventory views.
- Skill or upgrade selection.
- Current area, encounter, and boss progress.
- A compact activity or loot history.
- Overlay placement, display, sound, performance, and launch-at-login settings.

The overlay itself should stay compact. Inventory grids and detailed build editing belong in the management window, not in the desktop strip.

### Content Target

The MVP should favor a small set of well-differentiated content over hundreds of shallow items. A reasonable target for validating the game is:

- 3 classes.
- 3 areas plus a boss encounter for each area.
- 8-12 normal enemy types with a few elite modifiers.
- 30-50 equipment templates with procedural stat rolls.
- 15-25 class upgrades or skills in total.
- 60-90 minutes to see the complete basic loop, with longer progression available through builds and difficulty increases.

These are planning targets, not commitments. Playtesting should determine the final quantities.

## MVP Definition

The MVP is successful when a player can:

1. Launch the app and see a stable game strip positioned above the Dock.
2. Continue using other applications without the strip stealing focus or blocking normal clicks in passive mode.
3. Watch a party automatically fight through several encounters.
4. Receive, inspect, equip, and salvage loot in a separate management window.
5. Close and reopen the app without losing progress.
6. Return after time away and receive believable, bounded offline rewards.
7. Move between displays, toggle Dock auto-hide, and change Spaces without leaving the overlay stranded or incorrectly sized.

The MVP does not need a large campaign, online services, multiplayer, trading, or a live economy.

## Features to Defer

The following features should be intentionally excluded from the initial build.

### Steam Market and Tradable Items

Do not launch with tradable Steam inventory items. A real-money-adjacent item economy requires much more than connecting the Steam SDK:

- Server-authoritative item grants and inventory reconciliation.
- Drop-rate limits and platform policy compliance.
- Fraud, botting, automation, replay, and clock-manipulation defenses.
- Idempotent reward processing so retries cannot duplicate items.
- Economy telemetry and emergency controls.
- Item lifecycle, scarcity, pricing, and balance management.
- Backend scaling, monitoring, incident response, and support tooling.
- Ongoing coordination with Valve as player volume and item traffic change.

*Task Bar Hero* itself encountered Steam marketplace and server-load problems after unexpectedly high adoption, making this a concrete warning rather than a theoretical concern. Tradable items should be treated as a separate product and backend phase after the local game has proven retention and balance.

### Multiplayer and Social Systems

Skip cooperative combat, PvP, guilds, chat, leaderboards, shared worlds, and player-to-player trading. Each introduces identity, moderation, synchronization, cheating, service availability, and support requirements that do not improve the core desktop-companion experiment.

### Cross-Platform Support

Do not build Windows or Linux versions during the Mac MVP. The distinctive technical risk is Mac overlay behavior, so platform abstraction before that behavior is validated would slow development. Keep simulation and data models portable where practical, but do not promise another platform yet.

### Mobile Companion

Skip iPhone or iPad companions, remote inventory management, and push notifications. They require account infrastructure and synchronization before the desktop game has demonstrated that players need those capabilities.

### App Store Release

Defer Mac App Store packaging until the direct build is stable. Sandbox restrictions, review interpretation, in-app purchasing rules, and Steam incompatibilities may require a distinct distribution strategy.

### Large Content Volume

Do not target hundreds of items, dozens of classes, multiple long acts, or fifty-plus achievements for the first release. Content production and balance can consume more time than the engine. Build data-driven tools and prove that a small content set is fun before scaling it.

### Custom Engine and Low-Level Renderer

Do not begin with a custom Metal renderer or general-purpose game engine architecture. SpriteKit can handle the proposed scale. A lower-level renderer should only be introduced in response to measured limitations.

### Advanced Live Operations

Skip daily quests, seasons, battle passes, rotating shops, remote balance configuration, limited-time events, and always-online requirements. These features create an operational treadmill and can distort the quiet desktop-companion experience.

### Generative Content

Skip AI-generated live dialogue, quests, items, or art in the running game. It would add latency, cost, safety, consistency, and offline behavior problems without validating the central game loop.

## Delivery Phases

### Phase 0: Technical Prototype (1-3 Weeks)

Goal: prove that the Mac desktop presentation is viable.

- Create a transparent borderless overlay with a simple animated SpriteKit scene.
- Align it above the Dock and respond to display changes.
- Test click-through, activation, Spaces, fullscreen apps, Stage Manager, and Dock auto-hide.
- Add a minimal menu bar item for show, hide, pause, interaction mode, and quit.
- Measure idle CPU, GPU, and energy impact.

This phase should use placeholder art and minimal game logic. Its output is a go/no-go decision on the desktop experience.

### Phase 1: Playable MVP (Approximately 6-10 Weeks Total)

Goal: validate the complete idle-RPG loop.

- Add frame-independent combat and encounter progression.
- Add classes, stats, abilities, enemies, bosses, loot, and equipment.
- Build the management window.
- Add versioned local saves and offline progress.
- Add enough placeholder or early production art to judge readability.
- Add unit tests for simulation, rewards, persistence, and offline calculations.
- Run repeated overlay testing across supported Mac configurations.

### Phase 2: Release Candidate (Approximately 3-5 Months Total)

Goal: ship a polished Mac game without market trading.

- Replace placeholder visuals and audio.
- Expand and balance content based on playtests.
- Improve onboarding, accessibility, settings, and save recovery.
- Add Steam achievements, stats, and cloud saves if distributing on Steam.
- Add crash reporting and privacy-conscious runtime telemetry.
- Complete signing, hardened runtime configuration, notarization, packaging, and update delivery.
- Test on Intel only if Intel Macs are explicitly supported; otherwise set and communicate an Apple Silicon minimum.

### Phase 3: Optional Online Economy (Additional 2-4+ Months)

Goal: evaluate tradable items only after the game has demonstrated demand.

This phase requires backend engineering, security review, economy design, abuse testing, operational dashboards, rate limiting, platform coordination, and an ongoing support commitment. The estimate can increase substantially depending on compliance requirements and player scale.

## Team and Effort

For one experienced developer who can handle Swift/AppKit and game systems, supported by purchased or commissioned art and audio:

| Milestone | Rough effort |
| --- | ---: |
| Overlay technical proof | 1-3 weeks |
| Playable MVP | 6-10 weeks total |
| Polished release without trading | 3-5 months total |
| Steam Market economy | 2-4+ additional months |

The largest schedule variables are content production, balance iteration, Mac window-behavior edge cases, and the quality bar for animation and audio. A small team could parallelize art, content, and engineering, but the overlay prototype should still happen first because it validates the product's defining feature.

Suggested minimum roles for a polished commercial release:

- macOS/gameplay engineer.
- Pixel artist and animator, part-time or contract.
- Sound designer and composer, contract.
- Game designer or strong design ownership from the engineer.
- QA coverage across Mac hardware and display configurations.

An online economy additionally needs backend, security, live-operations, and support ownership.

## Principal Risks and Mitigations

### Overlay Feels Intrusive

**Risk:** The strip blocks content, steals focus, distracts the player, or behaves unpredictably across Spaces.

**Mitigation:** Prototype first; default to passive click-through; provide fast hide and pause controls; keep placement and opacity adjustable; define clear fullscreen behavior.

### Excessive Resource Use

**Risk:** A constantly visible game consumes noticeable battery or GPU time.

**Mitigation:** Cap animation frame rate, suspend rendering when hidden or occluded, keep simulation ticks coarse, batch sprites, avoid unnecessary effects, and profile energy impact on a laptop.

### Idle Progress Invalidates Gameplay

**Risk:** Rewards are either too slow to matter or so fast that build choices do not matter.

**Mitigation:** Keep progression formulas data-driven, cap offline gains, instrument progression pacing, and playtest both frequent check-ins and multi-day absences.

### Inventory Becomes Chore Work

**Risk:** Procedural drops produce constant low-value management.

**Mitigation:** Limit early item complexity; make comparisons clear; add lock, filters, and bulk salvage; tune drop frequency around meaningful decisions rather than volume.

### Save Exploits and Clock Manipulation

**Risk:** Players change system time or duplicate save files to gain rewards.

**Mitigation:** For a local-only game, accept that determined players can modify their own progress while preventing accidental exploits. Strong enforcement is only necessary if rewards become tradable or competitive, at which point the server must become authoritative.

### Content Scope Expands Too Early

**Risk:** Production focuses on classes and item count before the overlay and combat loop are enjoyable.

**Mitigation:** Hold content to the MVP targets until retention, progression pacing, and desktop ergonomics are validated.

## Testing Strategy

### Automated Tests

- Deterministic combat outcomes using seeded randomness.
- Stat, damage, mitigation, ability, and status-effect calculations.
- Loot rarity, affix eligibility, and drop-table boundaries.
- Inventory capacity, equip rules, locking, and salvage behavior.
- Area and boss progression.
- Save/load round trips and migration from older save versions.
- Interrupted or corrupt save recovery.
- Offline progress caps and large elapsed-time calculations.
- Steam service behavior through a local test double.

### macOS Integration Tests

- Overlay position with Dock on each supported edge.
- Dock auto-hide enabled and disabled.
- Single and multiple displays with mixed scaling.
- Display connect, disconnect, rearrangement, and primary-display changes.
- Spaces, Mission Control, fullscreen apps, and Stage Manager.
- Click-through and interactive modes.
- Sleep, wake, logout, relaunch, and launch at login.
- Reduced motion, audio controls, and relevant accessibility settings.
- CPU, GPU, memory, and energy impact while active, idle, hidden, and paused.

### Playtesting

- First-session understanding without lengthy instructions.
- Readability at the small overlay scale.
- Whether the game remains pleasant during normal computer use.
- Frequency and quality of inventory decisions.
- Progression during short sessions, workday-length absences, and multi-day absences.
- Whether hiding the strip feels like a normal control rather than abandoning the game.

## Recommended First Build

The first build should be a Mac-only, local-first desktop companion with:

- A native transparent overlay above the Dock.
- A menu bar controller.
- One small party auto-fighting through a few encounters.
- Basic loot and equipment management.
- Local persistence.
- No accounts, servers, multiplayer, trading, or marketplace integration.

The project should advance only after the overlay prototype demonstrates that it can remain stable, unobtrusive, readable, and energy-efficient during real daily Mac use. If that experience works, the simulation and content can grow with relatively conventional game-development techniques. If it does not, more content will not rescue the core product premise.

## Reference Material

- [TBH: Task Bar Hero on Steam](https://store.steampowered.com/app/3678970/TBH_Task_Bar_Hero/)
- [PC Gamer overview of Task Bar Hero's classes and play loop](https://www.pcgamer.com/games/rpg/task-bar-hero-tier-list/)
- [GamesRadar report on Task Bar Hero's Steam marketplace and server-load problems](https://www.gamesradar.com/games/rpg/rpg-devs-apologize-to-steam-staff-and-all-of-our-players-after-their-game-draws-164-000-concurrent-players-and-starts-breaking-valves-marketplace/)
