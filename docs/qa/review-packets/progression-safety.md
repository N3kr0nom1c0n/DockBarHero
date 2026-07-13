# Progression Safety Review Packet

## Scope

Internal schema-v2 Progression Safety gate only. This checkpoint is not release-eligible until Heroes and Party and Class Actions are implemented and accepted.

## Automated Evidence

- Full suite: 255 tests, 0 failures on 2026-07-12 after all review and launch-window repairs.
- Clean build: arm64 macOS Debug build succeeded with signing disabled.
- Launch verification: `./script/build_and_run.sh --verify` built and launched DockBarHero successfully.
- Regression coverage includes XP thresholds and penalties, tier scheduling and rewards, farming repeat, queued destination changes, 174 to 149 retreat, v2 save validation and replacement safety, first-run class selection, automatic management-window requests, exact reset phrase, management routes, and rail labels.
- Terra integration review found one stale final-flush/reset snapshot race; commit `f5fdb24` repaired it and Terra re-review returned no findings.
- Sol final review found three persistence-boundary issues; commit `aac04cc` repaired reset/save serialization, backup-only recovery, and Push/frontier validation. Sol re-review returned no findings.

## Implemented Gate

- Hero XP, levels, class growth, gold, and deterministic Normal, Elite, and Boss rewards.
- Separate frontier and selected farming level with explicit return and no combat interruption while queueing.
- Three-defeat automatic retreat without lowering the frontier or auto-returning later.
- Schema-v2 `classSelection` and `active` runs; v1 development saves are not migrated.
- Tank, DPS, or Healer first-run choice and exact `GAME OVER MAN!` New Game confirmation.
- Abilities, Skills, and Shop routes are intentional inactive placeholders.
- Explicit Hero, Enemy, and Item level labels in management and rail presentation.
- A loaded class-selection state opens the singleton management window; New Game confirmation uses a visibly labeled rounded input.

## Manual QA Still Required

- [ ] Confirm class selection appears before combat on a clean application-support directory.
- [ ] Exercise farming selection and Return to Frontier through the management window.
- [ ] Confirm XP, gold, queued level, and farming mode survive relaunch.
- [x] Confirm the Danger Zone exposes a visible confirmation input and requires the exact phrase.
- [ ] Confirm failed and successful New Game persistence interactions preserve or replace the run as designed.
- [ ] Inspect Abilities, Skills, and Shop empty states and all explicit level labels.
- [ ] Recheck overlay placement, passive input, fullscreen suppression, focus, and animation controls.

## Hold

The owner lifted the internal merge/push hold and authorized integration to `main` on 2026-07-12. This checkpoint remains non-release-eligible until Heroes and Party and Class Actions are implemented and accepted.
