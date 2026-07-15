# Project Map

## Purpose

DockBarHero is a native macOS menu-bar idle RPG with a passive desktop rail, deterministic combat and progression, durable local runs, production pixel sprites, and a management window containing the ridiculous Book-driven lore manga.

## Current Milestone

- Goal: deliver the lore Book as readable multi-panel manga pages alongside the newer Heroes, Class Actions, Loot, farming-status, and production-sprite work.
- Current checkpoint: `codex/lore-manga-vertical-slice` at `4bc33d2` contains six five-to-seven-panel pages, one animated panel per page, six context atlases, automatic ordered TTS, and the final readability/RTL repairs.
- Integration source: `feature/class-actions-and-loot` is the pushed sprite/game branch; local and remote `main` do not contain those changes.
- Remaining: post-fix user/visual review plus compact, audio, VoiceOver, light-appearance, reduced-motion, potentiometer, and Adult-setting interaction checks. The Mac locked before post-fix screenshots could be captured.

## Architecture

- GameSimulation: deterministic fixed-point party combat, tiered rewards, XP/levels, farming, retreat, loot, equipment, and presentation snapshots.
- AbilityResolver: transactional Tank Guard, DPS Power Strike, and Healer Mend with persisted active-time cooldowns.
- LootGenerator, InventoryResolver, SalvageResolver: deterministic enriched drops, exact stacking, finite capacity, durable overflow, exclusive extraction, and atomic salvage.
- SimulationDriver and GameSession: MainActor advancement, lifecycle, autosave triggers, safe run replacement, status propagation, and final flush.
- SaveCodec, SaveStore, SaveCoordinator: schema-v2 validation, atomic recovery/replacement, quarantine, and coalescing.
- AppModel and management views: run presentation, routes, inventory, party, class actions, settings, and Book access.
- PrototypeScene: snapshot-only SpriteKit rail with deterministic clip-driven production sprites and event-only reactions.
- Lore: validated page/dialogue/composition sidecars, frontier unlock resolver, Book-scoped opt-in TTS, one four-frame motion region plus four-to-six context stills per page, irregular right-to-left layouts, and reactions reserved in the responsive header.
- AppDelegate: production dependency construction, singleton management window, and bounded termination save.

## Key Paths

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

- Parent orchestrator: keep the exact post-fix Book bundle open for user review and finish direct wide/compact QA after the Mac unlocks.
- Preserve the clean `feature/class-actions-and-loot` worktree and branch as the accepted sprite/game source.
- Do not merge the combined branch back to `main` or delete either worktree until combined verification and user review complete.
- Manual evidence stays explicit in the review packets; automated results never substitute for visual/audio inspection.

## Last Verified State

- Date: 2026-07-14.
- Pre-merge lore checkpoint: 298 arm64 tests passed; clean unsigned build and exact-worktree launch succeeded.
- Sprite/game source checkpoint: 355 arm64 tests passed; clean unsigned build, exact-worktree launch, and prior gameplay QA succeeded.
- Final checkpoint: 441 arm64 tests and 15 sprite-pipeline tests passed with zero failures; clean unsigned arm64 build and context guard succeeded.
- Exact worktree bundle launched with `--open-book` as the only DockBarHero process (PID 64599).
- Direct pre-fix inspection confirmed all six authored manga pages render as five-to-seven-panel spreads and exposed narration/reaction overlap defects. Commits `0c1a4c2`, `521453c`, `162d5cd`, and `4bc33d2` repaired readability, multi-cue TTS, catalog-order validation, and Level 10 RTL geometry; each final-review finding passed focused tests and independent re-review. Post-fix visual confirmation remains pending because the Mac locked.

## Decisions and Risks

- Gameplay time is signed Int64 nanoseconds; floating point is presentation-only.
- Save recovery preserves unreadable bytes; schema v2 uses only v2 paths because no player saves were released.
- The frontier and farming selection remain separate; three defeats retreat one Boss segment and never auto-return to the frontier.
- Party combat uses independent hero timers, ascending slot ties, lowest-living targeting, time-alive XP, and per-hero death streaks.
- Inventory is party-shared, equipped item IDs are exclusive per hero, and overflow prevents item loss.
- Production sprites are checksum-locked, normalized into transparent 96x64 cells, nearest-filtered, and selected deterministically without save-state changes.
- Lore speech defaults off, never starts outside the open active Book, and stops when the Book closes or the app resigns active.
- Lore speech completion advances every authored cue in order and rejects stale callbacks after interruption.
- Clean mode rewrites jokes rather than blanking profanity; Adult art requires confirmation.
- Long narration for Levels 5, 15, and 20 is anchored to each page's dominant motion panel so it cannot be promoted over neighboring top-row speech.
- The Book is an unreliable interface character, but accessibility labels state controls plainly.
- The current Adult alternate is a censor gag over a fully clothed adult subject.
