# Project Map

## Purpose

DockBarHero is a native macOS menu-bar idle RPG with a passive desktop rail, deterministic combat and progression, durable local runs, production pixel sprites, and a management window containing the ridiculous Book-driven lore manga.

## Current Milestone

- Goal: integrate the authored Area One campaign, current Heroes/Class Actions/Loot/sprites, multi-panel manga Book, and recorded Book voiceover into one verified local milestone.
- Current checkpoint: local `main` contains all four source workstreams, live-QA repairs, synchronized management-window titles, and the procedural enemy combat-identity repair.
- Area One replaces Levels 1 through 25 with authored dungeon encounters, then preserves the procedural campaign from Level 26 onward.
- Remaining: user review of the open Book; no push or source-worktree deletion is authorized.

## Architecture

- GameSimulation: deterministic fixed-point party combat, tiered rewards, XP/levels, farming, retreat, loot, equipment, and presentation snapshots.
- AbilityResolver: transactional Tank Guard, DPS Power Strike, and Healer Mend with persisted active-time cooldowns.
- LootGenerator, InventoryResolver, SalvageResolver: deterministic enriched drops, exact stacking, finite capacity, durable overflow, exclusive extraction, and atomic salvage.
- SimulationDriver and GameSession: MainActor advancement, lifecycle, autosave triggers, safe run replacement, status propagation, and final flush.
- SaveCodec, SaveStore, SaveCoordinator: schema-v2 validation, atomic recovery/replacement, quarantine, and coalescing.
- AppModel and management views: run presentation, routes, inventory, party, class actions, settings, and Book access.
- PrototypeScene: snapshot-only SpriteKit rail with deterministic clip-driven production sprites and event-only reactions.
- CampaignCatalog, CampaignResolver, and EnemyFactory: validated authored Area One identities and stat profiles, campaign presentation, and procedural compatibility after Level 25.
- Lore: validated page/dialogue/composition/audio sidecars, frontier unlock resolver, Book-scoped opt-in recorded MP3 speech with system-TTS fallback, one four-frame motion region plus four-to-six context stills per page, irregular right-to-left layouts, and reactions reserved in the responsive header.
- AppDelegate: production dependency construction, singleton management window, and bounded termination save.

## Key Paths

- `docs/superpowers/plans/2026-07-15-dockbarhero-worktree-integration.md`: current integration and verification plan.
- `docs/superpowers/plans/2026-07-15-dockbarhero-recorded-lore-voiceover.md`: recorded dialogue implementation plan.
- `docs/superpowers/specs/2026-07-13-dockbarhero-campaign-area-one-design.md`: authored Area One contract.
- `docs/superpowers/plans/2026-07-13-dockbarhero-campaign-area-one.md`: Area One implementation plan.
- `docs/superpowers/plans/2026-07-14-lore-book-fixed-spread.md`: fixed-spread repair plan.
- `docs/superpowers/specs/2026-07-14-dockbarhero-multi-panel-manga-pages-design.md`: approved multi-panel page design.
- `docs/superpowers/plans/2026-07-14-dockbarhero-multi-panel-manga-pages.md`: implemented multi-panel plan and verification contract.
- `docs/superpowers/specs/2026-07-13-dockbarhero-lore-manga-design.md`: approved lore, manga, censorship, and 100-level-volume design.
- `docs/superpowers/specs/2026-07-13-dockbarhero-spoken-dialogue-design.md`: approved voice and Book-audio contract.
- `docs/qa/review-packets/lore-manga-vertical-slice.md`: lore automated evidence and live-QA checklist.
- `docs/art/lore-volume1-chapter1-asset-manifest.md`: final manga image sources and visual acceptance record.
- `docs/superpowers/plans/2026-07-13-dockbarhero-production-sprites.md`: production-sprite implementation plan.
- `docs/qa/review-packets/production-sprites.md`: sprite asset, runtime, build, launch, and live-QA evidence.
- `docs/qa/review-packets/class-actions-and-loot.md`: Heroes, Class Actions, and Loot evidence.
- `docs/qa/review-packets/farming-status-indicator.md`: farming/frontier rail-status evidence.
- `DockBarHero/Lore/`: manga reader, catalog, page animation, dialogue, speech, and layout policy.
- `DockBarHero/Game/CampaignCatalog.swift`, `CampaignResolver.swift`, `EnemyFactory.swift`: authored encounter content and resolution.
- `DockBarHero/Resources/Sprites/`: bundled production sprite clips and runtime manifest.
- `DockBarHero/Game/`, `DockBarHero/Persistence/`, `DockBarHero/App/`, `DockBarHero/Rendering/`: runtime systems.
- `DockBarHeroTests/`: focused and integration tests.

## Commands

- Generate: `xcodegen generate`
- Focused test: `xcodebuild` with `platform=macOS,arch=arm64` and one test class.
- Full test: `xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -destination 'platform=macOS,arch=arm64'`
- Clean build: `xcodebuild clean build` with `CODE_SIGNING_ALLOWED=NO`.
- Live verify: `./script/build_and_run.sh --verify`
- Context check: `python3 /Users/n3kr0/.codex/skills/maintaining-project-context/scripts/context_guard.py check --root .`

## Active Work

- Parent orchestrator: keep the exact local-`main` bundle running for user review.
- Preserve every source worktree and its branch after integration.
- Merge to local `main` only after live QA succeeds; do not push.
- Manual evidence stays explicit in the review packets; automated results never substitute for visual/audio inspection.

## Last Verified State

- Date: 2026-07-15.
- Combined checkpoint: 545 arm64 XCTest tests passed with zero failures (`** TEST SUCCEEDED **`).
- Sprite-pipeline suite: 16 Python tests passed with zero failures.
- Clean unsigned arm64 build succeeded; context guard, `git diff --check`, and unmerged-entry check passed.
- Focused merge gates passed: 30 sprite/catalog tests, 49 lore/audio/catalog tests, and 111 campaign/rendering/catalog tests.
- Exact integration bundle launched as the only process. Direct QA passed wide/compact Book layout, fixed captions, RTL navigation, dark/Aqua contrast, clean/unfiltered copy, Adult confirmation, reversed volume/reaction behavior, route titles, Area One management/rail presentation, and frontier restoration.
- Procedural Level 74 live QA passed across idle, hit, defeated, and the next combat cycle: the resolved wolf sprite remained stable instead of swapping to the generic fallback.
- Recorded Replay opened the expected bundled MP3; leaving the Book immediately closed it. Subjective voice/cast audibility, Reduced Motion, and a human VoiceOver pass remain unclaimed.
- Local `main` merge `08542fe` independently passed 544 arm64 tests, 16 Python tests, a clean unsigned build, and exact-bundle launch as one process from `/Users/n3kr0/Projects/TBH/.build/RunDerivedData`.

## Decisions and Risks

- Gameplay time is signed Int64 nanoseconds; floating point is presentation-only.
- Save recovery preserves unreadable bytes; schema v2 uses only v2 paths because no player saves were released.
- The frontier and farming selection remain separate; three defeats retreat one Boss segment and never auto-return to the frontier.
- Party combat uses independent hero timers, ascending slot ties, lowest-living targeting, time-alive XP, and per-hero death streaks.
- Inventory is party-shared, equipped item IDs are exclusive per hero, and overflow prevents item loss.
- Production sprites are checksum-locked, normalized into transparent 96x64 cells, nearest-filtered, and selected deterministically without save-state changes.
- Authored campaign sprite identity takes precedence for Levels 1 through 25; procedural presentations continue through the level-based sprite resolver.
- Procedural enemy combat actions and idle restoration use that same level-resolved token; authored encounters retain their explicit campaign sprite identity.
- Rail actors retain their normal 54x36 size and scale proportionally only when a narrow three-hero lane cannot fit them.
- Lore speech defaults off, never starts outside the open active Book, and stops when the Book closes or the app resigns active.
- Recorded speech completion advances every authored cue in order, rejects stale callbacks after interruption, and falls back to system synthesis when recorded assets cannot validate.
- Clean mode rewrites jokes rather than blanking profanity; Adult art requires confirmation.
- Long narration for Levels 5, 15, and 20 is anchored to each page's dominant motion panel so it cannot be promoted over neighboring top-row speech.
- The Book is an unreliable interface character, but accessibility labels state controls plainly.
- The current Adult alternate is a censor gag over a fully clothed adult subject.
