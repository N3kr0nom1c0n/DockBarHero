# DockBarHero Production Sprites Design

**Status:** Approved

## Goal

Replace the provisional one-frame code sprites and procedural actor movement with class-specific, enemy-specific, and boss-specific pixel animation clips derived from the owner's five approved reference boards. Preserve every supplied action as an asset, wire the actions supported by current gameplay, and make future actions available without changing combat or persistence.

## Approved Sources

The originals are immutable visual masters and remain outside the application bundle. The repository archives byte-identical copies with descriptive names and records these SHA-256 values:

- DPS hero: `fc43a019203daa866cca3566da6c8995ffac0cc5f8c171bd94b81b161824e00d`
- Tank hero: `2949a94a44da7a6661822bfe5758195d85360dd22b5469fcb674179a783095b6`
- Healer hero: `56f6fafe84ca6c0d00e20cfb3967598f73bcde893eb532318114a318fd9d5b1f`
- Standard enemies: `78022cd5929034704aca0b63c309be69942545172c298f727cea54c5fbb2e2aa`
- Elite enemies: `5e7ff01b808396d510dfce2c19a4637bf10e63184a4ec0c4cb101df9a464df0d`

All five sources are 1402×1122 RGB PNG presentation boards without transparency. They are references, not runtime atlases.

## Asset Production

A manifest-driven repository script owns every crop, frame order, action name, frame duration, facing direction, and source checksum. It extracts usable source frames, removes the connected dark board background, excludes labels and dividers, normalizes all frames with one scale per actor, and bottom-center anchors them in equal 96×64 transparent cells. It emits one horizontal PNG strip per actor/action plus one runtime JSON manifest.

The pipeline fails closed on a checksum mismatch, missing source, empty frame, nontransparent output, inconsistent cell size, or ImageMagick failure. It never overwrites or edits a source board. Generated strips use nearest-neighbor scaling and retain crisp pixel clusters.

Supplied actions are preserved even when current gameplay does not invoke them. Weapon, staff, equipment, palette, scale, and direction examples remain reference-only rather than becoming animation clips.

## Runtime Catalog

`SpriteClip` owns frames, seconds per frame, and loop behavior. The production catalog loads the generated strips and manifest from the application bundle, slices equal cells, assigns `.nearest` filtering, and falls back to the existing built-in pixel definition when any asset is unavailable or invalid.

The runtime action vocabulary includes idle, walk, run, jump, fall, land, three ordinary attacks, class action, block/defend, dodge, hit, defeated, and victory. Current rail behavior uses:

- Every actor: looping idle, attack, hit, and nonlooping defeat.
- Heroes: nonlooping victory.
- DPS Power Strike, Tank Guard, and Healer Mend: the matching supplied class-action clip.

Procedural idle bobbing and attack lunges are removed after animated clips are verified. Sprite position remains fixed at the shared bottom-center anchor, preventing frame drift and ensuring all party slots animate identically.

## Enemy Identity

Enemy art is presentation-only and deterministic. No enemy identity is saved and no combat value changes.

- Normal encounters cycle through goblin, skeleton, bandit, wolf, orc, bat, slime, harpy, mimic, ghost, dark mage, zombie, elemental slime, and plant monster by level.
- Elite encounters cycle through elite knight, dread skeleton, infernal brute, frost wraith, poison naga queen, storm lich, dragon whelp, and ancient golem by elite encounter index.
- Boss encounters cycle through four original bosses by 25-level boss segment: Ironroot Warchief, Ossuary Sovereign, Embermaw Colossus, and Astral Wyrm.

The original bosses match the approved side-view pixel language, face left, use larger readable silhouettes, and each provide idle, attack, signature attack, hit, and defeat clips. Boss art does not add mechanics, authored rewards, or party-size scaling.

## Scene Behavior

`PrototypeScene` retains stable nodes for each party slot and the enemy. Rendering changes identity or returns a completed action to the appropriate idle clip; it does not restart idle clips on every presentation snapshot. Events select the exact slot and action clip. Same-timestamp attacks remain ordered by simulation events and do not move nodes.

Victory and revival restore every hero's alpha and idle clip. Defeated heroes remain on their final defeat frame until encounter resolution. Animation preference pauses SpriteKit globally exactly as before, and passive input behavior is unchanged.

## Verification

Work proceeds in vertical TDD slices:

1. Source archive and deterministic asset builder.
2. Runtime clip manifest and bundled catalog.
3. Hero idle/combat/class-action integration.
4. Normal and elite enemy identity/animation integration.
5. Original boss production and boss selection.
6. Full arm64 tests, clean build, context guard, exact-bundle launch, and live visual QA.

Automated checks cover source hashes, output transparency and dimensions, stable anchors, manifest completeness, nearest filtering, deterministic enemy selection, clip loop rules, exact-slot event routing, no procedural movement, defeated-state retention, and victory/revival restoration. Documentation records only freshly verified facts. The branch remains isolated and is pushed only after every gate passes; it is not merged or released.
