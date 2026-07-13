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

- App-name targeting initially launched a stale registered DockBarHero bundle beside the candidate. All DockBarHero processes were terminated, `./script/build_and_run.sh --verify` rebuilt the candidate, and every later check used the absolute worktree bundle path. Process inspection then showed one DockBarHero executable, from `.worktrees/heroes-and-party/.build/RunDerivedData/Build/Products/Debug/DockBarHero.app`.
- The clean run selected DPS first, chose Tank at the durable Boss 25 pause, and received Healer automatically at Boss 100 without another pause. The saved party had three exclusive equipment pairs and the newcomer began at the current highest hero level with zero XP.
- DPS Power Strike and Tank Guard were cast from the interactive rail. Healer Mend was cast from management after damage was present. Each action visibly entered cooldown.
- Passive mode rejected rail casts; Interactive mode accepted them. Power Strike was cast and the app was terminated immediately with `5,893,251,459` ns remaining on disk; relaunch displayed `PS 5.6`, confirming cooldown did not consume offline time. The temporary preference was returned to Passive after QA while overlay visibility and animations remained enabled.
- The clean run naturally produced Common, Uncommon, Rare, and Epic items. Every inspected non-Common row had canonical affixes, and the management table visibly showed rarity color, affix text, comparison results, auto-equip, capacity, and overflow. Auto-equip remained enabled and the six equipped IDs were distinct.
- Four provisional 10-slot expansions were purchased to continue the run. The second purchase visibly cost exactly 1,000 gold; the later 8,000-gold next-price presentation matched the approved doubling schedule.
- Capacity pressure routed nonmatching drops to overflow. Moving one stack back changed inventory from 44 to 45 stacks and overflow from 12 to 11. Ordinary identical items naturally stacked above 100 quantity; the saved run later contained a 254-item stack.
- Partial salvage confirmed exactly 1 item for 74 gold, reduced the selected stack from 104 to 103, and raised gold from 603,787 to 603,861. Bulk salvage confirmed exactly 1,030 items from 357 stacks for 100,810 gold and changed inventory from 70 to 7 stacks and overflow from 298 to 12.
- A common armor stack was locked and remained locked after relaunch. The final live save retained one locked stack, four expansion purchases, finite 110-stack capacity, durable overflow, and auto-equip enabled.
- The rail window showed three class-distinct pixel silhouettes, three health bars and action labels, one enemy, and the centered DPS scale. This exact-window evidence replaced the stale rectangle-era bundle image.
- Live play exercised deterministic remedial farming twice: a Boss 75 loss retreated to level 49, and a later frontier-84 loss retreated to level 74. Player-directed progress resumed from those farming destinations and subsequently cleared the blocked bosses.
- Native computer-control transport failed after the live session had started, so remaining clicks used macOS Accessibility and exact-window captures. No locked-screen or inferred visual result is presented as evidence.

## Rendering Correction Found During QA

- Live QA exposed a real candidate-build defect: a hero defeated during a party victory could remain invisible even though party state restored every hero.
- A regression test first failed because two defeated party slots retained zero alpha after `.victory`. The minimal fix restores every rendered hero's idle texture and visibility when victory resolves.
- Fresh focused verification passed all 15 `PrototypeSceneHostTests`, including `testVictoryRestoresEveryDefeatedPartySprite`, with zero failures; `** TEST SUCCEEDED **`.

## Final Gates

- The final post-QA arm64 suite executed 344 tests with zero failures or unexpected results; `** TEST SUCCEEDED **` using `.build/ClassActionsLootFinalQA2`.
- `xcodebuild clean build` completed successfully for the unsigned arm64 target and reported `** BUILD SUCCEEDED **` using `.build/ClassActionsLootBuildFinalQA2`.
- The project context guard reported `project context is valid`; `AGENTS.md` is 28 lines and `PROJECT.md` remains below 150 lines.
- `./script/build_and_run.sh --verify` rebuilt and launched PID 98411. Process inspection found exactly one DockBarHero executable, at the absolute worktree bundle path.
- A final exact-window capture from that process showed all three pixel heroes, their action labels and health bars, the enemy, and the centered DPS scale. Both settings files still matched the original SHA-256 `1bd458308cf46a91b10dfe45093bf41993bdd24477626ca80278cf6e981a61a9`.
- `git diff --check` was clean before the documentation commit.
- `git push -u origin feature/class-actions-and-loot` created the remote feature branch and configured upstream tracking; the isolated worktree was retained.
- The branch is not merged or released. Authored Unique reward content and Class Action modifiers remain excluded.
