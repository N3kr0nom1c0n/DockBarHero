# DockBarHero Spoken Dialogue and TTS Design

**Date:** 2026-07-13

**Project:** DockBarHero

**Status:** Approved addition awaiting final written-spec review

**Parent design:** `2026-07-13-dockbarhero-lore-manga-design.md`

## 1. Purpose

Every recurring character can speak through text-to-speech while the manga is open. Spoken dialogue is an optional presentation of the authored text, never a replacement for visible dialogue and never part of deterministic combat.

Production dialogue lives in one bundled runtime sidecar, conceptually `SpokenDialogue.json`. It is separate from manga layout data so voices, delivery, pronunciation, censorship, and TTS behavior can change without rewriting page composition.

## 2. Nonnegotiable Audio Rules

- Spoken dialogue is disabled by default and requires explicit local opt-in.
- No lore voice may play unless the manga Book is visibly open.
- Closing the Book stops the current utterance and clears its queue immediately.
- Combat, the passive rail, menus outside the Book, background activity, and application launch never begin lore speech.
- Visible dialogue and captions remain complete when TTS is unavailable or disabled.
- Speech never pauses combat, changes simulation time, or blocks a page turn.
- Newly unlocked pages may auto-read once only when spoken dialogue is enabled.
- Rereading a page is silent until the Reader presses its replay control.

## 3. Runtime Dialogue Sidecar

The implementation target is one versioned `SpokenDialogue.json` file containing speaker profiles, pronunciation guidance, and dialogue cues.

Each speaker profile contains:

- stable speaker ID;
- display name;
- preferred voice traits rather than a provider-specific voice name;
- baseline rate, pitch, energy, and pause style;
- pronunciation overrides shared by that character;
- accessible description of nonverbal reactions.

Each dialogue cue contains:

- stable cue ID;
- related lore page or Book-interaction trigger;
- speaker ID;
- unfiltered and clean text variants;
- delivery direction: emotion, pace, intensity, pauses, and emphasized words;
- optional cue-specific pronunciation hints;
- playback policy: normal, interrupt-current, replace-preview, or nonverbal reaction;
- whether the cue is eligible for first-open auto-read;
- visible fallback text for a nonverbal cue.

The runtime resolves the current language mode before submitting text to TTS. Adult-art mode does not select spoken text, preventing a combinatorial language-by-art dialogue matrix.

## 4. Character Voice Bible

### The Book

Pompous theatrical narrator; confident even when obviously fabricating facts. It changes from booming authority to tiny defensive muttering when caught lying. Book-interaction reactions use this same voice.

### Brünhilda “Brick” Broadside

Low, tired deadpan. She rarely raises her voice, which makes her threats sound like routine customer-service policy.

### Kaizen Bloodedge Omega

Maximum anime conviction. Attack names accelerate, emotional declarations receive excessive pauses, and ordinary observations sound like season finales.

### Doctor Reverend Sister Mercy Malpractice, DDS

Warm, soothing clinical delivery while saying alarming things. Recommendations for therapy, boundaries, sleep, and supervised psychiatric medication remain sincere rather than sarcastic.

### Kevin

Frazzled everyman. Every alleged “different Kevin” uses the same underlying voice with an increasingly unconvincing accent or disguise note.

### The Editor

Precise, clipped, and emotionally compressed. Redactions interrupt other speech cleanly rather than competing at full volume.

Future characters must receive a speaker profile before any cue references them.

## 5. The Book's Reversed Volume Potentiometer

A physical-looking potentiometer sits along the bottom edge of the open manga.

- It has eleven detents labeled only `0` through `10`.
- The interface never visually explains which direction is louder.
- `0` maps to maximum output gain.
- `10` maps to the quietest nonzero output gain.
- The initial enabled value is `5`.
- Disabling spoken dialogue is the only true mute; the potentiometer does not replace the opt-in control.
- The initial gain curve is linear from `1.0` at `0` to `0.1` at `10`; later audio tuning may change the curve while preserving the reversed direction and endpoints.

Moving to a new detent triggers a short Book giggle at the newly selected gain. This is both the volume preview and the joke that teaches the reversed control.

- Each detent replaces any in-progress preview rather than stacking giggles.
- Rapid dragging is coalesced so previews remain intelligible and do not create an audio backlog.
- The giggle rotates through a small cue group such as `heh`, `hehehe`, a smug throat laugh, and an overly theatrical chuckle.
- With spoken dialogue disabled, turning the control produces a small visual `heh` in the margin and no sound.
- VoiceOver identifies the control as `Book volume`, exposes the effective percentage, and announces that lower numbers are louder. The visual joke never makes the accessible control deceptive.

## 6. Book Interaction Reactions

The Book has a reaction whenever the Reader manipulates Book-specific controls, subject to coalescing and cooldown rules.

Reaction triggers include:

- opening the Book;
- attempting to close it during a speech;
- enabling or disabling spoken dialogue;
- moving the volume potentiometer;
- changing clean/unfiltered language;
- changing safe/adult illustrations;
- attempting to open a locked page;
- repeatedly flipping pages in conflicting directions;
- replaying or skipping spoken dialogue;
- resizing the reader enough to change between spread and single-page layout.

Ordinary page turns do not add a separate reaction on top of story dialogue. Repeated rapid changes collapse into one escalating response, followed by a cooldown. This preserves the “Book always has something to say” personality without making the reader unusable.

When spoken dialogue is off, reactions remain visible as speech bubbles, margin notes, facial marks, or typography. When speech is on, only reactions that occur while the Book remains open may be voiced.

## 7. Initial Cue Examples

| Cue ID | Speaker | Unfiltered | Clean | Delivery |
|---|---|---|---|---|
| `prologue.book.wrong-way` | Book | “Hey, American jackass! This is a manga! You're reading it backwards, ya fuckwad!” | “Hey, confused hamburger enthusiast! This is manga! You're reading it backward!” | Outraged accusation hiding panic |
| `prologue.book.arrow-denial` | Book | “Slander. The arrow has always pointed left.” | Same | Immediate defensive certainty |
| `interaction.sound.enabled` | Book | “Oh good. You found my voice. This can only improve things.” | Same | Smug anticipation |
| `interaction.close.interrupt` | Book | “Wait, I wasn't fu—” | “Wait, I wasn't fini—” | Hard-cut when Book closes |
| `interaction.locked-page` | Book | “That page is locked because the plot hasn't suffered enough yet.” | Same | Patronizing |
| `interaction.volume.giggle-01` | Book | “Heh.” | Same | Short smug giggle |
| `interaction.volume.giggle-02` | Book | “Hehehehe.” | Same | Delighted, slightly concerning |
| `brick.policy-warning` | Brick | “Vomiting blood on the adventurers is against dungeon policy.” | Same | Calm customer service |
| `kaizen.preliminary-strike` | Kaizen | “Forbidden Crimson Dragon—preliminary strike!” | Same | Huge opening, embarrassed correction |
| `mercy.therapy-referral` | Mercy | “A cursed crown is not a substitute for mood stabilizers.” | Same | Kind clinical certainty |
| `kevin.not-kevin` | Kevin | “I'm not Kevin. Kevin died. This mustache is hereditary.” | Same | Poorly concealed panic |
| `editor.narrator-warning` | Editor | “The narrator is lying.” | Same | Precise interruption |

These examples establish voice and schema expectations; full page scripts are authored alongside their Volume rather than filling empty cue slots in advance.

## 8. Playback and Queue Behavior

- One lore voice speaks at a time.
- A page turn stops dialogue belonging to the page being left.
- An Editor interruption may interrupt the Book when the authored cue requires it.
- Replay restarts the current page's resolved cue sequence from the beginning.
- Skip advances to the next visible dialogue cue without advancing the manga page.
- Potentiometer previews use `replace-preview` and never interrupt an important story line unless the Reader deliberately moves the control; in that case the Book treats the interruption as the Reader's fault.
- TTS generation may be cached by engine, voice profile, resolved text, language mode, and delivery hash, but cached audio never enters game-save state.

## 9. Settings and Persistence

Versioned `AppSettings` gains presentation-only values for:

- spoken dialogue enabled;
- Book potentiometer detent `0...10`;
- first-open auto-read enabled, meaningful only while spoken dialogue is enabled;
- selected TTS engine or voice mapping if a later implementation exposes those choices.

The default state is spoken dialogue off, detent `5`, and first-open auto-read on for the future moment when speech is enabled. Settings migration must not touch game-save files.

## 10. TTS Boundary and Failure Behavior

The dialogue catalog describes intent and never hard-codes a particular TTS vendor. A narrow speech service resolves stable speaker traits to the active local or configured engine.

- Engine unavailable: keep text visible, disable replay, and show a concise Book-local diagnostic.
- Cue generation failure: skip only that cue and continue the page's visible content.
- Missing clean variant: invalidate required dialogue content before it becomes active; never send the unfiltered line in clean mode.
- Missing optional nonverbal rendering: show its fallback text.
- Book closed during synthesis: discard the result unless it remains useful in the bounded cache; never begin playback.
- Application loses active status: stop lore speech instead of continuing unexpectedly in the background.

## 11. Verification

Automated checks cover:

- dialogue sidecar schema and stable-reference validation;
- every referenced speaker having a voice profile;
- required clean and unfiltered variants;
- language resolution before TTS submission;
- no playback while the Book is closed or the application is inactive;
- immediate queue clearing when the Book closes;
- one-time auto-read and manual reread behavior;
- reversed potentiometer endpoint mapping and detent persistence;
- preview replacement and rapid-drag coalescing;
- settings migration without game-save mutation;
- visible fallback behavior when TTS is absent.

Manual verification covers character differentiation, intelligibility, the Book's giggle previews at `0`, `5`, and `10`, abrupt close interruption, VoiceOver's honest volume announcement, and the absence of surprise speech outside the open Book.

## 12. Acceptance

The spoken-dialogue design is successful when every character can receive a consistent TTS performance from one separate authored sidecar, the Book reacts audibly or visually to manipulation, the reversed volume control is funny but accessible, clean mode cannot leak profanity, and closing the Book guarantees silence without affecting gameplay.
