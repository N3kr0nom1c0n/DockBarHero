# DockBarHero Book Speech and Unlock UX Design

## Purpose

Clarify when the Book speaks, what "read newly unlocked pages" means, and how pages unlock without changing the current speech engine or progression rules.

This spec covers `BACKLOG.md` item C5 only. It does not implement the full audio mixer, hero conversation audio, new manga pages, or new unlock progression.

## Approved Direction

Keep the current speech posture:

- Spoken dialogue remains opt-in.
- Auto-reading newly unlocked pages remains a separate opt-in sub-setting under Spoken dialogue.
- The Book only speaks while the Book is visibly open and the app is active.
- Closing the Book or deactivating the app stops speech immediately.
- Replay remains the explicit command to read the current page.
- Page navigation interrupts current speech. It does not read an already-read page unless the page qualifies for the auto-read rule.

## Current Rules to Make Discoverable

The UI must communicate these existing rules plainly:

- Pages unlock from campaign/frontier progress.
- Unlocked pages can always be revisited from the Book.
- Spoken dialogue being on does not mean the Book talks while closed.
- Auto-read only applies to newly unlocked pages that come after the last auto-read page.
- Changing pages stops the current line/page.
- Replay starts the selected page from its first dialogue cue.
- Skip advances to the next cue and stops when the page has no more cues.
- Book volume controls Book speech and preview giggles, not future hero conversation audio.

## Presentation

Add short explanatory copy in two places.

### Settings

In the Manga Book settings section, keep the existing controls but tighten the explanation around them:

- `Spoken dialogue`: opt-in toggle.
- `Read newly unlocked pages`: enabled only when Spoken dialogue is on.
- Short copy below the toggles:
  - Speech only plays while the Book is open.
  - Newly unlocked pages can auto-read if that option is on.
  - Closing the Book stops speech.

Settings must explain the durable rule, not current page state.

### Book Footer

Add a compact one-line status near the existing Book controls:

- If speech is off: "Spoken dialogue is off."
- If speech is on and auto-read is off: "Replay reads this page. New pages will not auto-read."
- If speech and auto-read are on: "Replay reads this page. Newly unlocked pages can auto-read while the Book is open."

This line must stay concise and must not crowd the controls. It must be secondary text, not a modal or tutorial.

## Behavior

No gameplay or save semantics change in this slice.

Implementation must preserve the current controller behavior:

- `LoreReaderController.select(_:)` interrupts current speech, selects the requested page, resets cue index, then invokes the existing auto-read check.
- `LoreReaderController.replay()` remains the explicit read command and starts at cue zero.
- `LoreReaderController.skip()` advances the current page's cue sequence.
- `LoreReaderController.update(settings:pages:)` keeps stopping speech when Spoken dialogue is disabled.
- App active/inactive and Book open/close gating remains unchanged.

The only expected behavior change is improved discoverability through visible copy and accessibility labels where appropriate.

## Accessibility

- Status copy must be reachable by VoiceOver as normal text.
- Replay and Skip labels must remain explicit enough for VoiceOver users.
- If the footer status changes when settings change, SwiftUI's normal text update is sufficient; no announcement is required for this slice.

## Testing

Use focused verification rather than broad UI automation.

Required coverage:

- A small formatting helper or view-facing computed value returns the correct status line for the three Book speech states.
- Existing `LoreReaderControllerTests` continue to prove speech gating, replay, skip, close, app inactive, and auto-read persistence behavior.
- A focused Settings/AppModel test confirms disabling Spoken dialogue prevents auto-read speech from starting even if the auto-read setting remains saved.
- Build the app to verify SwiftUI copy compiles.

Manual acceptance remains explicit:

- Owner confirmation of the Book footer copy in the running app remains a manual acceptance gate.
- This does not satisfy subjective Book giggle audibility, motion-panel animation, manga overlay sizing, or volume knob padding acceptance.
