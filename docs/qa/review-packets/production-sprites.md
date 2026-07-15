# Production Sprites Review Packet

## Scope

- Branch: `feature/class-actions-and-loot`
- Worktree: `/Users/n3kr0/Projects/TBH/.worktrees/heroes-and-party`
- Design: `docs/superpowers/specs/2026-07-13-dockbarhero-production-sprites-design.md`
- Plan: `docs/superpowers/plans/2026-07-13-dockbarhero-production-sprites.md`
- Main was not merged or modified by this milestone.

## Asset Evidence

- Nine immutable reference boards are checksum-locked: the five owner-supplied hero/enemy boards and four generated original boss boards.
- `python3 -m unittest scripts.tests.test_build_sprite_assets -v`: 10 tests passed.
- `python3 scripts/build_sprite_assets.py --manifest art/sprite-manifest.json --output DockBarHero/Resources/Sprites --check`: passed with byte-identical regeneration.
- The runtime manifest contains 186 unique clips across 34 tokens.
- Every generated PNG passed the 96-pixel cell multiple, 64-pixel height, and nonempty-alpha validator.
- Contact sheets under `.build/SpritePreviews/` were inspected for heroes, standard enemies, elites, and bosses; embedded board labels are excluded and the four bosses retain distinct silhouettes.

## Runtime Evidence

- Focused SpriteCatalog, EnemySpriteResolver, and PrototypeSceneHost run: 32 tests passed with zero failures.
- Coverage includes runtime JSON decoding, equal-cell strip slicing, nearest filtering, declared playback timing, production-idle fallback, exact normal/elite/boss selection, stable actor nodes, independent party idle loops, fixed positions during attacks, exact-slot class-action animation, retained defeat poses, revival/victory restoration, and no procedural bob/lunge/fade actions.
- The production host loaded 96x64 textures for both initial actors and displayed them in 54x36 aspect-preserving scene nodes.

## Complete Gates

- Fresh arm64 suite: 355 tests passed, zero failures, `** TEST SUCCEEDED **`.
- Clean unsigned arm64 build: `** BUILD SUCCEEDED **`.
- Exact launch: `./script/build_and_run.sh --verify` succeeded.
- Process isolation: exactly one `DockBarHero` process was running, from `/Users/n3kr0/Projects/TBH/.worktrees/heroes-and-party/.build/RunDerivedData/Build/Products/Debug/DockBarHero.app/Contents/MacOS/DockBarHero`.

## Live QA Status

Live overlay inspection is not yet recorded. Computer control reported that the Mac session was locked and automatic unlock was unavailable. No visual claim is inferred from the automated or contact-sheet evidence, and the branch must not be pushed as a completed milestone until the exact running overlay is inspectable.

Pending live checks:

- three independent hero idle animations and simultaneous event routing without drift;
- class-action, damage, defeat, victory, and revival presentation;
- normal, elite, and boss identity transitions;
- farming/frontier, health, level, action, and DPS label clearance;
- passive click-through and animation pause behavior.
