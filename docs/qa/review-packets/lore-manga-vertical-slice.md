# Lore Manga Vertical Slice Review Packet

**Date:** 2026-07-13

**Branch:** `codex/lore-manga-vertical-slice`

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
| Combined lore/settings/app tests | PASS: 72 tests, 0 failures |
| Full `DockBarHeroTests` suite | PASS: 291 tests, 0 failures |
| Every catalog image loads and crops | PASS: 7 sheets, 28 frames |
| Mechanical image dimensions | PASS: all seven are 1024x1024 |
| Clean unsigned Apple Silicon build | PASS |
| `./script/build_and_run.sh --verify` | PASS: launched PID 28026 |
| `git diff --check` | PASS before each feature commit |

## Visual Asset Inspection

Each final bundled PNG was reopened at original detail after normalization. PASS for all seven: exact 2x2 grid, stable principal identity, clear four-step loop, no generated lettering, no watermark/logo, and correct safe/censored presentation. Detailed source paths and selection notes are in `docs/art/lore-volume1-chapter1-asset-manifest.md`.

## Live QA Status

The launched app's passive rail was directly visible and the process launch was verified. The Mac locked while attempting to open the management window through the menu-bar UI. The control layer could not unlock it, so the following live checks remain honestly unverified:

- open Book route and confirm the spread/single-page transition visually;
- watch a complete four-frame loop in the running reader;
- enable speech, verify Book-only playback, and close mid-line to confirm audible interruption;
- turn the potentiometer at 0, 5, and 10 and compare the giggle volume;
- confirm the Adult dialog and pixel-censor alternate in the running reader;
- verify VoiceOver announcement for the reversed control.

Automated controller tests cover the safety-critical speech gates and stop behavior, but they are not represented as manual audio evidence.

The final review also added explicit coverage for one-time sequential auto-read, visible clean/unfiltered opening insults, close/reopen route reset, and the Book's dishonest arrow correction.

## Known Scope Boundaries

- The slice stops at Level 20; no Boss 25 page is authored yet.
- The mature-content alternate contains no nudity. It is a censorship satire asset gated behind the Adult confirmation.
- TTS uses macOS system voices selected by authored rate/pitch traits; provider-specific voice casting is future work.
