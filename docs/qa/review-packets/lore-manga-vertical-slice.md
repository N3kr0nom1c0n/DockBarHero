# Lore Manga Vertical Slice Review Packet

**Date:** 2026-07-15

**Branch:** `codex/integrate-current-worktrees`

**Source checkpoints:** manga through `11ef72f`; recorded runtime through `1595f6f`; combined integration through `90b7cac`.

**Scope:** dishonest Level 100,000 prologue plus Volume I pages unlocked at Levels 1, 5, 10, 15, and 20. Boss 25 remains intentionally out of scope until Heroes and Party defines the cast.

## Delivered

- Right-to-left manga reader with four deterministic irregular layouts, five-to-seven panels per page, and responsive spread/single-page presentation.
- Six validated lore pages with unfiltered/clean copy and frontier-completion unlock rules.
- Separate validated `SpokenDialogue.json` with Book, Brick, Kaizen, Mercy, Kevin, and Editor voice profiles.
- Opt-in recorded ElevenLabs dialogue that is bundled in-app, gated to an open and active Book, and stops on close/deactivation; AVSpeechSynthesizer remains the launch-safe fallback when recorded assets fail validation.
- Reversed 0...10 Book potentiometer: 0 is loudest, 10 is quietest, accessible value is honest, and movement triggers rotating Book giggles.
- Settings-v2 migration, clean/unfiltered language, safe/adult illustrations, speech opt-in, auto-read toggle, and adult-art confirmation.
- Seven final 1024x1024 four-frame motion sheets plus six 1536x1024 six-cell context atlases. Exactly one panel animates while surrounding panels remain distinct still beats. The adult alternate is a deliberately unnecessary pixel-censor gag over a fully clothed adult character.

## Automated Evidence

| Check | Result |
|---|---|
| Combined integration `DockBarHeroTests` suite | PASS final (2026-07-15): 544 tests, 0 failures (`** TEST SUCCEEDED **`) |
| Combined sprite-pipeline Python suite | PASS (2026-07-15): 16 tests, 0 failures |
| Combined clean unsigned Apple Silicon build | PASS (2026-07-15): `** BUILD SUCCEEDED **` |
| Combined focused lore/audio/catalog suite | PASS (2026-07-15): 49 tests, 0 failures |
| Combined focused campaign/rendering/catalog suite | PASS (2026-07-15): 111 tests, 0 failures |
| Combined context, whitespace, and merge checks | PASS (2026-07-15): context guard, `git diff --check`, and no unmerged entries |
| Focused launch/window regressions | PASS (2026-07-14): 2 tests, 0 failures, after confirmed compile-failing red runs |
| Manga source `DockBarHeroTests` suite | PASS final (2026-07-14): 441 tests, 0 failures (`** TEST SUCCEEDED **`) |
| Recorded-voiceover source `DockBarHeroTests` suite | PASS (2026-07-14): 430 tests, 0 failures (`** TEST SUCCEEDED **`) |
| Sprite-pipeline Python suite | PASS (2026-07-14): 15 tests, 0 failures |
| Motion sheets load and crop | PASS: 7 sheets, 28 frames |
| Context atlases load and crop | PASS: 6 atlases, 36 cells |
| Mechanical image dimensions | PASS: motion sheets are 1024x1024; context atlases are 1536x1024 |
| Source clean unsigned Apple Silicon builds | PASS (2026-07-14): manga and recorded-voiceover source branches |
| Manga exact final launch | PASS (2026-07-14): one process, PID 64599, exact worktree bundle with `--open-book` |
| Runtime management-window frame | PASS (2026-07-14): 1100x752 outer frame after SwiftUI sizing repair |
| Context guard and `git diff --check` | PASS at the post-fix checkpoint |

## Recorded Voiceover Evidence

- Voice provider: ElevenLabs offline generation only; no runtime network dependency.
- Cast: Book Branok, Kevin Cooper, Brick Zoey, Mercy Dr. Lauren, Kaizen Horatius, Editor Adam.
- Generated asset manifest: `DockBarHero/Lore/Resources/Audio/LoreAudioManifest.json`.
- Automated checks: focused `LoreReaderControllerTests` and `LoreAudioManifestTests` pass with 15 tests and 0 failures; full `DockBarHeroTests` suite passes with 430 tests and 0 failures.
- Combined integration checks: the 49-test lore/audio/catalog gate and final 544-test full suite pass with zero failures.
- Bundle checks: `RecordedLoreSpeechService` validates every manifest MP3 is present/readable, exact manifest coverage for every dialogue cue, and distinct clean/unfiltered assets whenever clean text differs.
- Live audio operation: PASS for opt-in gating and Book scope. Replay opened the expected bundled Level 1 MP3 in the running process; leaving the Book immediately released it. Subjective cast distinction and audible quality remain unclaimed.

## Visual Asset Inspection

Each motion PNG was reopened at original detail after normalization. Each context atlas was inspected at original 1536x1024 detail for six distinct, text-free cells in physical right-to-left order. Detailed source paths, selections, and the regenerated Level 20 therapy sequence are in `docs/art/lore-volume1-chapter1-asset-manifest.md`.

## Parent-Owned Live QA Status

The parent launched the exact worktree bundle with `--open-book`, confirmed one process, and inspected every authored page in the 1100x752 live window. The first launch had no campaign save, so a Tank was selected; a DPS was selected when the running game reached its Boss 25 party reward during inspection.

The combined pass launched one exact-worktree process and directly inspected the Book in wide, compact, dark, and forced Aqua appearances. It exposed a Clean-only Level 1 bubble promotion that covered the top caption; `8e44734` keeps both language variants attached to their panel and a live Aqua recheck confirmed full separation. `90b7cac` also keeps the macOS window title synchronized as routes change. Both repairs passed focused checks, the final 544-test suite, and a clean unsigned build.

### Wide window

- PASS (pre-fix observation): the 1100-point initial window shows two pages, with the selected page on the right and following page on the left.
- PASS (pre-fix observation): all six pages render irregular five-to-seven-panel compositions with distinct surrounding still beats and an obvious right-to-left sequence.
- PASS: wheel input leaves both fixed caption cards anchored; no page scroll indicator appears.
- PASS: complete, unclipped `Level 100,000: The Finaler Ending` title and body.
- PASS: readable title/body against opaque caption cards in the currently active dark appearance.
- PASS: readable caption/header contrast in forced Aqua appearance.
- PASS: repaired narration and header reaction remain contained at wide width.
- PASS: potentiometer movement changed the reserved reaction to `Heh.` and left pages/controls anchored; decreasing the detent raised the accessible gain from 55% to 64%.
- PASS: lying-arrow correction changed the arrow and anchored reaction without covering page art.
- PASS: Next/Previous preserve right-to-left page placement and return to the original prologue spread.
- PASS: reaction bubble remains in reserved header flow and did not cover page art.

### Compact and preserved behavior

- PASS: minimum width shows one centered page with complete caption.
- PASS: restoring wide width returns the spread without changing the selected page.
- PENDING: Reduced Motion freezes the illustration on its static frame.
- PASS: disabled speech disables Replay/Skip while potentiometer movement still produces the visual Book reaction.
- PARTIAL (audio): enabled speech exposes Replay/Skip, Replay opens the recorded MP3, and leaving the Book stops it. Audible cast quality and app-deactivation listening were not manually judged.
- PASS: Adult illustrations require a confirmation sheet; the test enabled Adult, verified the setting, and restored Safe.
- PENDING (VoiceOver): announces `Next Page`, `Previous Page`, and the honest effective Book volume.

Automated tests cover controller behavior but are not manual visual, audio, or VoiceOver evidence.

## Known Scope Boundaries

- The slice stops at Level 20; no Boss 25 page is authored yet.
- The mature-content alternate contains no nudity. It is a censorship satire asset gated behind the Adult confirmation.
- Recorded voiceover is the production provider; macOS system TTS remains a launch-safe fallback if bundled audio cannot load.
