# Progression Safety Review Packet

## Scope

Internal schema-v2 Progression Safety gate only. This checkpoint is not release-eligible until Heroes and Party and Class Actions are implemented and accepted.

## Automated Evidence

- Full suite: 249 tests, 0 failures on 2026-07-12.
- Clean build: arm64 macOS Debug build succeeded with signing disabled.
- Launch verification: `./script/build_and_run.sh --verify` built and launched DockBarHero successfully.
- Regression coverage includes XP thresholds and penalties, tier scheduling and rewards, farming repeat, queued destination changes, 174 to 149 retreat, v2 save validation and replacement safety, first-run class selection, exact reset phrase, management routes, and rail labels.

## Implemented Gate

- Hero XP, levels, class growth, gold, and deterministic Normal, Elite, and Boss rewards.
- Separate frontier and selected farming level with explicit return and no combat interruption while queueing.
- Three-defeat automatic retreat without lowering the frontier or auto-returning later.
- Schema-v2 `classSelection` and `active` runs; v1 development saves are not migrated.
- Tank, DPS, or Healer first-run choice and exact `GAME OVER MAN!` New Game confirmation.
- Abilities, Skills, and Shop routes are intentional inactive placeholders.
- Explicit Hero, Enemy, and Item level labels in management and rail presentation.

## Manual QA Still Required

- [ ] Confirm class selection appears before combat on a clean application-support directory.
- [ ] Exercise farming selection and Return to Frontier through the management window.
- [ ] Confirm XP, gold, queued level, and farming mode survive relaunch.
- [ ] Confirm failed and successful New Game interactions preserve or replace the run as designed.
- [ ] Inspect Abilities, Skills, and Shop empty states and all explicit level labels.
- [ ] Recheck overlay placement, passive input, fullscreen suppression, focus, and animation controls.

## Hold

Do not merge, push, release, or call schema v2 complete from this packet. Next work is the separate Heroes and Party plan, followed by the three class abilities.
