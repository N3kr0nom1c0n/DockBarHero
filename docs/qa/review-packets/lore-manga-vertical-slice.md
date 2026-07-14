# Lore Manga Vertical Slice Review Packet

**Date:** 2026-07-14

**Branch:** `codex/lore-manga-vertical-slice`

**Candidate commit tested:** `c29296ef2666be4428c17a4b1900625e3330379a` (`fix: anchor the two-page lore reader`)

**Scope:** dishonest Level 100,000 prologue plus Volume I pages unlocked at Levels 1, 5, 10, 15, and 20. Boss 25 remains intentionally out of scope until Heroes and Party defines the cast.

## Delivered

- Right-to-left manga reader in the management window with responsive spread/single-page layout.
- Six validated lore pages with unfiltered/clean copy and frontier-completion unlock rules.
- Separate validated `SpokenDialogue.json` with Book, Brick, Kaizen, Mercy, Kevin, and Editor voice profiles.
- Opt-in AVSpeechSynthesizer dialogue that is gated to an open, active Book and stops on close/deactivation.
- Reversed 0...10 Book potentiometer: 0 is loudest, 10 is quietest, accessible value is honest, and movement triggers rotating Book giggles.
- Settings-v2 migration, clean/unfiltered language, safe/adult illustrations, speech opt-in, auto-read toggle, and adult-art confirmation.
- Seven final 1024x1024 four-frame manga sheets. The adult alternate is a deliberately unnecessary pixel-censor gag over a fully clothed adult character because two non-explicit generation attempts were safety-blocked.

## Automated Evidence

| Check | Result |
|---|---|
| Focused lore/settings/app tests | Prior accepted candidate evidence: 72 tests, 0 failures; not rerun in this automated-only Task 4 pass |
| Full `DockBarHeroTests` suite | PASS (2026-07-14): 298 tests, 0 failures (`** TEST SUCCEEDED **`) |
| Every catalog image loads and crops | PASS: 7 sheets, 28 frames |
| Mechanical image dimensions | PASS: all seven are 1024x1024 |
| Clean unsigned Apple Silicon build | PASS (2026-07-14): `** BUILD SUCCEEDED **` |
| `./script/build_and_run.sh --verify` | PASS (2026-07-14): launched PID 57167 |
| `git diff --check` | PASS before each feature commit |

## Visual Asset Inspection

Each final bundled PNG was reopened at original detail after normalization. PASS for all seven: exact 2x2 grid, stable principal identity, clear four-step loop, no generated lettering, no watermark/logo, and correct safe/censored presentation. Detailed source paths and selection notes are in `docs/art/lore-volume1-chapter1-asset-manifest.md`.

## Parent-Owned Live QA Status

The 2026-07-14 automated pass launched DockBarHero (PID 57167), but it did not perform visual, audio, or VoiceOver inspection. The parent orchestrator must mark each item below from observed live evidence only; no screenshots were captured in this pass.

### Wide window

- PENDING: initial two-page spread, with current page on the right.
- PENDING: fixed caption cards under pointer, trackpad, and wheel input; no page scroll indicator.
- PENDING: complete, unclipped `Level 100,000: The Finaler Ending` title and body.
- PENDING: readable title/body against opaque caption cards in light and dark appearances.
- PENDING: potentiometer changes only the Book reaction, not header, pages, or bottom controls.
- PENDING: lying-arrow correction changes only the arrow and anchored reaction bubble.
- PENDING: Next/Previous preserve right-to-left page placement.
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
- TTS uses macOS system voices selected by authored rate/pitch traits; provider-specific voice casting is future work.
