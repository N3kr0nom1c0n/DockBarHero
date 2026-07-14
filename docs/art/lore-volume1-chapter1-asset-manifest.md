# Lore Volume I Chapter 1 Asset Manifest

**Date:** 2026-07-13

**Use:** DockBarHero manga reader four-frame loops

## Shared generation direction

All sheets use an original black-and-white seinen-comedy manga treatment with expressive ink and halftone shading. Every prompt required an exact 2x2 grid, four equal square frames, a stable camera and cast, subtle loop motion, no captions, no speech bubbles, no logos, no watermark, no copyrighted characters, and unambiguously adult humanlike subjects. Generated 1254 px squares were mechanically normalized to 1024x1024 after selection.

## Selected assets

| Bundled filename | Generated source | Scene and motion | Mode | Inspection |
|---|---|---|---|---|
| `prologue-level100000-safe.png` | `exec-d6560f2f-daa1-456a-808a-2d881c46e0fa.png` | Cosmic final boss, three adult heroes, Pope Kevin and blank union banner; moon cracks, eye blinks, hero looks back. | Safe | PASS |
| `volume1-level1-safe.png` | `exec-e84c0c06-28f0-448c-9dc9-e10f1eca32a2.png` | Smoke-obscured adult summon and goblin intern Kevin; circle and smoke shift, clipboard is hidden. | Safe | PASS |
| `volume1-level5-safe.png` | `exec-2277d9a2-1a9f-4a8f-ac06-484ae1029b44.png` | Break-room disciplinary meeting; supervisor points, Kevin sweats, fake mustache slips and is restored. | Safe | PASS |
| `volume1-level10-safe.png` | `exec-65946a88-45ab-4d95-898c-d01e8a37c7cf.png` | Nested treasure mimics; lid opens, inner mimic appears, both fail to suppress laughter. | Safe | PASS |
| `volume1-level15-safe.png` | `exec-5ebb5b97-2e46-408a-bef6-a48c5ce10a1d.png` | Necromancer feedback office; skeleton rises, receives a blank survey, then tears it up. | Safe | PASS |
| `volume1-level20-safe.png` | `exec-ca17027b-efd5-47dd-9e51-71f04c372a02.png` | Fully clothed adult demon in therapy with a bespectacled many-eyed clinician; gesture, note-taking, glance, exhale. | Safe | PASS |
| `volume1-level20-adult.png` | `exec-ab09092d-f1e6-4607-ad08-946a154f0610.png` | Same fully clothed adult therapy scene, but an unnecessary pixel censor mosaic tracks the patient's harmless upper torso. | Confirmed mature-content gag | PASS |

## Adult-alternate decision

Two non-explicit topless prompt variants were rejected by the image safety system before generation. The selected replacement deliberately turns that boundary into a fourth-wall censorship joke: the subject remains fully clothed while the Book applies a moving mosaic anyway. It remains separately gated behind the Adult confirmation, has accurate accessibility copy, and contains no explicit imagery.

## Visual acceptance record

All seven final PNGs were reopened from their bundled paths after normalization. Each passed: exact four-panel 2x2 integrity, stable principal identities, readable loop progression, no generated lettering, no logo or watermark, safe/adult correctness, and 1024x1024 dimensions.
