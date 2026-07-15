# Lore Manga Vertical Slice Review Packet

**Date:** 2026-07-14

**Branch:** `codex/recorded-lore-voiceover`

**Candidate commit tested:** recorded-lore-voiceover branch HEAD, including recorded MP3 bundle validation, dialogue-catalog coverage validation, inactive-startup silence, and system-speech fallback for an incomplete, mismatched, or unreadable recorded asset set.

**Scope:** dishonest Level 100,000 prologue plus Volume I pages unlocked at Levels 1, 5, 10, 15, and 20. Boss 25 remains intentionally out of scope until Heroes and Party defines the cast.

## Delivered

- Right-to-left manga reader in the management window with responsive spread/single-page layout.
- Six validated lore pages with unfiltered/clean copy and frontier-completion unlock rules.
- Separate validated `SpokenDialogue.json` with Book, Brick, Kaizen, Mercy, Kevin, and Editor voice profiles.
- Opt-in recorded ElevenLabs dialogue that is bundled in-app, gated to an open and active Book, and stops on close/deactivation; AVSpeechSynthesizer remains the launch-safe fallback when recorded assets fail validation.
- Reversed 0...10 Book potentiometer: 0 is loudest, 10 is quietest, accessible value is honest, and movement triggers rotating Book giggles.
- Settings-v2 migration, clean/unfiltered language, safe/adult illustrations, speech opt-in, auto-read toggle, and adult-art confirmation.
- Seven final 1024x1024 four-frame manga sheets. The adult alternate is a deliberately unnecessary pixel-censor gag over a fully clothed adult character because two non-explicit generation attempts were safety-blocked.

## Automated Evidence

| Check | Result |
|---|---|
| Focused launch/window regressions | PASS (2026-07-14): 2 tests, 0 failures, after confirmed compile-failing red runs |
| Full combined `DockBarHeroTests` suite | PASS (2026-07-14): 429 tests, 0 failures (`** TEST SUCCEEDED **`) |
| Sprite-pipeline Python suite | PASS (2026-07-14): 15 tests, 0 failures |
| Every catalog image loads and crops | PASS: 7 sheets, 28 frames |
| Mechanical image dimensions | PASS: all seven are 1024x1024 |
| Clean unsigned Apple Silicon build | PASS (2026-07-14): `** BUILD SUCCEEDED **`, with recorded MP3 resources copied into the app bundle |
| Exact combined launch | PASS (2026-07-14): one process, PID 39103, exact worktree bundle with `--open-book` |
| Runtime management-window frame | PASS (2026-07-14): 1100x752 outer frame after SwiftUI sizing repair |
| `git diff --check` | PASS after conflict resolution and before the integration commit |

## Recorded Voiceover Evidence

- Voice provider: ElevenLabs offline generation only; no runtime network dependency.
- Cast: Book Branok, Kevin Cooper, Brick Zoey, Mercy Dr. Lauren, Kaizen Horatius, Editor Adam.
- Generated asset manifest: `DockBarHero/Lore/Resources/Audio/LoreAudioManifest.json`.
- Automated checks: focused `LoreReaderControllerTests` and `LoreAudioManifestTests` pass with 14 tests and 0 failures; full `DockBarHeroTests` suite passes with 429 tests and 0 failures.
- Bundle checks: `RecordedLoreSpeechService` validates every manifest MP3 is present/readable, exact manifest coverage for every dialogue cue, and distinct clean/unfiltered assets whenever clean text differs.
- Live audio QA: unchecked; build-and-run verification launched the app, but no inspectable manual audio session was available to verify cast distinction, detents 0/5/10, or immediate stop on window close.

## Visual Asset Inspection

Each final bundled PNG was reopened at original detail after normalization. PASS for all seven: exact 2x2 grid, stable principal identity, clear four-step loop, no generated lettering, no watermark/logo, and correct safe/censored presentation. Detailed source paths and selection notes are in `docs/art/lore-volume1-chapter1-asset-manifest.md`.

## Parent-Owned Live QA Status

The parent launched the exact combined worktree bundle with `--open-book`, confirmed one process at PID 39103, inspected the accessibility tree and live window, and exercised wheel input plus Next/Previous. Audio, VoiceOver, appearance switching, reduced motion, compact resizing, and the remaining controls were not exercised.

### Wide window

- PASS: the 1100-point initial window shows two pages, with the selected page on the right and following page on the left.
- PASS: wheel input leaves both fixed caption cards anchored; no page scroll indicator appears.
- PASS: complete, unclipped `Level 100,000: The Finaler Ending` title and body.
- PASS: readable title/body against opaque caption cards in the currently active dark appearance.
- PENDING: repeat caption contrast inspection in light appearance.
- PENDING: potentiometer changes only the Book reaction, not header, pages, or bottom controls.
- PENDING: lying-arrow correction changes only the arrow and anchored reaction bubble.
- PASS: Next/Previous preserve right-to-left page placement and return to the original prologue spread.
- PENDING: reaction bubble cannot intercept page, navigation, Replay, Skip, or potentiometer input.

### Compact and preserved behavior

- PENDING: minimum width shows one centered page with complete caption.
- PENDING: restoring wide width returns the spread without changing the selected page.
- PENDING: Reduced Motion freezes the illustration on its static frame.
- PENDING (audio): disabled speech yields only the visual Book giggle when moving the potentiometer.
- PENDING (audio): enabled speech preserves Replay, Skip, volume preview, page-turn interruption, Book-close interruption, and app-deactivation silence.
- PENDING (VoiceOver): announces `Next Page`, `Previous Page`, and the honest effective Book volume.

Automated tests cover controller behavior but are not manual visual, audio, or VoiceOver evidence.

## Known Scope Boundaries

- The slice stops at Level 20; no Boss 25 page is authored yet.
- The mature-content alternate contains no nudity. It is a censorship satire asset gated behind the Adult confirmation.
- Recorded voiceover is the production provider; macOS system TTS remains a launch-safe fallback if bundled audio cannot load.
