# DockBarHero Phase 1 Deterministic Time Recovery Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this recovery with test-driven development and independent review.

**Goal:** Replace the failed floating-point combat clock with a bounded fixed-point time domain that guarantees deterministic ordering, exact chunk invariance, and finite work for every accepted input.

**Architecture:** Gameplay state stores signed 64-bit nanoseconds through `SimulationDuration`; `GameSimulation` performs only checked integer timing arithmetic. Accepted attack intervals are at least 1 millisecond and one `advance(by:)` call is at most 10 seconds, bounding scheduled combat actions without a per-call event budget. Floating-point conversion is presentation-only.

**Tech Stack:** Swift 6.3.2, Foundation, XCTest, Xcode 26.5, XcodeGen 2.45.4.

## Root Cause

The current implementation stores countdowns and elapsed time as `Double` and requires exact chunk-independent outcomes for every finite value. Binary floating subtraction, `Decimal` conversion, ULP clamping, and a per-call event budget cannot jointly satisfy that contract:

- Tiny positive values can fail to reduce a larger `Double`.
- `Decimal` does not represent the full finite `Double` range.
- Repeated conversion changes deadline results across chunks.
- A per-call event budget rejects one large call while equivalent smaller calls succeed.

The time domain itself must be explicit and bounded.

## Binding Recovery Contract

- `SimulationDuration` is the only gameplay timing value.
- Its canonical representation is signed `Int64` nanoseconds.
- It conforms to `RawRepresentable`, `Codable`, `Hashable`, `Comparable`, and `Sendable`.
- It provides checked construction helpers for nanoseconds, milliseconds, and whole seconds plus a presentation-only `timeInterval` conversion.
- Negative raw values can be constructed so boundary validation can return errors instead of trapping.
- Combat state, balance configuration, encounter state, and simulation timing contain no `TimeInterval`, `Double`, or `Decimal` fields.
- Minimum accepted hero or enemy attack interval: 1,000,000 ns (1 ms).
- Maximum accepted elapsed value for one `advance(by:)`: 10,000,000,000 ns (10 s).
- Revive delay is nonnegative and no greater than 10 s in this slice.
- Countdown and active-elapsed arithmetic uses checked `Int64` addition/subtraction. Overflow returns an error before caller-visible mutation.
- `advance(by:)` runs on a candidate copy and commits only on success.
- No epsilon, rounding, readiness clamp, `Decimal`, or event-count budget is permitted.
- Exact ties resolve the hero first. A representable one-nanosecond difference must not become a tie.
- For any total duration expressible as accepted `SimulationDuration` chunks, event order and complete `GameState` equality are exact regardless of chunk partitioning.
- The live driver in Task 4 will use an integer monotonic source and cap callbacks to 1 s, which is inside the simulation's 10 s contract.

## Files

- Create: `DockBarHero/Game/SimulationDuration.swift`
- Modify: `DockBarHero/Game/GameModels.swift`
- Modify: `DockBarHero/Game/BalanceConfiguration.swift`
- Modify: `DockBarHero/Game/GameSimulation.swift`
- Create: `DockBarHeroTests/SimulationDurationTests.swift`
- Modify: `DockBarHeroTests/BalanceConfigurationTests.swift`
- Replace timing-focused portions: `DockBarHeroTests/GameSimulationTests.swift`
- Modify: `docs/superpowers/specs/2026-07-10-dockbarhero-phase-1-playable-slice-design.md`
- Modify: `docs/superpowers/plans/2026-07-10-dockbarhero-phase-1-playable-slice.md`
- Generate: `DockBarHero.xcodeproj/`

## Interfaces

```swift
struct SimulationDuration: RawRepresentable, Codable, Hashable, Comparable, Sendable {
    let rawValue: Int64

    static let zero = SimulationDuration(rawValue: 0)
    static let minimumAttackInterval = SimulationDuration(rawValue: 1_000_000)
    static let maximumAdvance = SimulationDuration(rawValue: 10_000_000_000)

    static func nanoseconds(_ value: Int64) -> SimulationDuration
    static func milliseconds(_ value: Int64) -> SimulationDuration?
    static func seconds(_ value: Int64) -> SimulationDuration?
    var timeInterval: TimeInterval { get }
}
```

`CombatantState.attackInterval`, `CombatantState.timeUntilNextAttack`, `EncounterState.activeElapsed`, `EncounterState.reviveRemaining`, `BalanceConfiguration.heroAttackInterval`, `enemyAttackInterval`, and `reviveDelay` all become `SimulationDuration`.

`GameSimulation` exposes:

```swift
mutating func advance(by elapsed: SimulationDuration) throws -> [GameEvent]
```

`SimulationError` contains:

```swift
case invalidElapsed
case invalidTimer
case arithmeticOverflow
```

Remove `eventDensity` because the supported time domain statically bounds work.

## TDD Sequence

1. Write `SimulationDuration` construction, ordering, Codable round-trip, and checked-overflow tests.
2. Rewrite simulation tests to use `.milliseconds(...)`, `.seconds(...)`, or exact nanoseconds.
3. Add RED tests proving:
   - A 999,999,999 ns advance does not fire a 1 s attack.
   - An enemy due at 1 s resolves before a hero due at 1,000,000,001 ns.
   - One 1,200,000 ns advance and three 400,000 ns advances produce exactly equal state/events.
   - One 2.1 s advance and three 0.7 s advances produce exactly equal state/events.
   - A 999,999 ns attack interval is rejected before mutation.
   - Negative and greater-than-10-second elapsed values are rejected before mutation.
   - Checked arithmetic overflow is rejected before mutation.
   - The three-second hero-first victory order and same-level revive behavior remain unchanged.
4. Run the focused tests and capture the expected compile failures from the old timing types.
5. Implement `SimulationDuration` and migrate domain state.
6. Replace floating arithmetic with checked integer arithmetic on a candidate copy.
7. Remove Decimal, ULP, and event-budget logic.
8. Update the approved design and main implementation plan so DPS timestamps and the driver use fixed-point time.
9. Regenerate Xcode project.
10. Run focused `SimulationDurationTests`, `BalanceConfigurationTests`, and `GameSimulationTests`.
11. Run the complete suite and a clean arm64 build.
12. Commit and obtain independent Terra review of the complete recovery diff.

## Acceptance Gate

- Every focused and complete test passes.
- Clean arm64 build succeeds.
- `rg -n 'TimeInterval|Decimal|maximumScheduledEventsPerAdvance|eventDensity' DockBarHero/Game` returns matches only for the presentation-only `SimulationDuration.timeInterval` property.
- Complete `GameState` equality is used for chunk-invariance tests; no floating accuracy helper is needed.
- Independent review finds no unresolved Critical or Important timing issue.
- The feature branch remains local and unmerged until the original final Phase 1 gate.
