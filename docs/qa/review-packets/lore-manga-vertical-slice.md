# Lore Manga Vertical Slice Review Packet

**Date:** 2026-07-14

**Branch:** `codex/lore-manga-vertical-slice`

**Candidate commit tested:** `4bc33d2` (`fix: restore shattered manga RTL order`), including final TTS, catalog-order, reaction, narration, and RTL repairs

**Scope:** dishonest Level 100,000 prologue plus Volume I pages unlocked at Levels 1, 5, 10, 15, and 20. Boss 25 remains intentionally out of scope until Heroes and Party defines the cast.

## Delivered

- Right-to-left manga reader with four deterministic irregular layouts, five-to-seven panels per page, and responsive spread/single-page presentation.
- Six validated lore pages with unfiltered/clean copy and frontier-completion unlock rules.
- Separate validated `SpokenDialogue.json` with Book, Brick, Kaizen, Mercy, Kevin, and Editor voice profiles.
- Opt-in AVSpeechSynthesizer dialogue that is gated to an open, active Book and stops on close/deactivation.
- Reversed 0...10 Book potentiometer: 0 is loudest, 10 is quietest, accessible value is honest, and movement triggers rotating Book giggles.
- Settings-v2 migration, clean/unfiltered language, safe/adult illustrations, speech opt-in, auto-read toggle, and adult-art confirmation.
- Seven final 1024x1024 four-frame motion sheets plus six 1536x1024 six-cell context atlases. Exactly one panel animates while surrounding panels remain distinct still beats. The adult alternate is a deliberately unnecessary pixel-censor gag over a fully clothed adult character.

## Automated Evidence

| Check | Result |
|---|---|
| Focused launch/window regressions | PASS (2026-07-14): 2 tests, 0 failures, after confirmed compile-failing red runs |
| Full combined `DockBarHeroTests` suite | PASS final (2026-07-14): 441 tests, 0 failures (`** TEST SUCCEEDED **`) |
| Sprite-pipeline Python suite | PASS (2026-07-14): 15 tests, 0 failures |
| Motion sheets load and crop | PASS: 7 sheets, 28 frames |
| Context atlases load and crop | PASS: 6 atlases, 36 cells |
| Mechanical image dimensions | PASS: motion sheets are 1024x1024; context atlases are 1536x1024 |
| Clean unsigned Apple Silicon build | PASS (2026-07-14): `** BUILD SUCCEEDED **` |
| Exact final launch | PASS (2026-07-14): one process, PID 64599, exact worktree bundle with `--open-book` |
| Runtime management-window frame | PASS (2026-07-14): 1100x752 outer frame after SwiftUI sizing repair |
| Context guard and `git diff --check` | PASS at the post-fix checkpoint |

## Visual Asset Inspection

Each motion PNG was reopened at original detail after normalization. Each context atlas was inspected at original 1536x1024 detail for six distinct, text-free cells in physical right-to-left order. Detailed source paths, selections, and the regenerated Level 20 therapy sequence are in `docs/art/lore-volume1-chapter1-asset-manifest.md`.

## Parent-Owned Live QA Status

The parent launched the exact worktree bundle with `--open-book`, confirmed one process, and inspected every authored page in the 1100x752 live window. The first launch had no campaign save, so a Tank was selected; a DPS was selected when the running game reached its Boss 25 party reward during inspection.

The live pass found two defects: the persistent Book reaction covered upper-right page art, and long narration overlapped neighboring speech on Levels 5, 15, and 20. `0c1a4c2` moved only those narration overlays to their large motion panels; `521453c` moved reactions into responsive reserved header flow. Final feature review then found and repaired automatic multi-cue TTS/catalog-order validation (`162d5cd`) and Level 10's reversed seven-panel geometry (`4bc33d2`). All review findings passed focused TDD, independent re-review, the final 441-test suite, and clean build. The final bundle launched as the only process at PID 64599, but the Mac remains locked, so post-fix visual claims remain pending.

### Wide window

- PASS (pre-fix observation): the 1100-point initial window shows two pages, with the selected page on the right and following page on the left.
- PASS (pre-fix observation): all six pages render irregular five-to-seven-panel compositions with distinct surrounding still beats and an obvious right-to-left sequence.
- PASS: wheel input leaves both fixed caption cards anchored; no page scroll indicator appears.
- PASS: complete, unclipped `Level 100,000: The Finaler Ending` title and body.
- PASS: readable title/body against opaque caption cards in the currently active dark appearance.
- PENDING: repeat caption contrast inspection in light appearance.
- PENDING post-fix: repaired narration and header reaction containment at wide width.
- PENDING: potentiometer changes only the reserved header reaction, not pages or bottom controls.
- PENDING: lying-arrow correction changes only the arrow and anchored reaction bubble.
- PASS: Next/Previous preserve right-to-left page placement and return to the original prologue spread.
- PASS (code): reaction bubble remains non-hit-testing and is no longer in the page-covering root ZStack. PENDING: post-fix visual containment.

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
- TTS uses macOS system voices selected by authored rate/pitch traits; provider-specific voice casting is future work.
