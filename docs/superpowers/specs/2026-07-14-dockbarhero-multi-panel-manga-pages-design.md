# DockBarHero Multi-Panel Manga Pages Design

**Date:** 2026-07-14
**Project:** DockBarHero
**Status:** Approved design
**Parent design:** `2026-07-13-dockbarhero-lore-manga-design.md`

## 1. Purpose

The lore reader currently presents each page as one large animated illustration over a separate prose block. The result is readable, but it resembles an illustrated storybook more than manga.

Each lore page will instead become a short right-to-left sequential-art scene. One dominant panel retains the existing subtle animation. Three to five surrounding still panels establish the scene, show reactions and close-ups, extend the joke, and hide optional background gags. Narration and dialogue move into live overlays within the panel composition.

## 2. Composition Contract

Each normal page contains:

- five to seven irregular panels;
- exactly one animated anchor panel occupying roughly 35 to 45 percent of the available page area;
- four to five primary still story panels;
- zero or one optional tiny gag panel;
- one or two rectangular Book narration boxes;
- one to three character speech balloons;
- optional sound effects, margin notes, redactions, or editorial marks.

Pages rotate deterministically through four reusable irregular layouts inspired by printed manga page geometry. A layout may be mirrored or receive small controlled variations, but panel reading order must remain unambiguous. A page does not receive random geometry when it is reopened.

The artwork fills the page. The current fixed bottom caption region is removed. Titles become small chapter marks or compact caption boxes rather than consuming a separate section.

## 3. Reading Order and Visual Hierarchy

Panel order is right to left and top to bottom. Within a panel, speech balloons are ordered from upper right toward lower left. The current page remains on the right side of a two-page spread.

The animated anchor panel is the visual focus, not necessarily the first panel. Still panels may occur before or after it in reading order so a loop can serve as the setup, impact, or payoff. Strong border weight, consistent gutters, and restrained halftone backgrounds separate panels without making the page visually noisy.

Every scene must remain understandable if the animation is frozen on its first frame, if decorative sound effects are hidden, or if the Reader misses an Easter egg.

## 4. Live Text System

Text is rendered by SwiftUI and is never baked into generated artwork.

- The Book speaks through rectangular narration boxes, margin notes, labels, redactions, and occasional captions that contradict another caption.
- Characters speak through rounded or hand-inked speech balloons with tails pointing toward the speaker.
- Sound effects use short decorative display text and are excluded when they would hurt legibility.
- Clean and unfiltered variants resolve before layout.
- Spoken-dialogue cues remain in `SpokenDialogue.json`; visible bubbles and narration stay complete when speech is disabled or unavailable.

Text containers have a bounded amount of copy. If localized or accessibility-sized text does not fit, the layout selects a roomier text treatment rather than shrinking below the reader's legibility floor. Full authored text remains available to accessibility APIs even when a decorative sound effect is omitted.

## 5. Art Asset Strategy

Each page uses two independent art sources:

1. The existing four-frame 2x2 animation sheet supplies the animated anchor panel.
2. A new six-image 3x2 context sheet supplies distinct still story moments.

The context sheet is not an animation sequence. Its cells show different camera angles or story beats: establishing shot, reaction, close-up, cutaway, aftermath, or background gag. Runtime cropping produces individual still panels, which may use aspect-fill crops chosen by the page composition. Five-panel layouts may leave two context cells unused; the six-panel and seven-panel layouts consume five and six context cells respectively.

All generated art remains text-free, black-and-white, high-contrast, and stylistically consistent with the existing seinen-comedy sheets. Principal character identity, costume, props, and setting must remain recognizable across the motion and context sheets.

Safe context art is required. An adult context sheet is optional and independently selected. If no adult context sheet exists, adult mode may replace only the animated panel while still panels retain their safe art. No essential plot information may exist only in an adult variant.

## 6. Initial Vertical-Slice Scenes

The initial six pages receive these still-panel beats:

- **Level 100,000:** impossible victory tableau; suspicious navigation arrow; the Book's bookmark caught rotating it; attempted redaction of the evidence; heroes looking toward the Reader while the Book begins blaming them.
- **Level 1:** summoning form with `Show Similar Results` selected; confused adult hero emerging; Kevin comparing the hero with an obviously wrong checklist; the Book quietly hiding the qualification requirements.
- **Level 5:** Kevin applying a fake mustache; supervisor presenting the employee handbook; close-up of identical ID badges; hero noticing a box labeled `REPLACEMENT KEVINS`.
- **Level 10:** hero approaching the chest with an excessive pole; outer mimic sweating; inner mimic emerging; both mimics attempting innocent expressions; Kevin selling mimic insurance nearby.
- **Level 15:** necromancer distributing satisfaction surveys; skeleton trying to return an incomplete form; close-up of a one-star review; necromancer raising a complaint department instead of the dead.
- **Level 20:** demon on the tiny therapy couch; Mercy presenting a legitimate referral; abomination taking notes; cursed crown filling out intake paperwork; a medication bottle labeled with a sincere supervision reminder rather than a medication joke.

These beats guide generation but may be adjusted during visual review to preserve character consistency and readable crops.

## 7. Content and Runtime Model

The lore page definition gains authored composition data:

- stable layout template identifier;
- safe context-sheet resource name and optional adult resource name;
- ordered panel descriptors with role, source cell, crop focal point, and reading order;
- ordered live-text descriptors with speaker, text style, panel attachment, placement preference, and dialogue cue reference where applicable;
- accessibility descriptions for the page and meaningful panel beats.

Layout geometry is normalized rather than stored in pixels. Runtime layout code maps normalized panel paths into the available page rectangle, applies gutters and border styling, then positions live text within declared safe regions. The four templates are deterministic pure data and can be tested without rendering the full Book.

Exactly one panel has the `motion` role. Catalog validation rejects pages with zero or multiple motion panels, invalid source cells, duplicate reading-order positions, missing required safe context art, or live text attached to a nonexistent panel.

## 8. Responsive and Accessible Behavior

Wide windows retain the two-page spread; compact windows retain one page. The same panel composition scales within a page rather than reordering its story. At very small supported sizes, decorative gag panels may be hidden and narration may use a larger overlay, but the animated panel, required still beats, and authored reading order remain intact.

VoiceOver exposes one ordered page narrative followed by optional individual controls. Decorative panels are hidden from the accessibility tree when their meaning is already represented in the page description. Speech balloons are read in authored manga order, not geometric platform order.

Reduced Motion freezes the animated anchor on its complete first frame. Closing the Book, losing application activity, or turning away from the page also stops its animation. These states do not change still panels or text.

## 9. Book Interruptions and TTS

Book reactions may invade gutters, overwrite a narration box, or temporarily paste a correction over a panel, but they cannot permanently obscure page navigation or required dialogue. The Level 100,000 arrow frame-up uses the multi-panel sequence to make the Book's tampering visible before it denies responsibility.

TTS follows the authored text order across narration boxes and speech balloons. Page turns stop speech for the page being left. The existing opt-in, Book-open-only, clean-language, volume-potentiometer, and interruption rules remain unchanged.

## 10. Failure Behavior

- Missing required safe context art invalidates only the affected catalog page and reports the resource name.
- Missing optional adult context art falls back to safe context art.
- Missing optional animation uses the page's configured context frame as a static anchor.
- An invalid optional gag panel is omitted without disturbing required reading order.
- A text container that cannot meet its legibility constraints selects the fallback text treatment; it never silently clips required dialogue.
- The reader never falls back to the old floating or scrolling prose layout.

## 11. Verification

Automated checks cover:

- all four normalized layout templates staying in bounds with non-overlapping panel interiors;
- exactly one motion panel and an unambiguous right-to-left reading order per page;
- context-sheet decoding and all six crops;
- catalog validation for resources, panel roles, text attachments, and safe/adult fallback;
- clean and unfiltered text resolution before composition;
- reduced-motion, Book-closed, and inactive-window animation freezing;
- deterministic layouts across reopen and resize;
- ordered accessibility output and complete TTS cue mapping;
- no return of the fixed bottom-caption region or scrolling page text.

Manual review covers every initial page in wide and compact reader modes, checks that each sequence reads right to left without instruction, verifies that only one panel moves, inspects text contrast and balloon tails, exercises safe/adult and clean/unfiltered settings, and confirms that the animated and still artwork depict one coherent scene.

## 12. Acceptance

The redesign is accepted when each initial lore page reads as a short manga sequence rather than an illustration with prose; exactly one panel animates; the surrounding still panels add distinct story information or jokes; narration boxes and speech balloons remain legible, censorable, speakable, and accessible; and the page remains stable while scrolling, resizing, reopening, and switching between spread and compact presentation.
