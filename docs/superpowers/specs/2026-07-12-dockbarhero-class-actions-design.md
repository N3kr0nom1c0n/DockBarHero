# DockBarHero Class Actions Design

**Status:** Approved

**Date:** 2026-07-12

**Project:** DockBarHero

**Builds on:**

- `docs/superpowers/specs/2026-07-12-dockbarhero-heroes-and-party-design.md`
- `feature/heroes-and-party` at `6c0c88c`

## 1. Scope

This milestone replaces the Abilities placeholder with one manually activated, cooldown-only Class Action for each party class. It adds deterministic action state and resolution, management controls, interactive-only rail controls, persistence, presentation events, tests, and live QA.

The actions are Guard for Tank, Power Strike for DPS, and Mend for Healer. Automatic casting, resources, action upgrades, revival actions, area damage, action-related item affixes, and additional actions are outside this milestone.

## 2. Architecture

Each `HeroState` owns a persisted `ClassActionState` containing its stable action ID, remaining cooldown, and optional active effect state. Only Tank may persist an active Guard interception in this milestone. Stable definitions map each class to exactly one action and contain cooldown and basis-point tuning values; tuning is validated content, not save semantics.

A pure `AbilityResolver` validates and resolves manual action intents against party, enemy, encounter, and definition snapshots. It returns a complete candidate result and exact domain events without mutating shared state. `GameSimulation` remains the transaction boundary and commits only a fully valid result.

`CombatResolver` remains responsible for scheduled automatic attacks. Its enemy-attack path consumes a valid Guard interception supplied by party state. Victory caused by Power Strike enters the same reward, unlock, queued-destination, retreat, and next-encounter transaction used by automatic attacks.

## 3. Cooldown Model

New runs and newly unlocked heroes start with their action ready. A successful cast sets the definition's full cooldown. Cooldowns carry across encounter boundaries and advance only during active combat time using checked `SimulationDuration` integer nanoseconds.

A downed hero's cooldown freezes. Cooldowns also freeze during class selection, the Boss 25 party-choice boundary, completed-encounter transitions, revival, and application downtime. The overlay animation preference remains presentation-only and does not pause gameplay. Victory and defeat do not reset cooldowns. Completed revival restores health and attack timers but leaves action cooldowns unchanged.

Partitioned and unpartitioned advances must produce identical cooldown state and action ordering.

## 4. Action Definitions

### 4.1 Guard

- Class: Tank.
- Cooldown: 8 seconds.
- On cast, stores one Guard interception owned by that Tank.
- The next real enemy attack redirects to the guarding Tank, regardless of the enemy's original lowest-living target.
- If the Tank was already the target, the action still applies.
- After normal defense calculation, final damage is multiplied by 5,000 basis points and floored, with the existing minimum-damage rule applied to the final result.
- Guard is consumed by the attack it modifies.
- Guard expires unused when its owner goes down or the encounter resolves.
- An already-active Guard rejects another Guard cast without changing cooldown or state.

### 4.2 Power Strike

- Class: DPS.
- Cooldown: 6 seconds.
- On cast, effective attack is multiplied by 25,000 basis points with checked integer arithmetic.
- Existing enemy-defense and minimum-damage rules then produce final damage.
- Damage is immediate and contributes to rolling and encounter DPS.
- A lethal Power Strike resolves victory and rewards exactly once through the existing transaction.

### 4.3 Mend

- Class: Healer.
- Cooldown: 10 seconds.
- On cast, target the living hero with the lowest current-health ratio.
- Compare health ratios using checked integer cross multiplication without floating point; ties resolve by ascending party slot.
- Heal 3,500 basis points of target maximum health, floored and clamped to missing health. A positive valid heal restores at least one health.
- Downed heroes are ineligible and Mend cannot revive.
- A full-health living party rejects Mend without starting cooldown.

## 5. Intent Ordering and Validation

Manual casts use a slot-addressed intent containing the party slot and stable action ID. The simulation resolves an accepted intent atomically between clock advances; an intent is never inserted halfway through automatic actions already being processed at one timestamp. Existing simultaneous automatic hero attacks retain ascending-slot order and hero-before-enemy ties.

A cast requires:

- an active encounter;
- an existing living hero at the addressed slot;
- the action assigned to that hero's class;
- zero remaining cooldown;
- no conflicting active Guard;
- a valid target and checked arithmetic.

Invalid slot, unknown or wrong-class action, downed caster, inactive encounter, cooldown, duplicate Guard, full-health Mend, invalid definitions, and arithmetic failure reject the cast. Rejection produces a typed reason for presentation while leaving health, cooldowns, active effects, DPS, rewards, and campaign state unchanged.

## 6. Persistence and Recovery

Schema-v2 validation requires exactly the action assigned to each hero class, a remaining cooldown between zero and that definition's maximum, and Guard state only on a living Tank in an unresolved active encounter. Invalid action state rejects the complete save document under existing preservation rules.

Partial cooldowns and an active Guard round-trip through primary and backup saves. Relaunch restores them without consuming offline time. Boss 25 and Boss 100 newcomers receive ready action state as part of the same unlock candidate transaction that seeds their level and equipment.

## 7. Presentation

The Abilities route becomes a party-ordered Class Actions page. Each hero card shows class, action name, concise effect description, cooldown state, and a Cast button. A disabled button exposes a specific visible reason: encounter inactive, down, cooldown remaining, no valid target, or action already active. Accessibility identifiers address the party slot and stable action ID.

The desktop rail displays one compact class-distinct action control adjacent to each hero. Cooldown progress remains visible in both passive and interactive modes, but controls accept input only while the existing overlay is explicitly interactive. Passive mode remains click-through and does not create hit targets. Adding controls must not change overlay placement, focus, fullscreen suppression, or application preference behavior.

Cast, damage, heal, interception, rejection, and cooldown-ready events provide concise slot-addressed visual feedback. Presentation observes domain state and events; it never grants effects or advances cooldowns.

## 8. Error and Transaction Guarantees

All action arithmetic uses checked integer operations and `SimulationDuration`. Floating point is presentation-only. Any validation, targeting, arithmetic, damage, healing, reward, unlock, loot, or next-encounter failure rejects the complete candidate state.

A Power Strike victory cannot expose damage without its reward transition. Guard cannot redirect an attack without atomically consuming its effect. Mend cannot start cooldown without committing its heal. Failed saves preserve the last durable action state under the existing save coordinator guarantees.

## 9. Testing and Live QA

Implementation proceeds as TDD vertical slices:

1. action definitions, persisted state, and validation;
2. deterministic cooldown advancement and freeze rules;
3. Guard interception and expiration;
4. Power Strike damage, DPS, and victory transaction;
5. Mend targeting and healing;
6. management and interactive/passive rail presentation;
7. full regression and live QA.

Focused tests cover save round trips, invalid state, newcomer readiness, partition invariance, downed cooldown freeze, encounter carryover, every rejection rollback, checked overflow, Guard redirect/reduction/expiration, Power Strike defense/DPS/victory, Mend ratio ties/full-health/downed behavior, slot-addressed events, disabled reasons, and passive rail click-through.

The final gate runs the complete arm64 suite, clean unsigned arm64 build, context guard, exact-bundle launch, and live three-class casts. Live QA confirms Guard interception, Power Strike damage and DPS, Mend targeting, cooldown carryover, relaunch persistence, management controls, and passive versus interactive rail behavior.

## 10. Completion Criteria

The milestone is complete when each class can manually cast its one deterministic cooldown-only action from management and the interactive rail, all action state persists safely, passive overlay behavior remains unchanged, action outcomes preserve transactional combat and reward guarantees, and every automated, build, context, launch, and live-QA gate passes.
