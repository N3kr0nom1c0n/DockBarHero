# DockBarHero Heroes and Party Design

**Status:** Approved

**Date:** 2026-07-12

**Project:** DockBarHero

**Builds on:**

- `docs/superpowers/specs/2026-07-12-dockbarhero-progression-safety-design.md`
- `docs/superpowers/plans/2026-07-12-dockbarhero-progression-safety.md`
- integrated `main` at `8acdec4`

## 1. Scope and Milestone Shape

This milestone completes Heroes and Party on schema v2. It starts a run with one chosen hero, unlocks a chosen second hero after Boss 25, automatically adds the final class after Boss 100, expands deterministic combat to three party slots, makes inventory shared and equipment per hero, and presents the party in management and on the desktop rail.

Implementation proceeds as verified vertical slices on one feature branch:

1. party state and persistence;
2. unlock lifecycle;
3. party combat and rewards;
4. shared inventory and per-hero equipment;
5. management and rail presentation;
6. full verification and live QA.

Abilities remains a placeholder. Class Actions, enemy scaling by party size, gold spending, skills, shop purchases, and save migration are outside this milestone.

## 2. Durable Party State

`PartyState` owns one to three ordered `HeroState` values and a `PartyUnlockState`. Array order is party-slot order; slots are zero-based in the domain and shown as Hero 1 through Hero 3 in UI.

Each `HeroState` persists:

- its unique `HeroClassID`;
- level and current XP;
- combat health and independent attack timer;
- weapon and armor item references;
- encounter alive duration;
- whether it has been down during the current encounter;
- its consecutive encounter-death streak.

`PartyUnlockState` persists completed milestones and an optional `PendingPartyUnlock`. A pending Boss 25 unlock records the defeated milestone and the two remaining class choices. The state is valid only with one hero, a defeated Boss 25 encounter, and the encounter phase `awaitingPartyChoice`. Boss 100 is recorded complete only with all three unique classes present and never creates a pending choice.

The three party classes must be unique. Every equipped item reference must resolve to exactly one shared-inventory item of the correct slot, and one item may be referenced by at most one hero. Existing development saves receive no migration; archived bytes are diagnostic only and clean end-to-end QA begins from a new schema-v2 save.

## 3. Unlock Lifecycle and Durability

Boss 25 victory is a transaction with a durable UI gate:

1. resolve victory and all rewards;
2. update per-hero XP and death streaks;
3. record the pending slot-two unlock and its two remaining classes;
4. leave the defeated Boss encounter at the encounter boundary in `awaitingPartyChoice`;
5. commit the complete candidate `GameState` in memory;
6. synchronously flush that exact active run through `SaveCoordinator`;
7. only after the flush completes, publish `RunPresentation.partySelection` and open the singleton management window.

The simulation consumes no combat time in `awaitingPartyChoice`. Combat intents other than choosing the pending class are rejected, and the driver cannot begin another encounter. The coordinator reports whether a flush reached durable storage. If the flush fails, the driver remains paused, the save failure is shown without class-choice buttons, and the session retries the same immutable checkpoint on the normal autosave cadence. The first successful retry publishes the choice exactly once. Relaunching a valid pending save publishes the party-selection screen immediately without briefly resuming combat.

Choosing the second hero constructs a full candidate state, seeds and equips the newcomer, clears the pending unlock, completes the already-earned encounter transition, and durably replaces the run before combat presentation resumes. A replacement failure keeps the pending choice and defeated Boss boundary intact, so the player can retry without duplicated rewards.

Boss 100 resolves rewards, creates and equips the final missing class automatically, records slot three complete, and continues through the normal encounter transition without pausing. Re-farming Boss 25 or Boss 100 cannot repeat an already completed unlock.

## 4. New-Hero Seeding and Equipment

A new hero starts at the highest level currently present in the party and has zero XP toward that level's next threshold. Its health is full, its attack timer is reset to its class interval, its encounter alive duration is zero, it is not down, and its death streak is zero.

The newcomer automatically equips the strongest unused weapon and strongest unused armor from the party inventory. “Strongest” is deterministic per slot:

1. greater `primaryStat`;
2. greater item level;
3. lower creation sequence;
4. lower item ID.

Items already referenced by another hero are ineligible. If no unused item exists for a slot, that slot starts empty. Seeding and both equipment assignments are part of the same candidate-state transaction as the unlock; any validation or arithmetic failure rolls back the whole operation.

## 5. Deterministic Party Combat

Each living hero has an independent countdown. Active-time consumption subtracts the same integer nanosecond step from the enemy timer and every living hero timer, and adds it to the encounter duration and each living hero's encounter-alive duration. Downed heroes neither attack nor accumulate alive duration.

The next step is the minimum timer among the enemy and all living heroes. At a timestamp:

1. ready living heroes attack in ascending party slot;
2. stop hero processing as soon as the enemy is defeated;
3. if the enemy remains alive and is ready, it attacks the lowest-numbered living hero.

Hero-before-enemy ordering therefore remains unchanged, while same-timestamp hero ties are deterministic by slot. Events identify a hero by party slot so rendering and tests never infer the actor from mutable state.

A hero reduced to zero health remains down until encounter resolution. The enemy retargets the next lowest living slot on later actions. Party defeat begins only when all heroes are down. Completed revival restores every hero to full health, clears current-encounter down/alive tracking, and resets every hero and enemy attack timer. Victory also restores the whole party while constructing the next encounter or pending unlock boundary.

Enemy health, damage, and timing use the existing level and tier data without party-size multipliers. Balance targets are one hero for levels 1–25, two heroes for levels 26–100, and three heroes for levels 101 and above.

## 6. XP, Death Streaks, and Retreat

For each hero, capture its class, level, and alive duration from the defeated encounter before applying XP. With `fullXP` from the existing level/tier formula:

```text
heroXP = floor(fullXP * aliveDuration / encounterDuration)
```

All multiplication is checked integer arithmetic. A hero with positive alive duration receives at least 1 XP. A hero with zero alive duration receives zero XP. Production encounters have positive duration. For deterministic compatibility with existing instantaneous simulation fixtures, a zero-duration victory awards full XP to each living hero and zero XP to a downed hero; it never divides by zero. Each hero then applies its own XP thresholds and may level multiple times.

At every encounter resolution, each hero's streak is updated independently:

- a hero that was down increments only its own streak, including on party victory;
- a hero that survived resets its own streak to zero;
- defeat and completed revival do not erase streaks unless a remedial or player-selected transition resets them.

After victory rewards and streak updates, transition precedence is:

1. a newly earned Boss 25 unlock records the mandatory pending choice while retaining any queued destination;
2. otherwise a queued player destination preserves existing behavior;
3. otherwise remedial retreat applies if any hero reached three consecutive deaths;
4. otherwise the normal Push or Farming transition applies.

Completing the Boss 25 choice resumes at the deferred transition boundary: the retained queued destination applies first, then a death-streak retreat if no destination was queued, then normal Push or Farming behavior. Combat therefore never resumes before the second hero is chosen, and an earlier player destination still takes precedence over automatic retreat.

After a party defeat, the same queued-destination-first rule is applied at completed revival; otherwise any three-death streak triggers retreat before retrying the failed level. Remedial retreat uses the existing deterministic `EncounterDirector.fallback(afterFailing:)` result and resets every hero's death streak. Applying a queued player destination also retains the existing reset behavior and clears all hero death streaks. Victory rewards remain committed before a death-streak retreat.

## 7. Rewards and Transaction Boundaries

Victory candidate order is:

1. emit victory;
2. calculate and apply proportional XP per hero and all level-ups;
3. calculate and apply shared gold;
4. generate exactly one shared-inventory item;
5. evaluate auto-equip across eligible heroes;
6. update each hero's death streak;
7. apply Boss unlock state;
8. apply queued destination, pending-choice pause, death-streak retreat, or normal transition;
9. restore the party and reset encounter timers as required by that transition.

Any invalid timer, duplicate class, shared equipment reference, checked-arithmetic failure, loot failure, unlock failure, or next-encounter construction failure rejects the complete candidate. No partial XP, gold, item, equipment, streak, unlock, or campaign transition is caller-visible.

Auto-equip for normal drops evaluates the item's strict effective-stat improvement for every eligible hero not blocked by another hero's reference. It chooses the greatest improvement, then ascending party slot. Equal-to-current items are not upgrades. Replaced and unused items remain party-owned.

Manual equip identifies both party slot and item ID. It rejects an unknown slot, wrong-slot item, malformed item, or item equipped by another hero. Equipping an owned unused item replaces only that hero's same-slot reference; it never transfers an item implicitly from another hero.

## 8. Session, Save, and Relaunch Behavior

`RunPresentation` gains `partySelection(PendingPartyUnlock, GamePresentation)`. `GameSession` owns the durability gate between the simulation's pending state and that presentation. The pending save remains a normal `.active(GameState)` document so all encounter, reward, and inventory data stays in one validated transactional payload.

Party unlock creation, class choice, equipment changes, per-hero XP and levels, down/streak changes at durable boundaries, and retreat transitions request saves. The Boss 25 pending checkpoint and completed class choice use flush/replace semantics because UI and combat lifecycle depend on their durability. Autosave and termination persist an awaiting-choice run without starting combat.

New Game still replaces the run with `.classSelection` and preserves application and overlay settings. Unsupported or unreadable saves remain preserved under the existing diagnostic rules.

## 9. Management Presentation

The Boss 25 choice screen reuses the class-card language from initial selection but shows only the two persisted remaining classes, explains that the party is paused after rewards, disables repeat submission, reports save errors, and exposes accessibility identifiers for both choices.

Overview presents a card for each hero in party order with class, Hero level, XP, current/max health, effective attack, effective defense, attack interval, and death streak. Down heroes are explicitly labeled “Down.” Campaign, enemy, gold, destination, and DPS information remains shared.

Inventory remains one shared table. It adds an explicit selected-hero control and shows which hero, if any, equips each item. Equip actions include the selected party slot. Auto-equip remains a party-wide preference.

Abilities remains the existing placeholder and explicitly says Class Actions are a later milestone. No ability controls or save fields are added.

## 10. Rail Presentation

The desktop rail renders one sprite and one health bar per active hero, ordered left-to-right by party slot, facing the single enemy. Each hero has a class-distinct stable sprite token or palette and its own level label. The enemy and shared DPS remain on the right/center without overlapping hero labels at three slots.

Attack, hit, down, victory, and revival animation events address the exact hero slot. A downed hero remains visibly down or hidden until encounter resolution. The pending Boss 25 choice hides or freezes combat presentation and relies on the management window for the required choice. Rail input behavior, overlay placement, fullscreen hiding, and existing application preferences remain unchanged.

## 11. Verification and Live QA

Every slice follows red-green-refactor with focused arm64 tests and a coherent commit. Tests cover:

- one-to-three unique heroes, pending-unlock invariants, per-hero timers, streaks, and save round trips;
- Boss 25 reward-before-pause durability, relaunch into choice, failed-save gating, successful and failed class choice, and Boss 100 automatic final class;
- same-timestamp slot ordering, lowest-living targeting, downed heroes, all-down defeat, full-party restoration, time-alive XP rounding/minimum/overflow, individual streak updates, reward-before-retreat, and queued precedence;
- exclusive equipment validation, deterministic newcomer equipment, per-hero manual equip, party auto-equip improvement and tie ordering;
- party management cards, choice accessibility, shared inventory ownership labels, and three-hero rail layout/events;
- model-based balance through Boss 25 solo, levels 26–100 with two heroes, and level 101-plus construction with three heroes, without dynamic party scaling.

The final gate is the complete `platform=macOS,arch=arm64` test suite, a clean unsigned arm64 build, the project context guard, `./script/build_and_run.sh --verify`, and live QA from a clean save after archiving current saves. Live QA performs all initial class, Boss 25 unlock, Boss 100 automatic-addition, inventory, relaunch-pending-choice, management, and rail interactions without owner input. Verified facts only are recorded in `PROJECT.md` and the Heroes and Party QA packet.

## 12. Completion Criteria

The milestone is complete when a clean run can choose its first hero, durably pause and resume through the Boss 25 second-hero choice, automatically gain the final class at Boss 100, resolve deterministic one-to-three-hero combat and time-alive rewards, enforce exclusive per-hero equipment over shared inventory, retreat on per-hero three-death streaks with queued precedence intact, and present the party accurately in management and on the rail. All automated, build, context, launch, and proportional live-QA gates must pass on `feature/heroes-and-party`; the branch may be pushed but is not merged, released, or extended into Class Actions.
