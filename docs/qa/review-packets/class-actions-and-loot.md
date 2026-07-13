# Class Actions and Loot Expansion Review Packet

- Base: Heroes and Party candidate history rooted at `main` commit `8acdec4`
- Candidate branch: `feature/class-actions-and-loot`
- Scope: class actions, deterministic item depth, authored Unique grant contract, stacking, capacity, overflow, inventory queries, and atomic salvage
- Explicit exclusions: merge, release, authored quest/boss Unique rewards, Class Action modifiers, and party-size enemy scaling

## Automated Evidence

- Class Actions integrated gate: 308 arm64 tests passed with zero failures.
- Item Depth integrated gate: 318 arm64 tests passed with zero failures.
- Inventory Operations focused UI/core gate: 24 tests passed with zero failures.
- Self-review corrections covered exact stack signatures, exclusive extraction, newcomer stacked equipment, replacement consolidation, authored Unique validation, expanded filters, and exact salvage previews.
- Transaction edge gate: 45 tests passed for capacity cap/prices, overflow rollback, quantity overflow, final-layout equipment replacement, salvage rollback, and save durability.
- Final full arm64 suite: 343 tests passed with zero failures or unexpected results; `** TEST SUCCEEDED **`.

## Implemented Behavior

- Tank Guard, DPS Power Strike, and Healer Mend are deterministic, persisted, cooldown-bound actions available in management and on the interactive rail.
- Class-action cooldowns advance only with active living time; passive rail mode remains noninteractive.
- Guaranteed drops use deterministic Common through Epic rarity and legal canonical affixes; effective Might, Ward, Vitality, and Haste stats feed class-weighted comparisons and auto-equip.
- Authored Unique definitions now create permanently locked, individual items and validation rejects descriptor impostors; authored quest/boss grant content remains outside this milestone.
- Ordinary items stack with no product quantity limit only across the approved template, level, rarity, affix, and lock signature; arithmetic overflow rejects transactionally.
- Inventory starts at 40 slots, gains 10 at Boss 25 and 20 at Boss 100, purchases 10-slot expansions from a tuneable 500-gold doubling schedule, and caps at 200.
- Nonmatching full-capacity drops persist in unlimited overflow. Matching moves merge even at capacity; invalid moves expose no mutation.
- Equipped identities remain exclusive. Stack extraction, replacement return, and newcomer auto-equipment evaluate final capacity and use stable deterministic identities.
- Inventory management shows capacity, overflow, quantities, item names, rarity text/color, affixes, exact hero deltas, lock/equipment/location/upgrade filters, deterministic sorts, partial movement, partial salvage, visible bulk salvage, and exact confirmation gold.
- Salvage rejects unknown, duplicate, excessive, equipped, locked, and Unique selections; the complete checked batch removes all quantities and grants gold once or rolls back.

## Save Isolation

- The active gameplay save was archived before clean launch at `~/Library/Application Support/com.n3kr0nom1c0n.DockBarHero/class-actions-loot-pre-qa-20260712-2223/`.
- Archived `save-v2.pending.json` SHA-256: `8577e88abf7588b211f8b98147464d2fe313ee56f382d3ba297fe96ea5032f82`.
- Active gameplay save names were removed only after `cmp` verified the archive. Existing invalid-save diagnostics were retained.
- `settings-v1.json` and `settings-v1.backup.json` remained byte-identical at SHA-256 `1bd458308cf46a91b10dfe45093bf41993bdd24477626ca80278cf6e981a61a9`.

## Exact-Bundle and Live QA

- `./script/build_and_run.sh --verify` regenerated the project, built successfully, and launched PID 37995 from `.worktrees/heroes-and-party/.build/RunDerivedData/Build/Products/Debug/DockBarHero.app`.
- The clean launch remained at class selection and did not create a gameplay save before a class choice.
- The Mac was locked when computer control attached. The runtime explicitly reported that automatic unlock could not unlock it, so no class choice, cast, inventory click, confirmation, or visual claim is recorded.
- Required live three-class casts, cooldown carryover/relaunch, rarity/affix inspection, lock/relaunch, capacity purchase, overflow recovery, partial/bulk salvage, and rail visual confirmation remain open. Automated coverage is not presented as visual evidence.

## Final Gates

- The clean unsigned arm64 build reported both `** CLEAN SUCCEEDED **` and `** BUILD SUCCEEDED **` using `.build/ClassActionsLootBuildFinal`.
- The project context guard reported `project context is valid`; `AGENTS.md` is 28 lines and `PROJECT.md` remains below 150 lines.
- `git diff --check` was clean before documentation.
- The branch is not merged or released. Push is withheld because the required live click gate could not run while macOS was locked.
