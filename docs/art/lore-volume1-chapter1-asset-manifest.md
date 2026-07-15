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

## Six-cell context atlases

**Delivery date:** 2026-07-14

Each context atlas was generated with its matching selected four-frame motion sheet as the only visual reference. The common direction required an original black-and-white seinen-comedy manga, an exact 3x2 contact sheet, six equal square cells, thick clean white gutters, no text/lettering/logo/watermark, stable adult identities, and story order read right-to-left across the top row and then the bottom row. Selected sources were resized and stripped with ImageMagick to sRGB 1536x1024 PNG. When a generated sheet placed beats left-to-right, the normalized image was mechanically cropped into six 512x512 cells and reassembled in story order without mirroring or editing any cell content.

| Bundled filename | Motion reference | Selected generation result | RTL story beats and accepted adjustments | Dimensions | Inspection |
|---|---|---|---|---|---|
| `prologue-level100000-context-safe.png` | `prologue-level100000-safe.png` | `exec-41e43ca5-1679-43ce-a262-47002d831b54.png` | Victory; suspicious arrow; Book/bookmark rotation; guilty bookmark with shocked hero; evidence erased in red ink; Book blaming the heroes toward the Reader. Rows mechanically reversed. | 1536x1024 | PASS: six distinct square cells, clean gutters, stable heroes/Book, text-free, no logo/watermark, safe. |
| `volume1-level1-context-safe.png` | `volume1-level1-safe.png` | `exec-a5e2b1c2-dec2-44f1-b977-78b82225fd7e.png` | Rejected celestial form; confused adult hero; absurd pictographic checklist; Kevin hiding the Book's qualification paperwork on its behalf; Kevin's fake mustache/wrong badge; adult applicant queue. Generated in RTL order. | 1536x1024 | PASS with recorded subject adjustment: six distinct square cells, clean gutters, stable Kevin/hero, symbols only with no lettering, no logo/watermark, safe adults. |
| `volume1-level5-context-safe.png` | `volume1-level5-safe.png` | `exec-1ad91c74-90ee-4dba-9dda-da98eea00e45.png` | Kevin applies mustache; supervisor presents handbook; matching blank badge; Kevin notices two smaller replacement goblins entering in uniform; unsigned-form accusation; Kevin rehearses his own fake accent. Rows mechanically reversed. | 1536x1024 | PASS with recorded comedy substitutions: six distinct square cells, clean gutters, stable Kevin/supervisor, text-free, no logo/watermark, safe adults. |
| `volume1-level10-context-safe.png` | `volume1-level10-safe.png` | `exec-c896fcd7-96c1-4f76-88a8-9a4ef0a0a5cc.png` | Adult hero with absurd pole; sweating outer mimic; peeking inner mimic; both suppress laughter; both pose innocently; adult hero, rather than Kevin, sells the blank insurance scroll. Cells mechanically sequenced RTL. | 1536x1024 | PASS with recorded seller substitution: six distinct square cells, clean gutters, stable nested mimics/hero, text-free, no logo/watermark, safe adult. |
| `volume1-level15-context-safe.png` | `volume1-level15-safe.png` | `exec-9c4bc8f3-be8b-4e0b-9a43-fde90d3aba96.png` | Necromancer distributes blank survey; skeleton returns incomplete form; one-to-five-star pictographic scale communicates the one-star rating; complaint desk rises; adult Brick enforces policy; bottomless suggestion box. Rows mechanically reversed. | 1536x1024 | PASS: six distinct square cells, clean gutters, stable necromancer/skeleton cast and adult Brick, pictographs only with no lettering, no logo/watermark, safe. |
| `volume1-level20-context-safe.png` | `volume1-level20-safe.png` | `exec-5730c365-a6c7-477e-97eb-19f9b6133f44.png` | Fully clothed adult demon on tiny couch; demon passes the blank referral card on Mercy's behalf; many-eyed clinician takes notes; clinician completes the demon's intake rather than a separate cursed crown; closed unlabeled supervised-medication container; physical Book waits outside therapy. Rows mechanically reversed. | 1536x1024 | PASS with recorded subject substitutions: six distinct square cells, clean gutters, stable fully clothed demon/clinician, no lettering/logo/watermark, closed container, safe adults. |

All six bundled PNGs were reopened at original resolution after final normalization and ordering. The final `magick identify DockBarHero/Lore/Resources/Images/*-context-safe.png` output reported `PNG 1536x1024` for every atlas.
