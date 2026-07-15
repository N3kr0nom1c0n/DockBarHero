# DockBarHero Campaign Area One Design

## 1. Purpose

This milestone replaces levels 1 through 25 of the provisional periodic campaign with one authored, playable dungeon area while preserving every accepted progression, farming, party, class-action, loot, inventory, save, and macOS behavior.

Area 1 is **The Forgotten Shallow Depths That Were Remembered**. It introduces deterministic enemy identities and identity-specific stat profiles, presents the authored area and enemy in the rail and management window, ends at a placeholder Boss 25, and then continues into the existing procedural campaign at level 26.

The implementation is an isolated overnight milestone. It does not merge or release, and it does not select the final Boss 25 identity or artwork.

## 2. Scope

The milestone includes:

- a typed campaign catalog and validated authored definitions;
- exact authored encounters for levels 1 through 25;
- procedural compatibility fallback for level 26 and above;
- deterministic health, attack, defense, and attack-interval profiles per identity;
- area and enemy presentation in management and on the rail;
- a one-pass area-title marquee with Interactive-only hover replay;
- stable sprite identifiers with generic-enemy fallback;
- clean-save live QA through Boss 25 and into level 26;
- compatibility coverage for existing advanced schema-v2 saves.

The milestone excludes:

- the final Boss 25 identity or artwork;
- authored Unique rewards, quests, or boss-specific rewards;
- enemy-specific combat mechanics such as splitting, revival, ambush, poison, or spellcasting;
- Class Action modifiers, party-size scaling, Area 2, economy expansion, offline progression, merge, and release.

## 3. Campaign Catalog Architecture

`CampaignCatalog.standard` is the single source of authored campaign content. It owns these typed definitions:

- `AreaDefinition`: stable ID, full display name, short rail name, and covered level range;
- `EnemyDefinition`: stable ID, display name, tier, sprite ID, and stat profile;
- `EncounterDefinition`: exact level, area ID, and enemy ID;
- `EnemyStatProfile`: checked integer health, attack, defense, and attack-interval adjustments.

`CampaignResolver` validates the catalog and resolves a complete encounter definition for a level. Levels 1 through 25 must resolve from authored content. Levels 26 and above resolve through a compatibility definition that retains the existing periodic Normal, Elite, and Boss schedule and current generic enemy behavior.

The catalog must reject duplicate area, enemy, or encounter IDs; missing authored levels; overlapping authored levels; unknown content references; tier mismatches; empty or malformed sprite IDs; nonpositive health or interval ratios; negative attack or defense values; and values that cannot be applied with checked arithmetic. A syntactically valid sprite ID does not require installed artwork.

`EncounterDirector` requests an encounter definition from `CampaignResolver` when activating a level. An enemy factory applies, in order:

1. existing level scaling;
2. existing Normal, Elite, or Boss health scaling;
3. the resolved identity stat profile.

The existing tier damage multiplier remains in combat resolution. Identity attack adjusts the enemy's stored base attack before that unchanged tier damage rule is applied.

All gameplay calculations remain deterministic and use checked integer or basis-point arithmetic. Floating point remains presentation-only.

## 4. Save Compatibility And State Ownership

The schema-v2 save shape does not change. Durable state continues to store the selected level, frontier, queued destination, campaign mode, tier, and complete in-progress combat state.

Area and enemy identity are deterministic projections of the saved encounter level. They are not duplicated in the save. Existing saves at levels 1 through 25 load their saved in-progress combat state and receive the authored presentation for that level; the next encounter boundary constructs the authored stat profile. Existing advanced saves at level 26 or above continue through the procedural compatibility path.

Save validation must confirm that the current and next levels resolve through the campaign resolver without requiring exact reconstruction of an in-progress enemy's current health or timers. Invalid catalog content or arithmetic rejects encounter construction transactionally and leaves the prior game state unchanged.

Boss 25 behavior remains unchanged: victory commits ordinary rewards, durably pauses for the second-class choice, and begins procedural level 26 only after the choice is saved. Farming, queued destinations, automatic retreat, frontier ownership, and per-hero death streaks retain their current semantics.

## 5. Authored Area Content

Area ID: `forgottenShallowDepths`

Full display name: `The Forgotten Shallow Depths That Were Remembered`

Settled rail name: `Shallow Depths`

The exact encounter sequence is:

| Level | Enemy | Tier |
|---:|---|---|
| 1 | Slime | Normal |
| 2 | Bat | Normal |
| 3 | Goblin | Normal |
| 4 | Skeleton | Normal |
| 5 | Knight | Elite |
| 6 | Zombie | Normal |
| 7 | Bandit | Normal |
| 8 | Slime | Normal |
| 9 | Mimic | Normal |
| 10 | Frost Wraith | Elite |
| 11 | Goblin | Normal |
| 12 | Bat | Normal |
| 13 | Skeleton | Normal |
| 14 | Zombie | Normal |
| 15 | Poison Naga Queen | Elite |
| 16 | Bandit | Normal |
| 17 | Mimic | Normal |
| 18 | Goblin | Normal |
| 19 | Skeleton | Normal |
| 20 | Ancient Golem | Elite |
| 21 | Bat | Normal |
| 22 | Zombie | Normal |
| 23 | Bandit | Normal |
| 24 | Mimic | Normal |
| 25 | Unknown Guardian | Boss |

The level-25 content and sprite IDs must make their placeholder status explicit so the separate boss/sprite milestone can replace the definition without changing progression code.

## 6. Initial Stat Profiles

Health is a basis-point multiplier applied after existing level and tier health scaling. Attack and attack interval are basis-point multipliers applied after existing level scaling; the unchanged tier damage rule applies later during combat resolution. Defense is a checked flat addition. An interval below the simulation minimum is invalid rather than clamped silently.

| Enemy | Health | Attack | Defense | Attack interval |
|---|---:|---:|---:|---:|
| Goblin | 10,000 bp | 10,000 bp | +0 | 10,000 bp |
| Bandit | 8,500 bp | 11,500 bp | +0 | 8,000 bp |
| Slime | 13,000 bp | 7,500 bp | +0 | 13,000 bp |
| Mimic | 12,500 bp | 11,500 bp | +2 | 11,500 bp |
| Skeleton | 10,500 bp | 9,000 bp | +1 | 10,500 bp |
| Bat | 7,000 bp | 8,000 bp | +0 | 6,000 bp |
| Zombie | 14,000 bp | 9,000 bp | +0 | 13,500 bp |
| Knight | 12,500 bp | 10,000 bp | +3 | 11,000 bp |
| Frost Wraith | 8,500 bp | 11,500 bp | +1 | 7,000 bp |
| Poison Naga Queen | 11,000 bp | 12,000 bp | +2 | 8,500 bp |
| Ancient Golem | 16,000 bp | 11,000 bp | +4 | 15,000 bp |
| Unknown Guardian | 10,000 bp | 10,000 bp | +0 | 10,000 bp |

These are provisional content values. The implementation may tune only these catalog values when fresh deterministic balance tests prove that a starting class cannot complete Area 1. Combat rules, progression formulas, tier ratios, rewards, and class definitions are not tuning surfaces for this milestone.

Tank, DPS, and Healer must each clear Boss 25 solo with ordinarily obtainable equipment under deterministic tests.

## 7. Presentation

`GamePresentation` gains a transient campaign presentation containing area ID and names, enemy ID and name, sprite ID, tier, and level. SwiftUI and SpriteKit consume this projection and do not perform independent catalog lookups.

The management Overview shows:

- the full area title;
- enemy name, tier, and explicit enemy level;
- the existing frontier, selected level, queued destination, mode, gold, hero, combat, and DPS data;
- authored enemy names beside farming destinations for levels 1 through 25.

The rail preserves its dimensions, hero and enemy health bars, class actions, DPS label, farming status, placement, focus, fullscreen suppression, animation control, and Passive click-through behavior.

The enemy column shows the resolved enemy name with the existing tier and level information. Long names must fit without overlapping the centered title lane or leaving the rail bounds. The orange `FARMING • FRONTIER <level>` line remains unchanged.

## 8. Area Title Marquee

The rail adds a clipped center title lane above the centered DPS label. Its behavior is presentation-only and uses an injected or otherwise deterministic animation clock in tests.

- The full area name scrolls right-to-left once when an active area is first presented or the area ID changes.
- After that pass, the lane settles on `Shallow Depths`.
- Re-rendering the same area does not restart the animation.
- Entering class or party selection hides and cancels the title presentation.
- In Interactive mode, a pointer held continuously inside the title lane for three seconds triggers one additional full-title pass.
- Leaving before three seconds resets the hover duration.
- After a hover-triggered pass, the pointer must leave and re-enter before another replay can arm.
- Passive mode performs the initial pass but does not track hover.
- Pointer tracking is local to the rail view. The feature must not add a global event monitor, accessibility dependency, or Passive input region.

The marquee remains static when animations are disabled. In that state it shows the settled short name and does not accumulate hidden hover time.

## 9. Sprite Resolution

Every enemy definition carries a stable sprite ID. The sprite catalog first attempts the identity-specific idle, attack, hit, and defeated frames. Missing actions fall back to the identity's idle frames, and a missing or invalid identity falls back to the existing generic enemy animations.

Missing artwork must never block catalog validation, combat, persistence, or launch. Invalid decoded pixel data retains the existing visible fallback and one-time diagnostic behavior. `Unknown Guardian` deliberately uses the generic placeholder path.

Changing from one encounter identity to another updates the enemy idle texture immediately and preserves the existing event-driven animation behavior.

## 10. Failure And Transaction Rules

- Catalog validation completes before a definition is used.
- Encounter activation constructs a complete candidate state and commits only after definition lookup, checked stat application, tier agreement, and timer validation succeed.
- Arithmetic overflow, missing campaign content, illegal ratios, invalid intervals, or malformed sprite identifiers expose a typed failure and preserve the prior state. A valid sprite ID with no installed artwork uses the generic fallback instead of failing.
- Presentation failure cannot mutate simulation state.
- Procedural fallback remains total for every positive level supported by existing checked scaling.
- No authored content may lower the frontier, bypass queued-destination precedence, change farming selection, or skip the durable Boss 25 party-choice gate.

## 11. Automated Verification

Focused tests must cover:

- exact Area 1 levels, identities, tiers, and display values;
- complete coverage of levels 1 through 25;
- duplicate, missing, overlapping, unknown, mismatched, and arithmetically invalid definitions;
- exact stat-profile application and rollback;
- procedural resolution at levels 26, 50, 100, 192, and large checked boundaries;
- equivalent deterministic state and event order across time partitions;
- farming repeat, queued return, automatic retreat, and frontier preservation with authored identities;
- rewards, loot, Boss 25 pause, save durability, second-class choice, and level-26 continuation;
- loading schema-v2 saves at authored and procedural levels;
- solo Area 1 completion for Tank, DPS, and Healer with ordinary obtainable equipment;
- management area/enemy copy and authored farming labels;
- enemy sprite selection, missing-action fallback, invalid-identity fallback, and identity transition;
- marquee initial pass, same-area stability, area transition, settled name, three-second hover, early exit, leave/re-enter rearming, animations-disabled behavior, and Passive hover rejection;
- rail layout at default and narrow widths with one and three heroes, long names, DPS, and farming status.

The final automated gate runs the focused suites, complete arm64 suite, clean unsigned arm64 build, project context guard, exact-worktree launch, exact process-path inspection, and `git diff --check`.

## 12. Overnight Worktree And Live QA

Implementation uses a new `.worktrees/campaign-area-one` worktree on `feature/campaign-area-one`, based on the completed and pushed `feature/class-actions-and-loot` branch. It does not modify `main` or reuse the active feature worktree.

Before beginning long-running work, start `caffeinate -dimsu` in the background, record its PID, and confirm the assertion remains alive. The assertion keeps the Mac and display awake; it does not authorize or attempt to bypass a locked session. Stop the recorded process during final cleanup.

Implementation proceeds through four locally committed vertical slices:

1. campaign catalog, validation, and exact Area 1 assignments;
2. deterministic stat profiles and encounter integration;
3. campaign presentation, sprite fallback, management labels, and rail marquee;
4. integrated balance, save compatibility, live QA, and evidence-only documentation.

For clean-save QA:

1. Archive the current active `save-v2.*` files and verify the copies before removing active names.
2. Hash and preserve settings files.
3. Start a disposable clean DPS run and play through level 25 without editing the save to advance progression.
4. Verify the exact authored identities, visible stat tendencies, farming and return behavior, full-title initial marquee, settled title, Interactive three-second replay, Passive rejection, generic sprite fallback, Boss 25 rewards, second-class choice, relaunch durability, and procedural level 26.
5. Delete the disposable QA save.
6. Restore the original active saves and settings byte-identically.

If the UI session becomes unavailable, the app cannot be controlled, the exact worktree bundle cannot be distinguished, or any required observation cannot be proven, live QA is blocked. Automated success must not be reported as visual success.

## 13. Completion And Push Gate

The branch is eligible to push only when:

- all four implementation slices are locally committed;
- focused and full arm64 tests pass with zero failures;
- Tank, DPS, and Healer deterministic Area 1 balance tests pass;
- the clean unsigned build, context guard, exact-bundle launch, and diff check pass;
- the clean-save live QA path passes through procedural level 26;
- the original saves and settings are restored and verified;
- the QA packet and `PROJECT.md` contain only fresh verified facts;
- the worktree is clean;
- the `caffeinate` process is stopped.

After every gate succeeds, push `feature/campaign-area-one` with upstream tracking. Do not merge, release, begin Area 2, or start excluded content. If any required gate remains unproven, retain the local branch, do not push, and report the exact blocker.
